import 'package:flutter/material.dart';

/// Short fade + rise entrance used for cards and sections.
///
/// [index] staggers the start so a column of cards settles in sequence. The
/// delay is folded into a single controller via an [Interval] — no timers, so
/// nothing to leak if the widget is disposed mid-animation.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;

  /// Length of the movement itself (not counting the stagger delay).
  final Duration duration;

  /// Distance travelled, in logical pixels.
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 320),
    this.offsetY = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = Duration(
    // Capped so a long list never feels like it is loading.
    milliseconds: (widget.index.clamp(0, 8)) * 45,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + widget.duration,
  );

  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / (_delay + widget.duration).inMilliseconds,
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform's "reduce motion" setting: settle instantly rather
    // than animating. Read here rather than in initState because MediaQuery is
    // not available that early.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1.0;
    } else if (_controller.value == 0.0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _anim.value) * widget.offsetY),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
