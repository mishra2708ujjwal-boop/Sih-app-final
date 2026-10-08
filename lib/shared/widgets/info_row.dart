import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'icon_chip.dart';

/// Icon + title + subtitle (+ optional trailing) row.
///
/// Replaces six independent reimplementations of the same layout:
/// `_advisoryRow`, `_biomarkerRow`, `_sensorRow`, `_insightFeedItem`,
/// `_auditRow`, `_baselineItem`.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Right-aligned value text. Ignored when [trailing] is supplied.
  final String? value;

  /// Fully custom trailing widget (pill, switch, chevron).
  final Widget? trailing;

  final Color? iconColor;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// Show a chevron and treat the row as navigational.
  final bool showChevron;

  /// Render on a dark surface (privacy audit, demo lab).
  final bool onDark;

  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.iconColor,
    this.valueColor,
    this.onTap,
    this.showChevron = false,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary;

    final titleColor = onDark ? Colors.white : AppColors.textPrimary;
    final subtitleColor =
        onDark ? Colors.white.withValues(alpha: 0.62) : AppColors.textSecondary;

    Widget? resolvedTrailing = trailing;
    if (resolvedTrailing == null && value != null) {
      resolvedTrailing = Text(
        value!,
        style: AppTypography.titleMedium.copyWith(
          color: valueColor ?? titleColor,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.right,
      );
    }
    if (resolvedTrailing == null && showChevron) {
      resolvedTrailing = Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: onDark ? Colors.white38 : AppColors.textTertiary,
      );
    }

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          // On a dark surface the pastel tint has nothing to sit against, so
          // the chip goes translucent-white and the glyph goes white with it.
          onDark
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(40 * 0.34),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                )
              : IconChip(icon: icon, color: accent, size: 40),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          if (resolvedTrailing != null) ...[
            AppSpacing.hGapXs,
            // Cap the trailing width so a long value can never squeeze the
            // title column to zero and trigger an overflow.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: resolvedTrailing,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        child: row,
      ),
    );
  }
}
