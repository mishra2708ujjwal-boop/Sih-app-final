import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// A thick arc gauge with rounded caps and optional end labels — the shape the
/// reference uses for a timed reading.
///
/// Draws a partial ring (not a full circle) so the two ends can carry labels,
/// which is what makes a countdown legible: you can see where it started and
/// where it finishes without reading a number.
class ProgressRing extends StatelessWidget {
  /// 0.0 – 1.0. Values outside are clamped rather than wrapping.
  final double progress;

  final double size;
  final double thickness;

  final Color color;
  final Color? trackColor;

  /// Total sweep in degrees. 300 leaves a 60° gap at the bottom for labels.
  final double sweepDegrees;

  /// Label at the arc's start, e.g. "0s".
  final String? startLabel;

  /// Label at the arc's end, e.g. "20s".
  final String? endLabel;

  /// Small caption floated above the moving head of the arc, e.g. "15s".
  final String? headLabel;

  /// Optional highlighted segment of the *track*, as two 0.0–1.0 fractions of
  /// the sweep. Used to mark a healthy range so the head's position can be read
  /// as inside or outside it, not just as a bare fraction. Ignored unless both
  /// are supplied and [bandEnd] is greater than [bandStart].
  final double? bandStart;
  final double? bandEnd;

  /// Fill for the band. Defaults to the mint tint.
  final Color? bandColor;

  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 220,
    this.thickness = 10,
    this.color = AppColors.textPrimary,
    this.trackColor,
    this.sweepDegrees = 300,
    this.startLabel,
    this.endLabel,
    this.headLabel,
    this.bandStart,
    this.bandEnd,
    this.bandColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: clamped,
                thickness: thickness,
                color: color,
                trackColor: trackColor ?? AppColors.surfaceWell,
                sweepDegrees: sweepDegrees,
                bandStart: bandStart,
                bandEnd: bandEnd,
                bandColor: bandColor ?? AppColors.mintDeep,
              ),
            ),
          ),
          if (child != null)
            Padding(
              // Keep the centre content clear of the arc itself.
              padding: EdgeInsets.all(thickness + size * 0.11),
              child: Center(child: child),
            ),
          if (startLabel != null || endLabel != null)
            _EndLabels(
              size: size,
              sweepDegrees: sweepDegrees,
              startLabel: startLabel,
              endLabel: endLabel,
            ),
          if (headLabel != null)
            _HeadLabel(
              size: size,
              thickness: thickness,
              sweepDegrees: sweepDegrees,
              progress: clamped,
              label: headLabel!,
            ),
        ],
      ),
    );
  }
}

/// Places the two static captions just outside the arc's endpoints.
class _EndLabels extends StatelessWidget {
  final double size;
  final double sweepDegrees;
  final String? startLabel;
  final String? endLabel;

  const _EndLabels({
    required this.size,
    required this.sweepDegrees,
    this.startLabel,
    this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    // The arc is centred on 12 o'clock, so it starts at -90 - sweep/2.
    final startDeg = -90 - sweepDegrees / 2;
    final endDeg = -90 + sweepDegrees / 2;
    final radius = size / 2 * 0.98;

    Widget place(double deg, String text) {
      final rad = deg * math.pi / 180;
      return Positioned(
        left: size / 2 + math.cos(rad) * radius - 22,
        top: size / 2 + math.sin(rad) * radius - 9,
        width: 44,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Stack(
      children: [
        if (startLabel != null) place(startDeg, startLabel!),
        if (endLabel != null) place(endDeg, endLabel!),
      ],
    );
  }
}

/// The caption that rides the moving head of the arc.
class _HeadLabel extends StatelessWidget {
  final double size;
  final double thickness;
  final double sweepDegrees;
  final double progress;
  final String label;

  const _HeadLabel({
    required this.size,
    required this.thickness,
    required this.sweepDegrees,
    required this.progress,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final deg = -90 - sweepDegrees / 2 + sweepDegrees * progress;
    final rad = deg * math.pi / 180;
    // Sit outside the stroke, not on it.
    final radius = size / 2 - thickness / 2 + thickness + 8;

    return Positioned(
      left: size / 2 + math.cos(rad) * radius - 22,
      top: size / 2 + math.sin(rad) * radius - 10,
      width: 44,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double thickness;
  final Color color;
  final Color trackColor;
  final double sweepDegrees;
  final double? bandStart;
  final double? bandEnd;
  final Color bandColor;

  _RingPainter({
    required this.progress,
    required this.thickness,
    required this.color,
    required this.trackColor,
    required this.sweepDegrees,
    required this.bandColor,
    this.bandStart,
    this.bandEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      thickness / 2,
      thickness / 2,
      size.width - thickness,
      size.height - thickness,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final startRad = (-90 - sweepDegrees / 2) * math.pi / 180;
    final sweepRad = sweepDegrees * math.pi / 180;

    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    // Healthy-range band, painted over the track and under the progress arc so
    // the head stays the most prominent mark on the ring.
    final bs = bandStart;
    final be = bandEnd;
    if (bs != null && be != null) {
      final a = bs.clamp(0.0, 1.0);
      final b = be.clamp(0.0, 1.0);
      if (b > a) {
        canvas.drawArc(
          rect,
          startRad + sweepRad * a,
          sweepRad * (b - a),
          false,
          Paint()
            ..color = bandColor.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            // Butt caps: a rounded band would spill past the range it marks.
            ..strokeCap = StrokeCap.butt,
        );
      }
    }

    if (progress > 0) {
      canvas.drawArc(
        rect,
        startRad,
        sweepRad * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round,
      );

      // A square tick at the head reads as "this is where we are now" more
      // clearly than the rounded cap alone.
      final headRad = startRad + sweepRad * progress;
      final r = rect.width / 2;
      final c = rect.center;
      final head = Offset(
        c.dx + math.cos(headRad) * r,
        c.dy + math.sin(headRad) * r,
      );
      canvas.save();
      canvas.translate(head.dx, head.dy);
      canvas.rotate(headRad + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: thickness * 1.05,
            height: thickness * 1.05,
          ),
          Radius.circular(thickness * 0.28),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.thickness != thickness ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.sweepDegrees != sweepDegrees ||
      old.bandStart != bandStart ||
      old.bandEnd != bandEnd ||
      old.bandColor != bandColor;
}
