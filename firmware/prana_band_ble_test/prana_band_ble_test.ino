/*
 * PRANA Band — STEP 1: BLE link test
 * ---------------------------------------------------------------------------
 * This is the sketch from docs/esp32_hardware_integration_guide.html.
 * Its only job is to prove that ESP32 -> BLE -> PRANA app works. It needs NO
 * sensors wired and only ONE library (ArduinoJson), so it compiles and runs on
 * a bare ESP32 board.
 *
 * IMPORTANT: the vitals below are SYNTHETIC placeholders, not measurements.
 * Once the app shows these numbers, the transport is proven — then flash
 * ../prana_band/prana_band.ino for real sensor data.
 *
 * Board: any ESP32 (DevKit v1, ESP32-S3, ...)
 * Library: ArduinoJson (Library Manager)
 * Serial: 115200 baud
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

// These three MUST match lib/core/constants/ble_constants.dart
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "PRANA_BAND_PRO"

BLEServer* pServer = NULL;
BLECharacteristic* pTelemetryCharacteristic = NULL;
bool deviceConnected = false;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("PRANA App Connected via BLE!");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("App Disconnected! Restarting Advertising...");
    BLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);

  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pTelemetryCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);

  // Without BLE2902 the phone connects but never receives a notification.
  pTelemetryCharacteristic->addDescriptor(new BLE2902());

  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("ESP32 BLE Advertising as: " DEVICE_NAME);
}

void loop() {
  if (deviceConnected) {
    // ---- SYNTHETIC values: link test only, replace with real sensors ----
    float hr = 76.0 + random(-2, 3);
    float spo2 = 98.2 + (random(0, 10) / 10.0);
    float temp = 36.7;
    int steps = 3420;
    int battery = 88;

    StaticJsonDocument<256> doc;
    doc["heartRate"] = hr;
    doc["spo2"] = spo2;
    doc["temperature"] = temp;
    doc["activityLevel"] = "Moderate";
    doc["steps"] = steps;
    doc["accX"] = 0.02;
    doc["accY"] = 0.04;
    doc["accZ"] = 0.98;
    doc["battery"] = battery;

    char buffer[256];
    serializeJson(doc, buffer);

    pTelemetryCharacteristic->setValue((uint8_t*)buffer, strlen(buffer));
    pTelemetryCharacteristic->notify();

    Serial.print("Sent Telemetry: ");
    Serial.println(buffer);
  }
  delay(1000);  // the app expects roughly 1 packet per second
}
