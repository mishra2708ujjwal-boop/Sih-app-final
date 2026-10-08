import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// Sliding-pill segmented control.
///
/// One nesting idiom for the whole app — used by Vitals (Heart / Oxygen / Temp
/// / Sleep) and Insights (Analysis / Environment). Replaces Health's `TabBar`
/// and Sleep's `_periodTab`, both of which clipped their labels on a 360dp
/// screen.
///
/// The indicator is positioned by measured width rather than by `Expanded`
/// inside a Stack, so it stays aligned at any segment count. The selected pill
/// is a solid dark fill — the same treatment the reference gives a selected
/// day — because a tinted pill on cream doesn't read as "chosen" strongly
/// enough to be the only selection cue on the screen.
class AppSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Optional per-segment icons. Must match [segments] length when supplied.
  final List<IconData>? icons;

  /// Fill of the active pill. Defaults to the deep brand green.
  final Color? activeColor;

  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    assert(icons == null || icons!.length == segments.length);
    final active = activeColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: AppRadius.brPill,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / segments.length;

          return SizedBox(
            height: 42,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: segmentWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: active,
                      borderRadius: AppRadius.brPill,
                      boxShadow: AppShadows.card,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(segments.length, (i) {
                    final isActive = i == selectedIndex;
                    // White on the dark pill; muted ink on the well.
                    final fg =
                        isActive ? Colors.white : AppColors.textSecondary;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isActive,
                        label: segments[i],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (isActive) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxs,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icons != null) ...[
                                    Icon(icons![i], size: 15, color: fg),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      segments[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          AppTypography.labelMedium.copyWith(
                                        fontSize: 13,
                                        color: fg,
                                        fontWeight: isActive
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
