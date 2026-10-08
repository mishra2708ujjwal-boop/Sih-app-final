import 'dart:convert';
import 'dart:typed_data';
import '../../shared/models/health_reading.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/models/environment_reading.dart';

/// Sensor Packet Parser
/// Decodes both structured JSON telemetry packets and raw binary BLE GATT characteristic buffers.
class SensorParser {
  SensorParser._();

  /// Parse JSON telemetry payload from ESP32 / Wearable
  /// Example JSON:
  /// {
  ///   "heartRate": 82.5,
  ///   "spo2": 97.2,
  ///   "temperature": 36.85,
  ///   "activityLevel": "Moderate",
  ///   "steps": 4120,
  ///   "accX": 0.08,
  ///   "accY": 0.14,
  ///   "accZ": 0.98,
  ///   "envTemp": 27.5,
  ///   "envHumidity": 54.0,
  ///   "aqi": 48,
  ///   "battery": 86,
  ///   "timestamp": 1724784000000
  /// }
  static Map<String, dynamic>? parseJsonTelemetry(String rawString) {
    try {
      final decoded = jsonDecode(rawString) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Parse Standard Bluetooth SIG Heart Rate Measurement (0x2A37) Characteristic
  /// Flags byte: Bit 0 = 0 (UINT8 HR) or 1 (UINT16 HR)
  static double parseGattHeartRate(Uint8List data) {
    if (data.isEmpty) return 72.0;
    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    if (is16Bit && data.length >= 3) {
      return (data[1] | (data[2] << 8)).toDouble();
    } else if (data.length >= 2) {
      return data[1].toDouble();
    }
    return 72.0;
  }

  /// Parse Standard Pulse Oximeter Continuous (0x2A5F) Characteristic
  static double parseGattSpo2(Uint8List data) {
    if (data.length < 3) return 98.0;
    // Standard GATT: SpO2 percentage in index 1
    return data[1].toDouble().clamp(70.0, 100.0);
  }

  /// Parse Standard Health Thermometer (0x2A1C) Characteristic IEEE-11073 FLOAT
  static double parseGattTemperature(Uint8List data) {
    if (data.length < 5) return 36.7;
    final mantissa = data[1] | (data[2] << 8) | (data[3] << 16);
    final exponent = data[4].toSigned(8);
    return mantissa * (exponent == -1 ? 0.1 : 0.01);
  }

  /// Parse Standard Battery Level (0x2A19) Characteristic (0-100%)
  static int parseGattBatteryLevel(Uint8List data) {
    if (data.isEmpty) return 0;
    return data[0].clamp(0, 100);
  }

  /// Parse binary 3-axis accelerometer data (6 bytes: int16 X, int16 Y, int16 Z in milli-g)
  static MotionReading parseGattMotion(Uint8List data) {
    if (data.length < 6) {
      return MotionReading(
        accX: 0.0,
        accY: 0.0,
        accZ: 1.0,
        activityState: 'Stationary',
        timestamp: DateTime.now(),
      );
    }
    final byteData = ByteData.sublistView(data);
    final rawX = byteData.getInt16(0, Endian.little);
    final rawY = byteData.getInt16(2, Endian.little);
    final rawZ = byteData.getInt16(4, Endian.little);
    final x = rawX / 1000.0;
    final y = rawY / 1000.0;
    final z = rawZ / 1000.0;
    return MotionReading(
      accX: x,
      accY: y,
      accZ: z,
      activityState: (x.abs() > 0.3 || y.abs() > 0.3) ? 'Active' : 'Stationary',
      timestamp: DateTime.now(),
    );
  }

  /// Convert parsed JSON map into domain HealthReading
  static HealthReading toHealthReading(Map<String, dynamic> json) {
    return HealthReading.fromJson(normalizeTelemetryKeys(json));
  }

  /// Reconciles the two packet spellings this project's hardware uses.
  ///
  /// The reference firmware in `docs/esp32_hardware_integration_guide.html`
  /// sends `heartRate` / `spo2` / `temperature`; compact sketches send
  /// `hr` / `spo2` / `temp`. Accepting both here means neither firmware needs a
  /// change, and no domain model has to know about wire formats.
  ///
  /// It also guards the two casts in `HealthReading.fromJson` that would throw
  /// on a valid-but-differently-typed packet — one exception there drops the
  /// whole reading, so a single stray field would show as "no data at all".
  static Map<String, dynamic> normalizeTelemetryKeys(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.of(json);

    void alias(String from, String to) {
      if (out[to] == null && out[from] != null) out[to] = out[from];
    }

    alias('hr', 'heartRate');
    alias('temp', 'temperature');

    // IMU: compact sketches spell the accelerometer axes `ax`/`ay`/`az`.
    // Values are expected in g — the app's fall threshold (2.8 g) and
    // `parseGattMotion` both work in g, so a firmware reporting m/s² must
    // divide by 9.81 before sending. See firmware/prana_band/prana_band.ino.
    alias('ax', 'accX');
    alias('ay', 'accY');
    alias('az', 'accZ');

    // steps is read with `as int?`: coerce a float-valued step count.
    final steps = out['steps'];
    if (steps is num && steps is! int) out['steps'] = steps.toInt();

    // timestamp is read with `as String`. Anything else (an ArduinoJson
    // `millis()` value, for instance) is dropped so the packet is stamped with
    // phone time on arrival instead of being thrown away.
    final ts = out['timestamp'];
    if (ts != null && (ts is! String || DateTime.tryParse(ts) == null)) {
      out.remove('timestamp');
    }

    return out;
  }

  /// Convert parsed JSON map into domain MotionReading
  static MotionReading toMotionReading(Map<String, dynamic> json) {
    return MotionReading.fromJson(normalizeTelemetryKeys(json));
  }

  /// Convert parsed JSON map into domain EnvironmentReading
  static EnvironmentReading toEnvironmentReading(Map<String, dynamic> json) {
    return EnvironmentReading.fromJson(normalizeTelemetryKeys(json));
  }
}
