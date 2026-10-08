/// BLE Hardware Configuration & UUID Constants
///
/// NOTE FOR HARDWARE INTEGRATION:
/// When flashing your ESP32 / Arduino / nRF52 wearable firmware, ensure the GATT Service
/// and Characteristic UUIDs match the definitions below or update this configuration file.
class BleConstants {
  BleConstants._();

  // Target Wearable Device Advertising Name
  static const String targetDeviceName = 'PRANA_BAND_PRO';
  static const String fallbackDevicePrefix = 'PRANA_';

  // Primary Health Service UUID (Standard 128-bit or 16-bit Custom)
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // Characteristic UUIDs
  static const String telemetryStreamCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String heartRateCharacteristicUuid = '00002a37-0000-1000-8000-00805f9b34fb'; // Standard Heart Rate Measurement
  static const String spo2CharacteristicUuid = '00002a5f-0000-1000-8000-00805f9b34fb';      // Pulse Oximeter Continuous
  static const String temperatureCharacteristicUuid = '00002a1c-0000-1000-8000-00805f9b34fb'; // Health Thermometer
  static const String motionCharacteristicUuid = 'c8659210-90fb-4d1a-85d7-160ec8c8c501';      // 3-Axis IMU Packet
  static const String batteryCharacteristicUuid = '00002a19-0000-1000-8000-00805f9b34fb';     // Battery Level

  // Connection Parameters
  static const int scanTimeoutSeconds = 12;
  static const int connectionTimeoutSeconds = 10;
  static const int maxReconnectAttempts = 3;
}
