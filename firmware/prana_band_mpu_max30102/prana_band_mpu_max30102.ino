/*
 * PRANA Band — MPU6050 + MAX30102 firmware
 * ---------------------------------------------------------------------------
 * Drives BOTH sensors over the single BLE link. The app shows them as two
 * SEPARATE graphs on two different screens — they are never combined:
 *
 *   MPU6050  accX/Y/Z  -> Me > Device and data > Fall detection  (motion trace)
 *   MAX30102 heartRate -> Vitals > Heart   (BPM line)
 *   MAX30102 spo2      -> Vitals > Oxygen  (SpO2 line)
 *
 * The loop is fully non-blocking so neither sensor stalls the other:
 *   MPU6050  sampled + fall check   50 Hz   (catches an impact peak)
 *   MAX30102 FIFO drained           ~25 Hz  (HR/SpO2 recomputed once a second)
 *   BLE packet sent                 10 Hz   (smooth live motion graph)
 *
 * Fall detection runs ON the ESP32 (a 100-300 ms impact peak falls between
 * 10 Hz packets, so a phone-side check would miss it). When it fires, one
 * packet carries "isFallSuspected": true and the app's existing
 * FallDetectionService treats that as a direct trigger.
 *
 * LIBRARIES (Arduino IDE -> Library Manager)
 *   ArduinoJson · SparkFun MAX3010x · Adafruit MPU6050 · Adafruit Unified Sensor
 *
 * WIRING (ESP32 DevKit defaults — both sensors share the I2C bus)
 *   MAX30102  VIN -> 3V3   GND -> GND   SDA -> GPIO21   SCL -> GPIO22
 *   MPU6050   VCC -> 3V3   GND -> GND   SDA -> GPIO21   SCL -> GPIO22
 *   (MAX30102 = I2C 0x57, MPU6050 = 0x68 — no address clash.)
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

// ── Must match lib/core/constants/ble_constants.dart ───────────────────────
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "PRANA_BAND_PRO"

// ── Pins ───────────────────────────────────────────────────────────────────
#define I2C_SDA  21
#define I2C_SCL  22

// ── Schedules (milliseconds) ───────────────────────────────────────────────
#define IMU_PERIOD_MS     20    //  50 Hz
#define PACKET_PERIOD_MS  100   //  10 Hz

// ── Fall detection thresholds, in g ────────────────────────────────────────
#define IMPACT_G       2.8f     // mirrors AppConstants.fallAccelerationThresholdG
#define FREEFALL_G     0.55f
#define STILL_BAND_G   0.18f
#define STILL_HOLD_MS  1200
#define FALL_WINDOW_MS 2500
#define REFRACTORY_MS  15000

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

// ── MAX30102 heart rate / SpO2 (Maxim sliding-window algorithm) ────────────
const int32_t BUF_LEN = 100;
uint32_t irBuffer[BUF_LEN];
uint32_t redBuffer[BUF_LEN];
int32_t bufIdx = 0;
int32_t spo2 = 0;
int8_t validSpo2 = 0;
int32_t heartRate = 0;
int8_t validHeartRate = 0;
bool fingerOn = false;

// ── MPU6050 motion ─────────────────────────────────────────────────────────
float accX = 0, accY = 0, accZ = 1.0f;
uint32_t stepCount = 0;
float lastMag = 1.0f;
bool rising = false;
uint32_t lastStepMs = 0;
float motionEma = 0.0f;

// ── Fall state machine ─────────────────────────────────────────────────────
enum FallPhase { FALL_IDLE, FALL_IMPACTED };
FallPhase fallPhase = FALL_IDLE;
uint32_t impactMs = 0;
uint32_t stillSinceMs = 0;
bool freefallSeen = false;
uint32_t freefallMs = 0;
uint32_t refractoryUntilMs = 0;
bool fallFlagPending = false;
float peakG = 0.0f;

// ── Schedulers ─────────────────────────────────────────────────────────────
uint32_t lastImuMs = 0;
uint32_t lastPacketMs = 0;

// ---------------------------------------------------------------------------
// Drain the MAX30102 FIFO whenever samples are ready (non-blocking). Every 25
// fresh samples (~1 s at the 25 Hz effective rate) recompute HR + SpO2 over a
// sliding 100-sample window.
// ---------------------------------------------------------------------------
void serviceOptical() {
  particleSensor.check();
  while (particleSensor.available()) {
    redBuffer[bufIdx] = particleSensor.getRed();
    irBuffer[bufIdx] = particleSensor.getIR();
    particleSensor.nextSample();
    bufIdx++;

    if (bufIdx >= BUF_LEN) {
      maxim_heart_rate_and_oxygen_saturation(
          irBuffer, BUF_LEN, redBuffer, &spo2, &validSpo2, &heartRate,
          &validHeartRate);

      // Finger presence: the IR channel collapses with nothing on the sensor.
      uint64_t irSum = 0;
      for (int32_t i = 0; i < BUF_LEN; i++) irSum += irBuffer[i];
      fingerOn = (irSum / BUF_LEN) > 50000;

      // Slide the window: keep the last 75, refill from index 75.
      for (int32_t i = 25; i < BUF_LEN; i++) {
        redBuffer[i - 25] = redBuffer[i];
        irBuffer[i - 25] = irBuffer[i];
      }
      bufIdx = 75;
    }
  }
}

// ---------------------------------------------------------------------------
// 50 Hz: MPU6050 sample, step count, and on-device fall detection.
// ---------------------------------------------------------------------------
void sampleMotion() {
  sensors_event_t a, g, t;
  if (!mpu.getEvent(&a, &g, &t)) return;

  // m/s^2 -> g. The app's threshold and GATT parser both work in g.
  accX = a.acceleration.x / 9.81f;
  accY = a.acceleration.y / 9.81f;
  accZ = a.acceleration.z / 9.81f;

  const float mag = sqrtf(accX * accX + accY * accY + accZ * accZ);
  const uint32_t now = millis();

  motionEma = 0.9f * motionEma + 0.1f * fabsf(mag - 1.0f);

  if (mag > lastMag && mag > 1.15f) {
    rising = true;
  } else if (rising && mag < lastMag && (now - lastStepMs) > 300) {
    stepCount++;
    lastStepMs = now;
    rising = false;
  }
  lastMag = mag;

  if (now < refractoryUntilMs) return;

  if (mag < FREEFALL_G) {
    freefallSeen = true;
    freefallMs = now;
  } else if (freefallSeen && (now - freefallMs) > 1000) {
    freefallSeen = false;
  }

  switch (fallPhase) {
    case FALL_IDLE:
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
// 10 Hz: one packet. Motion is always present (drives the fall graph). Pulse
// keys are added only when the optical signal is valid — so the Heart and
// Oxygen graphs stay idle rather than showing an invented number when the
// finger is off the sensor.
// ---------------------------------------------------------------------------
void sendPacket() {
  StaticJsonDocument<192> doc;
  doc["accX"] = accX;
  doc["accY"] = accY;
  doc["accZ"] = accZ;
  doc["steps"] = stepCount;
  doc["activityLevel"] = activityLabel();

  const bool hrOk = fingerOn && validHeartRate && heartRate > 30 &&
                    heartRate < 220;
  const bool spo2Ok = fingerOn && validSpo2 && spo2 > 70 && spo2 <= 100;
  if (hrOk) doc["heartRate"] = heartRate;
  if (spo2Ok) doc["spo2"] = spo2;

  if (fallFlagPending) {
    doc["isFallSuspected"] = true;  // exactly one packet, then cleared
    fallFlagPending = false;
  }

  char buffer[192];
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
    Serial.println("MAX30102 not found — check I2C wiring / address 0x57.");
    while (1) delay(1000);
  }
  // ledBrightness, sampleAverage(4), ledMode(2=red+IR), sampleRate(100),
  // pulseWidth(411), adcRange(4096). Averaging 4 gives ~25 Hz output — the
  // rate the Maxim HR/SpO2 algorithm expects.
  particleSensor.setup(60, 4, 2, 100, 411, 4096);

  // ---- MPU6050 ----
  if (!mpu.begin()) {
    Serial.println("MPU6050 not found — check I2C wiring / address 0x68.");
    while (1) delay(1000);
  }
  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);  // headroom for impact peaks
  mpu.setFilterBandwidth(MPU6050_BAND_44_HZ);

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

  serviceOptical();  // every iteration — keeps the FIFO from overflowing

  if (now - lastImuMs >= IMU_PERIOD_MS) {
    lastImuMs = now;
    sampleMotion();
  }

  if (now - lastPacketMs >= PACKET_PERIOD_MS) {
    lastPacketMs = now;
    if (deviceConnected) {
      sendPacket();
    } else if (now % 1000 < PACKET_PERIOD_MS) {
      Serial.printf("accZ %.2f  HR %ld  SpO2 %ld  finger:%s  (not connected)\n",
                    accZ, heartRate, spo2, fingerOn ? "yes" : "no");
    }
  }
}
