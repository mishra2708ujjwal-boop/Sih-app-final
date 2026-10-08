import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:prana_health/features/devices/sensor_parser.dart';

void main() {
  group('SensorParser Tests', () {
    test('Parse valid JSON telemetry packet', () {
      const jsonString = '''
      {
        "heartRate": 84.5,
        "spo2": 97.2,
        "temperature": 36.85,
        "activityLevel": "Moderate",
        "steps": 4120,
        "accX": 0.08,
        "accY": 0.14,
        "accZ": 0.98,
        "envTemp": 27.5,
        "envHumidity": 54.0,
        "aqi": 48,
        "battery": 86
      }
      ''';

      final map = SensorParser.parseJsonTelemetry(jsonString);
      expect(map, isNotNull);

      final health = SensorParser.toHealthReading(map!);
      expect(health.heartRate, equals(84.5));
      expect(health.spo2, equals(97.2));
      expect(health.bodyTemperature, equals(36.85));
      expect(health.activityLevel, equals('Moderate'));
      expect(health.steps, equals(4120));

      final motion = SensorParser.toMotionReading(map);
      expect(motion.accX, equals(0.08));
      expect(motion.accY, equals(0.14));
      expect(motion.accZ, equals(0.98));

      final env = SensorParser.toEnvironmentReading(map);
      expect(env.temperature, equals(27.5));
      expect(env.humidity, equals(54.0));
      expect(env.aqi, equals(48));
    });

    test('Parse invalid JSON returns null gracefully without crashing', () {
      const invalidJson = 'NOT_JSON_DATA_BUFFER';
      final map = SensorParser.parseJsonTelemetry(invalidJson);
      expect(map, isNull);
    });

    test('Parse Standard GATT 8-bit Heart Rate (0x2A37)', () {
      // Byte 0: flags (0 = 8-bit HR), Byte 1: HR value 78
      final data = Uint8List.fromList([0x00, 78]);
      final hr = SensorParser.parseGattHeartRate(data);
      expect(hr, equals(78.0));
    });

    test('Parse Standard GATT 16-bit Heart Rate (0x2A37)', () {
      // Byte 0: flags (Bit 0 set = 16-bit HR), Byte 1: low, Byte 2: high (130 BPM)
      final data = Uint8List.fromList([0x01, 130, 0]);
      final hr = SensorParser.parseGattHeartRate(data);
      expect(hr, equals(130.0));
    });

    test('Parse Standard GATT SpO2 (0x2A5F)', () {
      final data = Uint8List.fromList([0x00, 98, 0x00]);
      final spo2 = SensorParser.parseGattSpo2(data);
      expect(spo2, equals(98.0));
    });

    test('Parse Standard GATT Battery Level (0x2A19)', () {
      final data = Uint8List.fromList([88]);
      final battery = SensorParser.parseGattBatteryLevel(data);
      expect(battery, equals(88));
    });
  });
}
