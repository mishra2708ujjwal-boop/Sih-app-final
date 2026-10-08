import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// Soft pastel icon chip — the rounded square that precedes almost every label
/// in the reference language.
///
/// One implementation so the chip behind a heart glyph and the chip behind a
/// thermometer glyph are always the same size, radius and tint strength.
class IconChip extends StatelessWidget {
  final IconData icon;

  /// Glyph colour. The chip fill derives from this when [background] is null.
  final Color color;

  /// Explicit fill. Prefer passing the domain's `*Bg` token from AppColors.
  final Color? background;

  /// Outer box edge length. The glyph scales with it.
  final double size;

  /// Fully round instead of a rounded square.
  final bool circular;

  const IconChip({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 38,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        // The radius tracks the box so a 28px chip and a 48px chip read as the
        // same shape rather than the small one looking like a circle.
        borderRadius: circular ? null : BorderRadius.circular(size * 0.34),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Center(
        child: Icon(icon, size: size * 0.5, color: color),
      ),
    );
  }
}

/// A circular icon button on a tinted well — the "…" and calendar affordances
/// in the reference header rows.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? background;
  final double size;
  final String? tooltip;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.background,
    this.size = 38,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background ?? Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Icon(icon, size: size * 0.5, color: color)),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// A row of pastel chips used as a legend or a quick-filter strip. Scrolls
/// horizontally so a long list never overflows a narrow phone.
class ChipStrip extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const ChipStrip({
    super.key,
    required this.children,
    this.padding = AppSpacing.pageH,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) AppSpacing.hGapXs,
            children[i],
          ],
        ],
      ),
    );
  }
}
