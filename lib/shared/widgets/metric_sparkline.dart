import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Tiny inline trend line for a metric tile.
///
/// Deliberately axis-less and label-less: at this size a reader can only take
/// away shape, so anything else is noise. Use [PranaLineChart] when the actual
/// values matter.
///
/// Renders nothing (a flat baseline hint) when there are fewer than two points,
/// so a tile that has only just started receiving data doesn't draw a
/// misleading spike from a single sample.
class MetricSparkline extends StatelessWidget {
  /// Newest value last. Values are normalised against their own min/max.
  final List<double> values;

  final Color color;

  /// Wash under the line. Defaults to a faint tint of [color].
  final Color? fillColor;

  final double strokeWidth;

  /// Draw a dot on the most recent point.
  final bool showEndDot;

  const MetricSparkline({
    super.key,
    required this.values,
    required this.color,
    this.fillColor,
    this.strokeWidth = 2.2,
    this.showEndDot = true,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          fillColor: fillColor ?? color.withValues(alpha: 0.14),
          strokeWidth: strokeWidth,
          showEndDot: showEndDot,
        ),
        // Expands to whatever the parent gives it. Callers wrap in SizedBox.
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color fillColor;
  final double strokeWidth;
  final bool showEndDot;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fillColor,
    required this.strokeWidth,
    required this.showEndDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Not enough shape to be honest about — draw a resting baseline instead.
    if (values.length < 2) {
      final baseline = Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final y = size.height * 0.62;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), baseline);
      return;
    }

    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    // A flat series would divide by zero; centre it instead of exploding.
    final range = (max - min).abs() < 0.0001 ? 1.0 : max - min;

    // Inset by half the stroke so the line's own thickness never clips.
    final pad = strokeWidth / 2 + (showEndDot ? strokeWidth : 0);
    final left = pad;
    final right = size.width - pad;
    final top = pad;
    final bottom = size.height - pad;
    if (right <= left || bottom <= top) return;

    final dx = (right - left) / (values.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final norm = (max - min).abs() < 0.0001
          ? 0.5
          : (values[i] - min) / range;
      points.add(Offset(left + dx * i, bottom - norm * (bottom - top)));
    }

    // Catmull-Rom-ish smoothing via midpoint quadratics: cheap, and it never
    // overshoots the data the way a naive cubic through every point does.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p = points[i];
      final n = points[i + 1];
      final mid = Offset((p.dx + n.dx) / 2, (p.dy + n.dy) / 2);
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    if (fillColor.a > 0) {
      final fill = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fillColor, fillColor.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showEndDot) {
      final last = points.last;
      canvas.drawCircle(
        last,
        strokeWidth * 1.5,
        Paint()..color = AppColors.surface,
      );
      canvas.drawCircle(last, strokeWidth * 0.95, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.fillColor != fillColor ||
      old.strokeWidth != strokeWidth ||
      old.showEndDot != showEndDot ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
