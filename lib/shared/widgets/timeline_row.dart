import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'status_pill.dart';

/// A dated history row: stacked month/day on the left, a sentence and a thin
/// magnitude bar in the middle, a status pill on the right.
///
/// This is the shape a health log wants — the date is a gutter you can scan
/// down, the bar gives you the trend without reading numbers, and the pill
/// carries the one-word verdict.
class TimelineRow extends StatelessWidget {
  final DateTime date;

  /// The sentence, e.g. "Slept 5.2 h".
  final String title;

  /// Optional second line, e.g. "2 suggestions".
  final String? subtitle;

  /// 0.0 – 1.0 magnitude bar. Omit to hide the bar entirely.
  final double? progress;

  final Color accent;

  /// Right-hand pill. Omit both to hide it.
  final String? pillLabel;
  final Color? pillColor;
  final Color? pillBackground;

  final VoidCallback? onTap;

  /// Draw a connector line down to the next row.
  final bool showConnector;

  const TimelineRow({
    super.key,
    required this.date,
    required this.title,
    required this.accent,
    this.subtitle,
    this.progress,
    this.pillLabel,
    this.pillColor,
    this.pillBackground,
    this.onTap,
    this.showConnector = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Date gutter ────────────────────────────────────────────────────
          SizedBox(
            width: 34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMM').format(date),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${date.day}',
                  maxLines: 1,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showConnector) ...[
                  const SizedBox(height: 6),
                  Container(width: 1.5, height: 10, color: AppColors.borderLight),
                ],
              ],
            ),
          ),
          AppSpacing.hGapSm,

          // ── Sentence + bar ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: AppRadius.brPill,
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceWell,
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),

          // ── Verdict pill ───────────────────────────────────────────────────
          if (pillLabel != null) ...[
            AppSpacing.hGapSm,
            // Capped so a long verdict shrinks instead of squeezing the
            // sentence to nothing.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: StatusPill(
                label: pillLabel!,
                color: pillColor ?? accent,
                backgroundColor: pillBackground,
                dense: true,
              ),
            ),
          ],
          if (onTap != null) ...[
            AppSpacing.hGapXxs,
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: content,
      ),
    );
  }
}
