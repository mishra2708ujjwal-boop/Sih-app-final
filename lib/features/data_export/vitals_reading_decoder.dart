import '../ai/feature_schema.dart';

/// A stored 16-feature vector decoded back into human-readable, real-world
/// units — the mathematical inverse of `FeatureProcessor.extractFeatureVector`.
///
/// PRANA stores each calm reading as a normalized vector (see
/// `feature_processor.dart` / [FeatureSchema]), which is exactly what the
/// on-device model trains on but is unreadable to a person. This decoder undoes
/// the normalization using the SAME frozen constants from [FeatureSchema], so
/// an export reads "HR 72 BPM, SpO2 98%" instead of raw floats. Because it
/// references the schema constants directly, it can never drift out of sync
/// with the forward contract.
///
/// Three features are intentionally NOT surfaced: f1/f3/f5 are baseline-relative
/// deviations whose per-reading baseline isn't stored (and are redundant with
/// the absolute f0/f2/f4). Values are linear inverses of clamped inputs, so a
/// reading that sits exactly on a sensor limit means "at or beyond" that limit.
class DecodedReading {
  const DecodedReading({
    required this.heartRateBpm,
    required this.spo2Pct,
    required this.bodyTempC,
    required this.activity,
    required this.hrvRmssdMs,
    required this.hrTrendBpmPerMin,
    required this.sleepHours,
    required this.sleepQuality,
    required this.ambientTempC,
    required this.humidityPct,
    required this.aqi,
    required this.heatIndexC,
    required this.heatExposureHours,
  });

  final double heartRateBpm; // f0
  final double spo2Pct; // f2
  final double bodyTempC; // f4
  final String activity; // f6 (categorical)
  final double hrvRmssdMs; // f14
  final double hrTrendBpmPerMin; // f15
  final double sleepHours; // f7
  final double sleepQuality; // f8
  final double ambientTempC; // f9
  final double humidityPct; // f10
  final double aqi; // f11
  final double heatIndexC; // f12
  final double heatExposureHours; // f13

  /// Decode a stored feature vector. Short/empty vectors decode what they can
  /// and leave the rest at 0 rather than throwing, so a malformed row can never
  /// break an export.
  static DecodedReading fromFeatures(List<double> f) {
    double at(int i) => i < f.length ? f[i] : 0.0;
    return DecodedReading(
      heartRateBpm: at(0) * FeatureSchema.hrRangeBpm + FeatureSchema.hrMinBpm,
      spo2Pct: at(2) * FeatureSchema.spo2RangePct + FeatureSchema.spo2MinPct,
      bodyTempC: at(4) * FeatureSchema.tempRangeC + FeatureSchema.tempMinC,
      activity: _activityLabel(at(6)),
      hrvRmssdMs: at(14) * FeatureSchema.hrvMaxMs,
      hrTrendBpmPerMin: at(15) * FeatureSchema.trendNormalizationBpmPerMin,
      sleepHours: at(7) * FeatureSchema.sleepGoalMinutes / 60.0,
      sleepQuality: at(8) * 100.0,
      ambientTempC:
          at(9) * FeatureSchema.envTempRangeC + FeatureSchema.envTempMinC,
      humidityPct: at(10) * 100.0,
      aqi: at(11) * FeatureSchema.aqiMax,
      heatIndexC: at(12) * FeatureSchema.heatIndexMaxC,
      heatExposureHours: at(13) * FeatureSchema.heatExposureDivisorHours,
    );
  }

  /// Inverse of FeatureProcessor's categorical activity mapping. The forward map
  /// is lossy (many strings collapse to the "moderate" default), so we report
  /// the nearest canonical bucket. Thresholds are the midpoints between the four
  /// [FeatureSchema] activity levels (0.0 / 0.25 / 0.5 / 0.85).
  static String _activityLabel(double v) {
    if (v < 0.125) return 'Rest'; // 0.0
    if (v < 0.375) return 'Low'; // 0.25
    if (v < 0.675) return 'Moderate'; // 0.5
    return 'High'; // 0.85
  }
}
