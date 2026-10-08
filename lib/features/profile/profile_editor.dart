import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/models/user_profile.dart';

/// Editors for the profile and its emergency contacts.
///
/// These exist because everything downstream of the profile is real: the SOS
/// message quotes the name, age, blood group and medical notes, and the
/// emergency screen names the primary contact. Shipping those as unchangeable
/// defaults would have meant an alert message about somebody who does not
/// exist.
///
/// Both editors return their result rather than saving it, so the caller owns
/// the single `updateUserProfile` write.

const List<String> _bloodGroups = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
];

const List<String> _genders = ['Male', 'Female', 'Other'];

/// Edit the person: name, age, body, blood group, medical notes.
Future<UserProfile?> showEditProfileSheet(
  BuildContext context,
  UserProfile profile,
) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => _EditProfileSheet(profile: profile),
  );
}

/// Add or edit one emergency contact. Returns null when cancelled.
Future<EmergencyContact?> showEditContactSheet(
  BuildContext context, {
  EmergencyContact? existing,
}) {
  return showModalBottomSheet<EmergencyContact>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => _EditContactSheet(existing: existing),
  );
}

// ── Profile ───────────────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final UserProfile profile;

  const _EditProfileSheet({required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _conditions;
  late String _gender;
  late String _bloodGroup;
  late bool _vulnerable;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age > 0 ? '${p.age}' : '');
    _height = TextEditingController(
      text: p.heightCm > 0 ? p.heightCm.toStringAsFixed(0) : '',
    );
    _weight = TextEditingController(
      text: p.weightKg > 0 ? p.weightKg.toStringAsFixed(1) : '',
    );
    _conditions = TextEditingController(text: p.medicalConditions.join(', '));
    _gender = _genders.contains(p.gender) ? p.gender : _genders.last;
    _bloodGroup =
        _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : _bloodGroups.first;
    _vulnerable = p.isVulnerableProfile;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _conditions.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final conditions = _conditions.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(
      widget.profile.copyWith(
        name: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        gender: _gender,
        heightCm: double.parse(_height.text.trim()),
        weightKg: double.parse(_weight.text.trim()),
        bloodGroup: _bloodGroup,
        medicalConditions: conditions,
        isVulnerableProfile: _vulnerable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Edit your details',
      subtitle: 'These go into your SOS message, so keep them accurate.',
      onSave: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(
              label: 'Full name',
              controller: _name,
              hint: 'As a responder should hear it',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            AppSpacing.gapSm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    label: 'Age',
                    controller: _age,
                    hint: 'Years',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _range(v, 1, 120, 'age'),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _Field(
                    label: 'Height',
                    controller: _height,
                    hint: 'cm',
                    keyboardType: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _range(v, 50, 250, 'height'),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _Field(
                    label: 'Weight',
                    controller: _weight,
                    hint: 'kg',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (v) => _range(v, 10, 300, 'weight'),
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            _ChipField(
              label: 'Sex',
              options: _genders,
              selected: _gender,
              onSelect: (v) => setState(() => _gender = v),
            ),
            AppSpacing.gapSm,
            _ChipField(
              label: 'Blood group',
              options: _bloodGroups,
              selected: _bloodGroup,
              onSelect: (v) => setState(() => _bloodGroup = v),
            ),
            AppSpacing.gapSm,
            _Field(
              label: 'Medical conditions',
              controller: _conditions,
              hint: 'Asthma, diabetes…',
              helper: 'Separate with commas. Sent with every SOS.',
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
            ),
            AppSpacing.gapSm,
            _SwitchRow(
              title: 'Higher-risk profile',
              subtitle: 'Tightens the thresholds PRANA warns you at. '
                  'Use it if you are pregnant, elderly or recovering.',
              value: _vulnerable,
              onChanged: (v) => setState(() => _vulnerable = v),
            ),
          ],
        ),
      ),
    );
  }

  /// Numeric range check shared by the three body fields.
  static String? _range(String? raw, num lo, num hi, String what) {
    final v = double.tryParse((raw ?? '').trim());
    if (v == null) return 'Enter a $what';
    if (v < lo || v > hi) return '$lo–$hi';
    return null;
  }
}

// ── Contact ───────────────────────────────────────────────────────────────────
class _EditContactSheet extends StatefulWidget {
  final EmergencyContact? existing;

  const _EditContactSheet({this.existing});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relation;
  late final TextEditingController _phone;
  late bool _primary;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _relation = TextEditingController(text: c?.relation ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _primary = c?.isPrimary ?? widget.existing == null;
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      EmergencyContact(
        name: _name.text.trim(),
        relation: _relation.text.trim().isEmpty
            ? 'Contact'
            : _relation.text.trim(),
        phone: _phone.text.trim(),
        isPrimary: _primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: widget.existing == null ? 'Add a contact' : 'Edit contact',
      subtitle: 'Saved on this phone only. PRANA never uploads it.',
      onSave: _save,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(
              label: 'Name',
              controller: _name,
              hint: 'Who to reach',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            AppSpacing.gapSm,
            _Field(
              label: 'Relationship',
              controller: _relation,
              hint: 'Spouse, physician, neighbour…',
              textCapitalization: TextCapitalization.words,
            ),
            AppSpacing.gapSm,
            _Field(
              label: 'Phone number',
              controller: _phone,
              hint: '+91 98765 43210',
              keyboardType: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
              ],
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 6) return 'Enter a full number';
                return null;
              },
            ),
            AppSpacing.gapSm,
            _SwitchRow(
              title: 'Primary contact',
              subtitle: 'The one named on the SOS screen. Only one at a time.',
              value: _primary,
              onChanged: (v) => setState(() => _primary = v),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sheet chrome ───────────────────────────────────────────────────────
/// Drag handle, title, scrollable body, and a save bar that clears the
/// keyboard inset so the button is never hidden behind it.
class _SheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onSave;

  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.gapSm,
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.headlineSmall),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    AppSpacing.gapMd,
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled text field on the recessed well surface the theme provides.
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.keyboardType,
    this.formatters,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          validator: validator,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(hintText: hint, helperText: helper),
        ),
      ],
    );
  }
}

/// A label with a wrapping row of single-choice pills. Used where the set of
/// answers is small and fixed — sex, blood group.
class _ChipField extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChipField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapXxs,
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in options)
              _ChoicePill(
                label: option,
                selected: option == selected,
                onTap: () => onSelect(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.brPill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceWell,
            borderRadius: AppRadius.brPill,
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hGapXs,
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
