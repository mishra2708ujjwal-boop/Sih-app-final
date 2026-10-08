import '../../core/services/prana_health_controller.dart';
import '../../shared/models/alert_model.dart';
import '../../shared/models/daily_summary.dart';
import '../../shared/models/health_reading.dart';
import '../../shared/models/risk_result.dart';
import '../../shared/models/user_baseline.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/widgets/prana_line_chart.dart';

/// The timeline the user picks for the doctor report.
enum ReportRange {
  week,
  month,
  quarter,
  all;

  /// Full label for the report header, e.g. "Last 7 days".
  String get label {
    switch (this) {
      case ReportRange.week:
        return 'Last 7 days';
      case ReportRange.month:
        return 'Last 30 days';
      case ReportRange.quarter:
        return 'Last 90 days';
      case ReportRange.all:
        return 'All recorded';
    }
  }

  /// Compact label for the on-screen picker.
  String get shortLabel {
    switch (this) {
      case ReportRange.week:
        return '7 days';
      case ReportRange.month:
        return '30 days';
      case ReportRange.quarter:
        return '90 days';
      case ReportRange.all:
        return 'All';
    }
  }

  /// Days back from today the range spans, or `null` for "everything on record".
  int? get days {
    switch (this) {
      case ReportRange.week:
        return 7;
      case ReportRange.month:
        return 30;
      case ReportRange.quarter:
        return 90;
      case ReportRange.all:
        return null;
    }
  }
}

/// An immutable snapshot of everything the doctor PDF needs, assembled off the
/// [PranaHealthController] so the PDF builder can stay a pure function of its
/// input (easy to reason about and to preview on screen).
///
/// The report is intentionally **day-resolution**: only [DailySummary]
/// day-aggregates are persisted on disk, so the trend graphs plot one point per
/// day over the chosen span, and a separate "current snapshot" carries the
/// latest live band reading.
class HealthReportData {
  final UserProfile profile;
  final UserBaseline baseline;
  final DateTime generatedAt;

  final ReportRange range;
  final String rangeLabel;

  /// First and last day actually covered by [days] (falls back to the requested
  /// window when nothing was recorded).
  final DateTime from;
  final DateTime to;

  /// Vitals-bearing days inside the range, oldest first.
  final List<DailySummary> days;

  // ── Period aggregates over [days] ──────────────────────────────────────────
  final double avgHeartRate;
  final double peakHeartRate;

  /// Lowest daily-minimum SpO₂ across the range (0 when never locked).
  final double minSpo2;

  /// Highest daily-peak temperature across the range (0 when never locked).
  final double peakTemperature;
  final double avgRiskScore;
  final int peakRiskScore;
  final int totalSteps;
  final int avgSteps;
  final int alertTotal;
  final int daysRecorded;

  // ── Current live snapshot ───────────────────────────────────────────────────
  final HealthReading current;
  final RiskResult currentRisk;
  final bool hasLiveData;
  final bool isDemo;

  /// Recent in-memory live points for the snapshot sparkline (may be empty).
  final List<ChartDataPoint> hrPoints;
  final List<ChartDataPoint> spo2Points;
  final List<ChartDataPoint> tempPoints;

  final List<AlertModel> activeAlerts;

  const HealthReportData({
    required this.profile,
    required this.baseline,
    required this.generatedAt,
    required this.range,
    required this.rangeLabel,
    required this.from,
    required this.to,
    required this.days,
    required this.avgHeartRate,
    required this.peakHeartRate,
    required this.minSpo2,
    required this.peakTemperature,
    required this.avgRiskScore,
    required this.peakRiskScore,
    required this.totalSteps,
    required this.avgSteps,
    required this.alertTotal,
    required this.daysRecorded,
    required this.current,
    required this.currentRisk,
    required this.hasLiveData,
    required this.isDemo,
    required this.hrPoints,
    required this.spo2Points,
    required this.tempPoints,
    required this.activeAlerts,
  });

  /// Whether there is at least one recorded day to draw trends/table for.
  bool get hasDays => days.isNotEmpty;

  /// BMI from the profile's height/weight, or `null` when height is missing.
  double? get bmi {
    if (profile.heightCm <= 0) return null;
    final m = profile.heightCm / 100.0;
    return profile.weightKg / (m * m);
  }

  /// The primary emergency contact (or the first one on record), if any.
  EmergencyContact? get primaryContact {
    if (profile.emergencyContacts.isEmpty) return null;
    for (final c in profile.emergencyContacts) {
      if (c.isPrimary) return c;
    }
    return profile.emergencyContacts.first;
  }

  /// Assembles the report snapshot from the controller. Reads existing getters
  /// only — the controller is never mutated, so the dependency stays one-way
  /// (report → controller).
  factory HealthReportData.fromController(
    PranaHealthController c, {
    required ReportRange range,
  }) {
    final now = DateTime.now();
    final today = DailySummary.dayOf(now);
    final span = range.days;

    // Oldest-first, vitals-bearing days only.
    final recorded =
        c.dailySummaries.where((s) => s.hasVitals).toList(growable: false);

    final DateTime windowStart = span == null
        ? (recorded.isEmpty ? today : recorded.first.date)
        : DailySummary.dayOf(now.subtract(Duration(days: span - 1)));

    final inRange = recorded
        .where((s) =>
            !s.date.isBefore(windowStart) && !s.date.isAfter(today))
        .toList(growable: false);

    // Period aggregates.
    var sumHr = 0.0;
    var hrDays = 0;
    var peakHr = 0.0;
    var minSpo2 = 0.0;
    var peakTemp = 0.0;
    var sumRisk = 0.0;
    var peakRisk = 0;
    var totalSteps = 0;
    var stepDays = 0;
    var alertTotal = 0;

    for (final s in inRange) {
      if (s.avgHeartRate > 0) {
        sumHr += s.avgHeartRate;
        hrDays++;
      }
      if (s.peakHeartRate > peakHr) peakHr = s.peakHeartRate;
      if (s.minSpo2 > 0 && (minSpo2 == 0 || s.minSpo2 < minSpo2)) {
        minSpo2 = s.minSpo2;
      }
      if (s.peakTemperature > peakTemp) peakTemp = s.peakTemperature;
      sumRisk += s.avgRiskScore;
      if (s.peakRiskScore > peakRisk) peakRisk = s.peakRiskScore;
      if (s.steps > 0) {
        totalSteps += s.steps;
        stepDays++;
      }
      alertTotal += s.alertCount;
    }

    final from = inRange.isEmpty ? windowStart : inRange.first.date;
    final to = inRange.isEmpty ? today : inRange.last.date;

    return HealthReportData(
      profile: c.userProfile,
      baseline: c.currentBaseline,
      generatedAt: now,
      range: range,
      rangeLabel: range.label,
      from: from,
      to: to,
      days: inRange,
      avgHeartRate: hrDays > 0 ? sumHr / hrDays : 0.0,
      peakHeartRate: peakHr,
      minSpo2: minSpo2,
      peakTemperature: peakTemp,
      avgRiskScore: inRange.isEmpty ? 0.0 : sumRisk / inRange.length,
      peakRiskScore: peakRisk,
      totalSteps: totalSteps,
      avgSteps: stepDays > 0 ? (totalSteps / stepDays).round() : 0,
      alertTotal: alertTotal,
      daysRecorded: inRange.length,
      current: c.currentHealth,
      currentRisk: c.currentRisk,
      hasLiveData: c.hasLiveData,
      isDemo: c.isMockMode,
      hrPoints: c.hrHistory,
      spo2Points: c.spo2History,
      tempPoints: c.tempHistory,
      activeAlerts: c.activeAlerts,
    );
  }
}
