/*
 * PRANA Band — MPU6050-ONLY firmware
 * ---------------------------------------------------------------------------
 * Use this when the MPU6050 is the only sensor wired. It streams live
 * accelerometer data and runs on-device fall detection — exactly what the
 * app's Fall Detection page needs. No pulse sensor, no DHT, no body temp.
 *
 * The app is fine with a motion-only packet: it only shows the cards a packet
 * actually carries data for, so the vitals screens simply stay on "waiting"
 * while this sketch runs. Nothing is faked.
 *
 * TIMING
 *   IMU sampled + fall check at 50 Hz  — fast enough to catch an impact peak
 *   Packets sent at            10 Hz   — smooth live graph in the app
 * The loop never blocks; both are scheduled off millis().
 *
 * WHY THE ESP32 DETECTS THE FALL (not the app)
 *   An impact peak lasts 100-300 ms. At the 10 Hz packet rate the peak usually
 *   falls between samples, so a phone-side threshold would miss real falls.
 *   The app honours a hardware flag: MotionReading reads "isFallSuspected" and
 *   FallDetectionService treats it as a direct trigger. So detection runs here.
 *
 * LIBRARIES (Arduino IDE → Library Manager)
 *   ArduinoJson · Adafruit MPU6050 · Adafruit Unified Sensor
 *
 * WIRING (ESP32 DevKit defaults — change to match your board)
 *   MPU6050  VCC -> 3V3   GND -> GND   SDA -> GPIO21   SCL -> GPIO22
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <Wire.h>

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
// IMPACT_G mirrors AppConstants.fallAccelerationThresholdG so the phone and
// the band agree on what counts as an impact.
#define IMPACT_G      2.8f
#define FREEFALL_G    0.55f   // magnitude dips toward 0 g while falling
#define STILL_BAND_G  0.18f   // |magnitude - 1 g| below this = at rest
#define STILL_HOLD_MS 1200    // rest must persist this long to confirm
#define FALL_WINDOW_MS 2500   // rest must begin within this of the impact
#define REFRACTORY_MS 15000   // ignore new falls for this long after one

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

// ── Sensor ─────────────────────────────────────────────────────────────────
Adafruit_MPU6050 mpu;

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

// ── Schedulers ─────────────────────────────────────────────────────────────
uint32_t lastImuMs = 0;
uint32_t lastPacketMs = 0;

// ---------------------------------------------------------------------------
// 50 Hz: sample the IMU, count steps, and run fall detection on-device.
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
// 10 Hz: one motion packet. No vitals keys — the app leaves those cards idle.
// ---------------------------------------------------------------------------
void sendPacket() {
  StaticJsonDocument<160> doc;
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

  char buffer[160];
  const size_t n = serializeJson(doc, buffer);
  pTelemetryCharacteristic->setValue((uint8_t*)buffer, n);
  pTelemetryCharacteristic->notify();
}

// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  Wire.begin(I2C_SDA, I2C_SCL);

  if (!mpu.begin()) {
    Serial.println("MPU6050 not found — check I2C wiring.");
    while (1) delay(1000);
  }
  // 16 g range: a fall impact can exceed 8 g and would otherwise clip.
  mpu.setAccelerometerRange(MPU6050_RANGE_16_G);
  mpu.setFilterBandwidth(MPU6050_BAND_44_HZ);

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

  if (now - lastPacketMs >= PACKET_PERIOD_MS) {
    lastPacketMs = now;
    if (deviceConnected) {
      sendPacket();
    } else if (now % 1000 < PACKET_PERIOD_MS) {
      Serial.printf("accX %.2f  accY %.2f  accZ %.2f  (app not connected)\n",
                    accX, accY, accZ);
    }
  }
}
