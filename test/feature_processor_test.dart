import 'package:flutter_test/flutter_test.dart';
import 'package:prana_health/features/ai/feature_processor.dart';
import 'package:prana_health/shared/models/health_reading.dart';
import 'package:prana_health/shared/models/environment_reading.dart';
import 'package:prana_health/shared/models/user_baseline.dart';
import 'package:prana_health/shared/models/sleep_reading.dart';

void main() {
  group('FeatureProcessor Tests', () {
    test('Extracts 16 normalized features within bounds [0.0, 1.0]', () {
      final health = HealthReading(
        heartRate: 75.0,
        spo2: 98.0,
        bodyTemperature: 36.7,
        activityLevel: 'Moderate',
        steps: 3500,
        restingHeartRate: 68.0,
        hrvRmssd: 50.0,
        timestamp: DateTime.now(),
      );

      final env = EnvironmentReading(
        temperature: 28.0,
        humidity: 50.0,
        aqi: 60,
        heatIndex: 29.0,
        aqiCategory: 'Moderate',
        weatherCondition: 'Clear',
        heatExposureHours: 1.0,
        timestamp: DateTime.now(),
      );

      final baseline = UserBaseline.defaultBaseline();

      final sleep = SleepReading(
        totalDurationMinutes: 480,
        deepSleepMinutes: 120,
        remSleepMinutes: 100,
        lightSleepMinutes: 220,
        awakeMinutes: 40,
        sleepQualityScore: 85.0,
        restingHeartRate: 64.0,
        respiratoryRate: 15.0,
        recoveryIndex: 88.0,
        hypnogramStages: const [0, 1, 2, 3],
        date: DateTime.now(),
      );

      final vector = FeatureProcessor.extractFeatureVector(
        health: health,
        environment: env,
        baseline: baseline,
        sleep: sleep,
      );

      expect(vector.length, equals(16));
      for (int i = 0; i < vector.length; i++) {
        expect(vector[i].isFinite, isTrue, reason: 'Feature $i is not finite');
      }
    });
  });
}
