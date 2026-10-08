import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'ambient_background.dart';
import 'icon_chip.dart';

/// The single page shell for PRANA.
///
/// Replaces the per-screen `Scaffold` + `AppBar` pairs so every screen gets the
/// same large title, the same ambient background wash and the same header
/// rhythm. [headerBottom] is for content that belongs with the title rather
/// than with the scrolling body — a segmented control, for example.
class PranaScaffold extends StatelessWidget {
  /// Screen title. Ignored when [titleOverride] is supplied.
  final String? title;

  /// Optional one-line caption under the title.
  final String? subtitle;

  /// Replaces the whole title block. Use for bespoke headers (the dashboard).
  final Widget? titleOverride;

  final List<Widget> actions;

  /// Pinned under the header, above [body].
  final Widget? headerBottom;

  final Widget body;

  /// Pinned to the bottom, inside the safe area, above the body. For the one
  /// primary action of a screen — a swipe pill, a "Save" button. Screens that
  /// live inside the tab shell should leave this null and let the body scroll
  /// under the nav bar instead.
  final Widget? footer;

  /// Ambient wash tint. Defaults to the sage accent.
  final Color? tint;

  /// Scales the ambient wash. Drop below 1 on colour-heavy screens.
  final double ambientIntensity;

  /// Forces the back button on or off. Defaults to whether the route can pop.
  final bool? showBack;

  const PranaScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.titleOverride,
    this.actions = const [],
    this.headerBottom,
    required this.body,
    this.footer,
    this.tint,
    this.ambientIntensity = 1.0,
    this.showBack,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AmbientBackground(
        tint: tint,
        intensity: ambientIntensity,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (canPop) ...[
                      // Circular, surface-filled: the reference treats every
                      // isolated control as a disc, and a bare IconButton on
                      // cream has no edge to sit against.
                      CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                        tooltip: 'Back',
                        size: 40,
                      ),
                      AppSpacing.hGapSm,
                    ],
                    Expanded(
                      child: titleOverride ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineLarge,
                              ),
                              if (subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                    ),
                    if (actions.isNotEmpty) ...[
                      AppSpacing.hGapXs,
                      // Actions get their own row so a long title ellipsises
                      // instead of squeezing them to zero width.
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                  ],
                ),
              ),
              if (headerBottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: headerBottom!,
                ),
              Expanded(child: body),
              if (footer != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: footer!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
