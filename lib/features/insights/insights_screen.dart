import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/ai/prediction_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/risk_result.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/prana_line_chart.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';
import '../emergency/sos_action_button.dart';

/// Insights — the on-device analysis of the wearer's own vitals.
///
/// This is the "manage the human" half of the app: the risk score and the model
/// reasoning behind it. The surrounding conditions now live on their own
/// [EnvironmentScreen] tab, so nothing here is about the weather except where it
/// shows up as a *driver* of the person's own risk.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PranaScaffold(
      title: 'Insights',
      subtitle: 'Worked out on your phone, from your own readings',
      actions: [SosActionButton()],
      body: _AnalysisView(),
    );
  }
}

/// The analysis body: why the score is what it is.
///
/// Every sentence on this screen traces to a number the app actually has —
/// a sensor reading, a learned baseline bound, a model output or a risk-engine
/// weight. Nothing is narrated from a value PRANA cannot measure.
class _AnalysisView extends StatelessWidget {
  const _AnalysisView();

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xxs,
    AppSpacing.md,
    AppSpacing.navClearance,
  );

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final risk = controller.currentRisk;
    final health = controller.currentHealth;
    final env = controller.currentEnvironment;
    final baseline = controller.currentBaseline;
    final prediction = controller.currentMlPrediction;

    // No live stream means every number below would be a zero dressed up as a
    // finding. Say so instead.
    if (!controller.hasLiveData) {
      return ListView(
        padding: _padding,
        children: [
          AppCard(
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'Nothing to analyse yet',
              subtitle:
                  'PRANA needs live readings from your sensor before it can '
                  'explain what your body is doing.',
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

    final spo2Drop = controller.baselineService.getSpo2DropPoints(health.spo2);

    final hot = env.heatIndex > 35.0;
    final learning = baseline.totalReadingsLearned < 60;

    // Sorted highest-impact first: the list answers "what is pushing my score
    // up", so the answer belongs at the top.
    final drivers = [...risk.drivers]
      ..sort((a, b) => b.impactPercentage.compareTo(a.impactPercentage));

    var order = 0;

    return ListView(
      padding: _padding,
      children: [
        // ── The model itself ────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: _ModelCard(
            anomalyProbability: prediction.overallAnomalyProbability,
            signalsAvailable: prediction.signalsAvailable,
            signalsTotal: prediction.signalsTotal,
            trend: risk.trend,
          ),
        ),
        AppSpacing.gapSm,

        // ── Still learning ──────────────────────────────────────────────────
        if (learning)
          FadeSlideIn(
            index: order++,
            child: _LearningNotice(readings: baseline.totalReadingsLearned),
          ),

        // ── Plain-language observations ─────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'What PRANA noticed',
            subtitle: 'Read straight off your sensor and your baseline',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.favorite_rounded,
                  title: 'Your heart rate',
                  subtitle: hrDev.abs() > 5.0
                      ? '${health.heartRate.toStringAsFixed(0)} BPM — '
                            '${hrDev.abs().toStringAsFixed(0)}% '
                            '${hrDev > 0 ? 'above' : 'below'} your usual range.'
                      : '${health.heartRate.toStringAsFixed(0)} BPM, inside your '
                            'usual ${baseline.normalHrMin.toStringAsFixed(0)}–'
                            '${baseline.normalHrMax.toStringAsFixed(0)} BPM.',
                  iconColor: hrDev.abs() > 5.0
                      ? AppColors.riskHigh
                      : AppColors.heartRate,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.water_drop_rounded,
                  title: 'Blood oxygen',
                  subtitle: spo2Drop > 0
                      ? '${health.spo2.toStringAsFixed(0)}% — '
                            '${spo2Drop.toStringAsFixed(1)} points under your '
                            'normal floor of '
                            '${baseline.normalSpo2Min.toStringAsFixed(0)}%.'
                      : '${health.spo2.toStringAsFixed(0)}%, at or above your '
                            'normal floor.',
                  iconColor: spo2Drop > 0 ? AppColors.riskHigh : AppColors.spo2,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.thermostat_rounded,
                  title: 'Heat around you',
                  subtitle: hot
                      ? 'Feels like ${env.heatIndex.toStringAsFixed(0)}°C. '
                            'Coping with it is '
                            '${(risk.heatStressRisk * 100).toStringAsFixed(0)}% of '
                            'your current risk.'
                      : 'Feels like ${env.heatIndex.toStringAsFixed(0)}°C — '
                            'little chance of overheating right now.',
                  iconColor: hot ? AppColors.riskHigh : AppColors.heatIndex,
                ),
                const Divider(height: 1, color: AppColors.borderLight),

                // Heart rate variability, not a recovery percentage.
                InfoRow(
                  icon: Icons.monitor_heart_rounded,
                  title: 'Heart rate variability',
                  subtitle: health.hrvRmssd > 0
                      ? '${health.hrvRmssd.toStringAsFixed(0)} ms. Higher '
                            'generally means your nervous system is rested.'
                      : 'Waiting for a stable reading from your band.',
                  iconColor: AppColors.sleep,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.directions_walk_rounded,
                  title: 'Movement today',
                  subtitle:
                      '${Fmt.count(health.steps)} steps so far, currently '
                      '${health.activityLevel.toLowerCase()}.',
                  iconColor: AppColors.activity,
                ),
              ],
            ),
          ),
        ),

        AppSpacing.gapSm,

        // ── ML prediction breakdown ─────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'AI prediction breakdown',
            subtitle: 'Signals identified by the on-device ML model',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: _MlPredictionBreakdown(prediction: prediction),
        ),

        AppSpacing.gapSm,

        // ── Risk-engine interpretation ──────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'Risk interpretation',
            subtitle: 'How PRANA combines ML with your sensor context',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: _DomainCard(
            title: 'Heat stress',
            score: risk.heatStressRisk,
            color: AppColors.heatIndex,
            icon: Icons.wb_sunny_rounded,
            explanation:
                'How the heat around you is affecting your body temperature',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: _DomainCard(
            title: 'Breathing',
            score: risk.respiratoryRisk,
            color: AppColors.spo2,
            icon: Icons.air_rounded,
            explanation: 'Air quality where you are, and your blood oxygen',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: _DomainCard(
            title: 'Heart',
            score: risk.cardiovascularRisk,
            color: AppColors.heartRate,
            icon: Icons.favorite_rounded,
            explanation: 'How far your heart rate has drifted from your normal',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: _DomainCard(
            title: 'Fatigue',
            score: risk.fatigueRisk,
            color: AppColors.sleep,
            icon: Icons.battery_3_bar_rounded,
            explanation:
                'Your movement, heart rate recovery and time on your feet',
          ),
        ),

        AppSpacing.gapSm,

        // ── The drivers the engine named ─────────────────────────────────────
        if (drivers.isNotEmpty) ...[
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: 'What is pushing the score',
              subtitle:
                  '${drivers.length} '
                  '${drivers.length == 1 ? 'factor' : 'factors'}, '
                  'biggest first',
            ),
          ),

          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < drivers.length; i++) ...[
                    if (i > 0) AppSpacing.gapSm,
                    _DriverBar(driver: drivers[i]),
                  ],
                ],
              ),
            ),
          ),

          AppSpacing.gapSm,
        ],

        // ── What to do ───────────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(title: 'What to do now'),
        ),

        FadeSlideIn(
          index: order++,
          child: _AdviceCard(
            level: risk.level,
            primary: risk.primaryRecommendation,
            secondary: risk.secondaryRecommendation,
          ),
        ),

        AppSpacing.gapSm,

        // ── Trend ────────────────────────────────────────────────────────────
        FadeSlideIn(
          index: order++,
          child: const SectionHeader(
            title: 'Risk trend',
            subtitle: 'Every reading since PRANA started streaming',
          ),
        ),

        FadeSlideIn(
          index: order++,
          child: PranaLineChart(
            title: 'Risk score',
            dataPoints: controller.riskScoreHistory,
            baselineMin: 0.0,
            baselineMax: 29.0,
            unit: '',
            bandLabel: 'Safe zone (0–29)',
            valueDecimals: 0,
            lineColor: risk.level.color,
          ),
        ),
      ],
    );
  }
}

/// The dark card that says, plainly, what is doing the thinking.
class _ModelCard extends StatelessWidget {
  final double anomalyProbability;
  final int signalsAvailable;
  final int signalsTotal;
  final String trend;

  const _ModelCard({
    required this.anomalyProbability,
    required this.signalsAvailable,
    required this.signalsTotal,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (anomalyProbability * 100).clamp(0.0, 100.0);
    final elevated = percent >= 30;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      showBorder: false,
      radius: AppRadius.xl,
      gradient: const LinearGradient(
        colors: AppColors.gradientDark,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.accent,
                background: Colors.white.withValues(alpha: 0.10),
                size: 34,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  'On-device model',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: StatusPill(
                  label: trend,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  dense: true,
                ),
              ),
            ],
          ),

          AppSpacing.gapMd,

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    percent.toStringAsFixed(0),
                    style: AppTypography.metricHero.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 3),
                child: Text(
                  '%',
                  style: AppTypography.metricUnit.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),

          Text(
            elevated
                ? 'chance your readings are unusual for you'
                : 'chance your readings are unusual — low',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),

          AppSpacing.gapMd,

          Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),

          AppSpacing.gapSm,

          Text(
            '$signalsAvailable of $signalsTotal trained signals are live '
            'from your band right now. The model compares them against '
            'thousands of real recorded sessions to score how unusual this '
            'moment is for a body generally — all of it on this phone.',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the individual outputs currently exposed through PredictionResult.
///
/// The underlying PRANA model is an autoencoder. Its direct output is an
/// anomaly/reconstruction signal. The domain probabilities are currently
/// exposed through PredictionResult as an application compatibility layer.
class _MlPredictionBreakdown extends StatelessWidget {
  final PredictionResult prediction;

  const _MlPredictionBreakdown({required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MlPredictionCard(
          title: 'Heat stress',
          score: prediction.heatStressProbability,
          color: AppColors.heatIndex,
          icon: Icons.wb_sunny_rounded,
          explanation: 'ML-derived heat stress anomaly signal',
        ),
        _MlPredictionCard(
          title: 'Dehydration',
          score: prediction.dehydrationRiskProbability,
          color: AppColors.spo2,
          icon: Icons.water_drop_rounded,
          explanation: 'ML-derived dehydration anomaly signal',
        ),
        _MlPredictionCard(
          title: 'Fatigue',
          score: prediction.fatigueProbability,
          color: AppColors.sleep,
          icon: Icons.battery_3_bar_rounded,
          explanation: 'ML-derived fatigue anomaly signal',
        ),
        _MlPredictionCard(
          title: 'Respiratory',
          score: prediction.respiratoryRiskProbability,
          color: AppColors.spo2,
          icon: Icons.air_rounded,
          explanation: 'ML-derived respiratory anomaly signal',
        ),
        _MlPredictionCard(
          title: 'Cardiovascular',
          score: prediction.cardiovascularRiskProbability,
          color: AppColors.heartRate,
          icon: Icons.favorite_rounded,
          explanation: 'ML-derived cardiovascular anomaly signal',
        ),
        AppCard(
          color: AppColors.surfaceWell,
          flat: true,
          showBorder: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  'These domain values currently reflect the same anomaly '
                  'signal produced by PRANA’s on-device autoencoder. The '
                  'Risk Engine combines that signal with your vitals, '
                  'baseline and available context to calculate the final '
                  'risk score.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Displays one output from the PRANA on-device ML prediction.
class _MlPredictionCard extends StatelessWidget {
  final String title;
  final double score;
  final Color color;
  final IconData icon;
  final String explanation;

  const _MlPredictionCard({
    required this.title,
    required this.score,
    required this.color,
    required this.icon,
    required this.explanation,
  });

  static RiskLevel _levelOf(int percentage) {
    if (percentage < 30) return RiskLevel.safe;
    if (percentage < 60) return RiskLevel.moderate;
    if (percentage < 80) return RiskLevel.high;
    return RiskLevel.critical;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).clamp(0.0, 100.0).round();
    final level = _levelOf(percentage);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: icon, color: color, size: 34),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$percentage%',
                style: AppTypography.metricSmall.copyWith(color: color),
              ),
            ],
          ),

          AppSpacing.gapSm,

          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceWell,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),

          AppSpacing.gapSm,

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(explanation, style: AppTypography.bodySmall),
              ),
              AppSpacing.hGapXs,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: StatusPill(
                  label: level.displayName,
                  color: level.color,
                  backgroundColor: level.bgColor,
                  dense: true,
                  caps: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown while the baseline is too thin to compare against.
class _LearningNotice extends StatelessWidget {
  final int readings;

  const _LearningNotice({required this.readings});

  @override
  Widget build(BuildContext context) {
    final progress = (readings / 60).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: AppColors.mint.withValues(alpha: 0.5),
        showBorder: false,
        flat: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconChip(
                  icon: Icons.school_rounded,
                  color: AppColors.primary,
                  background: AppColors.surface,
                  size: 32,
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: Text(
                    'Still learning your normal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$readings/60',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            AppSpacing.gapSm,

            ClipRRect(
              borderRadius: AppRadius.brPill,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),

            AppSpacing.gapXs,

            Text(
              'Until then PRANA compares you against typical ranges rather '
              'than your own, so the breakdown below is a rougher estimate.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the four risk domains, with its bar sweeping in on first display.
class _DomainCard extends StatefulWidget {
  final String title;
  final double score;
  final Color color;
  final IconData icon;
  final String explanation;

  const _DomainCard({
    required this.title,
    required this.score,
    required this.color,
    required this.icon,
    required this.explanation,
  });

  @override
  State<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends State<_DomainCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late Animation<double> _anim = _tween(0, widget.score);

  Animation<double> _tween(double from, double to) => Tween<double>(
    begin: from,
    end: to,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _DomainCard old) {
    super.didUpdateWidget(old);

    if (old.score != widget.score) {
      _anim = _tween(old.score, widget.score);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static RiskLevel _levelOf(int percentage) {
    if (percentage < 30) return RiskLevel.safe;
    if (percentage < 60) return RiskLevel.moderate;
    if (percentage < 80) return RiskLevel.high;
    return RiskLevel.critical;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score * 100).round();
    final level = _levelOf(percentage);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(icon: widget.icon, color: widget.color, size: 34),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppSpacing.hGapXs,
              Text(
                '$percentage%',
                style: AppTypography.metricSmall.copyWith(color: widget.color),
              ),
            ],
          ),

          AppSpacing.gapSm,

          ClipRRect(
            borderRadius: AppRadius.brPill,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => LinearProgressIndicator(
                value: _anim.value.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceWell,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 7,
              ),
            ),
          ),

          AppSpacing.gapSm,

          Row(
            children: [
              Expanded(
                child: Text(widget.explanation, style: AppTypography.bodySmall),
              ),
              AppSpacing.hGapXs,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: StatusPill(
                  label: level.displayName,
                  color: level.color,
                  backgroundColor: level.bgColor,
                  dense: true,
                  caps: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One named driver from the risk engine, with its relative weight.
class _DriverBar extends StatelessWidget {
  final DriverFactor driver;

  const _DriverBar({required this.driver});

  @override
  Widget build(BuildContext context) {
    final weight = driver.impactPercentage.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(driver.icon, size: 15, color: AppColors.primary),
            AppSpacing.hGapXs,
            Expanded(
              child: Text(
                driver.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppSpacing.hGapXs,
            Text(
              '${(weight * 100).toStringAsFixed(0)}%',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: LinearProgressIndicator(
            value: weight,
            backgroundColor: AppColors.surfaceWell,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 5,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          driver.description,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// The engine's two recommendations, tinted by how urgent the situation is.
class _AdviceCard extends StatelessWidget {
  final RiskLevel level;
  final String primary;
  final String secondary;

  const _AdviceCard({
    required this.level,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final urgent = level == RiskLevel.high || level == RiskLevel.critical;

    return AppCard(
      accent: urgent ? level.color : null,
      color: urgent ? level.bgColor : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: urgent
                    ? Icons.priority_high_rounded
                    : Icons.tips_and_updates_rounded,
                color: urgent ? level.color : AppColors.primary,
                background: urgent ? Colors.white : null,
                size: 34,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  urgent ? 'Do this first' : 'Suggested',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: urgent ? level.color : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          AppSpacing.gapSm,

          Text(primary, style: AppTypography.bodyMedium),

          if (secondary.isNotEmpty) ...[
            AppSpacing.gapSm,

            Container(
              height: 1,
              color: urgent
                  ? level.color.withValues(alpha: 0.18)
                  : AppColors.borderLight,
            ),

            AppSpacing.gapSm,

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 15,
                    color: AppColors.textTertiary,
                  ),
                ),
                AppSpacing.hGapXs,
                Expanded(
                  child: Text(
                    secondary,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
