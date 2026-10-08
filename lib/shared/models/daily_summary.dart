import 'health_reading.dart';
import 'risk_result.dart';

/// One day of aggregated readings, persisted locally so history survives a
/// restart.
///
/// PRANA's in-memory chart buffers hold the last 50 points — minutes, not days.
/// Nothing was ever written down, so "how was last Tuesday" had no answer and
/// the History screen had nothing real to draw. This is that record: a rolling
/// aggregate updated as readings arrive, small enough to keep 90 days of it in
/// `SharedPreferences`.
///
/// Aggregates only. No individual reading, no timestamp beyond the date, and
/// nothing that leaves the phone — the same privacy posture as the rest of the
/// app.
class DailySummary {
  /// Midnight of the day this covers. Always date-only; see [dayOf].
  final DateTime date;

  /// How many sensor readings fed this summary. Used both to weight the running
  /// means and to tell a full day apart from a five-minute glance.
  final int readings;

  final double avgHeartRate;
  final double peakHeartRate;

  /// Lowest oxygen seen. 0 when no reading has arrived, which is why
  /// [hasVitals] exists rather than treating 0 as "0%".
  final double minSpo2;

  final double peakTemperature;

  final double avgRiskScore;
  final int peakRiskScore;

  /// Highest step count reported that day. The band reports steps cumulatively
  /// and resets at midnight, so the maximum *is* the day's total.
  final int steps;

  /// Alerts raised during the day.
  final int alertCount;

  const DailySummary({
    required this.date,
    this.readings = 0,
    this.avgHeartRate = 0,
    this.peakHeartRate = 0,
    this.minSpo2 = 0,
    this.peakTemperature = 0,
    this.avgRiskScore = 0,
    this.peakRiskScore = 0,
    this.steps = 0,
    this.alertCount = 0,
  });

  DailySummary.empty(DateTime day) : this(date: dayOf(day));

  /// Strips the time off a timestamp so two readings on the same day land on the
  /// same record.
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  bool get hasVitals => readings > 0;

  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  /// The worst risk band the day reached, using the same thresholds as
  /// `RiskEngine`.
  RiskLevel get peakLevel {
    if (peakRiskScore < 30) return RiskLevel.safe;
    if (peakRiskScore < 60) return RiskLevel.moderate;
    if (peakRiskScore < 80) return RiskLevel.high;
    return RiskLevel.critical;
  }

  /// Folds one reading into the day. Means are updated incrementally so the
  /// individual readings never need to be kept.
  DailySummary withReading(HealthReading reading, RiskResult risk) {
    final n = readings + 1;

    double mean(double previous, double value) =>
        previous + (value - previous) / n;

    return DailySummary(
      date: date,
      readings: n,
      // Guard against a zeroed reading dragging the mean down: the sensor
      // reports 0.0 before it has a lock.
      avgHeartRate: reading.heartRate > 0
          ? mean(avgHeartRate, reading.heartRate)
          : avgHeartRate,
      peakHeartRate: reading.heartRate > peakHeartRate
          ? reading.heartRate
          : peakHeartRate,
      minSpo2: reading.spo2 > 0 && (minSpo2 == 0 || reading.spo2 < minSpo2)
          ? reading.spo2
          : minSpo2,
      peakTemperature: reading.bodyTemperature > peakTemperature
          ? reading.bodyTemperature
          : peakTemperature,
      avgRiskScore: mean(avgRiskScore, risk.overallScore.toDouble()),
      peakRiskScore:
          risk.overallScore > peakRiskScore ? risk.overallScore : peakRiskScore,
      steps: reading.steps > steps ? reading.steps : steps,
      alertCount: alertCount,
    );
  }

  DailySummary withAlert() => DailySummary(
        date: date,
        readings: readings,
        avgHeartRate: avgHeartRate,
        peakHeartRate: peakHeartRate,
        minSpo2: minSpo2,
        peakTemperature: peakTemperature,
        avgRiskScore: avgRiskScore,
        peakRiskScore: peakRiskScore,
        steps: steps,
        alertCount: alertCount + 1,
      );

  Map<String, dynamic> toJson() => {
        // Date-only ISO string keeps the stored blob readable and small.
        'date': date.toIso8601String().split('T').first,
        'readings': readings,
        'avgHr': _round(avgHeartRate),
        'peakHr': _round(peakHeartRate),
        'minSpo2': _round(minSpo2),
        'peakTemp': _round(peakTemperature),
        'avgRisk': _round(avgRiskScore),
        'peakRisk': peakRiskScore,
        'steps': steps,
        'alerts': alertCount,
      };

  /// One decimal is all these aggregates justify, and it keeps the stored JSON
  /// from ballooning with float noise.
  static double _round(double v) => (v * 10).roundToDouble() / 10;

  static DailySummary? fromJson(Map<String, dynamic> json) {
    final raw = json['date'] as String?;
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    return DailySummary(
      date: dayOf(parsed),
      readings: (json['readings'] as num?)?.toInt() ?? 0,
      avgHeartRate: (json['avgHr'] as num?)?.toDouble() ?? 0,
      peakHeartRate: (json['peakHr'] as num?)?.toDouble() ?? 0,
      minSpo2: (json['minSpo2'] as num?)?.toDouble() ?? 0,
      peakTemperature: (json['peakTemp'] as num?)?.toDouble() ?? 0,
      avgRiskScore: (json['avgRisk'] as num?)?.toDouble() ?? 0,
      peakRiskScore: (json['peakRisk'] as num?)?.toInt() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      alertCount: (json['alerts'] as num?)?.toInt() ?? 0,
    );
  }
}
