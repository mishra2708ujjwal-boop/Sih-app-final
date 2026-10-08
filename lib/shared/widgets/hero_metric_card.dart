import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'status_pill.dart';

/// The mint feature card: a soft gradient panel carrying one headline figure,
/// a caption, and an optional action.
///
/// Reserved for the single most important thing on a screen. If two of these
/// sit next to each other, neither is a hero — use [AppCard] for the second.
class HeroMetricCard extends StatelessWidget {
  /// The headline figure, e.g. "7.4" or "126+".
  final String value;

  /// Trails [value] on its baseline, e.g. "h" or "%".
  final String? unit;

  /// The line under the figure, e.g. "Sleep irregularities".
  final String label;

  /// Optional line above the figure — a section name or timestamp.
  final String? caption;

  /// Small pill in the top-right, e.g. a trend or a state.
  final String? badgeLabel;
  final Color? badgeColor;

  /// Circular action in the bottom-right, e.g. a "+" or a chevron.
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// A decorative glyph watermarked behind the figure.
  final IconData? watermark;

  final VoidCallback? onTap;

  /// Background gradient. Defaults to the mint wash.
  final List<Color> gradient;

  /// Ink colour for text on [gradient]. Defaults to the near-black primary.
  final Color foreground;

  const HeroMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.caption,
    this.badgeLabel,
    this.badgeColor,
    this.actionIcon,
    this.onAction,
    this.watermark,
    this.onTap,
    this.gradient = AppColors.gradientMint,
    this.foreground = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.brXl,
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          if (watermark != null)
            Positioned(
              right: -12,
              bottom: -18,
              child: Icon(
                watermark,
                size: 108,
                color: foreground.withValues(alpha: 0.07),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null || badgeLabel != null)
                Row(
                  children: [
                    if (caption != null)
                      Expanded(
                        child: Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelCaps.copyWith(
                            color: foreground.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (badgeLabel != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: StatusPill(
                          label: badgeLabel!,
                          dense: true,
                          color: badgeColor ?? AppColors.primaryDark,
                          backgroundColor:
                              AppColors.surface.withValues(alpha: 0.62),
                        ),
                      ),
                  ],
                ),
              if (caption != null || badgeLabel != null) AppSpacing.gapMd,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.metricHero.copyWith(
                                  color: foreground,
                                ),
                              ),
                            ),
                            if (unit != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                unit!,
                                style: AppTypography.headlineSmall.copyWith(
                                  color: foreground.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: foreground.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionIcon != null && onAction != null) ...[
                    AppSpacing.hGapSm,
                    Semantics(
                      button: true,
                      label: label,
                      child: Material(
                        color: AppColors.surface.withValues(alpha: 0.72),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onAction,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                actionIcon,
                                size: 20,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.brXl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brXl,
        child: content,
      ),
    );
  }
}
