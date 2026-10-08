import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'icon_chip.dart';

/// Small label + value tile used inside grids and stat strips.
///
/// Replaces `_statBox`, `_deviceStat`, `_envStatItem` and `_stageBox`. Text
/// wraps to two lines and ellipsises rather than overflowing, which is what
/// broke the old 4-across environment strip on a 360dp screen.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? valueColor;
  final Color? accent;

  /// Render on a filled tinted surface rather than transparent.
  final bool filled;

  /// Wrap [icon] in a pastel rounded-square chip instead of drawing it bare.
  /// Reads as a proper tile; use inside a filled strip.
  final bool chipIcon;

  final CrossAxisAlignment alignment;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.valueColor,
    this.accent,
    this.filled = false,
    this.chipIcon = false,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAccent = accent ?? AppColors.primary;
    final centred = alignment == CrossAxisAlignment.center;

    final body = Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          if (chipIcon)
            IconChip(icon: icon!, color: resolvedAccent, size: 30)
          else
            Icon(icon, size: 18, color: resolvedAccent),
          AppSpacing.gapXs,
        ],
        // Baseline-aligned so the unit sits on the value's baseline, not centred.
        Row(
          mainAxisAlignment:
              centred ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                // Tabular so a column of these doesn't shimmy as digits change.
                style: AppTypography.metricSmall.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centred ? TextAlign.center : TextAlign.start,
        ),
      ],
    );

    if (!filled) return body;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.08),
        borderRadius: AppRadius.brLg,
      ),
      child: body,
    );
  }
}
