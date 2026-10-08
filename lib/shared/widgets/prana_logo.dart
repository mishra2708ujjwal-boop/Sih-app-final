import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// The PRANA brand mark: a soft "breath" ring with a single heartbeat pulse
/// cutting across it. Pure vector — no asset — so it scales crisply from a
/// 24px chip to a full-screen splash and always matches the brand palette.
///
/// Set [animate] to breathe the ring (a slow expand/contract) and sweep the
/// pulse; leave it false for a static mark in headers and cards.
class PranaLogo extends StatefulWidget {
  final double size;

  /// Ring + pulse colour. Defaults to the brand forest green.
  final Color? color;

  /// Colour of the heartbeat pulse. Defaults to [color].
  final Color? pulseColor;

  /// Optional filled disc behind the mark. Null = transparent.
  final Color? backgroundColor;

  /// Breathe the ring and sweep the pulse. Off for static placements.
  final bool animate;

  const PranaLogo({
    super.key,
    this.size = 96,
    this.color,
    this.pulseColor,
    this.backgroundColor,
    this.animate = false,
  });

  @override
  State<PranaLogo> createState() => _PranaLogoState();
}

class _PranaLogoState extends State<PranaLogo>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _breath.repeat(reverse: true);
      _sweep.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PranaLogo old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
      _sweep.repeat();
    } else if (!widget.animate && _breath.isAnimating) {
      _breath.stop();
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final pulse = widget.pulseColor ?? color;

    final mark = AnimatedBuilder(
      animation: Listenable.merge([_breath, _sweep]),
      builder: (context, _) {
        final breathT = widget.animate
            ? Curves.easeInOut.transform(_breath.value)
            : 0.5;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _PranaLogoPainter(
            color: color,
            pulseColor: pulse,
            breath: breathT,
            sweep: widget.animate ? _sweep.value : 1.0,
          ),
        );
      },
    );

    if (widget.backgroundColor == null) return mark;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: widget.size * 0.78,
        height: widget.size * 0.78,
        child: mark,
      ),
    );
  }
}

class _PranaLogoPainter extends CustomPainter {
  final Color color;
  final Color pulseColor;

  /// 0..1 breathing phase — scales the outer ring slightly.
  final double breath;

  /// 0..1 sweep phase — reveals the pulse trace left-to-right (1 = full).
  final double sweep;

  _PranaLogoPainter({
    required this.color,
    required this.pulseColor,
    required this.breath,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final stroke = size.width * 0.075;

    // Outer breath ring — a soft, slightly-open arc so the mark reads as a
    // lung/breath rather than a closed circle. Breathing nudges its radius.
    final ringR = r - stroke * 1.4 + (breath - 0.5) * size.width * 0.03;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.28 + breath * 0.14);
    // Gap at the bottom where the pulse "enters".
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR),
      math.pi * 0.62, // start lower-left
      math.pi * 1.76, // sweep almost all the way round
      false,
      ringPaint,
    );

    // Inner accent ring, thinner and brighter — gives the mark depth.
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR - stroke * 1.1),
      math.pi * 0.72,
      math.pi * 1.56,
      false,
      innerPaint,
    );

    // Heartbeat pulse across the middle — the "alive" signal. Built as a path
    // and revealed left-to-right by [sweep] using a PathMetric extract.
    final w = size.width;
    final midY = c.dy;
    final path = Path();
    // Baseline in, small dip, tall spike, deep trough, recovery, baseline out.
    path.moveTo(w * 0.16, midY);
    path.lineTo(w * 0.34, midY);
    path.lineTo(w * 0.40, midY - w * 0.06);
    path.lineTo(w * 0.47, midY + w * 0.20);
    path.lineTo(w * 0.55, midY - w * 0.30);
    path.lineTo(w * 0.62, midY + w * 0.08);
    path.lineTo(w * 0.68, midY);
    path.lineTo(w * 0.84, midY);

    final metric = path.computeMetrics().first;
    final revealLen = metric.length * sweep.clamp(0.0, 1.0);
    final revealed = metric.extractPath(0, revealLen);

    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.92
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = pulseColor;
    canvas.drawPath(revealed, pulsePaint);

    // Leading dot rides the tip of the revealed pulse.
    if (sweep > 0.02 && sweep < 0.999) {
      final tan = metric.getTangentForOffset(revealLen);
      if (tan != null) {
        canvas.drawCircle(
          tan.position,
          stroke * 0.62,
          Paint()..color = pulseColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PranaLogoPainter old) =>
      old.breath != breath ||
      old.sweep != sweep ||
      old.color != color ||
      old.pulseColor != pulseColor;
}
