import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/device_info.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/prana_action_sheet.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/status_pill.dart';
import '../privacy/privacy_screen.dart';
import '../devices/device_screen.dart';
import '../demo/demo_lab_screen.dart';
import '../emergency/fall_detection_screen.dart';
import '../emergency/sos_action_button.dart';
import '../history/history_screen.dart';
import 'profile_editor.dart';

/// "Me" — profile, learned baseline, emergency contacts and settings.
///
/// Everything on this screen is editable and persisted, because everything on
/// it is load-bearing somewhere else: the SOS message quotes the profile, the
/// emergency screen names the primary contact, and the risk engine compares
/// every reading against the learned baseline.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Readings before the baseline stops being the generic adult prior. Matches
  /// the threshold the Insights screen uses for its "still learning" notice.
  static const int _calibrationTarget = 60;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final profile = controller.userProfile;
    final baseline = controller.currentBaseline;
    final device = controller.currentDevice;
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;
    final contacts = profile.emergencyContacts;
    final learned = baseline.totalReadingsLearned;
    final calibrating = learned < _calibrationTarget;

    var order = 0;

    return PranaScaffold(
      title: 'Me',
      subtitle: 'Your profile, baseline and settings',
      actions: const [SosActionButton()],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xxs,
          AppSpacing.md,
          AppSpacing.navClearance,
        ),
        children: [
          // ── Profile header ──────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: _ProfileHero(
              profile: profile,
              onEdit: () => _editProfile(context, controller, profile),
            ),
          ),
          AppSpacing.gapSm,

          // ── Learned baseline ────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: 'Your baseline',
              subtitle: calibrating
                  ? 'Still learning what normal looks like for you'
                  : 'Learned from ${Fmt.count(learned)} of your own readings',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Column(
                children: [
                  if (calibrating) ...[
                    _CalibrationBar(
                      learned: learned,
                      target: _calibrationTarget,
                    ),
                    AppSpacing.gapMd,
                  ],
                  _BaselineRow(
                    label: 'Heart rate',
                    value: '${baseline.normalHrMin.toStringAsFixed(0)}–'
                        '${baseline.normalHrMax.toStringAsFixed(0)} BPM',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _BaselineRow(
                    label: 'Blood oxygen',
                    value: '≥ ${baseline.normalSpo2Min.toStringAsFixed(0)} %',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _BaselineRow(
                    label: 'Body temperature',
                    value: '${baseline.normalTempMin.toStringAsFixed(1)}–'
                        '${baseline.normalTempMax.toStringAsFixed(1)} °C',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _BaselineRow(
                    label: 'Resting heart rate',
                    value:
                        '${baseline.restingHrBaseline.toStringAsFixed(0)} BPM',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _BaselineRow(
                    label: 'Last recalculated',
                    value: Fmt.ago(baseline.lastCalibrated),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── Emergency contacts ──────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: 'Emergency contacts',
              subtitle: contacts.isEmpty
                  ? 'Nobody saved yet'
                  : 'Named on the SOS screen and in the alert message',
              actionLabel: 'Add',
              onAction: () => _addContact(context, controller, profile),
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: contacts.isEmpty
                ? AppCard(
                    child: EmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      iconColor: AppColors.riskCritical,
                      title: 'No contacts yet',
                      subtitle:
                          'Add someone PRANA should name if you fall or send '
                          'an SOS. Saved on this phone only.',
                      actionLabel: 'Add a contact',
                      onAction: () => _addContact(context, controller, profile),
                      compact: true,
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < contacts.length; i++) ...[
                          if (i > 0)
                            const Divider(
                              height: 1,
                              color: AppColors.borderLight,
                            ),
                          InfoRow(
                            icon: contacts[i].isPrimary
                                ? Icons.star_rounded
                                : Icons.person_outline_rounded,
                            iconColor: contacts[i].isPrimary
                                ? AppColors.riskCritical
                                : AppColors.textSecondary,
                            title: contacts[i].name,
                            subtitle: '${contacts[i].relation} · '
                                '${contacts[i].phone}',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (contacts[i].isPrimary)
                                  const StatusPill(
                                    label: 'Primary',
                                    color: AppColors.riskCritical,
                                    backgroundColor: AppColors.riskCriticalBg,
                                    dense: true,
                                  ),
                                AppSpacing.hGapXxs,
                                CircleIconButton(
                                  icon: Icons.more_horiz_rounded,
                                  size: 32,
                                  tooltip: 'Contact options',
                                  onTap: () => _contactOptions(
                                    context,
                                    controller,
                                    profile,
                                    i,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          AppSpacing.gapSm,

          // ── Device & data ───────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(title: 'Device and data'),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.watch_outlined,
                    title: 'Your band',
                    subtitle: isConnected
                        ? 'Connected · ${device.batteryLevel}% battery'
                        : 'Not connected',
                    iconColor: isConnected
                        ? AppColors.bleConnected
                        : AppColors.textTertiary,
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DeviceScreen()),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.calendar_month_outlined,
                    title: 'Day-by-day history',
                    subtitle: controller.dailySummaries.isEmpty
                        ? 'Nothing recorded yet'
                        : '${controller.dailySummaries.length} '
                            'day${controller.dailySummaries.length == 1 ? '' : 's'} '
                            'saved on this phone',
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.personal_injury_outlined,
                    title: 'Fall detection',
                    subtitle: 'Live motion trace and the detection rule',
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FallDetectionScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.shield_outlined,
                    title: 'Privacy and data',
                    subtitle: 'Everything stays on your phone',
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── About ───────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(title: 'About'),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSmall,
                        ),
                      ),
                      AppSpacing.hGapXs,
                      const StatusPill(
                        label: AppConstants.appVersion,
                        color: AppColors.textSecondary,
                        backgroundColor: AppColors.surfaceWell,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppConstants.appTagline,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: AppSpacing.lg),
                  Text(
                    'Built for Smart India Hackathon.',
                    style: AppTypography.bodyMedium,
                  ),
                  AppSpacing.gapXs,
                  // Developer entry lives here rather than in its own section —
                  // it matters to us, not to the person wearing the band.
                  InfoRow(
                    icon: Icons.science_outlined,
                    iconColor: AppColors.textTertiary,
                    title: 'Demo lab',
                    subtitle: 'Simulated scenarios for presenting the app',
                    showChevron: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DemoLabScreen()),
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

  // ── Edit actions ──────────────────────────────────────────────────────────
  static Future<void> _editProfile(
    BuildContext context,
    PranaHealthController controller,
    UserProfile profile,
  ) async {
    final updated = await showEditProfileSheet(context, profile);
    if (updated == null) return;
    await controller.updateUserProfile(updated);
  }

  static Future<void> _addContact(
    BuildContext context,
    PranaHealthController controller,
    UserProfile profile,
  ) async {
    final contact = await showEditContactSheet(context);
    if (contact == null) return;
    await _writeContacts(
      controller,
      profile,
      [...profile.emergencyContacts, contact],
      makePrimary: contact.isPrimary ? profile.emergencyContacts.length : null,
    );
  }

  static Future<void> _contactOptions(
    BuildContext context,
    PranaHealthController controller,
    UserProfile profile,
    int index,
  ) async {
    final contacts = profile.emergencyContacts;
    final contact = contacts[index];

    await showPranaActionSheet(
      context,
      title: contact.name,
      subtitle: '${contact.relation} · ${contact.phone}',
      actions: [
        PranaAction(
          icon: Icons.edit_outlined,
          label: 'Edit contact',
          onTap: () async {
            final updated = await showEditContactSheet(
              context,
              existing: contact,
            );
            if (updated == null) return;
            final next = [...contacts]..[index] = updated;
            await _writeContacts(
              controller,
              profile,
              next,
              makePrimary: updated.isPrimary ? index : null,
            );
          },
        ),
        PranaAction(
          icon: Icons.star_outline_rounded,
          label: 'Make primary',
          subtitle: contact.isPrimary
              ? 'Already the primary contact'
              : 'Named first on the SOS screen',
          enabled: !contact.isPrimary,
          onTap: () => _writeContacts(
            controller,
            profile,
            contacts,
            makePrimary: index,
          ),
        ),
        PranaAction(
          icon: Icons.person_remove_outlined,
          label: 'Remove contact',
          destructive: true,
          onTap: () async {
            final next = [...contacts]..removeAt(index);
            await _writeContacts(
              controller,
              profile,
              next,
              // Promote whoever is left, so an SOS is never left nameless
              // because the only primary was the one deleted.
              makePrimary: next.isEmpty ? null : 0,
            );
          },
        ),
      ],
    );
  }

  /// Writes the contact list back, keeping exactly one primary.
  ///
  /// Pass [makePrimary] to nominate an index; otherwise the existing primary is
  /// kept, and if there isn't one the first contact is promoted.
  static Future<void> _writeContacts(
    PranaHealthController controller,
    UserProfile profile,
    List<EmergencyContact> contacts, {
    int? makePrimary,
  }) {
    var primary = makePrimary;
    if (primary == null && contacts.isNotEmpty) {
      final existing = contacts.indexWhere((c) => c.isPrimary);
      primary = existing == -1 ? 0 : existing;
    }

    final normalised = <EmergencyContact>[
      for (var i = 0; i < contacts.length; i++)
        EmergencyContact(
          name: contacts[i].name,
          relation: contacts[i].relation,
          phone: contacts[i].phone,
          isPrimary: i == primary,
        ),
    ];

    return controller.updateUserProfile(
      profile.copyWith(emergencyContacts: normalised),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
/// Avatar, name and the facts a responder would be told, over the dark panel
/// the reference uses for its selected states.
class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;

  const _ProfileHero({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final parts = profile.name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2 && parts.first.isNotEmpty
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : profile.name.trim().isNotEmpty
            ? profile.name.trim()[0].toUpperCase()
            : 'P';

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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.trim().isEmpty ? 'Your name' : profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.heightCm.toStringAsFixed(0)} cm · '
                      '${profile.weightKg.toStringAsFixed(1)} kg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hGapXs,
              CircleIconButton(
                icon: Icons.edit_outlined,
                size: 38,
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.12),
                tooltip: 'Edit your details',
                onTap: onEdit,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              _HeroChip(label: '${profile.age} yrs'),
              _HeroChip(label: profile.gender),
              _HeroChip(label: profile.bloodGroup, accent: true),
              if (profile.isVulnerableProfile)
                const _HeroChip(label: 'Higher risk', accent: true),
              for (final condition in profile.medicalConditions)
                _HeroChip(label: condition),
              if (profile.medicalConditions.isEmpty)
                const _HeroChip(label: 'No conditions on record'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final bool accent;

  const _HeroChip({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: accent ? AppColors.accent : Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Baseline ──────────────────────────────────────────────────────────────────
/// How far through calibration the baseline is. Shown only while the numbers
/// below it are still partly the generic adult prior rather than this person's.
class _CalibrationBar extends StatelessWidget {
  final int learned;
  final int target;

  const _CalibrationBar({required this.learned, required this.target});

  @override
  Widget build(BuildContext context) {
    final progress = (learned / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconChip(
              icon: Icons.auto_graph_rounded,
              color: AppColors.primary,
              background: AppColors.mint,
              size: 34,
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                'Calibrating',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$learned / $target',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        AppSpacing.gapSm,
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 7),
        ),
        AppSpacing.gapXs,
        Text(
          'Until then the ranges below start from a standard adult prior and '
          'move towards your own numbers with every reading.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _BaselineRow extends StatelessWidget {
  final String label;
  final String value;

  const _BaselineRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        AppSpacing.hGapXs,
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
