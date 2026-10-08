import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Section title with an optional all-caps eyebrow, a "See all" link and an
/// overflow affordance — the header rhythm the reference repeats down a page.
///
/// The action is a plain text link rather than a button: on a page with five
/// sections, five buttons would out-shout the content they introduce.
class SectionHeader extends StatelessWidget {
  final String title;

  /// All-caps line above the title. Use for the domain ("SLEEP", "VITALS").
  final String? eyebrow;

  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Trailing "…" affordance, right of the action.
  final VoidCallback? onOverflow;

  /// Tighter top padding — for a header that directly follows another header.
  final bool dense;

  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onOverflow,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: dense ? AppSpacing.md : AppSpacing.xl,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.hGapXs,
            // Tap target sized for a thumb, and the label is constrained so a
            // long action can't squeeze the title to zero width.
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.brPill,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 7,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 104),
                  child: Text(
                    actionLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (onOverflow != null) ...[
            AppSpacing.hGapXxs,
            InkWell(
              onTap: onOverflow,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
