import 'package:flutter_test/flutter_test.dart';
import 'package:prana_health/features/risk/risk_engine.dart';
import 'package:prana_health/features/ai/prediction_model.dart';
import 'package:prana_health/shared/models/health_reading.dart';
import 'package:prana_health/shared/models/environment_reading.dart';
import 'package:prana_health/shared/models/user_baseline.dart';
import 'package:prana_health/shared/models/risk_result.dart';

void main() {
  group('RiskEngine Tests', () {
    late RiskEngine riskEngine;

    setUp(() {
      riskEngine = RiskEngine();
    });

    test('Calculates safe risk under normal resting physiological conditions', () {
      final health = HealthReading(
        heartRate: 72.0,
        spo2: 98.5,
        bodyTemperature: 36.6,
        activityLevel: 'Rest',
        steps: 2000,
        restingHeartRate: 70.0,
        hrvRmssd: 55.0,
        timestamp: DateTime.now(),
      );

      final env = EnvironmentReading(
        temperature: 24.0,
        humidity: 45.0,
        aqi: 35,
        heatIndex: 24.0,
        aqiCategory: 'Good',
        weatherCondition: 'Clear',
        heatExposureHours: 0.0,
        timestamp: DateTime.now(),
      );

      final baseline = UserBaseline.defaultBaseline();
      final ml = PredictionResult.initial();

      final risk = riskEngine.calculateRisk(
        health: health,
        environment: env,
        baseline: baseline,
        mlPrediction: ml,
        hrDeviationPercent: 0.0,
        spo2DropPoints: 0.0,
        tempElevation: 0.0,
      );

      expect(risk.overallScore, lessThan(35));
      expect(risk.level, equals(RiskLevel.safe));
      expect(risk.primaryRecommendation, isNotEmpty);
      expect(risk.drivers, isNotEmpty);
    });

    test('Calculates high or critical risk under extreme heat stress and tachycardia', () {
      final health = HealthReading(
        heartRate: 125.0,
        spo2: 93.0,
        bodyTemperature: 38.8,
        activityLevel: 'Low (Stressed)',
        steps: 4000,
        restingHeartRate: 70.0,
        hrvRmssd: 18.0,
        timestamp: DateTime.now(),
      );

      final env = EnvironmentReading(
        temperature: 42.0,
        humidity: 70.0,
        aqi: 160,
        heatIndex: 52.0,
        aqiCategory: 'Unhealthy',
        weatherCondition: 'Heatwave',
        heatExposureHours: 3.5,
        timestamp: DateTime.now(),
      );

      final baseline = UserBaseline.defaultBaseline();
      final ml = PredictionResult(
        heatStressProbability: 0.92,
        dehydrationRiskProbability: 0.88,
        fatigueProbability: 0.75,
        respiratoryRiskProbability: 0.70,
        cardiovascularRiskProbability: 0.85,
        overallAnomalyProbability: 0.90,
        timestamp: DateTime.now(),
      );

      final risk = riskEngine.calculateRisk(
        health: health,
        environment: env,
        baseline: baseline,
        mlPrediction: ml,
        hrDeviationPercent: 42.0,
        spo2DropPoints: 2.0,
        tempElevation: 1.5,
      );

      expect(risk.overallScore, greaterThan(65));
      expect(risk.level == RiskLevel.high || risk.level == RiskLevel.critical, isTrue);
    });
  });
}
