/*
 * PRANA Band — STEP 2: real sensor firmware
 * ---------------------------------------------------------------------------
 * Same BLE transport as prana_band_ble_test.ino, but every value sent is an
 * actual measurement. Flash this only after the link test has worked.
 *
 * TIMING (why this file is structured the way it is)
 *   IMU      sampled at  50 Hz  — fast enough to catch a fall impact peak
 *   Fall     detected on-device at that 50 Hz, sent as "isFallSuspected"
 *   Packets  sent at     10 Hz  — smooth live graph in the app
 *   HR/SpO2  recomputed at ~1 Hz (the Maxim algorithm needs a 4 s window)
 *   DHT      read every 2.5 s   (the part cannot be polled faster)
 * Nothing in the loop blocks: everything is scheduled off millis().
 *
 * WHY THE ESP32 DETECTS THE FALL, NOT THE APP
 *   An impact peak lasts 100-300 ms. At the app's 10 Hz packet rate the peak
 *   usually falls between samples, so a phone-side threshold would miss real
 *   falls. The app already honours a hardware flag: MotionReading reads
 *   "isFallSuspected" and FallDetectionService treats it as a direct trigger
 *   ahead of its own threshold logic. So detection runs here, at full rate.
 *
 * SENSORS
 *   MAX30102  (I2C)  -> heart rate + SpO2      [SparkFun MAX3010x library]
 *   MPU6050   (I2C)  -> accX/accY/accZ, steps, activity, falls  [Adafruit]
 *   DHT22/11  (1 pin)-> envTemp, envHumidity   [Adafruit DHT sensor library]
 *   MLX90614  (I2C)  -> body temperature (OPTIONAL, see HAS_MLX90614 below)
 *
 * LIBRARIES to install in Arduino IDE (Library Manager):
 *   ArduinoJson · SparkFun MAX3010x · Adafruit MPU6050 ·
 *   Adafruit Unified Sensor · DHT sensor library · (Adafruit MLX90614)
 *
 * WIRING — these are ESP32 DevKit defaults. Change them to match your board.
 *   All I2C sensors share: SDA -> GPIO21, SCL -> GPIO22, VIN -> 3V3, GND -> GND
 *   DHT data -> GPIO4 (with a 10k pull-up to 3V3)
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Wire.h>

#include <MAX30105.h>
#include <spo2_algorithm.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>

// Body temperature needs a skin/IR sensor. Set to 1 only if an MLX90614 is
// wired. Left at 0, the "temperature" field is omitted and the app falls back
// to its 36.7 default — so wire one before you trust the temperature card.
#define HAS_MLX90614 0
#if HAS_MLX90614
#include <Adafruit_MLX90614.h>
Adafruit_MLX90614 mlx;
#endif

// ── Must match lib/core/constants/ble_constants.dart ───────────────────────
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "PRANA_BAND_PRO"

// ── Pins ───────────────────────────────────────────────────────────────────
#define I2C_SDA  21
#define I2C_SCL  22
#define DHT_PIN  4
#define DHT_TYPE DHT22   // use DHT11 if that is the part you have

// ── Schedules (milliseconds) ───────────────────────────────────────────────
#define IMU_PERIOD_MS     20    //  50 Hz
#define PACKET_PERIOD_MS  100   //  10 Hz
#define DHT_PERIOD_MS     2500

// ── Fall detection thresholds, in g ────────────────────────────────────────
// IMPACT_G mirrors AppConstants.fallAccelerationThresholdG so the phone and
// the band agree on what counts as an impact.
#define IMPACT_G          2.8f
#define FREEFALL_G        0.55f   // magnitude dips toward 0 g while falling
#define STILL_BAND_G      0.18f   // |magnitude - 1 g| below this = at rest
#define STILL_HOLD_MS     1200    // rest must persist this long to confirm
#define FALL_WINDOW_MS    2500    // rest must begin within this of the impact
#define REFRACTORY_MS     15000   // ignore new falls for this long after one

// ── BLE state ──────────────────────────────────────────────────────────────
BLEServer* pServer = NULL;
BLECharacteristic* pTelemetryCharacteristic = NULL;
bool deviceConnected = false;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) {
    deviceConnected = true;
    Serial.println("PRANA app connected.");
  }
  void onDisconnect(BLEServer* s) {
    deviceConnected = false;
    Serial.println("App disconnected — advertising again.");
    BLEDevice::startAdvertising();
  }
};

// ── Sensors ────────────────────────────────────────────────────────────────
MAX30105 particleSensor;
Adafruit_MPU6050 mpu;
DHT dht(DHT_PIN, DHT_TYPE);

// ── Optical (HR / SpO2) ────────────────────────────────────────────────────
// The Maxim algorithm works on a 100-sample window at 25 Hz. The buffer fills
// non-blockingly; each time it is full we recompute and slide it by 25.
const int32_t BUF_LEN = 100;
uint32_t irBuffer[BUF_LEN];
uint32_t redBuffer[BUF_LEN];
int32_t bufIndex = 0;
int32_t spo2 = 0;
int8_t validSpo2 = 0;
int32_t heartRate = 0;
int8_t validHeartRate = 0;
bool fingerOn = false;

// ── Motion ─────────────────────────────────────────────────────────────────
float accX = 0, accY = 0, accZ = 1.0f;
uint32_t stepCount = 0;
float lastMag = 1.0f;
bool rising = false;
uint32_t lastStepMs = 0;
float motionEma = 0.0f;          // smoothed |magnitude - 1 g|, drives activity

// ── Fall state machine ─────────────────────────────────────────────────────
enum FallPhase { FALL_IDLE, FALL_IMPACTED };
FallPhase fallPhase = FALL_IDLE;
uint32_t impactMs = 0;
uint32_t stillSinceMs = 0;
bool freefallSeen = false;
uint32_t freefallMs = 0;
uint32_t refractoryUntilMs = 0;
bool fallFlagPending = false;    // sent in exactly one packet, then cleared
float peakG = 0.0f;

// ── Environment cache ──────────────────────────────────────────────────────
float envTempC = NAN;
float envHumidity = NAN;

// ── Schedulers ─────────────────────────────────────────────────────────────
uint32_t lastImuMs = 0;
uint32_t lastPacketMs = 0;
uint32_t lastDhtMs = 0;
bool vitalsFresh = false;        // a new HR/SpO2 result is waiting to be sent

// ---------------------------------------------------------------------------
// Motion: 50 Hz sampling, step counting, and on-device fall detection.
// ---------------------------------------------------------------------------
void sampleMotion() {
  sensors_event_t a, g, t;
  if (!mpu.getEvent(&a, &g, &t)) return;

  // m/s^2 -> g. The app's threshold and its GATT parser both work in g, so the
  // conversion has to happen here. Do not remove it.
  accX = a.acceleration.x / 9.81f;
  accY = a.acceleration.y / 9.81f;
  accZ = a.acceleration.z / 9.81f;

  const float mag = sqrtf(accX * accX + accY * accY + accZ * accZ);
  const uint32_t now = millis();

  // ---- activity level: smoothed deviation from 1 g ----
  motionEma = 0.9f * motionEma + 0.1f * fabsf(mag - 1.0f);

  // ---- step counting: rise past ~1.15 g then fall, debounced 300 ms ----
  if (mag > lastMag && mag > 1.15f) {
    rising = true;
  } else if (rising && mag < lastMag && (now - lastStepMs) > 300) {
    stepCount++;
    lastStepMs = now;
    rising = false;
  }
  lastMag = mag;

  // ---- fall detection ----
  if (now < refractoryUntilMs) return;

  // Free-fall usually precedes the impact. Remembering it for a second lets us
  // demand a lower impact threshold for a real fall than for a knock.
  if (mag < FREEFALL_G) {
    freefallSeen = true;
    freefallMs = now;
  } else if (freefallSeen && (now - freefallMs) > 1000) {
    freefallSeen = false;
  }

  switch (fallPhase) {
    case FALL_IDLE:
      // A hard knock on a table also spikes; requiring either a preceding
      // free-fall or a much larger peak keeps those out.
      if (mag > IMPACT_G && (freefallSeen || mag > 3.6f)) {
        fallPhase = FALL_IMPACTED;
        impactMs = now;
        stillSinceMs = 0;
        peakG = mag;
        Serial.printf("Impact %.2f g%s — watching for stillness\n", mag,
                      freefallSeen ? " (after free-fall)" : "");
      }
      break;

    case FALL_IMPACTED: {
      if (mag > peakG) peakG = mag;

      // After a real fall the body comes to rest: magnitude sits near 1 g
      // (gravity only) and stops changing.
      const bool atRest = fabsf(mag - 1.0f) < STILL_BAND_G;
      if (atRest) {
        if (stillSinceMs == 0) stillSinceMs = now;
        if ((now - stillSinceMs) >= STILL_HOLD_MS) {
          fallFlagPending = true;
          fallPhase = FALL_IDLE;
          freefallSeen = false;
          refractoryUntilMs = now + REFRACTORY_MS;
          Serial.printf("FALL CONFIRMED — peak %.2f g, then %d ms still\n",
                        peakG, (int)(now - stillSinceMs));
        }
      } else {
        stillSinceMs = 0;
      }

      // Still moving when the window closes: they caught themselves.
      if ((now - impactMs) > FALL_WINDOW_MS && stillSinceMs == 0) {
        fallPhase = FALL_IDLE;
        Serial.println("Impact but movement continued — not a fall.");
      }
      break;
    }
  }
}

const char* activityLabel() {
  if (motionEma > 0.35f) return "Vigorous";
  if (motionEma > 0.15f) return "Moderate";
  if (motionEma > 0.05f) return "Light";
  return "Resting";
}

// ---------------------------------------------------------------------------
// Optical: drain whatever the MAX30102 FIFO has ready, without blocking.
// ---------------------------------------------------------------------------
void pollOptical() {
  particleSensor.check();
  while (particleSensor.available()) {
    redBuffer[bufIndex] = particleSensor.getRed();
    irBuffer[bufIndex] = particleSensor.getIR();
    particleSensor.nextSample();
    bufIndex++;

    if (bufIndex >= BUF_LEN) {
      maxim_heart_rate_and_oxygen_saturation(irBuffer, BUF_LEN, redBuffer,
                                            &spo2, &validSpo2, &heartRate,
                                            &validHeartRate);

      // Finger presence: the IR channel collapses when nothing is on the lens.
      uint64_t irSum = 0;
      for (int32_t i = 0; i < BUF_LEN; i++) irSum += irBuffer[i];
      fingerOn = (irSum / BUF_LEN) > 50000;
      vitalsFresh = true;

      // Slide the window by 25 samples (~1 s at 25 Hz).
      for (int32_t i = 25; i < BUF_LEN; i++) {
        redBuffer[i - 25] = redBuffer[i];
        irBuffer[i - 25] = irBuffer[i];
      }
      bufIndex = BUF_LEN - 25;
    }
  }
}

// ---------------------------------------------------------------------------
void sendPacket() {
  StaticJsonDocument<256> doc;

  // Motion goes out every packet: the app's fall-detection page needs a
  // continuous IMU trace whether or not a finger is on the pulse sensor.
  doc["accX"] = accX;
  doc["accY"] = accY;
  doc["accZ"] = accZ;
  doc["steps"] = stepCount;
  doc["activityLevel"] = activityLabel();

  // Exactly one packet carries the flag. Repeating it would restart the app's
  // SOS countdown on every packet and it could never finish or be cancelled.
  if (fallFlagPending) {
    doc["isFallSuspected"] = true;
    fallFlagPending = false;
  }

  // Vitals only when a fresh, valid result exists (~1 Hz). Omitting the keys
  // is deliberate — the app then leaves its vitals cards on "waiting" rather
  // than showing a stale or invented number.
  if (vitalsFresh) {
    vitalsFresh = false;
    const bool usable = fingerOn && validHeartRate && validSpo2 &&
                        heartRate > 30 && heartRate < 220 && spo2 > 70;
    if (usable) {
      doc["heartRate"] = heartRate;
      doc["spo2"] = spo2;
#if HAS_MLX90614
      doc["temperature"] = mlx.readObjectTempC();  // skin temperature
#endif
    } else {
      Serial.println(fingerOn ? "Signal unstable — vitals withheld."
                              : "No finger on sensor — vitals withheld.");
    }
  }

  if (!isnan(envTempC)) doc["envTemp"] = envTempC;
  if (!isnan(envHumidity)) doc["envHumidity"] = envHumidity;

  // Replace with a real divider reading on an ADC pin if your build has one.
  // doc["battery"] = map(analogRead(34), 1860, 2400, 0, 100);

  char buffer[256];
  const size_t n = serializeJson(doc, buffer);
  pTelemetryCharacteristic->setValue((uint8_t*)buffer, n);
  pTelemetryCharacteristic->notify();
}

// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Wire.begin(I2C_SDA, I2C_SCL);

  // ---- MAX30102 ----
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found — check I2C wiring.");
    while (1) delay(1000);
  }
  // ledBrightness, sampleAverage, ledMode(2=red+IR), sampleRate,
  // pulseWidth, adcRange — the SpO2 algorithm assumes this configuration.
  particleSensor.setup(60, 4, 2, 100, 411, 4096);

  // ---- MPU6050 ----
  if (!mpu.begin()) {
    Serial.println("MPU6050 not found — check I2C wiring.");
  } else {
    // 16 g range: a fall impact can exceed 8 g and would otherwise clip.
    mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
    mpu.setFilterBandwidth(MPU6050_BAND_44_HZ);
  }

  // ---- DHT + optional MLX90614 ----
  dht.begin();
#if HAS_MLX90614
  mlx.begin();
#endif

  // ---- BLE ----
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pTelemetryCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pTelemetryCharacteristic->addDescriptor(new BLE2902());  // required for notify

  pService->start();
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("Advertising as: " DEVICE_NAME);
}

void loop() {
  const uint32_t now = millis();

  if (now - lastImuMs >= IMU_PERIOD_MS) {
    lastImuMs = now;
    sampleMotion();
  }

  pollOptical();

  if (now - lastDhtMs >= DHT_PERIOD_MS) {
    lastDhtMs = now;
    envTempC = dht.readTemperature();
    envHumidity = dht.readHumidity();
  }

  if (now - lastPacketMs >= PACKET_PERIOD_MS) {
    lastPacketMs = now;
    if (deviceConnected) {
      sendPacket();
    } else if (now % 1000 < PACKET_PERIOD_MS) {
      Serial.printf("accZ %.2f  HR %ld  (app not connected)\n", accZ,
                    heartRate);
    }
  }
}
