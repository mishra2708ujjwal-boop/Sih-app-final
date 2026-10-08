import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/prana_line_chart.dart';
import '../../shared/widgets/animated_metric_value.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_segmented_control.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/stat_tile.dart';
import '../sleep/sleep_screen.dart';
import '../report/report_screen.dart';
import '../emergency/sos_action_button.dart';

/// The plotting range and healthy band for one metric's dial.
///
/// [min] and [max] are display bounds — the span the dial draws, chosen so a
/// physiologically plausible reading always lands somewhere visible. They are
/// *not* thresholds; the band between [bandMin] and [bandMax] is the only part
/// that carries clinical meaning, and it comes from the learned baseline.
class _Scale {
  final double min;
  final double max;
  final double bandMin;
  final double bandMax;

  const _Scale({
    required this.min,
    required this.max,
    required this.bandMin,
    required this.bandMax,
  });

  double _f(double v) {
    final span = max - min;
    if (span <= 0) return 0;
    return ((v - min) / span).clamp(0.0, 1.0);
  }

  double fraction(double value) => _f(value);
  double get bandStart => _f(bandMin);
  double get bandEnd => _f(bandMax);
}

/// Vitals — Heart / Oxygen / Temp / Sleep.
class HealthScreen extends StatefulWidget {
  final int initialSegment;

  const HealthScreen({super.key, this.initialSegment = 0});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  late int _segment = widget.initialSegment;

  @override
  void didUpdateWidget(HealthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSegment != oldWidget.initialSegment) {
      setState(() => _segment = widget.initialSegment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final health = controller.currentHealth;
    final baseline = controller.currentBaseline;
    final hasData = controller.hasLiveData;

    final hrScale = _Scale(
      min: 40,
      max: 180,
      bandMin: baseline.normalHrMin,
      bandMax: baseline.normalHrMax,
    );
    final spo2Scale = _Scale(
      min: 85,
      max: 100,
      bandMin: baseline.normalSpo2Min,
      bandMax: 100,
    );
    final tempScale = _Scale(
      min: 34,
      max: 41,
      bandMin: baseline.normalTempMin,
      bandMax: baseline.normalTempMax,
    );

    return PranaScaffold(
      title: 'Vitals',
      subtitle: hasData
          ? 'Compared with the range PRANA has learned for you'
          : 'Waiting for your sensor',
      actions: [
        const SosActionButton(),
        CircleIconButton(
          icon: Icons.description_rounded,
          tooltip: 'Doctor report',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ReportScreen()),
          ),
        ),
      ],
      headerBottom: AppSegmentedControl(
        segments: const ['Heart', 'Oxygen', 'Temp', 'Sleep'],
        selectedIndex: _segment,
        onChanged: (i) => setState(() => _segment = i),
      ),
      body: IndexedStack(
        index: _segment,
        children: [
          // ── Heart rate ──────────────────────────────────────────────────────
          _MetricDetailView(
            hasData: hasData,
            metricTitle: 'Heart rate',
            icon: Icons.favorite_rounded,
            currentValue: health.heartRate.toStringAsFixed(0),
            unit: 'BPM',
            scale: hrScale,
            reading: health.heartRate,
            baselineText:
                'Your normal range: ${baseline.normalHrMin.toStringAsFixed(0)}–${baseline.normalHrMax.toStringAsFixed(0)} BPM',
            statusLabel: health.heartRate > baseline.normalHrMax
                ? '+${((health.heartRate - baseline.normalHrMax) / baseline.normalHrMax * 100).toStringAsFixed(0)}% above normal'
                : health.heartRate < baseline.normalHrMin
                    ? 'Below your normal range'
                    : 'Within your normal range',
            isNormal: health.heartRate <= baseline.normalHrMax &&
                health.heartRate >= baseline.normalHrMin,
            accent: AppColors.heartRate,
            emptyMessage:
                'Connect your PRANA sensor to see your heart rate and how it '
                'moves through the day.',
            chart: PranaLineChart(
              title: 'Recent readings',
              dataPoints: controller.hrHistory,
              baselineMin: baseline.normalHrMin,
              baselineMax: baseline.normalHrMax,
              unit: 'BPM',
              lineColor: AppColors.heartRate,
              valueDecimals: 0,
            ),
            stats: [
              StatTile(
                label: 'Now',
                value: health.heartRate.toStringAsFixed(0),
                unit: 'BPM',
                valueColor: AppColors.heartRate,
                filled: true,
                accent: AppColors.heartRate,
              ),
              StatTile(
                label: 'Your resting rate',
                value: baseline.restingHrBaseline.toStringAsFixed(0),
                unit: 'BPM',
                filled: true,
                accent: AppColors.textSecondary,
              ),
              StatTile(
                label: 'Variability',
                value: health.hrvRmssd.toStringAsFixed(0),
                unit: 'ms',
                filled: true,
                accent: AppColors.textSecondary,
              ),
            ],
            extras: [
              StatTile(
                label: 'Steps today',
                value: Fmt.count(health.steps),
                icon: Icons.directions_walk_rounded,
                accent: AppColors.activity,
                chipIcon: true,
                filled: true,
              ),
              StatTile(
                label: 'Activity',
                value: health.activityLevel,
                icon: Icons.bolt_rounded,
                accent: AppColors.activity,
                chipIcon: true,
                filled: true,
              ),
            ],
            analysisText: health.heartRate > baseline.normalHrMax
                ? 'Your heart rate has been running above your usual resting range. '
                    'PRANA is weighing this into your current risk score.'
                : 'Your heart rate matches the range PRANA has learned as normal '
                    'for you. Nothing to act on.',
          ),

          // ── Blood oxygen ────────────────────────────────────────────────────
          _MetricDetailView(
            hasData: hasData,
            metricTitle: 'Blood oxygen',
            icon: Icons.water_drop_rounded,
            currentValue: health.spo2.toStringAsFixed(1),
            unit: '%',
            scale: spo2Scale,
            reading: health.spo2,
            baselineText:
                'Your normal floor: ${baseline.normalSpo2Min.toStringAsFixed(0)}% and above',
            statusLabel: health.spo2 < baseline.normalSpo2Min
                ? '${(baseline.normalSpo2Min - health.spo2).toStringAsFixed(1)}% below normal'
                : 'Normal',
            isNormal: health.spo2 >= baseline.normalSpo2Min,
            accent: AppColors.spo2,
            emptyMessage:
                'Connect your PRANA sensor to track how well your blood is '
                'carrying oxygen.',
            chart: PranaLineChart(
              title: 'Recent readings',
              dataPoints: controller.spo2History,
              baselineMin: baseline.normalSpo2Min,
              baselineMax: 99.0,
              unit: '%',
              lineColor: AppColors.spo2,
              bandLabel: 'Your normal floor',
              valueDecimals: 0,
            ),
            stats: [
              StatTile(
                label: 'Now',
                value: health.spo2.toStringAsFixed(1),
                unit: '%',
                valueColor: AppColors.spo2,
                filled: true,
                accent: AppColors.spo2,
              ),
              StatTile(
                label: 'Your normal floor',
                value: baseline.normalSpo2Min.toStringAsFixed(0),
                unit: '%',
                filled: true,
                accent: AppColors.textSecondary,
              ),
              StatTile(
                label: 'Difference',
                value: health.spo2 < baseline.normalSpo2Min
                    ? '-${(baseline.normalSpo2Min - health.spo2).toStringAsFixed(1)}'
                    : '0.0',
                unit: '%',
                filled: true,
                accent: AppColors.textSecondary,
              ),
            ],
            // Air quality, not breathing rate: the band has no respiration
            // sensor, and the AQI actually feeding the risk engine is the real
            // context for a low oxygen reading.
            extras: [
              StatTile(
                label: 'Air quality',
                value: '${controller.currentEnvironment.aqi}',
                unit: 'AQI',
                icon: Icons.air_rounded,
                accent: AppColors.aqi,
                chipIcon: true,
                filled: true,
              ),
              StatTile(
                label: 'Air is',
                value: controller.currentEnvironment.aqiCategory,
                icon: Icons.eco_rounded,
                accent: AppColors.aqi,
                chipIcon: true,
                filled: true,
              ),
            ],
            analysisText: health.spo2 < baseline.normalSpo2Min
                ? 'Your blood oxygen has dipped below your usual level. PRANA is '
                    'weighing the air quality around you alongside it.'
                : 'Blood oxygen is steady and inside your normal range.',
          ),

          // ── Body temperature ────────────────────────────────────────────────
          _MetricDetailView(
            hasData: hasData,
            metricTitle: 'Body temperature',
            icon: Icons.thermostat_rounded,
            currentValue: health.bodyTemperature.toStringAsFixed(1),
            unit: '°C',
            scale: tempScale,
            reading: health.bodyTemperature,
            baselineText:
                'Your normal range: ${baseline.normalTempMin.toStringAsFixed(1)}–${baseline.normalTempMax.toStringAsFixed(1)} °C',
            statusLabel: health.bodyTemperature > baseline.normalTempMax
                ? '+${(health.bodyTemperature - baseline.normalTempMax).toStringAsFixed(1)}°C above normal'
                : 'Normal',
            isNormal: health.bodyTemperature <= baseline.normalTempMax,
            accent: AppColors.temperature,
            emptyMessage:
                'Connect your PRANA sensor to follow your body temperature '
                'through the day.',
            chart: PranaLineChart(
              title: 'Recent readings',
              dataPoints: controller.tempHistory,
              baselineMin: baseline.normalTempMin,
              baselineMax: baseline.normalTempMax,
              unit: '°C',
              lineColor: AppColors.temperature,
            ),
            stats: [
              StatTile(
                label: 'Now',
                value: health.bodyTemperature.toStringAsFixed(1),
                unit: '°C',
                valueColor: AppColors.temperature,
                filled: true,
                accent: AppColors.temperature,
              ),
              StatTile(
                label: 'Your upper bound',
                value: baseline.normalTempMax.toStringAsFixed(1),
                unit: '°C',
                filled: true,
                accent: AppColors.textSecondary,
              ),
              StatTile(
                label: 'Difference',
                value: health.bodyTemperature > baseline.normalTempMax
                    ? '+${(health.bodyTemperature - baseline.normalTempMax).toStringAsFixed(1)}'
                    : '0.0',
                unit: '°C',
                filled: true,
                accent: AppColors.textSecondary,
              ),
            ],
            extras: [
              StatTile(
                label: 'Air temperature',
                value: controller.currentEnvironment.temperature
                    .toStringAsFixed(0),
                unit: '°C',
                icon: Icons.wb_sunny_rounded,
                accent: AppColors.heatIndex,
                chipIcon: true,
                filled: true,
              ),
              StatTile(
                label: 'Feels like',
                value:
                    controller.currentEnvironment.heatIndex.toStringAsFixed(0),
                unit: '°C',
                icon: Icons.local_fire_department_rounded,
                accent: AppColors.heatIndex,
                chipIcon: true,
                filled: true,
              ),
            ],
            analysisText: health.bodyTemperature > baseline.normalTempMax
                ? 'Your temperature is above your normal range. PRANA is comparing '
                    'it with the heat around you before raising your risk score.'
                : 'Your body is holding its normal temperature.',
          ),

          // ── Sleep ───────────────────────────────────────────────────────────
          const SleepView(),
        ],
      ),
    );
  }
}

/// Shared detail layout for the biometric segments.
///
/// Structured after the reference's reading screen: one very large numeral
/// inside a dial, the dial's two ends labelled with the display range, and the
/// learned healthy band highlighted on the track so "is this normal for me" is
/// answered by position rather than by reading a second number.
class _MetricDetailView extends StatelessWidget {
  final bool hasData;
  final String metricTitle;
  final IconData icon;
  final String currentValue;
  final String unit;
  final _Scale scale;
  final double reading;
  final String baselineText;
  final String statusLabel;
  final bool isNormal;
  final Color accent;
  final Widget chart;
  final List<Widget> stats;

  /// Optional second row of context tiles under the primary stat strip.
  final List<Widget> extras;

  final String analysisText;
  final String emptyMessage;

  const _MetricDetailView({
    required this.hasData,
    required this.metricTitle,
    required this.icon,
    required this.currentValue,
    required this.unit,
    required this.scale,
    required this.reading,
    required this.baselineText,
    required this.statusLabel,
    required this.isNormal,
    required this.accent,
    required this.chart,
    required this.stats,
    required this.analysisText,
    required this.emptyMessage,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xxs,
      AppSpacing.md,
      AppSpacing.navClearance,
    );

    if (!hasData) {
      return SingleChildScrollView(
        padding: padding,
        child: AppCard(
          color: AppColors.surface,
          showBorder: false,
          radius: AppRadius.xl,
          child: EmptyState(
            icon: icon,
            iconColor: accent,
            title: 'No readings yet',
            subtitle: emptyMessage,
            actionLabel: 'Connect device',
            onAction: () => context.read<PranaHealthController>().startBleScan(),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            index: 0,
            child: _ReadingDial(
              metricTitle: metricTitle,
              icon: icon,
              value: currentValue,
              unit: unit,
              scale: scale,
              reading: reading,
              statusLabel: statusLabel,
              isNormal: isNormal,
              baselineText: baselineText,
              accent: accent,
            ),
          ),

          const SectionHeader(title: 'Trend', dense: true),
          FadeSlideIn(index: 1, child: chart),

          const SectionHeader(title: '', dense: true),
          FadeSlideIn(
            index: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          ),
          if (extras.isNotEmpty) ...[
            AppSpacing.gapXs,
            FadeSlideIn(
              index: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < extras.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(child: extras[i]),
                  ],
                ],
              ),
            ),
          ],

          AppSpacing.gapSm,
          FadeSlideIn(
            index: 4,
            child: AppCard(
              color: AppColors.mint.withValues(alpha: 0.5),
              accent: AppColors.primary,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconChip(
                    icon: Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    background: AppColors.surface,
                    size: 34,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What PRANA sees',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          analysisText,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
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

/// The big dial: current reading as a display numeral, positioned on a scale
/// whose healthy band is drawn in.
class _ReadingDial extends StatelessWidget {
  final String metricTitle;
  final IconData icon;
  final String value;
  final String unit;
  final _Scale scale;
  final double reading;
  final String statusLabel;
  final bool isNormal;
  final String baselineText;
  final Color accent;

  const _ReadingDial({
    required this.metricTitle,
    required this.icon,
    required this.value,
    required this.unit,
    required this.scale,
    required this.reading,
    required this.statusLabel,
    required this.isNormal,
    required this.baselineText,
    required this.accent,
  });

  /// Trim a trailing ".0" off a dial-end label — "100" reads better than "100.0".
  static String _tick(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      color: AppColors.surface,
      showBorder: false,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconChip(icon: icon, color: accent, size: 26),
              AppSpacing.hGapXs,
              Flexible(
                child: Text(
                  metricTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          // The dial is capped rather than stretched: on a wide phone a 300pt
          // ring would swallow the fold, and the numeral inside it is already
          // the largest type on the screen.
          LayoutBuilder(
            builder: (context, constraints) {
              final dialSize =
                  constraints.maxWidth.clamp(180.0, 248.0).toDouble();
              return ProgressRing(
                progress: scale.fraction(reading),
                size: dialSize,
                thickness: 13,
                color: isNormal ? accent : AppColors.riskHigh,
                bandStart: scale.bandStart,
                bandEnd: scale.bandEnd,
                startLabel: _tick(scale.min),
                endLabel: _tick(scale.max),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // scaleDown rather than a fixed size: at a 1.3 text scale a
                    // four-character reading would otherwise clip the ring.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedMetricValue(
                        value: value,
                        style: AppTypography.displayHuge.copyWith(
                          fontSize: 52,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metricUnit.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          AppSpacing.gapSm,
          StatusPill(
            label: statusLabel,
            color: isNormal ? AppColors.riskSafe : AppColors.riskHigh,
            backgroundColor:
                isNormal ? AppColors.riskSafeBg : AppColors.riskHighBg,
            icon: isNormal
                ? Icons.check_circle_rounded
                : Icons.trending_up_rounded,
          ),
          AppSpacing.gapSm,
          // The mint swatch ties the caption to the band drawn on the dial, so
          // it's clear which part of the ring "your normal range" refers to.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.mintDeep.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  baselineText,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
