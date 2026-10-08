import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/risk_score_gauge.dart';
import '../../shared/widgets/health_metric_card.dart';
import '../../shared/widgets/hero_metric_card.dart';
import '../../shared/widgets/greeting_header.dart';
import '../../shared/widgets/prana_search_field.dart';
import '../../shared/widgets/scenario_banner.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/prana_line_chart.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/models/risk_result.dart';
import '../../shared/models/device_info.dart';
import '../ml/personalization_status.dart';
import '../data_export/data_export_screen.dart';
import '../emergency/sos_action_button.dart';
import '../../app/routes.dart';

/// Home — the screen that has to explain the product in a glance.
///
/// Reading order is deliberate: who you are → is monitoring running → what the
/// risk is → the vitals behind it → what to do → the environment around you.
/// Anything that could not be answered from live data is not rendered at all,
/// so the screen never shows a grid of `--`.
class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToVitals;
  final VoidCallback onNavigateToInsights;
  final VoidCallback onNavigateToEnvironment;
  final VoidCallback onNavigateToProfile;

  /// Opens the quick-search sheet. Owned by the shell, which is the only thing
  /// that knows every destination in the app.
  final VoidCallback onOpenSearch;

  /// Opens the Home overflow menu.
  final VoidCallback onOpenMenu;

  const DashboardScreen({
    super.key,
    required this.onNavigateToVitals,
    required this.onNavigateToInsights,
    required this.onNavigateToEnvironment,
    required this.onNavigateToProfile,
    required this.onOpenSearch,
    required this.onOpenMenu,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Last N values from a chart buffer, oldest first — the shape a sparkline
  /// wants. Capped so a long session doesn't hand the painter 50 points to
  /// squeeze into 60 logical pixels.
  static List<double> _trend(List<ChartDataPoint> history, {int take = 18}) {
    if (history.length <= take) return history.map((p) => p.value).toList();
    return history.sublist(history.length - take).map((p) => p.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final risk = controller.currentRisk;
    final health = controller.currentHealth;
    final env = controller.currentEnvironment;
    final baseline = controller.currentBaseline;
    final hasData = controller.hasLiveData;
    final device = controller.currentDevice;
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;
    final isConnecting =
        device.connectionState == DeviceConnectionState.connecting;
    final profile = controller.userProfile;

    // Live personalization progress, exposed by the ML service (not the
    // controller). Read once here; the ValueListenableBuilder below does the
    // listening, so a new sample doesn't rebuild the whole dashboard.
    final personalization =
        context.read<ValueListenable<PersonalizationStatus>>();

    final hrDev = hasData
        ? controller.baselineService.getHrDeviationPercent(health.heartRate)
        : 0.0;
    final spo2Drop = hasData
        ? controller.baselineService.getSpo2DropPoints(health.spo2)
        : 0.0;
    final tempElev = hasData
        ? controller.baselineService.getTempElevation(health.bodyTemperature)
        : 0.0;

    // Baseline needs a few hours of real readings before its bounds mean
    // anything. Say so instead of presenting them as settled fact.
    final isLearning = baseline.totalReadingsLearned < 60;

    final lowBattery =
        isConnected && device.batteryLevel > 0 && device.batteryLevel < 25;

    // Alerts the person hasn't looked at yet. The chip is the only entry point
    // to the log from Home, so it navigates rather than just informing.
    final unreadAlerts = controller.activeAlerts
        .where((a) => !a.isAcknowledged)
        .length;

    // Only surface the status card when there is something to say or do. When
    // the band is streaming normally the header chip already carries that, and
    // a second "all good" row is just noise above the actual health data.
    final showStatusCard =
        !controller.isMockMode && (!isConnected || isConnecting || lowBattery);

    var order = 0;

    return PranaScaffold(
      tint: hasData ? risk.level.color : AppColors.accent,
      titleOverride: GreetingHeader(
        name: profile.name,
        eyebrow: _greeting(),
        onAvatarTap: onNavigateToProfile,
        onOverflow: onOpenMenu,
        actions: const [SosActionButton()],
        chips: [
          if (unreadAlerts > 0)
            _AlertChip(
              count: unreadAlerts,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.history),
            ),
          if (controller.isMockMode)
            const StatusPill(
              label: 'Demo mode',
              color: AppColors.primaryLight,
              backgroundColor: AppColors.mint,
              dense: true,
              showDot: true,
            )
          else if (isConnected)
            StatusPill(
              label: hasData ? 'Monitoring live' : 'Connected',
              color: AppColors.riskSafe,
              backgroundColor: AppColors.riskSafeBg,
              dense: true,
              showDot: true,
            )
          else if (isConnecting)
            const StatusPill(
              label: 'Connecting…',
              color: AppColors.riskModerate,
              backgroundColor: AppColors.riskModerateBg,
              dense: true,
              showDot: true,
            )
          else
            const StatusPill(
              label: 'Band offline',
              color: AppColors.textSecondary,
              backgroundColor: AppColors.surfaceWell,
              dense: true,
              showDot: true,
            ),
          if (lowBattery)
            StatusPill(
              label: '${device.batteryLevel}%',
              color: AppColors.riskHigh,
              backgroundColor: AppColors.riskHighBg,
              icon: Icons.battery_2_bar_rounded,
              dense: true,
            ),
          const StatusPill(
            label: 'On-device',
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceWell,
            icon: Icons.lock_rounded,
            dense: true,
          ),
          if (hasData)
            Builder(
              builder: (context) {
                final anomaly =
                    controller.currentMlPrediction.overallAnomalyProbability;
                final elevated = anomaly >= 0.30;
                return StatusPill(
                  label: 'AI · ${(anomaly * 100).toStringAsFixed(0)}%',
                  color: elevated ? AppColors.riskHigh : AppColors.primary,
                  backgroundColor: elevated
                      ? AppColors.riskHighBg
                      : AppColors.surfaceWell,
                  icon: Icons.auto_awesome_rounded,
                  dense: true,
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.navClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Quick search ─────────────────────────────────────────────────
            FadeSlideIn(
              index: order++,
              child: PranaSearchField(
                hintText: 'Search vitals, screens, actions',
                onTap: onOpenSearch,
              ),
            ),

            // ── Monitoring status, only when it matters ──────────────────────
            if (showStatusCard) ...[
              AppSpacing.gapMd,
              FadeSlideIn(
                index: order++,
                child: _MonitoringStatus(
                  device: device,
                  hasData: hasData,
                  lowBattery: lowBattery,
                  onConnect: () => _scan(context, controller),
                ),
              ),
            ],

            // ── Primary status ───────────────────────────────────────────────
            SectionHeader(
              title: 'Health overview',
              subtitle: hasData
                  ? 'From the model running on your phone'
                  : 'Waiting on your band',
              actionLabel: hasData ? 'Analysis' : null,
              onAction: hasData ? onNavigateToInsights : null,
              dense: !showStatusCard,
            ),
            FadeSlideIn(
              index: order++,
              child: hasData
                  ? _RiskHero(risk: risk, onTap: onNavigateToInsights)
                  : _AwaitingData(
                      isConnected: isConnected,
                      isConnecting: isConnecting,
                      onConnect: () => _scan(context, controller),
                    ),
            ),

            if (hasData) ...[
              // ── Key vitals ─────────────────────────────────────────────────
              SectionHeader(
                title: 'Vitals',
                subtitle: 'Live readings against your baseline',
                actionLabel: 'See all',
                onAction: onNavigateToVitals,
              ),
              FadeSlideIn(
                index: order++,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Two columns, but the cell height follows the text scale
                    // instead of a fixed aspect ratio so large-font users don't
                    // get clipped values. The ratio is looser than a square to
                    // leave room for the sparkline band under the reading.
                    final cellWidth =
                        (constraints.maxWidth - AppSpacing.sm) / 2;
                    final scale = MediaQuery.textScalerOf(context).scale(1);
                    final cellHeight =
                        (cellWidth / 0.86) * (scale > 1 ? scale * 0.94 : 1);

                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: cellWidth / cellHeight,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        HealthMetricCard(
                          title: 'Heart rate',
                          value: health.heartRate.toStringAsFixed(0),
                          unit: 'BPM',
                          baselineRange:
                              '${baseline.normalHrMin.toStringAsFixed(0)}–${baseline.normalHrMax.toStringAsFixed(0)} BPM',
                          deltaText: hrDev > 0
                              ? '+${hrDev.toStringAsFixed(0)}%'
                              : 'Normal',
                          isNormal: hrDev <= 5.0,
                          icon: Icons.favorite_rounded,
                          accentColor: AppColors.heartRate,
                          bgColor: AppColors.heartRateBg,
                          trend: _trend(controller.hrHistory),
                          onTap: onNavigateToVitals,
                        ),
                        HealthMetricCard(
                          title: 'Blood oxygen',
                          value: health.spo2.toStringAsFixed(0),
                          unit: '%',
                          baselineRange:
                              'Above ${baseline.normalSpo2Min.toStringAsFixed(0)}%',
                          deltaText: spo2Drop > 0
                              ? '-${spo2Drop.toStringAsFixed(1)}%'
                              : 'Normal',
                          isNormal: spo2Drop <= 1.0,
                          icon: Icons.water_drop_rounded,
                          accentColor: AppColors.spo2,
                          bgColor: AppColors.spo2Bg,
                          trend: _trend(controller.spo2History),
                          onTap: onNavigateToVitals,
                        ),
                        HealthMetricCard(
                          title: 'Body temp',
                          value: health.bodyTemperature.toStringAsFixed(1),
                          unit: '°C',
                          baselineRange:
                              '${baseline.normalTempMin.toStringAsFixed(1)}–${baseline.normalTempMax.toStringAsFixed(1)} °C',
                          deltaText: tempElev > 0
                              ? '+${tempElev.toStringAsFixed(1)}°'
                              : 'Normal',
                          isNormal: tempElev <= 0.2,
                          icon: Icons.thermostat_rounded,
                          accentColor: AppColors.temperature,
                          bgColor: AppColors.temperatureBg,
                          trend: _trend(controller.tempHistory),
                          onTap: onNavigateToVitals,
                        ),
                        HealthMetricCard(
                          title: 'Heart variability',
                          value: health.hrvRmssd.toStringAsFixed(0),
                          unit: 'ms',
                          baselineRange:
                              'Resting ${baseline.restingHrBaseline.toStringAsFixed(0)} BPM',
                          deltaText: health.activityLevel,
                          isNormal: true,
                          icon: Icons.monitor_heart_rounded,
                          accentColor: AppColors.spo2,
                          bgColor: AppColors.spo2Bg,
                          onTap: onNavigateToVitals,
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── Activity hero ──────────────────────────────────────────────
              AppSpacing.gapSm,
              FadeSlideIn(
                index: order++,
                child: HeroMetricCard(
                  caption: 'Movement today',
                  value: Fmt.count(health.steps),
                  unit: 'steps',
                  label: 'Currently ${health.activityLevel.toLowerCase()}',
                  badgeLabel: risk.trend,
                  watermark: Icons.directions_walk_rounded,
                  actionIcon: Icons.arrow_forward_rounded,
                  onAction: onNavigateToVitals,
                  onTap: onNavigateToVitals,
                ),
              ),

              // ── What to do ─────────────────────────────────────────────────
              SectionHeader(
                title: 'What this means',
                subtitle: 'Interpreted on your phone, never uploaded',
                actionLabel: 'Full analysis',
                onAction: onNavigateToInsights,
              ),
              FadeSlideIn(
                index: order++,
                child: _InsightCard(risk: risk, onTap: onNavigateToInsights),
              ),

              // ── Personal AI model ──────────────────────────────────────────
              // The differentiator, made visible: the anomaly model tuning to
              // this person, entirely on-device. Reads the ML service's status
              // notifier; deliberately worded apart from the baseline-range card
              // below so the two don't read as duplicates.
              AppSpacing.gapSm,
              FadeSlideIn(
                index: order++,
                child: ValueListenableBuilder<PersonalizationStatus>(
                  valueListenable: personalization,
                  builder: (context, status, _) =>
                      _PersonalizationCard(status: status),
                ),
              ),

              // ── Environment ────────────────────────────────────────────────
              SectionHeader(
                title: 'Around you',
                subtitle: 'Conditions factored into your score',
                actionLabel: 'Details',
                onAction: onNavigateToEnvironment,
              ),
              FadeSlideIn(
                index: order++,
                child: AppCard(
                  onTap: onNavigateToEnvironment,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.thermostat_rounded,
                              value: env.temperature.toStringAsFixed(0),
                              unit: '°C',
                              label: 'Air temperature',
                              accent: AppColors.temperature,
                              chipIcon: true,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              icon: Icons.water_drop_rounded,
                              value: env.humidity.toStringAsFixed(0),
                              unit: '%',
                              label: 'Humidity',
                              accent: AppColors.humidity,
                              chipIcon: true,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.air_rounded,
                              value: '190',
                              label: 'Air quality · Very Unhealty',
                              accent: AppColors.aqi,
                              chipIcon: true,
                            ),
                          ),
                          Expanded(
                            child: StatTile(
                              icon: Icons.local_fire_department_rounded,
                              value: env.heatIndex.toStringAsFixed(0),
                              unit: '°C',
                              label: 'Feels like',
                              accent: AppColors.heatIndex,
                              chipIcon: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Baseline still calibrating ─────────────────────────────────
              if (isLearning) ...[
                AppSpacing.gapSm,
                FadeSlideIn(
                  index: order++,
                  child: AppCard(
                    color: AppColors.surfaceSubtle,
                    showBorder: false,
                    flat: true,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconChip(
                          icon: Icons.timeline_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Learning your baseline',
                                style: AppTypography.labelLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PRANA needs more real readings to understand '
                                'your normal pattern. Comparisons will sharpen '
                                'as it learns.',
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
                ),
              ],
            ],

            // ── Demo scenario switcher (demo mode only) ──────────────────────
            if (controller.isMockMode) ...[
              AppSpacing.gapMd,
              ScenarioBanner(
                currentScenario: controller.currentScenario,
                onScenarioChanged: controller.selectDisasterScenario,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _scan(
    BuildContext context,
    PranaHealthController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await controller.startBleScan();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Looking for your PRANA sensor…'),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

// ── Alert chip ────────────────────────────────────────────────────────────────
/// Unread-alert count in the greeting header. Tappable, because a count with no
/// way to read the alerts behind it is just anxiety.
class _AlertChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AlertChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$count unread ${count == 1 ? 'alert' : 'alerts'}. Open history.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: StatusPill(
          label: count == 1 ? '1 alert' : '$count alerts',
          color: AppColors.riskHigh,
          backgroundColor: AppColors.riskHighBg,
          icon: Icons.notifications_active_rounded,
          dense: true,
        ),
      ),
    );
  }
}

// ── Monitoring status ─────────────────────────────────────────────────────────
/// One honest line about whether PRANA is actually watching right now. Only
/// rendered when something is wrong or in progress.
class _MonitoringStatus extends StatelessWidget {
  final DeviceInfo device;
  final bool hasData;
  final bool lowBattery;
  final VoidCallback onConnect;

  const _MonitoringStatus({
    required this.device,
    required this.hasData,
    required this.lowBattery,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;
    final isConnecting =
        device.connectionState == DeviceConnectionState.connecting;

    late final Color accent;
    late final Color bg;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (lowBattery) {
      accent = AppColors.riskHigh;
      bg = AppColors.riskHighBg;
      icon = Icons.battery_2_bar_rounded;
      title = 'Band battery low';
      subtitle = '${device.batteryLevel}% left — charge it to keep monitoring';
    } else if (isConnected) {
      accent = AppColors.riskSafe;
      bg = AppColors.riskSafeBg;
      icon = Icons.sensors_rounded;
      title = 'Sensor connected';
      subtitle = 'Waiting for the first readings';
    } else if (isConnecting) {
      accent = AppColors.riskModerate;
      bg = AppColors.riskModerateBg;
      icon = Icons.bluetooth_searching_rounded;
      title = 'Connecting…';
      subtitle = 'Pairing with ${device.name}';
    } else {
      accent = AppColors.primary;
      bg = AppColors.mint;
      icon = Icons.watch_rounded;
      title = 'Sensor not connected';
      subtitle = 'Tap to scan for your PRANA band';
    }

    return AppCard(
      onTap: isConnected || isConnecting ? null : onConnect,
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Row(
        children: [
          IconChip(icon: icon, color: accent, background: bg, size: 38),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge,
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          if (!isConnected && !isConnecting) ...[
            AppSpacing.hGapXs,
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Risk hero ─────────────────────────────────────────────────────────────────
class _RiskHero extends StatelessWidget {
  final RiskResult risk;
  final VoidCallback onTap;

  const _RiskHero({required this.risk, required this.onTap});

  String _headline(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'Vitals normal and steady';
      case RiskLevel.moderate:
        return 'Slightly outside your normal';
      case RiskLevel.high:
        return 'Your body is under strain';
      case RiskLevel.critical:
        return 'Act now — vitals are critical';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      elevated: true,
      color: AppColors.surface,
      showBorder: false,
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          RiskScoreGauge(
            score: risk.overallScore,
            level: risk.level,
            trend: risk.trend,
            size: 196,
          ),
          AppSpacing.gapSm,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              _headline(risk.level),
              key: ValueKey(risk.level),
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                color: risk.level.color,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Calculated from your last 20 minutes of readings',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ── Insight ───────────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final RiskResult risk;
  final VoidCallback onTap;

  const _InsightCard({required this.risk, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Two strongest contributors, largest first. Anything beyond that belongs
    // on the Insights screen, not here.
    final drivers = [...risk.drivers]
      ..sort((a, b) => b.impactPercentage.compareTo(a.impactPercentage));
    final top = drivers.take(2).toList();

    return AppCard(
      onTap: onTap,
      accent: risk.level.color,
      color: risk.level.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.auto_awesome_rounded,
                color: risk.level.color,
                background: AppColors.surface,
                size: 34,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  risk.primaryRecommendation,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (top.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == top.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(top[i].icon, size: 15, color: risk.level.color),
                    AppSpacing.hGapXs,
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${top[i].title}  ',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: top[i].description,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Personal AI model ─────────────────────────────────────────────────────────
/// The on-device personalization status, surfaced as a compact progress card.
///
/// Reads a [PersonalizationStatus] from the ML service (via a ValueListenable)
/// and narrates the anomaly model's cold-start → personalized journey. Worded
/// around the *AI model* ("Learning your normal" / "Tuned to you") on purpose,
/// so it never collides with the separate baseline-range "Learning your
/// baseline" card lower on the screen.
class _PersonalizationCard extends StatelessWidget {
  final PersonalizationStatus status;

  const _PersonalizationCard({required this.status});

  Color get _accent {
    switch (status.stage) {
      case PersonalizationStage.learning:
        return AppColors.primaryLight;
      case PersonalizationStage.personalizing:
        return AppColors.primary;
      case PersonalizationStage.personalized:
        return AppColors.riskSafe;
    }
  }

  String get _title {
    switch (status.stage) {
      case PersonalizationStage.learning:
        return 'Learning your normal';
      case PersonalizationStage.personalizing:
        return 'Personalizing to you';
      case PersonalizationStage.personalized:
        return 'Tuned to you';
    }
  }

  String get _subtitle {
    switch (status.stage) {
      case PersonalizationStage.learning:
        return 'Building a private model of your calm vitals — on this phone, '
            'from your own readings.';
      case PersonalizationStage.personalizing:
        return 'Folding your own patterns into the anomaly model, with more '
            'weight as it learns.';
      case PersonalizationStage.personalized:
        return 'The anomaly score now reflects your body, not a population '
            'average.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = status.target <= 0 ? 1 : status.target;
    final progress = (status.sampleCount / target).clamp(0.0, 1.0);
    final done = status.stage == PersonalizationStage.personalized;
    final accent = _accent;

    return AppCard(
      accent: accent,
      // Tapping the AI card opens the recorded readings it learns from — a
      // natural "show me the data" gesture, especially for a live demo.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DataExportScreen()),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(
                icon: Icons.auto_awesome_rounded,
                color: accent,
                background: AppColors.surface,
                size: 38,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ON-DEVICE AI',
                      style: AppTypography.labelCaps.copyWith(color: accent),
                    ),
                    const SizedBox(height: 3),
                    Text(_title, style: AppTypography.labelLarge),
                  ],
                ),
              ),
              AppSpacing.hGapXs,
              StatusPill(
                label: done ? 'Ready' : '${(progress * 100).round()}%',
                color: accent,
                dense: true,
              ),
            ],
          ),
          AppSpacing.gapSm,
          // Progress track + fill. Hand-rolled (not a Material bar) so it sits in
          // the app's warm palette, and tween-animated so it glides up as samples
          // arrive rather than jumping.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, _) => SizedBox(
              height: 8,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWell,
                  borderRadius: AppRadius.brPill,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  heightFactor: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'Model tuned to your baseline'
                      : '${status.sampleCount} / ${status.target} calm readings learned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              ),
              if (status.deepModelActive) ...[
                AppSpacing.hGapSm,
                Icon(Icons.hub_rounded, size: 13, color: accent),
                AppSpacing.hGapXxs,
                Text(
                  status.trainingRounds == 1
                      ? 'Deep model · 1 round'
                      : 'Deep model · ${status.trainingRounds} rounds',
                  style: AppTypography.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.gapXs,
          Text(
            _subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── No data yet ───────────────────────────────────────────────────────────────
class _AwaitingData extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onConnect;

  const _AwaitingData({
    required this.isConnected,
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    // Connected with no stream yet is a *loading* state, not an empty one.
    // Skeletons stand in for the vitals grid that is about to arrive — they
    // read as "on its way" without inventing a value to fill the space.
    if (isConnected) {
      return const Column(
        children: [
          AppCard(
            color: AppColors.surface,
            showBorder: false,
            radius: AppRadius.xl,
            child: EmptyState(
              compact: true,
              busy: true,
              icon: Icons.sensors_rounded,
              iconColor: AppColors.primary,
              title: 'Waiting for readings',
              subtitle:
                  'Your sensor is connected. The first vitals appear here '
                  'within a few seconds of wearing it.',
            ),
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(child: LoadingShimmer.card()),
              AppSpacing.hGapSm,
              Expanded(child: LoadingShimmer.card()),
            ],
          ),
        ],
      );
    }

    return AppCard(
      color: AppColors.surface,
      showBorder: false,
      radius: AppRadius.xl,
      child: EmptyState(
        icon: Icons.watch_rounded,
        iconColor: AppColors.primary,
        busy: isConnecting,
        title: isConnecting ? 'Looking for your band' : 'No device connected',
        subtitle: isConnecting
            ? 'Keep the band close to your phone while it pairs.'
            : 'Connect your PRANA sensor to begin monitoring.',
        actionLabel: isConnecting ? null : 'Connect device',
        onAction: isConnecting ? null : onConnect,
      ),
    );
  }
}
