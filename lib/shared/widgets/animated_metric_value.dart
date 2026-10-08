import 'package:flutter/material.dart';

/// A metric readout that eases between values instead of snapping.
///
/// Non-numeric input (`'--'`, `'Learning'`) renders as plain text, so callers
/// can hand it whatever the controller produced without branching. Decimal
/// places are inferred from the incoming string so a temperature keeps its
/// single decimal and a heart rate stays whole.
class AnimatedMetricValue extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedMetricValue({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 420),
  });

  @override
  Widget build(BuildContext context) {
    final numeric = double.tryParse(value);

    if (numeric == null) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final dot = value.indexOf('.');
    final digits = dot == -1 ? 0 : value.length - dot - 1;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: numeric),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        v.toStringAsFixed(digits),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
