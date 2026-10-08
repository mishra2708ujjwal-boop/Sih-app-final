import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';
import 'status_pill.dart';
import 'icon_chip.dart';
import 'metric_sparkline.dart';

/// Live vitals tile: pastel icon chip, the reading at display size, a delta
/// pill, and an optional trend line along the bottom.
///
/// Laid out to survive a narrow grid cell: every text run is single-line with
/// ellipsis, and the delta pill is `Flexible` so a long label ("+12% Elevated")
/// shrinks instead of overflowing. The sparkline sits in a fixed 26px band so
/// adding it never changes the tile's height at a given text scale.
class HealthMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String baselineRange;
  final String deltaText;
  final bool isNormal;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final VoidCallback? onTap;

  /// Recent readings, newest last. Renders a trend line when 2+ are supplied.
  final List<double> trend;

  const HealthMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.baselineRange,
    required this.deltaText,
    required this.isNormal,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    this.onTap,
    this.trend = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconChip(
                icon: icon,
                color: accentColor,
                background: bgColor,
                size: 34,
              ),
              AppSpacing.hGapXs,
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(
                    label: deltaText,
                    dense: true,
                    color: isNormal ? AppColors.riskSafe : AppColors.riskHigh,
                    backgroundColor:
                        isNormal ? AppColors.riskSafeBg : AppColors.riskHighBg,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricValue,
                ),
              ),
              const SizedBox(width: 3),
              Text(unit, style: AppTypography.metricUnit),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Fixed band: the trend line is decoration, so it must never be the
          // thing that decides how tall the tile is. When there aren't enough
          // points to draw an honest shape, the band collapses to nothing
          // rather than showing a fabricated line.
          if (trend.length >= 2)
            SizedBox(
              height: 24,
              child: MetricSparkline(values: trend, color: accentColor),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 12,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  baselineRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
