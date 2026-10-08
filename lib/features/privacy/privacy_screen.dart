import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/swipe_to_confirm.dart';
import '../data_export/data_export_screen.dart';

/// Privacy & data — where everything PRANA knows about you is kept.
///
/// The counts under "On this phone" are read from the real stores, not written
/// as copy. A privacy screen that claims "3 things stored" while the app holds
/// ninety days of history is worse than no privacy screen at all.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final privacy = controller.privacyService;
    final baseline = controller.currentBaseline;
    final profile = controller.userProfile;
    var order = 0;

    return PranaScaffold(
      title: 'Privacy and data',
      subtitle: 'Nothing here has ever left this device',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          // ── Hero ───────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const _PrivacyHero(),
          ),
          AppSpacing.gapSm,

          // ── What is actually stored ────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'On this phone',
              subtitle: 'Everything PRANA has saved, and nothing more',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard.well(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _Footprint(
                      icon: Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      value: '${controller.dailySummaries.length}',
                      label: controller.dailySummaries.length == 1
                          ? 'day of history'
                          : 'days of history',
                    ),
                  ),
                  const _FootprintDivider(),
                  Expanded(
                    child: _Footprint(
                      icon: Icons.insights_rounded,
                      color: AppColors.spo2,
                      value: Fmt.count(baseline.totalReadingsLearned),
                      label: 'readings learned',
                    ),
                  ),
                  const _FootprintDivider(),
                  Expanded(
                    child: _Footprint(
                      icon: Icons.contacts_rounded,
                      color: AppColors.heartRate,
                      value: '${profile.emergencyContacts.length}',
                      label: profile.emergencyContacts.length == 1
                          ? 'contact saved'
                          : 'contacts saved',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── Where the data lives ───────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(title: 'Where your data lives'),
          ),
          FadeSlideIn(
            index: order++,
            child: const AppCard(
              child: Column(
                children: [
                  _AuditRow('Your vitals', 'This phone'),
                  _AuditDivider(),
                  _AuditRow('The baseline PRANA learned', 'This phone'),
                  _AuditDivider(),
                  _AuditRow('Risk calculations', 'On device'),
                  _AuditDivider(),
                  _AuditRow('Fall detection', 'On device'),
                  _AuditDivider(),
                  _AuditRow('Day-by-day history', 'This phone'),
                  _AuditDivider(),
                  _AuditRow(
                    'Internet connection',
                    'Not needed',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── Sharing ────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'Sharing',
              subtitle: 'You decide what PRANA is allowed to send',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _SwitchTile(
                    title: 'Location with an SOS',
                    subtitle: 'Attach your coordinates when an SOS goes out',
                    value: privacy.isLocationSharingEnabled,
                    onChanged: (v) => privacy.updateToggle('shareLocation', v),
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    title: 'Alert your primary contact',
                    subtitle:
                        'Text them automatically if something serious happens',
                    value: privacy.isFamilySharingEnabled,
                    onChanged: (v) => privacy.updateToggle('shareFamily', v),
                  ),
                  const Divider(height: 1),
                  _SwitchTile(
                    title: 'Doctor summary',
                    subtitle: 'Let PRANA build a health summary you can share',
                    value: privacy.isHealthcareSharingEnabled,
                    onChanged: (v) =>
                        privacy.updateToggle('shareHealthcare', v),
                  ),
                  const Divider(height: 1),
                  // Deliberately fixed off and unswitchable. There is no server
                  // to sync to, and a toggle here would imply one exists.
                  const _SwitchTile(
                    title: 'Cloud sync',
                    subtitle: 'PRANA has no server. This cannot be turned on.',
                    value: false,
                    onChanged: null,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── Export ─────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'Export',
              subtitle: 'Take your recorded readings with you',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconChip(
                        icon: Icons.ios_share_rounded,
                        color: AppColors.primary,
                        background: AppColors.primaryContainer,
                        size: 36,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          'Recorded readings',
                          style: AppTypography.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Export the calm vitals PRANA has recorded — the data its '
                    'on-device model learns from — as a CSV you can open or '
                    'share. Decoded to real units; it stays on the phone until '
                    'you send it.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapMd,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      label: const Text('Export & share readings'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DataExportScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── Reset ──────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(title: 'Reset'),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              accent: AppColors.riskCritical,
              color: AppColors.riskCriticalBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconChip(
                        icon: Icons.delete_forever_rounded,
                        color: AppColors.riskCritical,
                        background: Colors.white,
                        size: 36,
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          'Wipe everything',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.riskCritical,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Text(
                    'Clears the baseline PRANA has learned, your saved history '
                    'and your emergency contacts. It cannot be undone.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  AppSpacing.gapMd,
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.riskCritical,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.riskCritical),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text('Wipe all data'),
                      onPressed: () => _showWipeSheet(context, controller),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The wipe confirmation.
  ///
  /// A sheet rather than a dialog so it can itemise what is about to go, with
  /// real counts, and so the confirmation can be a deliberate drag —
  /// [SwipeToConfirm] with `requireDrag`, because a tap is far too cheap a
  /// gesture for something irreversible.
  void _showWipeSheet(BuildContext context, PranaHealthController controller) {
    final messenger = ScaffoldMessenger.of(context);
    final days = controller.dailySummaries.length;
    final readings = controller.currentBaseline.totalReadingsLearned;
    final contacts = controller.userProfile.emergencyContacts.length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Text(
                  'Wipe all data?',
                  style: AppTypography.headlineSmall,
                ),
                AppSpacing.gapXs,
                Text(
                  'This is permanent. PRANA will start over from a blank '
                  'baseline the next time you wear your band.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                AppSpacing.gapMd,
                AppCard.well(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  child: Column(
                    children: [
                      _WipeLine(
                        icon: Icons.calendar_month_rounded,
                        label: days == 1
                            ? '1 day of history'
                            : '$days days of history',
                      ),
                      _WipeLine(
                        icon: Icons.insights_rounded,
                        label: '${Fmt.count(readings)} learned readings',
                      ),
                      _WipeLine(
                        icon: Icons.contacts_rounded,
                        label: contacts == 1
                            ? '1 emergency contact'
                            : '$contacts emergency contacts',
                      ),
                      const _WipeLine(
                        icon: Icons.person_rounded,
                        label: 'Your profile and preferences',
                        last: true,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                SwipeToConfirm(
                  label: 'Swipe to wipe everything',
                  requireDrag: true,
                  background: AppColors.riskCritical,
                  handleIcon: Icons.delete_forever_rounded,
                  onConfirm: () async {
                    final nav = Navigator.of(sheetContext);
                    await controller.wipeLocalData();
                    if (nav.canPop()) nav.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('All local data cleared.'),
                      ),
                    );
                  },
                ),
                AppSpacing.gapSm,
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Keep my data'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The dark statement card at the top of the screen.
class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      showBorder: false,
      radius: AppRadius.xl,
      gradient: const LinearGradient(
        colors: AppColors.gradientDark,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.shield_rounded,
                color: AppColors.accent,
                background: Colors.white.withValues(alpha: 0.10),
                size: 38,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Offline by design',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          Text(
            'Nothing leaves your phone',
            style: AppTypography.headlineSmall.copyWith(color: Colors.white),
          ),
          AppSpacing.gapXs,
          Text(
            'PRANA reads your sensor, learns your normal range and works out '
            'your risk entirely on this device. There is no account and no '
            'upload — the app has no server to talk to.',
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _HeroChip(label: 'No account'),
              _HeroChip(label: 'No upload'),
              _HeroChip(label: 'Works with no signal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three real counts under "On this phone".
class _Footprint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _Footprint({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.metricSmall,
        ),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _FootprintDivider extends StatelessWidget {
  const _FootprintDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
  }
}

class _AuditDivider extends StatelessWidget {
  const _AuditDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: AppSpacing.md, color: AppColors.borderLight);
  }
}

class _AuditRow extends StatelessWidget {
  final String label;
  final String status;
  final Color color;

  const _AuditRow(this.label, this.status, {this.color = AppColors.riskSafe});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppSpacing.hGapXs,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 116),
          child: StatusPill(
            label: status,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _WipeLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool last;

  const _WipeLine({required this.icon, required this.label, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.riskCritical),
          AppSpacing.hGapXs,
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;

  /// Null renders the row disabled — used for settings that exist in storage
  /// but have no working implementation to switch on.
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(
          color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
