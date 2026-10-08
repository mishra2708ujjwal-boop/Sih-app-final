import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/models/health_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/user_baseline.dart';
import '../../shared/models/risk_result.dart';
import '../ai/prediction_model.dart';
import '../recommendations/recommendation_engine.dart';

/// Multi-Domain Personalized Risk Engine
///
/// Synthesizes Edge-AI predictions, personal baseline deviations, environmental heat/air indices,
/// and recent rate of change into an explainable 0-100 Risk Score with key driving factors.
class RiskEngine {
  int _previousScore = 18;

  /// EMA of the headline score. The mock band emits a fresh reading every two
  /// seconds with a little physiological noise; snapping the displayed number
  /// straight to each raw score makes it jitter and flips the trend arrow on
  /// every tick. Easing toward the raw score keeps a resting demo visibly
  /// steady while a disaster scenario still climbs — just smoothly.
  double? _smoothedScore;

  /// How far the displayed score moves toward each new raw score. Lower is
  /// calmer; 0.28 settles a steady state in a few seconds yet still reacts
  /// clearly when a scenario changes.
  static const double _scoreSmoothing = 0.28;

  RiskResult calculateRisk({
    required HealthReading health,
    required EnvironmentReading environment,
    required UserBaseline baseline,
    required PredictionResult mlPrediction,
    required double hrDeviationPercent,
    required double spo2DropPoints,
    required double tempElevation,
  }) {
    // 1. Compute Individual Domain Risk Subscores [0.0 - 1.0]

    // Domain A: Heat Stress Risk (Compound of ML heat prob + Temp elevation + Env Heat Index)
    final heatEnvFactor = (environment.heatIndex - 27.0).clamp(0.0, 25.0) / 25.0;
    final heatPhysioFactor = (tempElevation / 2.0).clamp(0.0, 1.0);
    final heatStressScore = (0.5 * mlPrediction.heatStressProbability +
            0.3 * heatEnvFactor +
            0.2 * heatPhysioFactor)
        .clamp(0.0, 1.0);

    // Domain B: Respiratory Risk (Compound of ML resp prob + AQI factor + SpO2 drop)
    final aqiFactor = (environment.aqi / 400.0).clamp(0.0, 1.0);
    final spo2Factor = (spo2DropPoints / 6.0).clamp(0.0, 1.0);
    final respiratoryScore = (0.5 * mlPrediction.respiratoryRiskProbability +
            0.3 * aqiFactor +
            0.2 * spo2Factor)
        .clamp(0.0, 1.0);

    // Domain C: Cardiovascular Risk (Compound of ML cardio prob + HR deviation % + Temp stress)
    final hrDevFactor = (hrDeviationPercent / 35.0).clamp(0.0, 1.0);
    final cardiovascularScore = (0.55 * mlPrediction.cardiovascularRiskProbability +
            0.35 * hrDevFactor +
            0.10 * heatPhysioFactor)
        .clamp(0.0, 1.0);

    // Domain D: Autonomic Fatigue Risk (Compound of ML fatigue prob + HRV deficit)
    final fatigueScore = mlPrediction.fatigueProbability.clamp(0.0, 1.0);

    // 2. Synthesize Composite Risk Score [0 - 100]
    // Uses highest domain risk as dominant driver, plus weighted contributions from others
    final maxDomain = max(max(heatStressScore, respiratoryScore), max(cardiovascularScore, fatigueScore));
    final meanDomain = (heatStressScore + respiratoryScore + cardiovascularScore + fatigueScore) / 4.0;
    final anomalyWeight = mlPrediction.overallAnomalyProbability;

    final rawComposite = (0.50 * maxDomain + 0.30 * meanDomain + 0.20 * anomalyWeight) * 100.0;

    // Ease the displayed score toward the raw value instead of snapping to it,
    // so tick-to-tick sensor noise doesn't make the headline number flicker.
    // No artificial cap: the score spans the full 0–100 range so genuine risk
    // climbs into the Moderate/High/Critical bands instead of being held down.
    final prevSmoothed = _smoothedScore ?? rawComposite;
    final smoothed = prevSmoothed + (rawComposite - prevSmoothed) * _scoreSmoothing;
    _smoothedScore = smoothed;
    final overallScore = smoothed.round().clamp(0, 100);

    // 3. Categorize into Semantic Risk Level
    RiskLevel level;
    if (overallScore < 30) {
      level = RiskLevel.safe;
    } else if (overallScore < 60) {
      level = RiskLevel.moderate;
    } else if (overallScore < 80) {
      level = RiskLevel.high;
    } else {
      level = RiskLevel.critical;
    }

    // 4. Compute Dynamic Trend
    String trend;
    final delta = overallScore - _previousScore;
    if (delta > 8) {
      trend = 'Spiking';
    } else if (delta > 2) {
      trend = 'Increasing';
    } else if (delta < -3) {
      trend = 'Improving';
    } else {
      trend = 'Stable';
    }
    _previousScore = overallScore;

    // 5. Determine Top Contributing Drivers
    final drivers = <DriverFactor>[];

    if (hrDeviationPercent > 5.0) {
      drivers.add(DriverFactor(
        title: 'Heart Rate',
        description: '+${hrDeviationPercent.toStringAsFixed(0)}% above personal baseline',
        impactPercentage: min(1.0, hrDeviationPercent / 30.0),
        icon: Icons.favorite,
      ));
    } else {
      drivers.add(DriverFactor(
        title: 'Heart Rate',
        description: 'Within normal range (${health.heartRate.toStringAsFixed(0)} BPM)',
        impactPercentage: 0.15,
        icon: Icons.favorite,
      ));
    }

    if (environment.heatIndex > 32.0 || tempElevation > 0.3) {
      drivers.add(DriverFactor(
        title: 'Heat Stress',
        description: 'Ambient ${environment.temperature}°C (HI ${environment.heatIndex}°C)',
        impactPercentage: min(1.0, heatStressScore),
        icon: Icons.thermostat,
      ));
    }

    if (environment.aqi > 100 || spo2DropPoints > 1.5) {
      drivers.add(DriverFactor(
        title: 'Air Quality / SpO₂',
        description: 'AQI ${environment.aqi} (${environment.aqiCategory})',
        impactPercentage: min(1.0, respiratoryScore),
        icon: Icons.air,
      ));
    }

    if (fatigueScore > 0.45) {
      drivers.add(DriverFactor(
        title: 'Recovery Debt',
        description: 'Autonomic strain elevated',
        impactPercentage: fatigueScore,
        icon: Icons.bedtime,
      ));
    }

    // Sort drivers by descending impact
    drivers.sort((a, b) => b.impactPercentage.compareTo(a.impactPercentage));

    // 6. Generate Contextual Recommendations
    final recs = RecommendationEngine.generateRecommendations(
      level: level,
      mlPrediction: mlPrediction,
      health: health,
      environment: environment,
      hrDeviationPercent: hrDeviationPercent,
      spo2DropPoints: spo2DropPoints,
      tempElevation: tempElevation,
    );

    return RiskResult(
      overallScore: overallScore,
      level: level,
      trend: trend,
      heatStressRisk: double.parse(heatStressScore.toStringAsFixed(2)),
      fatigueRisk: double.parse(fatigueScore.toStringAsFixed(2)),
      respiratoryRisk: double.parse(respiratoryScore.toStringAsFixed(2)),
      cardiovascularRisk: double.parse(cardiovascularScore.toStringAsFixed(2)),
      anomalyProbability: mlPrediction.overallAnomalyProbability,
      drivers: drivers.take(3).toList(),
      primaryRecommendation: recs['primary']!,
      secondaryRecommendation: recs['secondary']!,
      confidence: 0.92,
      timestamp: DateTime.now(),
    );
  }
}
