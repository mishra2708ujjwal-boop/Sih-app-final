import '../../shared/models/health_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/risk_result.dart';
import '../ai/prediction_model.dart';

/// Clinical Contextual Recommendation Engine
///
/// Produces specific, physiological and environment-grounded early interventions.
/// Strictly avoids vague generic cliches like "Stay healthy" or "Drink water".
class RecommendationEngine {
  RecommendationEngine._();

  static Map<String, String> generateRecommendations({
    required RiskLevel level,
    required PredictionResult mlPrediction,
    required HealthReading health,
    required EnvironmentReading environment,
    required double hrDeviationPercent,
    required double spo2DropPoints,
    required double tempElevation,
  }) {
    String primary = 'Biometric telemetry aligns with your learned baseline. Maintain normal hydration and routine.';
    String secondary = 'Autonomic cardiac recovery is optimal.';

    // 1. Critical / High Heat Stress Scenario
    if (mlPrediction.heatStressProbability > 0.65 || tempElevation > 1.0 || environment.heatIndex > 38.0) {
      if (hrDeviationPercent > 15.0) {
        primary = 'Move to a shaded or air-conditioned environment immediately and cease physical exertion.';
        secondary = 'Your heart rate is +${hrDeviationPercent.toStringAsFixed(0)}% above baseline under severe heat strain (${environment.temperature}°C). Sip electrolyte fluids.';
      } else {
        primary = 'High ambient heat exposure detected (${environment.temperature}°C, ${environment.humidity}% humidity). Limit outdoor exposure.';
        secondary = 'Hydrate with cool fluids and monitor internal temperature.';
      }
    }
    // 2. Toxic Air Quality & Respiratory Risk Scenario
    else if (mlPrediction.respiratoryRiskProbability > 0.6 || environment.aqi > 200 || spo2DropPoints > 3.0) {
      if (health.spo2 < 93.0) {
        primary = 'Poor ambient air quality (AQI ${environment.aqi}) accompanied by SpO₂ drop (${health.spo2}%). Wear an N95 respirator or stay indoors.';
        secondary = 'Sit upright, practice relaxed diaphragm breathing, and monitor SpO₂ stability.';
      } else {
        primary = 'Hazardous ambient AQI (${environment.aqi}) detected. Avoid strenuous cardiovascular activities.';
        secondary = 'Keep windows closed and run air purification if available.';
      }
    }
    // 3. Cardiovascular Anomaly Scenario
    else if (mlPrediction.cardiovascularRiskProbability > 0.6 || hrDeviationPercent > 25.0) {
      primary = 'Unusual cardiac acceleration detected (${health.heartRate.toStringAsFixed(0)} BPM, +${hrDeviationPercent.toStringAsFixed(0)}% above normal baseline).';
      secondary = 'Sit down and rest quietly for 5 minutes. If shortness of breath or dizziness occurs, trigger SOS.';
    }
    // 4. Autonomic Fatigue & Sleep Debt Scenario
    else if (mlPrediction.fatigueProbability > 0.65) {
      primary = 'Significant autonomic fatigue and reduced HRV detected. Reduce physical workload today.';
      secondary = 'Prioritize early sleep and light recovery hydration.';
    }
    // 5. Moderate Mixed Risk
    else if (level == RiskLevel.moderate) {
      if (hrDeviationPercent > 10.0) {
        primary = 'Heart rate is mildly elevated above your resting baseline. Take a 10-minute rest break.';
        secondary = 'Ensure adequate hydration in current conditions (${environment.temperature}°C).';
      } else if (environment.aqi > 100) {
        primary = 'Moderate air pollution (AQI ${environment.aqi}). Sensitive individuals should limit prolonged outdoor exertion.';
        secondary = 'Vitals currently stable within personal normal bounds.';
      } else {
        primary = 'Mild physiological variation detected. Keep your PRANA band snug on your wrist.';
        secondary = 'Resting indicators remain stable.';
      }
    }

    return {
      'primary': primary,
      'secondary': secondary,
    };
  }
}
