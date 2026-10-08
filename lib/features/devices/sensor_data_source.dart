import 'dart:async';
import '../../shared/models/health_reading.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/device_info.dart';

/// Abstract Hardware Sensor Data Source.
///
/// Decouples the rest of the application (AI inference, risk engine, UI)
/// from whether data is originating from a real ESP32 BLE device or mock simulation.
abstract class SensorDataSource {
  /// Stream of normalized physiological readings (HR, SpO2, Temp, Activity)
  Stream<HealthReading> get healthStream;

  /// Stream of 3-axis IMU readings (AccX, AccY, AccZ, Falls)
  Stream<MotionReading> get motionStream;

  /// Stream of environmental context (Temp, Humidity, AQI, Heat Index)
  Stream<EnvironmentReading> get environmentStream;

  /// Stream of device status (Connection state, battery, RSSI)
  Stream<DeviceInfo> get deviceStatusStream;

  /// Connection controls
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> startScanning();
  Future<void> stopScanning();

  /// Sensor calibration & lifecycle
  void dispose();
}
