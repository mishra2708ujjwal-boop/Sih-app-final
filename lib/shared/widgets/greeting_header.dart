import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';

/// The greeting row from the reference: avatar, "Hey, {name} 👋", a strip of
/// small state chips, and an overflow affordance.
///
/// The chips are supplied by the caller because what belongs there is different
/// per screen and must reflect real state — band connectivity, demo mode, the
/// active scenario. Nothing here is decorative.
class GreetingHeader extends StatelessWidget {
  /// The person's display name. Falls back to a generic greeting when empty.
  final String name;

  /// Line above the name, e.g. "Good morning".
  final String? eyebrow;

  /// State chips, typically [StatusPill]s. Laid out in a wrap so a third chip
  /// drops to a second line instead of overflowing a 320dp screen.
  final List<Widget> chips;

  /// Avatar tap target — usually opens the profile.
  final VoidCallback? onAvatarTap;

  /// Trailing "…" affordance.
  final VoidCallback? onOverflow;

  /// Trailing widgets before the overflow, e.g. a notification bell.
  final List<Widget> actions;

  const GreetingHeader({
    super.key,
    required this.name,
    this.eyebrow,
    this.chips = const [],
    this.onAvatarTap,
    this.onOverflow,
    this.actions = const [],
  });

  /// First letters of the first two words — "Asha Devi" → "AD".
  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final greeting = trimmed.isEmpty ? 'Hey there 👋' : 'Hey, $trimmed 👋';
    final initials = _initials;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: onAvatarTap != null,
          label: trimmed.isEmpty ? 'Profile' : 'Profile: $trimmed',
          child: Material(
            color: AppColors.primaryContainer,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: initials.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: AppColors.primaryDark,
                        )
                      : Text(
                          initials,
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        AppSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 1),
              ],
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: chips,
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty || onOverflow != null) ...[
          AppSpacing.hGapXs,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...actions,
              if (onOverflow != null)
                IconButton(
                  onPressed: onOverflow,
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: AppColors.textSecondary,
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'More',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
