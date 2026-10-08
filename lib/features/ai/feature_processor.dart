import '../../shared/models/health_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/sleep_reading.dart';
import '../../shared/models/user_baseline.dart';

/// 16-Dimensional Feature Extraction & Normalization Layer
/// Transforms multi-modal inputs (Biometrics + Baseline + Environment + Sleep + Trends)
/// into a standardized float array for the on-device risk model. The layout is
/// the tensor contract in `assets/models/README.md`, so a trained `.tflite` can
/// replace the current logistic scorer without changing this file.
class FeatureProcessor {
  FeatureProcessor._();

  /// Build normalized 16-element feature vector
  static List<double> extractFeatureVector({
    required HealthReading health,
    required EnvironmentReading environment,
    required UserBaseline baseline,
    SleepReading? sleep,
    double hrTrendSlope = 0.0,
  }) {
    // 0. Normalized Heart Rate [40 - 200 BPM] -> [0.0, 1.0]
    final f0Hrnorm = ((health.heartRate - 40.0) / 160.0).clamp(0.0, 1.0);

    // 1. Heart Rate Baseline Deviation Ratio
    final hrBaselineMid = (baseline.normalHrMin + baseline.normalHrMax) / 2.0;
    final f1Hrdev = ((health.heartRate - hrBaselineMid) / hrBaselineMid).clamp(-1.0, 2.0);

    // 2. Normalized SpO2 [70 - 100%] -> [0.0, 1.0]
    final f2Spo2norm = ((health.spo2 - 70.0) / 30.0).clamp(0.0, 1.0);

    // 3. SpO2 Baseline Drop (Points below user baseline min)
    final f3Spo2drop = (baseline.normalSpo2Min - health.spo2).clamp(0.0, 30.0) / 10.0;

    // 4. Normalized Body Temperature [34.0 - 42.0 °C] -> [0.0, 1.0]
    final f4Tempnorm = ((health.bodyTemperature - 34.0) / 8.0).clamp(0.0, 1.0);

    // 5. Body Temperature Baseline Deviation
    final f5Tempdev = ((health.bodyTemperature - baseline.normalTempMax) / 2.0).clamp(-1.0, 2.0);

    // 6. Activity Level [0.0: Rest, 0.3: Low, 0.6: Moderate, 1.0: High]
    double f6Activity = 0.5;
    if (health.activityLevel.toLowerCase().contains('rest')) {
      f6Activity = 0.0;
    } else if (health.activityLevel.toLowerCase().contains('low')) {
      f6Activity = 0.25;
    } else if (health.activityLevel.toLowerCase().contains('high')) {
      f6Activity = 0.85;
    }

    // 7. Sleep Duration Ratio (relative to 8 hours)
    final sleepMins = sleep?.totalDurationMinutes ?? 450;
    final f7Sleepduration = (sleepMins / 480.0).clamp(0.0, 1.5);

    // 8. Sleep Quality Score [0.0 - 1.0]
    final f8Sleepquality = ((sleep?.sleepQualityScore ?? 80.0) / 100.0).clamp(0.0, 1.0);

    // 9. Normalized Ambient Temperature [-10 - 55 °C] -> [0.0, 1.0]
    final f9Envtemp = ((environment.temperature - (-10.0)) / 65.0).clamp(0.0, 1.0);

    // 10. Normalized Humidity [0 - 100%] -> [0.0, 1.0]
    final f10Humidity = (environment.humidity / 100.0).clamp(0.0, 1.0);

    // 11. Normalized AQI [0 - 500] -> [0.0, 1.0]
    final f11Aqi = (environment.aqi / 500.0).clamp(0.0, 1.0);

    // 12. Normalized Heat Index [0 - 60 °C] -> [0.0, 1.0]
    final f12Heatindex = (environment.heatIndex / 60.0).clamp(0.0, 1.0);

    // 13. Continuous Heat Exposure Duration (hours / 8.0)
    final f13Exposure = (environment.heatExposureHours / 8.0).clamp(0.0, 1.5);

    // 14. HRV RMSSD Normalized [0 - 150 ms] -> [0.0, 1.0] (Lower HRV = Higher stress)
    final f14Hrv = (health.hrvRmssd / 150.0).clamp(0.0, 1.0);

    // 15. Biometric Slope / Rate of Change
    final f15Trendslope = hrTrendSlope.clamp(-2.0, 2.0);

    return [
      f0Hrnorm,
      f1Hrdev,
      f2Spo2norm,
      f3Spo2drop,
      f4Tempnorm,
      f5Tempdev,
      f6Activity,
      f7Sleepduration,
      f8Sleepquality,
      f9Envtemp,
      f10Humidity,
      f11Aqi,
      f12Heatindex,
      f13Exposure,
      f14Hrv,
      f15Trendslope,
    ];
  }
}
