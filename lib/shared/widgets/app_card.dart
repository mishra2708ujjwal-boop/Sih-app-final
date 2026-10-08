import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The single card container for PRANA.
///
/// Replaces the ~25 hand-rolled `Container` + `BoxDecoration` blocks that had
/// drifted across 4/6/8/10/12/14/16/18/20px radii. Pass [accent] to tint the
/// surface and border with a semantic colour (risk level, biometric domain).
///
/// On the cream canvas an off-white card separates by *value*, not by outline,
/// so [showBorder] now paints a hairline that reads as an edge highlight rather
/// than the hard grey rule it was on white.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Tints background + border. Use for risk/biometric emphasis.
  final Color? accent;

  /// Solid background override. Wins over [accent].
  final Color? color;

  /// Gradient background. Wins over [color] and [accent].
  final Gradient? gradient;

  final double radius;
  final bool showBorder;
  final bool elevated;

  /// Drops the drop shadow. For cards nested inside another card, and for the
  /// recessed "well" panels that should read as holes rather than as objects.
  final bool flat;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.accent,
    this.color,
    this.gradient,
    this.radius = AppRadius.lg,
    this.showBorder = true,
    this.elevated = false,
    this.flat = false,
  });

  /// A recessed panel: no shadow, no border, one step darker than the canvas.
  /// Use to group controls *inside* a card without nesting a second object.
  const AppCard.well({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.radius = AppRadius.md,
  })  : accent = null,
        color = AppColors.surfaceWell,
        gradient = null,
        showBorder = false,
        elevated = false,
        flat = true;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final Color bg = color ??
        (accent != null ? accent!.withValues(alpha: 0.07) : AppColors.surface);

    final Color borderColor = accent != null
        ? accent!.withValues(alpha: 0.20)
        : AppColors.borderLight;

    final content = Container(
      padding: padding ?? AppSpacing.card,
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: showBorder && gradient == null
            ? Border.all(color: borderColor, width: 1)
            : null,
        boxShadow: flat
            ? null
            : (elevated ? AppShadows.raised : AppShadows.card),
      ),
      child: child,
    );

    if (onTap == null) {
      return margin == null ? content : Padding(padding: margin!, child: content);
    }

    final tappable = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        // Warm splash: the default grey ripple goes muddy over cream.
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: content,
      ),
    );

    return margin == null ? tappable : Padding(padding: margin!, child: tappable);
  }
}
