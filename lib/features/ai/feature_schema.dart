/*What we're changing: Creating a single authoritative Dart file that documents every constant and formula used by FeatureProcessor, so there is exactly one place that defines the 16-feature contract — the same place both FeatureProcessor and (later) your Python training script will need to agree with.*/
/// PRANA 16-Feature ML Contract — FROZEN SCHEMA
///
/// This file is the single authoritative definition of the feature vector
/// consumed by MLInferenceService implementations (MockInferenceService today,
/// TFLiteInferenceService once a trained model is integrated).
///
/// RULE: Any change to a formula or constant in this file is a BREAKING
/// CHANGE to the ML contract. It must be accompanied by:
///   1. A version bump below.
///   2. Retraining of any model built against the previous version.
///   3. An update to assets/models/README.md.
///
/// FeatureProcessor (feature_processor.dart) reads its numeric constants from
/// here rather than re-declaring its own literals, so the formulas documented
/// in this file are always the formulas that actually run.
class FeatureSchema {
  FeatureSchema._();

  /// Bump this when ANY formula, constant, or feature index changes.
  static const String version = '1.1.0-frozen';

  /// Number of elements in the feature vector. Must equal
  /// FeatureProcessor.extractFeatureVector(...).length in all cases.
  static const int featureCount = 16;

  // ── Feature 0: Normalized Heart Rate ──────────────────────────────────────
  // f0 = clamp((heartRate - hrMinBpm) / hrRangeBpm, 0.0, 1.0)
  static const double hrMinBpm = 40.0;
  static const double hrRangeBpm = 160.0; // covers 40-200 BPM

  // ── Feature 1: Heart Rate Baseline Deviation Ratio ────────────────────────
  // f1 = clamp((heartRate - hrBaselineMid) / hrBaselineMid, hrDevClampMin, hrDevClampMax)
  // where hrBaselineMid = (baseline.normalHrMin + baseline.normalHrMax) / 2.0
  // NOTE: this is a PERCENTAGE DEVIATION from the midpoint of the user's
  // learned normal range, NOT a z-score against a standard deviation. An
  // earlier draft of assets/models/README.md incorrectly documented this as
  // a std-dev-based z-score; the code below (and this schema) is now the
  // corrected, authoritative definition.
  static const double hrDevClampMin = -1.0;
  static const double hrDevClampMax = 2.0;

  // ── Feature 2: Normalized SpO2 ────────────────────────────────────────────
  // f2 = clamp((spo2 - spo2MinPct) / spo2RangePct, 0.0, 1.0)
  static const double spo2MinPct = 70.0;
  static const double spo2RangePct = 30.0; // covers 70-100%

  // ── Feature 3: SpO2 Baseline Drop ─────────────────────────────────────────
  // f3 = clamp(baseline.normalSpo2Min - spo2, 0.0, spo2DropClampMax) / spo2DropDivisor
  // NOTE: an earlier draft of assets/models/README.md omitted the divisor.
  // The implementation divides by 10.0 to compress the 0-30 point range into
  // a 0.0-3.0 feature range; this schema documents that divisor explicitly.
  static const double spo2DropClampMax = 30.0;
  static const double spo2DropDivisor = 10.0;

  // ── Feature 4: Normalized Body Temperature ────────────────────────────────
  // f4 = clamp((bodyTemperature - tempMinC) / tempRangeC, 0.0, 1.0)
  static const double tempMinC = 34.0;
  static const double tempRangeC = 8.0; // covers 34.0-42.0 degC

  // ── Feature 5: Body Temperature Baseline Deviation ────────────────────────
  // f5 = clamp((bodyTemperature - baseline.normalTempMax) / tempDevDivisor,
  //            tempDevClampMin, tempDevClampMax)
  static const double tempDevDivisor = 2.0;
  static const double tempDevClampMin = -1.0;
  static const double tempDevClampMax = 2.0;

  // ── Feature 6: Activity Level ─────────────────────────────────────────────
  // Categorical mapping from HealthReading.activityLevel (case-insensitive
  // substring match): "rest" -> activityRest, "low" -> activityLow,
  // "high" -> activityHigh, anything else (e.g. "Moderate") ->
  // activityModerateDefault.
  static const double activityRest = 0.0;
  static const double activityLow = 0.25;
  static const double activityModerateDefault = 0.5;
  static const double activityHigh = 0.85;

  // ── Feature 7: Sleep Duration Ratio ───────────────────────────────────────
  // f7 = clamp(sleepMinutes / sleepGoalMinutes, 0.0, sleepDurationClampMax)
  // sleepMinutes falls back to sleepDurationFallbackMinutes when no
  // SleepReading is supplied.
  static const double sleepGoalMinutes = 480.0; // 8 hours
  static const double sleepDurationFallbackMinutes = 450.0;
  static const double sleepDurationClampMax = 1.5;

  // ── Feature 8: Sleep Quality Score ────────────────────────────────────────
  // f8 = clamp(sleepQualityScore / 100.0, 0.0, 1.0)
  // sleepQualityScore falls back to sleepQualityFallback when no SleepReading
  // is supplied.
  static const double sleepQualityFallback = 80.0;

  // ── Feature 9: Normalized Ambient Temperature ─────────────────────────────
  // f9 = clamp((envTemp - envTempMinC) / envTempRangeC, 0.0, 1.0)
  static const double envTempMinC = -10.0;
  static const double envTempRangeC = 65.0; // covers -10 to 55 degC

  // ── Feature 10: Normalized Humidity ───────────────────────────────────────
  // f10 = clamp(humidity / 100.0, 0.0, 1.0)  (no dedicated constant needed)

  // ── Feature 11: Normalized AQI ────────────────────────────────────────────
  // f11 = clamp(aqi / aqiMax, 0.0, 1.0)
  static const double aqiMax = 500.0;

  // ── Feature 12: Normalized Heat Index ─────────────────────────────────────
  // f12 = clamp(heatIndex / heatIndexMaxC, 0.0, 1.0)
  static const double heatIndexMaxC = 60.0;

  // ── Feature 13: Heat Exposure Duration ────────────────────────────────────
  // f13 = clamp(heatExposureHours / heatExposureDivisorHours, 0.0, heatExposureClampMax)
  // NOTE: an earlier draft of assets/models/README.md incorrectly documented
  // this divisor as 12.0. The implementation — and therefore the frozen
  // contract — uses 8.0.
  static const double heatExposureDivisorHours = 8.0;
  static const double heatExposureClampMax = 1.5;

  // ── Feature 14: HRV RMSSD (normalized) ────────────────────────────────────
  // f14 = clamp(hrvRmssd / hrvMaxMs, 0.0, 1.0)
  static const double hrvMaxMs = 150.0;

  // ── Feature 15: Heart Rate Trend Slope ────────────────────────────────────
  // f15 = clamp(hrTrendSlope, trendSlopeClampMin, trendSlopeClampMax)
  // hrTrendSlope is computed by HrTrendCalculator.computeSlope(...) from the
  // controller's recent, real HR history (see hr_trend_calculator.dart). It
  // is a least-squares slope in BPM/minute, divided by
  // trendNormalizationBpmPerMin to bring it into a range comparable to the
  // other clamped features.
  static const double trendSlopeClampMin = -2.0;
  static const double trendSlopeClampMax = 2.0;
  // Raised from 5.0 -> 15.0 in v1.1.0 after PPG-DaLiA training-data
  // diagnostics showed 5.0 saturated 64.3% of real activity-transition
  // windows at the clamp (see diagnose_trend_saturation.py output,
  // Phase 3 Checkpoint B4). 15.0 reduces saturation to ~24.3%, leaving
  // genuine sharp transitions still reading near-maximum without pinning
  // the majority of ordinary readings.
  static const double trendNormalizationBpmPerMin = 15.0;
  static const int trendMinSamples = 3;
  static const int trendMaxSamples = 8;
  static const Duration trendMaxWindow = Duration(minutes: 10);
}
