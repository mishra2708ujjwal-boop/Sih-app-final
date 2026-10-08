import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../models/risk_result.dart';
import 'status_pill.dart';

/// Animated radial arc gauge showcasing the primary Risk Score (0-100).
///
/// A 270° sweep with the gap at the bottom, where the scale's two ends are
/// labelled — the same construction as the reference's reading dial, so the
/// number in the middle is read against a visible range rather than floating.
class RiskScoreGauge extends StatefulWidget {
  final int score;
  final RiskLevel level;
  final String trend;
  final double size;

  /// Hide the "CURRENT RISK" eyebrow — for use inside a card that already
  /// carries the section title.
  final bool showEyebrow;

  const RiskScoreGauge({
    super.key,
    required this.score,
    required this.level,
    required this.trend,
    this.size = 200.0,
    this.showEyebrow = true,
  });

  @override
  State<RiskScoreGauge> createState() => _RiskScoreGaugeState();
}

class _RiskScoreGaugeState extends State<RiskScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.score / 100.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RiskScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: oldWidget.score / 100.0,
        end: widget.score / 100.0,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getTrendIcon(String trend) {
    final t = trend.toLowerCase();
    if (t.contains('increas') || t.contains('spik')) {
      return Icons.arrow_upward_rounded;
    } else if (t.contains('decreas') || t.contains('improv')) {
      return Icons.arrow_downward_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  Color _getTrendColor(String trend) {
    final t = trend.toLowerCase();
    if (t.contains('increas') || t.contains('spik')) {
      return widget.level == RiskLevel.safe
          ? AppColors.textSecondary
          : AppColors.riskHigh;
    } else if (t.contains('decreas') || t.contains('improv')) {
      return AppColors.riskSafe;
    }
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    // The numeral is sized off the dial so a compact gauge doesn't overflow its
    // own centre. Tabular figures keep it from jittering as the score ticks.
    final numeralSize = (widget.size * 0.30).clamp(34.0, 62.0);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final animatedScore = (_animation.value * 100).round();
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _GaugePainter(
                    progress: _animation.value,
                    activeColor: widget.level.color,
                  ),
                ),
                // Scale ends, sitting in the 90° gap at the bottom of the arc.
                Positioned(
                  bottom: widget.size * 0.055,
                  left: widget.size * 0.16,
                  child: const _ScaleLabel('0'),
                ),
                Positioned(
                  bottom: widget.size * 0.055,
                  right: widget.size * 0.16,
                  child: const _ScaleLabel('100'),
                ),
                Padding(
                  // Keeps the stack clear of the two scale labels.
                  padding: EdgeInsets.only(bottom: widget.size * 0.06),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showEyebrow)
                        Text(
                          'CURRENT RISK',
                          style: AppTypography.labelCaps.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      Text(
                        '$animatedScore',
                        style: AppTypography.displayHuge.copyWith(
                          fontSize: numeralSize,
                          color: AppColors.textPrimary,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 5),
                      StatusPill(
                        label: widget.level.displayName,
                        color: widget.level.color,
                        backgroundColor: widget.level.bgColor,
                        caps: true,
                        dense: true,
                      ),
                      const SizedBox(height: 5),
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxWidth: widget.size * 0.58),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTrendIcon(widget.trend),
                              size: 13,
                              color: _getTrendColor(widget.trend),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                widget.trend,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(
                                  color: _getTrendColor(widget.trend),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScaleLabel extends StatelessWidget {
  final String text;

  const _ScaleLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelCaps.copyWith(color: AppColors.textTertiary),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  _GaugePainter({required this.progress, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    // Thinner stroke than before: on cream, a heavy ring reads as a bezel and
    // competes with the numeral it is supposed to frame.
    final strokeWidth = (size.shortestSide * 0.055).clamp(6.0, 11.0);
    final radius = size.shortestSide / 2 - strokeWidth;
    if (radius <= 0) return;

    const startAngle = 135 * (pi / 180);
    const sweepAngle = 270 * (pi / 180);

    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = AppColors.surfaceWell
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // Active progress arc — swept gradient from a lighter tint into the full
    // level colour, so the arc reads as a scale rather than a flat bar.
    final activeSweep = sweepAngle * progress.clamp(0.0, 1.0);
    if (activeSweep > 0.001) {
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [
            Color.lerp(activeColor, AppColors.surface, 0.55)!,
            activeColor,
          ],
          transform: const GradientRotation(startAngle),
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);

      // Head marker: a surface-filled disc ringed in the level colour, so the
      // current position stays findable where the arc's own tint is palest.
      final currentAngle = startAngle + activeSweep;
      final thumbCenter = Offset(
        center.dx + radius * cos(currentAngle),
        center.dy + radius * sin(currentAngle),
      );
      final thumbR = strokeWidth * 0.62;

      canvas.drawCircle(
        thumbCenter,
        thumbR * 1.7,
        Paint()..color = activeColor.withValues(alpha: 0.16),
      );
      canvas.drawCircle(
        thumbCenter,
        thumbR,
        Paint()..color = AppColors.surface,
      );
      canvas.drawCircle(
        thumbCenter,
        thumbR,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.28,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}
