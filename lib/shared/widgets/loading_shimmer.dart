import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Lightweight shimmer placeholder — no external packages, just Flutter's
/// built-in animation stack. Used on metric cards while `hasData == false`
/// so the layout doesn't jump when data first arrives.
class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  /// A preset that matches the metric value text height.
  const LoadingShimmer.metricValue({super.key})
      : width = 72,
        height = 36,
        borderRadius = AppRadius.sm;

  /// A preset that matches a full card.
  const LoadingShimmer.card({super.key})
      : width = double.infinity,
        height = 100,
        borderRadius = AppRadius.lg;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The sweep animates forever while it is on screen, so it gets its own
    // layer rather than repainting the card behind it every frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (_animation.value - 0.5).clamp(0.0, 1.0),
                  _animation.value.clamp(0.0, 1.0),
                  (_animation.value + 0.5).clamp(0.0, 1.0),
                ],
                // Warm greys, so a placeholder does not read as a cold hole in
                // the cream canvas.
                colors: const [
                  AppColors.surfaceWell,
                  AppColors.surfaceElevated,
                  AppColors.surfaceWell,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
