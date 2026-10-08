import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/hypnogram_chart.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_metric_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/info_row.dart';

/// Sleep & recovery body — embedded as the "Sleep" segment of Vitals.
///
/// No `Scaffold` of its own: the parent Vitals screen owns the header and the
/// segmented control.
///
/// The old Day/Week/Month switcher is gone. It set state but rendered identical
/// last-night data for all three periods, and `SleepReading` carries no
/// week/month history to render — one honest view beats three that lie.
class SleepView extends StatelessWidget {
  const SleepView({super.key});

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xxs,
    AppSpacing.md,
    AppSpacing.navClearance,
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final sleep = controller.currentSleep;
    final baseline = controller.currentBaseline;

    // The band streams heart rate, oxygen, temperature and motion; nothing in
    // the firmware or the on-device models derives sleep staging from them. So
    // rather than dress up sample numbers as last night's sleep, say what is
    // actually true. See PranaHealthController.hasSleepData.
    if (!controller.hasSleepData) {
      return SingleChildScrollView(
        padding: _padding,
        child: Column(
          children: [
            AppCard(
              color: AppColors.surface,
              showBorder: false,
              radius: AppRadius.xl,
              child: EmptyState(
                icon: Icons.bedtime_outlined,
                iconColor: AppColors.sleep,
                title: 'Sleep tracking isn’t live yet',
                subtitle:
                    'Your band reports heart rate, blood oxygen, temperature '
                    'and movement. It doesn’t yet report sleep stages, so PRANA '
                    'has nothing measured to show here.',
                actionLabel: 'See it in demo mode',
                onAction: () => controller.toggleMockMode(true),
              ),
            ),
            AppSpacing.gapSm,
            AppCard(
              color: AppColors.surfaceSubtle,
              showBorder: false,
              flat: true,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconChip(
                    icon: Icons.nightlight_round,
                    color: AppColors.sleep,
                    size: 32,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What PRANA can already tell you',
                          style: AppTypography.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your resting heart rate is '
                          '${baseline.restingHrBaseline.toStringAsFixed(0)} BPM '
                          'and your sleep goal is '
                          '${baseline.sleepGoalHours.toStringAsFixed(1)} hours. '
                          'Both are used when scoring fatigue.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Nothing recorded — don't draw an empty hypnogram and a 0h 0m hero.
    if (sleep.totalDurationMinutes <= 0) {
      return SingleChildScrollView(
        padding: _padding,
        child: AppCard(
          color: AppColors.surface,
          showBorder: false,
          radius: AppRadius.xl,
          child: EmptyState(
            icon: Icons.bedtime_outlined,
            iconColor: AppColors.sleep,
            title: 'No sleep recorded yet',
            subtitle:
                'Wear your PRANA band overnight and last night’s sleep will '
                'show up here.',
            actionLabel: 'Connect device',
            onAction: () => controller.startBleScan(),
          ),
        ),
      );
    }

    final goalMinutes = (baseline.sleepGoalHours * 60).round();
    final goalProgress = goalMinutes <= 0
        ? 0.0
        : (sleep.totalDurationMinutes / goalMinutes).clamp(0.0, 1.0);
    final shortfall = goalMinutes - sleep.totalDurationMinutes;

    // `SleepReading` carries one timestamp. Treating it as the moment the
    // recording ended is what makes the hypnogram's axis honest — the start is
    // then derived from the measured duration rather than guessed.
    final wokeAt = sleep.date;
    final startedAt =
        wokeAt.subtract(Duration(minutes: sleep.totalDurationMinutes));

    var order = 0;

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Duration hero ────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: HeroMetricCard(
              caption: 'Last night · ${Fmt.clock(startedAt)}–'
                  '${Fmt.clock(wokeAt)}',
              value: Fmt.duration(sleep.totalDurationMinutes),
              label: shortfall > 5
                  ? '${Fmt.duration(shortfall)} short of your '
                      '${baseline.sleepGoalHours.toStringAsFixed(1)}h goal'
                  : 'You met your '
                      '${baseline.sleepGoalHours.toStringAsFixed(1)}h goal',
              badgeLabel:
                  'Quality ${sleep.sleepQualityScore.toStringAsFixed(0)}',
              watermark: Icons.bedtime_rounded,
            ),
          ),
          AppSpacing.gapSm,

          // Goal progress reads better as its own thin bar than crammed into the
          // hero, where it would compete with the duration numeral.
          FadeSlideIn(
            index: order++,
            child: AppCard.well(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sleep goal',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${(goalProgress * 100).toStringAsFixed(0)}%',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.sleep,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapXs,
                  ClipRRect(
                    borderRadius: AppRadius.brPill,
                    child: LinearProgressIndicator(
                      value: goalProgress,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.sleep,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Hypnogram ────────────────────────────────────────────────────
          const SectionHeader(title: 'Through the night', dense: true),
          FadeSlideIn(
            index: order++,
            child: HypnogramChart(
              stages: sleep.hypnogramStages,
              startTime: startedAt,
              totalMinutes: sleep.totalDurationMinutes,
            ),
          ),

          // ── Stage breakdown ──────────────────────────────────────────────
          SectionHeader(
            title: 'Sleep stages',
            subtitle: 'Of ${Fmt.duration(sleep.totalDurationMinutes)} in bed',
          ),
          FadeSlideIn(
            index: order++,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final cellHeight =
                    (cellWidth / 2.05) * (scale > 1 ? scale * 0.96 : 1);

                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: cellWidth / cellHeight,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StageTile(
                      stage: SleepStage.deep,
                      minutes: sleep.deepSleepMinutes,
                      total: sleep.totalDurationMinutes,
                      note: 'Physical recovery',
                    ),
                    _StageTile(
                      stage: SleepStage.rem,
                      minutes: sleep.remSleepMinutes,
                      total: sleep.totalDurationMinutes,
                      note: 'Memory and mood',
                    ),
                    _StageTile(
                      stage: SleepStage.light,
                      minutes: sleep.lightSleepMinutes,
                      total: sleep.totalDurationMinutes,
                      note: 'Most of the night',
                    ),
                    _StageTile(
                      stage: SleepStage.awake,
                      minutes: sleep.awakeMinutes,
                      total: sleep.totalDurationMinutes,
                      note: 'Brief wake-ups',
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Recovery ─────────────────────────────────────────────────────
          const SectionHeader(title: 'Recovery'),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.favorite_rounded,
                    title: 'Resting heart rate',
                    subtitle:
                        'Your baseline is ${baseline.restingHrBaseline.toStringAsFixed(0)} BPM',
                    value: '${sleep.restingHeartRate.toStringAsFixed(0)} BPM',
                    iconColor: AppColors.heartRate,
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    icon: Icons.air_rounded,
                    title: 'Breathing rate',
                    subtitle: 'Normal is 12–20 breaths a minute',
                    value:
                        '${sleep.respiratoryRate.toStringAsFixed(0)} rpm',
                    iconColor: AppColors.spo2,
                  ),
                  const Divider(height: 1),
                  InfoRow(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Recovery',
                    subtitle: 'How rested your body is today',
                    value: '${sleep.recoveryIndex.toStringAsFixed(0)}%',
                    iconColor: AppColors.activity,
                    trailing: StatusPill(
                      label: '${sleep.recoveryIndex.toStringAsFixed(0)}%',
                      color: sleep.recoveryIndex >= 75
                          ? AppColors.riskSafe
                          : AppColors.riskModerate,
                      backgroundColor: sleep.recoveryIndex >= 75
                          ? AppColors.riskSafeBg
                          : AppColors.riskModerateBg,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AppSpacing.gapSm,
          // Demo mode is the only path that reaches this branch, but say so
          // on-screen rather than relying on the header chip.
          FadeSlideIn(
            index: order++,
            child: AppCard(
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
                      'Demo data. Sleep staging is not measured by the band.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final SleepStage stage;
  final int minutes;
  final int total;
  final String note;

  const _StageTile({
    required this.stage,
    required this.minutes,
    required this.total,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : (minutes / total).clamp(0.0, 1.0);

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: stage.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stage.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${(share * 100).toStringAsFixed(0)}%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            Fmt.duration(minutes),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.metricSmall,
          ),
          // The share bar makes four tiles comparable at a glance; the
          // percentage alone requires arithmetic.
          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: share,
              backgroundColor: AppColors.surfaceWell,
              valueColor: AlwaysStoppedAnimation<Color>(stage.color),
              minHeight: 5,
            ),
          ),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
