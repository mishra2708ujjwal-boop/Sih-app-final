import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_search_field.dart';

/// One thing the search pill can find: a screen, a metric, or an action.
///
/// Everything here is supplied by the caller, so search can only ever surface
/// destinations that actually exist and values that were actually measured.
class QuickSearchEntry {
  final String title;

  /// Right-hand detail. For a metric this is the live reading; for a screen,
  /// a one-line description of what's there.
  final String subtitle;

  final IconData icon;
  final Color color;

  /// Extra terms that should match this entry — synonyms, abbreviations, units.
  /// "spo2" and "oxygen" should both find blood oxygen.
  final List<String> keywords;

  /// Grouping label in the result list, e.g. "Vitals" or "Go to".
  final String group;

  /// Invoked after the sheet closes.
  final VoidCallback onSelect;

  const QuickSearchEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.group,
    required this.onSelect,
    this.keywords = const [],
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) return true;
    if (group.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }

  /// Lower sorts first. An exact title prefix beats a keyword hit, which beats
  /// a match buried in the subtitle — so typing "he" puts Heart rate on top
  /// rather than whichever entry happens to mention "the" in its description.
  int rank(String query) {
    if (query.isEmpty) return 2;
    final q = query.toLowerCase();
    final t = title.toLowerCase();
    if (t == q) return 0;
    if (t.startsWith(q)) return 1;
    if (keywords.any((k) => k.toLowerCase().startsWith(q))) return 2;
    if (t.contains(q)) return 3;
    if (keywords.any((k) => k.toLowerCase().contains(q))) return 4;
    if (group.toLowerCase().contains(q)) return 5;
    return 6;
  }
}

/// Opens the quick-search sheet. Returns when it closes.
Future<void> showQuickSearch(
  BuildContext context, {
  required List<QuickSearchEntry> entries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    // Tall but not full-bleed: leaving the page edge visible keeps the sheet
    // reading as a layer over Home rather than as a screen you navigated to.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
    ),
    builder: (_) => _QuickSearchSheet(entries: entries),
  );
}

class _QuickSearchSheet extends StatefulWidget {
  final List<QuickSearchEntry> entries;

  const _QuickSearchSheet({required this.entries});

  @override
  State<_QuickSearchSheet> createState() => _QuickSearchSheetState();
}

class _QuickSearchSheetState extends State<_QuickSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(QuickSearchEntry entry) {
    Navigator.of(context).pop();
    entry.onSelect();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.entries.where((e) => e.matches(_query)).toList()
      ..sort((a, b) {
        final r = a.rank(_query).compareTo(b.rank(_query));
        return r != 0 ? r : a.title.compareTo(b.title);
      });

    // Preserve first-appearance order of groups so the list doesn't reshuffle
    // its sections as the query narrows.
    final groups = <String, List<QuickSearchEntry>>{};
    for (final e in matches) {
      groups.putIfAbsent(e.group, () => []).add(e);
    }

    return Padding(
      // Lifts the sheet above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Column(
              children: [
                // Grab handle.
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
                AppSpacing.gapMd,
                PranaSearchField(
                  hintText: 'Search vitals, screens, actions',
                  controller: _controller,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) {
                    if (matches.isNotEmpty) _run(matches.first);
                  },
                ),
              ],
            ),
          ),
          Flexible(
            child: matches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      children: [
                        const IconChip(
                          icon: Icons.search_off_rounded,
                          color: AppColors.textTertiary,
                          size: 56,
                        ),
                        AppSpacing.gapMd,
                        Text(
                          'Nothing matches "$_query"',
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a vital sign, a screen name, or "emergency".',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      for (final group in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xs,
                            AppSpacing.sm,
                            0,
                            AppSpacing.xxs,
                          ),
                          child: Text(
                            group.key.toUpperCase(),
                            style: AppTypography.labelCaps.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        for (final entry in group.value)
                          _ResultTile(entry: entry, onTap: () => _run(entry)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final QuickSearchEntry entry;
  final VoidCallback onTap;

  const _ResultTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              IconChip(icon: entry.icon, color: entry.color, size: 38),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hGapXs,
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
