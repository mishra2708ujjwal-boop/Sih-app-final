import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Semantic Risk Levels
enum RiskLevel {
  safe,
  moderate,
  high,
  critical;

  String get displayName {
    switch (this) {
      case RiskLevel.safe:
        return 'SAFE';
      case RiskLevel.moderate:
        return 'MODERATE';
      case RiskLevel.high:
        return 'HIGH';
      case RiskLevel.critical:
        return 'CRITICAL';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.safe:
        return AppColors.riskSafe;
      case RiskLevel.moderate:
        return AppColors.riskModerate;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  Color get bgColor {
    switch (this) {
      case RiskLevel.safe:
        return AppColors.riskSafeBg;
      case RiskLevel.moderate:
        return AppColors.riskModerateBg;
      case RiskLevel.high:
        return AppColors.riskHighBg;
      case RiskLevel.critical:
        return AppColors.riskCriticalBg;
    }
  }
}

/// Contributing Driver Factor with quantitative percentage impact
class DriverFactor {
  final String title;              // e.g. 'Heart Rate'
  final String description;        // e.g. '+18% above baseline'
  final double impactPercentage;   // 0.0 - 1.0 (relative weight)
  final IconData icon;

  const DriverFactor({
    required this.title,
    required this.description,
    required this.impactPercentage,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'impactPercentage': impactPercentage,
      };
}

/// Synthesized Multi-Domain Health Risk Result produced by the Risk Engine
class RiskResult {
  final int overallScore;          // 0 - 100
  final RiskLevel level;
  final String trend;              // 'Improving', 'Stable', 'Increasing', 'Spiking'
  final double heatStressRisk;     // 0.0 - 1.0
  final double fatigueRisk;        // 0.0 - 1.0
  final double respiratoryRisk;    // 0.0 - 1.0
  final double cardiovascularRisk; // 0.0 - 1.0
  final double anomalyProbability; // Edge ML output
  final List<DriverFactor> drivers;
  final String primaryRecommendation;
  final String secondaryRecommendation;
  final double confidence;         // 0.0 - 1.0
  final DateTime timestamp;

  const RiskResult({
    required this.overallScore,
    required this.level,
    required this.trend,
    required this.heatStressRisk,
    required this.fatigueRisk,
    required this.respiratoryRisk,
    required this.cardiovascularRisk,
    required this.anomalyProbability,
    required this.drivers,
    required this.primaryRecommendation,
    required this.secondaryRecommendation,
    required this.confidence,
    required this.timestamp,
  });

  factory RiskResult.initial() {
    return RiskResult(
      overallScore: 18,
      level: RiskLevel.safe,
      trend: 'Stable',
      heatStressRisk: 0.12,
      fatigueRisk: 0.20,
      respiratoryRisk: 0.08,
      cardiovascularRisk: 0.15,
      anomalyProbability: 0.05,
      drivers: const [
        DriverFactor(
          title: 'Heart Rate',
          description: 'Within normal baseline (74 BPM)',
          impactPercentage: 0.2,
          icon: Icons.favorite,
        ),
        DriverFactor(
          title: 'Environment',
          description: 'Optimal ambient index (24°C)',
          impactPercentage: 0.15,
          icon: Icons.thermostat,
        ),
      ],
      primaryRecommendation: 'Physiological vitals align with your learned baseline. Maintain normal hydration and routine.',
      secondaryRecommendation: 'Resting cardiac recovery is optimal.',
      confidence: 0.94,
      timestamp: DateTime.now(),
    );
  }
}
