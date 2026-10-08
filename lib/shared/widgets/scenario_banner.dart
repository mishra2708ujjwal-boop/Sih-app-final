import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/scenarios/disaster_scenario_engine.dart';

/// Slim single-line scenario chip.
///
/// This is the only scenario control left in the main flow — the full preset
/// list with descriptions lives in Profile › Demo Lab. Kept on Home so a judge
/// can switch conditions mid-demo without leaving the dashboard.
class ScenarioBanner extends StatelessWidget {
  final DisasterScenario currentScenario;
  final ValueChanged<DisasterScenario> onScenarioChanged;

  const ScenarioBanner({
    super.key,
    required this.currentScenario,
    required this.onScenarioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isNormal = currentScenario == DisasterScenario.normal;
    final accent = isNormal ? AppColors.textSecondary : currentScenario.badgeColor;

    return PopupMenuButton<DisasterScenario>(
      initialValue: currentScenario,
      onSelected: onScenarioChanged,
      tooltip: 'Switch demo scenario',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      itemBuilder: (context) => DisasterScenario.values.map((scenario) {
        final selected = scenario == currentScenario;
        return PopupMenuItem<DisasterScenario>(
          value: scenario,
          child: Row(
            children: [
              Icon(scenario.icon, size: 18, color: scenario.badgeColor),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  scenario.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) ...[
                AppSpacing.hGapXs,
                const Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color:
              isNormal ? AppColors.surfaceSubtle : currentScenario.badgeBgColor,
          borderRadius: AppRadius.brPill,
          border: Border.all(
            color: isNormal
                ? AppColors.border
                : currentScenario.badgeColor.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.science_outlined, size: 16, color: accent),
            AppSpacing.hGapXs,
            Text(
              'DEMO',
              style: AppTypography.labelCaps.copyWith(color: accent, fontSize: 10),
            ),
            AppSpacing.hGapXs,
            Expanded(
              child: Text(
                currentScenario.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: isNormal ? AppColors.textPrimary : accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.unfold_more_rounded, size: 16, color: accent),
          ],
        ),
      ),
    );
  }
}
