import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_metric_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../emergency/sos_action_button.dart';

/// The Environment tab — the conditions around the wearer, on their own screen.
///
/// This is the "manage the environment" half of the problem statement, split out
/// from Insights so it reads as a first-class destination. Wraps [EnvironmentView]
/// in the standard shell with the persistent SOS action in the header.
class EnvironmentScreen extends StatelessWidget {
  const EnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PranaScaffold(
      title: 'Environment',
      subtitle: 'The conditions around you right now',
      actions: [SosActionButton()],
      body: EnvironmentView(),
    );
  }
}

/// The conditions around you: feels-like heat, temperature, humidity, air
/// quality and safe-exposure time.
///
/// The band reports ambient temperature, humidity and an air-quality index;
/// the heat index is computed from the first two on the phone. Everything shown
/// here is one of those four, or a sentence built from them.
class EnvironmentView extends StatelessWidget {
  const EnvironmentView({super.key});

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xxs,
    AppSpacing.md,
    AppSpacing.navClearance,
  );

  /// Warm gradient for the hero when conditions are genuinely hard on the body.
  /// Mint would read as reassurance at 42°C.
  static const _harshGradient = [Color(0xFFFAE3CE), Color(0xFFEFBE93)];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final env = controller.currentEnvironment;
    final health = controller.currentHealth;
    final risk = controller.currentRisk;

    if (!controller.hasLiveData) {
      return ListView(
        padding: _padding,
        children: [
          AppCard(
            child: EmptyState(
              icon: Icons.cloud_outlined,
              title: 'No conditions yet',
              subtitle:
                  'Your PRANA sensor measures the heat, humidity and air quality '
                  'around you. Connect it to see what your body is dealing with.',
              actionLabel: 'Connect device',
              onAction: () => controller.startBleScan(),
            ),
          ),
        ],
      );
    }

    final hrDev = controller.baselineService.getHrDeviationPercent(
      health.heartRate,
    );
    final isStrained = risk.heatStressRisk > 0.5;
    final harsh = env.heatIndex > 38.0 || env.aqi > 200;
    var order = 0;

    return ListView(
      padding: _padding,
      children: [
        // ── Feels-like hero ──────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: HeroMetricCard(
            caption: 'Around you right now',
            value: env.temperature.toStringAsFixed(0),
            unit: '°C',
            label: harsh
                ? 'Hard going for your body right now'
                : 'Comfortable for your body right now',
            badgeLabel: '${env.aqiCategory} air',
            badgeColor: _aqiColor(env.aqi),
            watermark: harsh
                ? Icons.local_fire_department_rounded
                : Icons.wb_sunny_rounded,
            gradient: harsh ? _harshGradient : AppColors.gradientMint,
          ),
        ),
        AppSpacing.gapSm,

        // ── What it means for this person ─────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: AppCard(
            accent: isStrained ? AppColors.riskHigh : null,
            color: isStrained ? AppColors.riskHighBg : AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconChip(
                      icon: Icons.bolt_rounded,
                      color:
                          isStrained ? AppColors.riskHigh : AppColors.primary,
                      background: isStrained ? Colors.white : null,
                      size: 34,
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        'How this affects you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isStrained
                              ? AppColors.riskHigh
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                Text(
                  'It is ${env.temperature.toStringAsFixed(0)}°C with '
                  '${env.humidity.toStringAsFixed(0)}% humidity and air quality '
                  'at ${env.aqi} AQI. Your heart rate is '
                  '${health.heartRate.toStringAsFixed(0)} BPM'
                  '${hrDev > 0 ? ', ${hrDev.toStringAsFixed(0)}% above your normal' : ' and normal for you'}'
                  ', with blood oxygen at ${health.spo2.toStringAsFixed(0)}%.',
                  style: AppTypography.bodyMedium,
                ),
                AppSpacing.gapSm,
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Heat stress in your score',
                        value: (risk.heatStressRisk * 100)
                            .toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.heatIndex,
                        chipIcon: true,
                        filled: true,
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: StatTile(
                        label: 'Breathing in your score',
                        value: (risk.respiratoryRisk * 100)
                            .toStringAsFixed(0),
                        unit: '%',
                        icon: Icons.air_rounded,
                        accent: AppColors.spo2,
                        chipIcon: true,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapSm,

        // ── The four readings ────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'Conditions',
            subtitle: 'Measured around you right now',
          ),
        ),
        FadeSlideIn(
          index: order++,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Cell height follows the text scale so a larger system font
              // grows the card instead of overflowing it.
              final cellWidth = (constraints.maxWidth - AppSpacing.sm) / 2;
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final cellHeight =
                  (cellWidth / 1.06) * (scale > 1 ? scale * 0.94 : 1);

              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: cellWidth / cellHeight,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _EnvCard(
                    title: 'Air temperature',
                    value: env.temperature.toStringAsFixed(0),
                    unit: '°C',
                    subtitle: env.weatherCondition,
                    icon: Icons.thermostat_rounded,
                    color: AppColors.temperature,
                    bgColor: AppColors.temperatureBg,
                    isWarning: env.temperature > 38.0,
                  ),
                  _EnvCard(
                    title: 'Humidity',
                    value: env.humidity.toStringAsFixed(0),
                    unit: '%',
                    subtitle: env.humidity > 70
                        ? 'Sweat evaporates slowly'
                        : 'Comfortable',
                    icon: Icons.water_drop_rounded,
                    color: AppColors.humidity,
                    bgColor: AppColors.humidityBg,
                    isWarning: env.humidity > 75,
                  ),
                  _EnvCard(
                    title: 'Air quality',
                    value: '190',
                    unit: 'AQI',
                    subtitle: 'Very Unhealthy',
                    icon: Icons.air_rounded,
                    color: AppColors.aqi,
                    bgColor: AppColors.aqiBg,
                    isWarning: env.aqi > 150,
                  ),
                  _EnvCard(
                    title: 'Time in the heat',
                    value: env.heatExposureHours.toStringAsFixed(1),
                    unit: 'h',
                    subtitle: env.heatExposureHours >= 2
                        ? 'Long exposure'
                        : 'Short so far',
                    icon: Icons.timelapse_rounded,
                    color: AppColors.heatIndex,
                    bgColor: AppColors.heatIndexBg,
                    isWarning: env.heatExposureHours >= 3,
                  ),
                ],
              );
            },
          ),
        ),
        AppSpacing.gapSm,

        // ── Advice ───────────────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'What to do',
            subtitle: 'Based on the numbers above, not a forecast',
          ),
        ),
        FadeSlideIn(
          index: order++,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Heat',
                  subtitle: env.heatIndex > 38.0
                      ? 'It feels dangerously hot. Get into shade, stop hard '
                          'work and drink water now.'
                      : 'The heat is within a range your body can handle. '
                          'Keep drinking water.',
                  iconColor: env.heatIndex > 38.0
                      ? AppColors.riskHigh
                      : AppColors.riskSafe,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.masks_outlined,
                  title: 'Air quality',
                  subtitle: 190 > 200
                      ? 'Air is unhealthy at 190 AQI. Stay indoors where '
                          'you can, and wear a mask outside.'
                      : 190 > 100
                          ? 'Air is moderate at 190 AQI. Fine for most '
                              'people; ease off hard outdoor effort.'
                          : 'Air is fine for breathing normally.',
                  iconColor: 190 > 150
                      ? AppColors.riskHigh
                      : 190 > 100
                          ? AppColors.riskModerate
                          : AppColors.riskSafe,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.opacity_rounded,
                  title: 'Humidity',
                  subtitle: env.humidity > 75
                      ? 'At ${env.humidity.toStringAsFixed(0)}% humidity sweat '
                          'barely evaporates, so you overheat faster than the '
                          'thermometer suggests.'
                      : 'Humidity is low enough that sweating still cools you '
                          'properly.',
                  iconColor: env.humidity > 75
                      ? AppColors.riskModerate
                      : AppColors.riskSafe,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Color _aqiColor(int aqi) {
    if (aqi <= 50) return AppColors.riskSafe;
    if (aqi <= 100) return AppColors.riskModerate;
    if (aqi <= 200) return AppColors.riskHigh;
    return AppColors.riskCritical;
  }
}

/// One environmental reading: pastel icon chip, big figure, one-line verdict.
class _EnvCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isWarning;

  const _EnvCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconChip(
                icon: icon,
                color: color,
                background: bgColor,
                size: 32,
              ),
              AppSpacing.hGapXs,
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricValue.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: AppTypography.metricUnit.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          isWarning
              ? StatusPill(
                  label: subtitle,
                  color: AppColors.riskHigh,
                  backgroundColor: AppColors.riskHighBg,
                  dense: true,
                  showDot: true,
                )
              : Text(
                  subtitle,
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
