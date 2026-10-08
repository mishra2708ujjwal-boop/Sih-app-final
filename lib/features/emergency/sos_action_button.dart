import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/icon_chip.dart';

/// Publishes the shell's emergency launcher to the tab subtree.
///
/// The navigation shell owns the one true path to the Emergency screen — it
/// adds the haptic and de-duplicates against the fall-detection auto-open. Rather
/// than thread that callback through five screen constructors, the shell exposes
/// it here and any header [SosActionButton] picks it up by context.
class EmergencyLauncher extends InheritedWidget {
  /// Opens the Emergency screen. Wired to the shell's guarded `_openEmergency`.
  final VoidCallback open;

  const EmergencyLauncher({
    super.key,
    required this.open,
    required super.child,
  });

  static VoidCallback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmergencyLauncher>()?.open;

  @override
  bool updateShouldNotify(EmergencyLauncher oldWidget) =>
      open != oldWidget.open;
}

/// The persistent SOS control that lives in the header of every tab.
///
/// A loud red disc — the one control that must be findable without looking. It
/// only ever *opens* the Emergency screen (it never dispatches an SOS directly),
/// so a mis-tap in a pocket costs nothing. Renders nothing when no
/// [EmergencyLauncher] is in scope, so it is safe to drop into any
/// [PranaScaffold] header.
class SosActionButton extends StatelessWidget {
  const SosActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    final open = EmergencyLauncher.maybeOf(context);
    if (open == null) return const SizedBox.shrink();

    return CircleIconButton(
      icon: Icons.sos_rounded,
      color: Colors.white,
      background: AppColors.riskCritical,
      size: 40,
      tooltip: 'Emergency SOS',
      onTap: open,
    );
  }
}
