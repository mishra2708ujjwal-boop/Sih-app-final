import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/alert_model.dart';
import '../../shared/models/daily_summary.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/calendar_strip.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_metric_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/timeline_row.dart';

/// History — what PRANA has written down, day by day.
///
/// Everything here comes from [DailySummary] records the controller accumulates
/// while a real band is connected, capped at 90 days and stored in
/// `SharedPreferences`. Nothing is synthesised: a day with no record shows as a
/// day with no record.
///
/// Alerts are the exception, and are labelled as such — the alert log lives in
/// memory for the current session only, so the day's *count* comes from the
/// persisted summary while the alert *text* is only available for today.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _selected = DailySummary.dayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final summaries = controller.dailySummaries;
    final selected = controller.summaryFor(_selected);
    final today = DailySummary.dayOf(DateTime.now());
    final isToday = _selected == today;

    // Newest first for the timeline; the store keeps them oldest-first.
    final recent = summaries.reversed.toList();

    return PranaScaffold(
      title: 'History',
      subtitle: 'Kept on this phone. Never uploaded.',
      headerBottom: CalendarStrip(
        selectedDate: _selected,
        markedDates: controller.recordedDates,
        onDateSelected: (d) => setState(() => _selected = d),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.navClearance,
        ),
        children: [
          if (!controller.isRecordingHistory)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DemoNotice(),            ),

          // ── The selected day ──────────────────────────────────────────────
          if (selected == null || !selected.hasVitals)
            AppCard(
              color: AppColors.surface,
              showBorder: false,
              radius: AppRadius.xl,
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: isToday
                    ? 'Nothing recorded today yet'
                    : 'Nothing recorded on '
                        '${DateFormat('EEEE d MMMM').format(_selected)}',
                subtitle: controller.isRecordingHistory
                    ? 'PRANA writes a summary of each day while your band is '
                        'connected. Wear it and this fills in on its own.'
                    : 'Demo readings are deliberately kept out of your history. '
                        'Turn demo mode off to record real days.',
                actionLabel: isToday && controller.isRecordingHistory
                    ? 'Connect device'
                    : null,
                onAction: isToday && controller.isRecordingHistory
                    ? () => controller.startBleScan()
                    : null,
                compact: true,
              ),
            )
          else
            _DaySummaryBody(summary: selected, isToday: isToday),

          // ── Today's alerts, if any ────────────────────────────────────────
          if (isToday && controller.activeAlerts.isNotEmpty) ...[
            SectionHeader(
              title: 'Alerts today',
              subtitle: '${controller.activeAlerts.length} raised this session',
            ),
            for (final alert in controller.activeAlerts)
              _AlertCard(
                alert: alert,
                onAcknowledge: alert.isAcknowledged
                    ? null
                    : () => controller.acknowledgeAlert(alert.id),
              ),
          ],

          // ── The record itself ─────────────────────────────────────────────
          SectionHeader(
            title: 'Recorded days',
            subtitle: recent.isEmpty
                ? 'Nothing yet'
                : '${recent.length} of the last 90 days',
          ),
          if (recent.isEmpty)
            AppCard.well(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Once you have worn your band for a day, it appears here — one '
                'row per day, newest first.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++)
                    TimelineRow(
                      date: recent[i].date,
                      title: _dayHeadline(recent[i]),
                      subtitle: _daySubtitle(recent[i]),
                      progress: recent[i].peakRiskScore / 100,
                      accent: recent[i].peakLevel.color,
                      pillLabel: recent[i].hasVitals
                          ? recent[i].peakLevel.displayName
                          : null,
                      pillColor: recent[i].peakLevel.color,
                      pillBackground: recent[i].peakLevel.bgColor,
                      showConnector: i < recent.length - 1,
                      onTap: () =>
                          setState(() => _selected = recent[i].date),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _dayHeadline(DailySummary s) {
    if (!s.hasVitals) {
      return s.alertCount > 0
          ? '${s.alertCount} alert${s.alertCount == 1 ? '' : 's'}, no readings'
          : 'No readings';
    }
    return 'Peak risk ${s.peakRiskScore} · avg '
        '${s.avgHeartRate.toStringAsFixed(0)} BPM';
  }

  static String _daySubtitle(DailySummary s) {
    final parts = <String>[];
    if (s.steps > 0) parts.add('${Fmt.count(s.steps)} steps');
    if (s.minSpo2 > 0) parts.add('low ${s.minSpo2.toStringAsFixed(0)}% O₂');
    if (s.alertCount > 0) {
      parts.add('${s.alertCount} alert${s.alertCount == 1 ? '' : 's'}');
    }
    // Reading count is the honesty signal: it separates a full day from a
    // two-minute glance that happens to have a scary peak.
    parts.add('${Fmt.count(s.readings)} readings');
    return parts.join(' · ');
  }
}

/// The body for one recorded day: hero figure, then the numbers behind it.
class _DaySummaryBody extends StatelessWidget {
  final DailySummary summary;
  final bool isToday;

  const _DaySummaryBody({required this.summary, required this.isToday});

  @override
  Widget build(BuildContext context) {
    var order = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          index: order++,
          child: HeroMetricCard(
            caption: isToday
                ? 'Today so far'
                : DateFormat('EEEE d MMMM').format(summary.date),
            value: '${summary.peakRiskScore}',
            label: 'Highest risk score of the day',
            badgeLabel: summary.peakLevel.displayName,
            watermark: Icons.shield_moon_rounded,
          ),
        ),
        AppSpacing.gapSm,

        FadeSlideIn(
          index: order++,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final cellHeight =
                  (cellWidth / 2.3) * (scale > 1 ? scale * 0.96 : 1);

              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: cellWidth / cellHeight,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatTile(
                    label: 'Average heart rate',
                    value: summary.avgHeartRate.toStringAsFixed(0),
                    unit: 'BPM',
                    icon: Icons.favorite_rounded,
                    accent: AppColors.heartRate,
                    chipIcon: true,
                    filled: true,
                  ),
                  StatTile(
                    label: 'Highest heart rate',
                    value: summary.peakHeartRate.toStringAsFixed(0),
                    unit: 'BPM',
                    icon: Icons.trending_up_rounded,
                    accent: AppColors.heartRate,
                    chipIcon: true,
                    filled: true,
                  ),
                  // A day with no oxygen lock shows a dash, not a zero — the
                  // sensor reports 0.0 before it has a reading.
                  StatTile(
                    label: 'Lowest oxygen',
                    value: summary.minSpo2 > 0
                        ? summary.minSpo2.toStringAsFixed(0)
                        : '—',
                    unit: summary.minSpo2 > 0 ? '%' : null,
                    icon: Icons.water_drop_rounded,
                    accent: AppColors.spo2,
                    chipIcon: true,
                    filled: true,
                  ),
                  StatTile(
                    label: 'Highest temperature',
                    value: summary.peakTemperature > 0
                        ? summary.peakTemperature.toStringAsFixed(1)
                        : '—',
                    unit: summary.peakTemperature > 0 ? '°C' : null,
                    icon: Icons.thermostat_rounded,
                    accent: AppColors.temperature,
                    chipIcon: true,
                    filled: true,
                  ),
                ],
              );
            },
          ),
        ),
        AppSpacing.gapSm,

        FadeSlideIn(
          index: order++,
          child: AppCard.well(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _MiniFact(
                    icon: Icons.directions_walk_rounded,
                    color: AppColors.activity,
                    label: 'Steps',
                    value: Fmt.count(summary.steps),
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                Expanded(
                  child: _MiniFact(
                    icon: Icons.notifications_active_rounded,
                    color: summary.alertCount > 0
                        ? AppColors.riskHigh
                        : AppColors.textSecondary,
                    label: 'Alerts',
                    value: '${summary.alertCount}',
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                Expanded(
                  child: _MiniFact(
                    icon: Icons.timeline_rounded,
                    color: AppColors.primary,
                    label: 'Average risk',
                    value: summary.avgRiskScore.toStringAsFixed(0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniFact extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _MiniFact({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onAcknowledge;

  const _AlertCard({required this.alert, this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      accent: alert.severity.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                icon: alert.severity == AlertSeverity.critical
                    ? Icons.warning_rounded
                    : Icons.info_rounded,
                color: alert.severity.color,
                background: alert.severity.bgColor,
                size: 34,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alert.category} · ${Fmt.ago(alert.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (alert.isAcknowledged) ...[
                AppSpacing.hGapXs,
                const StatusPill(
                  label: 'Seen',
                  color: AppColors.riskSafe,
                  backgroundColor: AppColors.riskSafeBg,
                  dense: true,
                ),
              ],
            ],
          ),
          AppSpacing.gapXs,
          Text(alert.message, style: AppTypography.bodySmall),
          if (onAcknowledge != null) ...[
            AppSpacing.gapXs,
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAcknowledge,
                child: const Text('Mark as seen'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.mint.withValues(alpha: 0.5),
      showBorder: false,
      flat: true,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          const IconChip(
            icon: Icons.science_rounded,
            color: AppColors.primary,
            background: AppColors.surface,
            size: 30,
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              'Demo mode is on. Simulated readings are not written to your '
              'history.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
