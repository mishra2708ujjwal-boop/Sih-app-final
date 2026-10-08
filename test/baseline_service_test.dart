import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prana_health/core/database/local_storage_service.dart';
import 'package:prana_health/features/baseline/baseline_service.dart';
import 'package:prana_health/shared/models/health_reading.dart';

void main() {
  group('BaselineService Tests', () {
    late LocalStorageService storage;
    late BaselineService baselineService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      baselineService = BaselineService(storage);
    });

    test('Initial baseline starts with default bounds and 0 learned readings', () {
      final baseline = baselineService.currentBaseline;
      expect(baseline.totalReadingsLearned, equals(0));
      expect(baseline.normalHrMin, equals(65.0));
      expect(baseline.normalHrMax, equals(88.0));
    });

    test('Calculates HR deviation percent correctly', () {
      // Normal range: 65 - 88 BPM
      expect(baselineService.getHrDeviationPercent(75.0), equals(0.0));

      // Above upper bound: 110 BPM vs 88 max = +25%
      final dev = baselineService.getHrDeviationPercent(110.0);
      expect(dev, closeTo(25.0, 0.1));
    });

    test('Calculates SpO2 drop points correctly', () {
      // Normal min: 95%
      expect(baselineService.getSpo2DropPoints(98.0), equals(0.0));
      expect(baselineService.getSpo2DropPoints(91.0), equals(4.0));
    });

    test('Records resting readings and refines baseline without throwing', () {
      for (int i = 0; i < 25; i++) {
        baselineService.recordReading(
          HealthReading(
            heartRate: 72.0 + (i % 3),
            spo2: 98.0,
            bodyTemperature: 36.6,
            activityLevel: 'Rest',
            steps: 100,
            restingHeartRate: 70.0,
            hrvRmssd: 50.0,
            timestamp: DateTime.now(),
          ),
        );
      }

      final updated = baselineService.currentBaseline;
      expect(updated.totalReadingsLearned, greaterThan(0));
    });
  });
}
