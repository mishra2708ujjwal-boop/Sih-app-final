import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'icon_chip.dart';

/// One row in a [showPranaActionSheet].
class PranaAction {
  final IconData icon;
  final String label;
  final String? subtitle;

  /// Accent for the icon chip. Defaults to the brand green.
  final Color? color;

  /// Renders in the critical colour and skips the chevron — for SOS and the
  /// like, where the row should not look like ordinary navigation.
  final bool destructive;

  /// Greys the row out and swallows taps. Use with [subtitle] to say why.
  final bool enabled;

  final VoidCallback onTap;

  const PranaAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
    this.destructive = false,
    this.enabled = true,
  });
}

/// The app's one overflow/quick-actions sheet.
///
/// Replaces scattered `PopupMenuButton`s: a bottom sheet is reachable one-handed
/// on a large phone, has room for a subtitle per row, and lands on the same
/// rounded-cream surface as everything else.
///
/// Each action's `onTap` fires *after* the sheet closes, so an action that
/// pushes a route doesn't fight the sheet's own dismissal animation.
Future<void> showPranaActionSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<PranaAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.82,
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Text(title, style: AppTypography.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm + 2,
                AppSpacing.sm,
                AppSpacing.sm + 2,
                AppSpacing.lg,
              ),
              children: [
                for (final action in actions)
                  _ActionRow(
                    action: action,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      action.onTap();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final PranaAction action;
  final VoidCallback onTap;

  const _ActionRow({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = action.destructive
        ? AppColors.riskCritical
        : (action.color ?? AppColors.primary);
    final disabled = !action.enabled;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          borderRadius: AppRadius.brMd,
          splashColor: accent.withValues(alpha: 0.07),
          highlightColor: accent.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm + 1,
            ),
            child: Row(
              children: [
                IconChip(icon: action.icon, color: accent, size: 40),
                AppSpacing.hGapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: action.destructive
                              ? AppColors.riskCritical
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (action.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          action.subtitle!,
                          maxLines: 2,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!action.destructive) ...[
                  AppSpacing.hGapXs,
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
