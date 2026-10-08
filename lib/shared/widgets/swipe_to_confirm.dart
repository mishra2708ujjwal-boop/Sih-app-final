import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// The dark action pill with a draggable handle — "Swipe to start reading".
///
/// A drag is the right gesture for starting something that takes time and
/// shouldn't fire from a pocket brush, but a swipe-only control is unusable with
/// a screen reader or a motor impairment. So the handle is draggable *and* the
/// whole pill is tappable, and the Semantics node advertises it as a plain
/// button. Set [requireDrag] for the rare case where a tap must not count.
class SwipeToConfirm extends StatefulWidget {
  final String label;

  /// Shown while [enabled] is false, e.g. "Connect a sensor first".
  final String? disabledLabel;

  final VoidCallback onConfirm;

  final bool enabled;

  /// Disallow tap-to-activate, forcing a full drag.
  final bool requireDrag;

  final Color background;
  final Color foreground;
  final IconData handleIcon;

  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.disabledLabel,
    this.enabled = true,
    this.requireDrag = false,
    this.background = AppColors.surfaceDark,
    this.foreground = Colors.white,
    this.handleIcon = Icons.chevron_right_rounded,
  });

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _height = 60;
  static const double _handleInset = 5;

  double _dragX = 0;
  bool _fired = false;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addListener(() {
      if (!mounted) return;
      setState(() => _dragX = _settleFrom * (1 - _settle.value));
    });

  double _settleFrom = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _snapBack() {
    _settleFrom = _dragX;
    _settle.forward(from: 0);
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    HapticFeedback.mediumImpact();
    widget.onConfirm();
    // Reset so the control can be used again after the caller returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _dragX = 0;
        _fired = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final text = enabled ? widget.label : (widget.disabledLabel ?? widget.label);

    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      onTap: enabled ? _fire : null,
      // The custom gesture is already exposed as a tap above; hide the raw
      // drag mechanics from assistive tech.
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final handleSize = _height - _handleInset * 2;
          final maxDrag = (width - handleSize - _handleInset * 2)
              .clamp(0.0, double.infinity);

          return GestureDetector(
            onTap: enabled && !widget.requireDrag ? _fire : null,
            onHorizontalDragUpdate: enabled
                ? (d) => setState(
                      () => _dragX = (_dragX + d.delta.dx).clamp(0.0, maxDrag),
                    )
                : null,
            onHorizontalDragEnd: enabled
                ? (_) {
                    // 65% of the track is far enough to be deliberate without
                    // demanding a full-width sweep on a large phone.
                    if (maxDrag > 0 && _dragX >= maxDrag * 0.65) {
                      _fire();
                    } else {
                      _snapBack();
                    }
                  }
                : null,
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: enabled
                    ? widget.background
                    : widget.background.withValues(alpha: 0.35),
                borderRadius: AppRadius.brPill,
                boxShadow: enabled ? AppShadows.floating : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Label is inset past the handle so a long string can never
                  // slide underneath it.
                  Padding(
                    padding: EdgeInsets.only(
                      left: handleSize + AppSpacing.md,
                      right: AppSpacing.xl,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLarge.copyWith(
                              color: widget.foreground.withValues(
                                alpha: enabled ? 0.92 : 0.5,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (enabled)
                          _ChevronHint(color: widget.foreground),
                      ],
                    ),
                  ),
                  Positioned(
                    left: _handleInset + _dragX,
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: BoxDecoration(
                        color: enabled
                            ? widget.foreground
                            : widget.foreground.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.handleIcon,
                        color: enabled
                            ? widget.background
                            : widget.background.withValues(alpha: 0.5),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Three chevrons that fade in sequence, hinting the drag direction.
class _ChevronHint extends StatefulWidget {
  final Color color;

  const _ChevronHint({required this.color});

  @override
  State<_ChevronHint> createState() => _ChevronHintState();
}

class _ChevronHintState extends State<_ChevronHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Opacity(
                  // Each chevron peaks a third of a cycle after the last.
                  opacity: 0.25 +
                      0.55 *
                          (0.5 +
                              0.5 *
                                  ((_ctrl.value - i / 3) % 1.0 < 0.34
                                      ? 1.0
                                      : -0.4)),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: widget.color,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
