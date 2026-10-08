import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Very subtle ambient wash painted behind a screen's content.
///
/// Three low-opacity radial washes, one of which drifts a few pixels over ~24s.
/// No blur filters and no repeated layout — the drift is a single small
/// `Transform` inside a `RepaintBoundary`, so it costs effectively nothing but
/// stops large flat areas from reading as dead space.
///
/// Tuned for the warm linen canvas: the washes are sage and deep green, both
/// warmer than the canvas is cool, so they read as light falling across paper
/// rather than as a coloured gradient. Opacities are higher than they were on
/// white because a pale sage over cream barely registers below ~0.15.
class AmbientBackground extends StatefulWidget {
  final Widget child;

  /// Tint of the upper wash. Defaults to the sage accent.
  final Color? tint;

  /// Tint of the lower wash. Defaults to the deeper brand green.
  final Color? secondaryTint;

  /// Base surface colour behind the washes.
  final Color? background;

  /// Scales all three washes. 0 disables them; 1 is the default strength.
  /// Drop it on dense screens where the content already carries the colour.
  final double intensity;

  const AmbientBackground({
    super.key,
    required this.child,
    this.tint,
    this.secondaryTint,
    this.background,
    this.intensity = 1.0,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppColors.accent;
    final secondary = widget.secondaryTint ?? AppColors.primaryLight;
    final size = MediaQuery.sizeOf(context);
    final k = widget.intensity.clamp(0.0, 2.0);

    return DecoratedBox(
      decoration:
          BoxDecoration(color: widget.background ?? AppColors.background),
      child: Stack(
        children: [
          if (k > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _drift,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(_drift.value);
                      return Stack(
                        children: [
                          // Upper-right sage wash — drifts vertically. Sits
                          // behind the header, which is where the eye lands.
                          Positioned(
                            right: -size.width * 0.34,
                            top: -size.width * 0.42 + (t * 14),
                            child: _Wash(
                              diameter: size.width * 1.08,
                              color: tint,
                              opacity: 0.22 * k,
                            ),
                          ),
                          // Upper-left, deeper and cooler, for asymmetry.
                          Positioned(
                            left: -size.width * 0.44,
                            top: size.width * 0.04 - (t * 10),
                            child: _Wash(
                              diameter: size.width * 0.94,
                              color: secondary,
                              opacity: 0.07 * k,
                            ),
                          ),
                          // Low anchor wash so the fold of long pages isn't flat.
                          Positioned(
                            right: -size.width * 0.3,
                            bottom: -size.width * 0.32,
                            child: _Wash(
                              diameter: size.width * 0.84,
                              color: tint,
                              opacity: 0.12 * k,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _Wash extends StatelessWidget {
  final double diameter;
  final Color color;
  final double opacity;

  const _Wash({
    required this.diameter,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          // Three stops, not two: a straight linear ramp to transparent leaves
          // a faintly visible disc edge on a flat canvas. Holding most of the
          // opacity through the core and dumping the rest over the outer half
          // makes the boundary genuinely unfindable.
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.42),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
