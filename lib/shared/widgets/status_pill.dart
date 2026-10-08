import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Compact status pill — the one implementation for every badge in the app.
///
/// Replaces the ~15 inline pill `Container`s that duplicated the same
/// padding/radius/background maths (delta chips, ACTIVE/OFFLINE badges, risk
/// level labels, baseline deviation flags).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  /// Background. Defaults to a 12% tint of [color].
  final Color? backgroundColor;

  final IconData? icon;

  /// Renders a small filled dot instead of an icon — for connectivity states.
  final bool showDot;

  /// Uppercase + wide tracking. Use for state badges, not for numbers.
  final bool caps;

  final bool dense;

  /// Solid fill with [color] and light text — for the one badge on a screen
  /// that should read as a chip rather than a tint.
  final bool solid;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.icon,
    this.showDot = false,
    this.caps = false,
    this.dense = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;

    final textStyle = (caps ? AppTypography.labelCaps : AppTypography.labelMedium)
        .copyWith(color: fg, fontWeight: FontWeight.w700);

    return Container(
      // Roomier than a Material chip: the reference pills are chunky, and the
      // extra horizontal padding is what makes a fully-round corner read as a
      // pill rather than as a squashed circle.
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm - 2 : AppSpacing.sm + 2,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: solid
            ? color
            : (backgroundColor ?? color.withValues(alpha: 0.12)),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            AppSpacing.hGapXxs,
          ] else if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            AppSpacing.hGapXxs,
          ],
          // Flexible so a long label ellipsises instead of overflowing its row.
          Flexible(
            child: Text(
              caps ? label.toUpperCase() : label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
