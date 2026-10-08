import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// The pill search field from the reference header.
///
/// Two modes. With [onTap] it is a *button* that looks like a field — no
/// keyboard, no focus, it just opens the real search surface; that is what the
/// dashboard uses. With [controller] it is a live text field.
class PranaSearchField extends StatelessWidget {
  final String hintText;

  /// Tapping opens a search surface. Mutually exclusive with [controller].
  final VoidCallback? onTap;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Trailing affordance. Defaults to a circular search glyph.
  final Widget? trailing;

  const PranaSearchField({
    super.key,
    this.hintText = 'Search',
    this.onTap,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing ??
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        );

    // Read-only presentation: a tappable pill that mimics the field.
    if (onTap != null) {
      return Semantics(
        button: true,
        label: hintText,
        child: Material(
          color: AppColors.surfaceWell,
          borderRadius: AppRadius.brPill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brPill,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  AppSpacing.hGapXs,
                  trailingWidget,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: AppRadius.brPill,
      ),
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyLarge,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          AppSpacing.hGapXs,
          trailingWidget,
        ],
      ),
    );
  }
}
