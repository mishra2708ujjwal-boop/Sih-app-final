import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Polished empty / disconnected / no-data state widget.
///
/// Used across every screen that depends on live data so blank spaces and
/// '--' placeholders are replaced with a clear, helpful message. This is the
/// honest fallback the project requires: when the band isn't streaming, a
/// screen shows one of these rather than a plausible-looking number.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional primary CTA. Renders a filled pill button when supplied.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional icon background color. Defaults to a subtle primary tint.
  final Color? iconColor;

  /// Compact mode — less vertical padding, smaller icon. Use inside cards.
  final bool compact;

  /// Swaps the glyph for a spinner. Use only while something is genuinely
  /// in flight (scanning, connecting, learning a baseline).
  final bool busy;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.compact = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary;
    final iconSize = compact ? 26.0 : 36.0;
    final containerSize = compact ? 58.0 : 78.0;
    final vertPad = compact ? AppSpacing.lg : AppSpacing.xxl;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: vertPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              // Rounded square, not a circle: it matches the icon chips used
              // everywhere else, so an empty slot reads as the same family of
              // object as the tile it stands in for.
              borderRadius: BorderRadius.circular(containerSize * 0.34),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: iconSize * 0.72,
                      height: iconSize * 0.72,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: accent.withValues(alpha: 0.8),
                        strokeCap: StrokeCap.round,
                      ),
                    )
                  : Icon(
                      icon,
                      size: iconSize,
                      color: accent.withValues(alpha: 0.75),
                    ),
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            // Intrinsic width, not full-bleed: an empty state is a suggestion,
            // and a full-width button in the middle of a page reads as a wall.
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                minimumSize: const Size(0, 50),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
