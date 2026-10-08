import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/widgets/ambient_background.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../profile/profile_editor.dart';
import '../../app/routes.dart';

/// First run: three slides explaining what PRANA does, then a setup step that
/// actually collects the details it needs.
///
/// That last step is not decoration. Before it existed, a new install kept the
/// sample profile — so the first SOS would have named a person who does not
/// exist and quoted somebody else's blood group. The step reuses the profile
/// editors from the Me tab rather than duplicating the forms.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;

  const _Slide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  /// What the setup step has collected so far. Held here, written once on
  /// finish, so backing out of a sheet changes nothing.
  UserProfile? _draftProfile;
  EmergencyContact? _draftContact;

  /// Seed for the profile sheet. Empty strings on purpose: the editor
  /// normalises an unrecognised sex or blood group to its own first option, so
  /// onboarding never pre-answers a question about the person using it.
  static const UserProfile _blank = UserProfile(
    name: '',
    age: 0,
    gender: '',
    heightCm: 0,
    weightKg: 0,
    bloodGroup: '',
    medicalConditions: [],
    emergencyContacts: [],
  );

  static const List<_Slide> _slides = [
    _Slide(
      title: 'Your health,\nunderstood',
      subtitle:
          'PRANA learns what normal looks like for you, then watches for the '
          'changes that actually matter.',
      icon: Icons.fingerprint_rounded,
      badge: 'Personal baseline',
    ),
    _Slide(
      title: 'Know before risk\nbecomes danger',
      subtitle:
          'Your vitals are read alongside the heat and air quality around you, '
          'so a warning arrives early.',
      icon: Icons.shield_outlined,
      badge: 'Vitals, heat and air',
    ),
    _Slide(
      title: 'Your data\nstays yours',
      subtitle:
          'Everything runs on this phone. No account, no upload, no internet '
          'needed.',
      icon: Icons.lock_outline_rounded,
      badge: 'Works offline',
    ),
  ];

  /// Slides plus the setup step.
  int get _pageCount => _slides.length + 1;
  bool get _onSetup => _currentPage == _slides.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editDetails() async {
    final updated = await showEditProfileSheet(context, _draftProfile ?? _blank);
    if (updated == null) return;
    setState(() => _draftProfile = updated);
  }

  Future<void> _editContact() async {
    final contact = await showEditContactSheet(
      context,
      existing: _draftContact,
    );
    if (contact == null) return;
    setState(() => _draftContact = contact);
  }

  /// Load the sample profile deliberately, and say out loud that it is sample
  /// data. The demo path stays available without being the silent default.
  void _useSample() {
    final sample = UserProfile.defaultProfile();
    setState(() {
      _draftProfile = sample;
      _draftContact = sample.emergencyContacts.isEmpty
          ? null
          : sample.emergencyContacts.first;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Sample details loaded. Replace them in the Me tab.'),
        ),
      );
  }

  Future<void> _finish() async {
    final draft = _draftProfile;
    if (draft == null || _saving) return;

    setState(() => _saving = true);
    final controller = context.read<PranaHealthController>();
    final navigator = Navigator.of(context);

    // A lone contact is always the primary one — the SOS screen names exactly
    // one, and it should never be nobody.
    final contact = _draftContact;
    final contacts = contact == null
        ? const <EmergencyContact>[]
        : [
            EmergencyContact(
              name: contact.name,
              relation: contact.relation,
              phone: contact.phone,
              isPrimary: true,
            ),
          ];

    await controller.updateUserProfile(
      draft.copyWith(emergencyContacts: contacts),
    );
    await controller.storage.setOnboardingComplete(true);

    if (!mounted) return;
    navigator.pushReplacementNamed(AppRoutes.mainShell);
  }

  void _onPrimaryAction() {
    if (!_onSetup) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      return;
    }
    // On the setup step the button is never dead: it opens the form until
    // there is something to save.
    if (_draftProfile == null) {
      _editDetails();
    } else {
      _finish();
    }
  }

  String get _actionLabel {
    if (!_onSetup) return 'Continue';
    if (_draftProfile == null) return 'Add your details';
    return 'Start monitoring';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Column(
              children: [
                // Wordmark + skip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppRadius.brXs,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        AppSpacing.hGapXs,
                        Text(
                          'PRANA',
                          style: AppTypography.titleMedium.copyWith(
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    // Skip jumps past the story, not past the setup step.
                    if (!_onSetup)
                      TextButton(
                        onPressed: () =>
                            _pageController.jumpToPage(_slides.length),
                        child: Text('Skip', style: AppTypography.bodyMedium),
                      ),
                  ],
                ),

                // Expanded (not a fixed-height box) so a small screen or a
                // large system font scrolls instead of overflowing.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _pageCount,
                    itemBuilder: (context, index) {
                      if (index == _slides.length) {
                        return _SetupStep(
                          profile: _draftProfile,
                          contact: _draftContact,
                          onEditDetails: _editDetails,
                          onEditContact: _editContact,
                          onUseSample: _useSample,
                        );
                      }
                      return _SlideView(slide: _slides[index]);
                    },
                  ),
                ),

                // Page indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pageCount, (index) {
                    final active = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.border,
                        borderRadius: AppRadius.brPill,
                      ),
                    );
                  }),
                ),
                AppSpacing.gapXl,

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _onPrimaryAction,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_actionLabel),
                  ),
                ),
                AppSpacing.gapSm,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Story slide ───────────────────────────────────────────────────────────────
class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppSpacing.gapXl,
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(slide.icon, size: 44, color: AppColors.primary),
          ),
          AppSpacing.gapXl,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              slide.badge,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AppSpacing.gapMd,
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(height: 1.15),
          ),
          AppSpacing.gapSm,
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          AppSpacing.gapXl,
        ],
      ),
    );
  }
}

// ── Setup step ────────────────────────────────────────────────────────────────
/// The one screen that turns a fresh install into somebody's install. Both rows
/// open the same editors the Me tab uses, so there is a single source of truth
/// for validation.
class _SetupStep extends StatelessWidget {
  final UserProfile? profile;
  final EmergencyContact? contact;
  final VoidCallback onEditDetails;
  final VoidCallback onEditContact;
  final VoidCallback onUseSample;

  const _SetupStep({
    required this.profile,
    required this.contact,
    required this.onEditDetails,
    required this.onEditContact,
    required this.onUseSample,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.gapLg,
          Text(
            'Two things\nbefore you start',
            style: AppTypography.displayMedium.copyWith(height: 1.15),
          ),
          AppSpacing.gapSm,
          Text(
            'PRANA reads both of these out in an emergency, so they need to be '
            'yours.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          AppSpacing.gapLg,
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Your details',
                  // Once filled, the row echoes what was entered — a bare tick
                  // would leave the user with nothing to check.
                  subtitle: p == null
                      ? 'Name, age, blood group and medical notes'
                      : '${p.name} · ${p.age} · ${p.gender} · ${p.bloodGroup}',
                  onTap: onEditDetails,
                  trailing: p == null ? null : const _DoneMark(),
                  showChevron: p == null,
                ),
                const Divider(height: 1, color: AppColors.borderLight),
                InfoRow(
                  icon: Icons.contact_phone_outlined,
                  title: 'Emergency contact',
                  subtitle: contact == null
                      ? 'Optional. Named on the SOS screen.'
                      : '${contact!.name} · ${contact!.relation} · '
                          '${contact!.phone}',
                  onTap: onEditContact,
                  trailing: contact == null ? null : const _DoneMark(),
                  showChevron: contact == null,
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
              AppSpacing.hGapXs,
              Expanded(
                child: Text(
                  'Saved on this phone only, and editable any time from the Me '
                  'tab. Nothing is uploaded.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (p == null) ...[
            AppSpacing.gapSm,
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onUseSample,
                icon: const Icon(Icons.science_outlined, size: 17),
                label: const Text('Just exploring — use sample details'),
              ),
            ),
          ],
          AppSpacing.gapLg,
        ],
      ),
    );
  }
}

class _DoneMark extends StatelessWidget {
  const _DoneMark();

  @override
  Widget build(BuildContext context) {
    return const IconChip(
      icon: Icons.check_rounded,
      color: AppColors.primary,
      background: AppColors.mint,
      size: 30,
    );
  }
}
