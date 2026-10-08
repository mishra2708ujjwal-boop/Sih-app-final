/*Purpose
What we're changing: PranaHealthController already keeps a real, timestamped rolling buffer of recent heart-rate readings (_hrHistory, a List<ChartDataPoint> capped at 50 entries) — it's just never used to compute a slope. This new file adds a small, independently-testable utility that computes a real least-squares slope from that buffer. No fabricated data — if there aren't enough real samples yet, it returns 0.0 rather than inventing a number.*/
import '../../shared/widgets/prana_line_chart.dart' show ChartDataPoint;
import 'feature_schema.dart';

/// Computes feature 15 (HR trend slope) from REAL historical HR samples.
///
/// Uses ordinary least-squares regression over the most recent samples
/// (bounded by FeatureSchema.trendMinSamples..trendMaxSamples and
/// FeatureSchema.trendMaxWindow) to estimate a rate of change in BPM per
/// minute, then normalizes and clamps it to match the range FeatureProcessor
/// expects for feature 15.
///
/// Returns 0.0 (flat trend) whenever there isn't enough real recent data to
/// compute a meaningful slope — this class never invents or randomizes a
/// value.
class HrTrendCalculator {
  HrTrendCalculator._();

  /// [history] should be the controller's real HR history buffer, oldest
  /// first, same ordering as PranaHealthController._hrHistory.
  static double computeSlope(List<ChartDataPoint> history) {
    if (history.length < FeatureSchema.trendMinSamples) return 0.0;

    final now = history.last.time;
    final windowStart = now.subtract(FeatureSchema.trendMaxWindow);

    // Only keep samples inside the trend window, most-recent last, capped at
    // trendMaxSamples so a long session doesn't skew the fit toward stale data.
    final windowed = history
        .where((p) => !p.time.isBefore(windowStart))
        .toList();
    final recent = windowed.length > FeatureSchema.trendMaxSamples
        ? windowed.sublist(windowed.length - FeatureSchema.trendMaxSamples)
        : windowed;

    if (recent.length < FeatureSchema.trendMinSamples) return 0.0;

    // Convert timestamps to minutes-elapsed-since-first-sample so the
    // regression's x-axis is in the units we want the slope expressed in.
    final t0 = recent.first.time;
    final xs = recent
        .map((p) => p.time.difference(t0).inMilliseconds / 60000.0)
        .toList();
    final ys = recent.map((p) => p.value).toList();

    final n = xs.length;
    final xMean = xs.reduce((a, b) => a + b) / n;
    final yMean = ys.reduce((a, b) => a + b) / n;

    double numerator = 0.0;
    double denominator = 0.0;
    for (int i = 0; i < n; i++) {
      numerator += (xs[i] - xMean) * (ys[i] - yMean);
      denominator += (xs[i] - xMean) * (xs[i] - xMean);
    }

    // All x-values identical (e.g. samples with the same timestamp) — no
    // meaningful slope can be computed.
    if (denominator == 0.0) return 0.0;

    final slopeBpmPerMinute = numerator / denominator;
    final normalized =
        slopeBpmPerMinute / FeatureSchema.trendNormalizationBpmPerMin;

    return normalized.clamp(
      FeatureSchema.trendSlopeClampMin,
      FeatureSchema.trendSlopeClampMax,
    );
  }
}