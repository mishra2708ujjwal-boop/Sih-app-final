import '../../core/constants/ble_constants.dart';

/// Configurable BLE Wearable Parameters
///
/// Change these parameters to target custom ESP32/nRF firmware.
class BleConfig {
  final String targetDeviceName;
  final String serviceUuid;
  final String telemetryStreamCharacteristicUuid;
  final String heartRateCharacteristicUuid;
  final String spo2CharacteristicUuid;
  final String temperatureCharacteristicUuid;
  final String motionCharacteristicUuid;
  final String batteryCharacteristicUuid;

  const BleConfig({
    this.targetDeviceName = BleConstants.targetDeviceName,
    this.serviceUuid = BleConstants.serviceUuid,
    this.telemetryStreamCharacteristicUuid = BleConstants.telemetryStreamCharacteristicUuid,
    this.heartRateCharacteristicUuid = BleConstants.heartRateCharacteristicUuid,
    this.spo2CharacteristicUuid = BleConstants.spo2CharacteristicUuid,
    this.temperatureCharacteristicUuid = BleConstants.temperatureCharacteristicUuid,
    this.motionCharacteristicUuid = BleConstants.motionCharacteristicUuid,
    this.batteryCharacteristicUuid = BleConstants.batteryCharacteristicUuid,
  });
}
