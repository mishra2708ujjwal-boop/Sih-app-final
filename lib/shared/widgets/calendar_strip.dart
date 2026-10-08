import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import 'icon_chip.dart';

/// A week-at-a-glance date selector: month title, week paging arrows, and seven
/// day cells with the selection filled in forest green.
///
/// Weeks are the right grain for this app — a health history is read "how was
/// my week", not "what happened on the 14th of March" — and one week fits seven
/// tappable cells on the narrowest phone without scrolling.
///
/// Future dates are rendered but not selectable: there is no data there, and
/// letting someone tap into an empty day is a dead end.
class CalendarStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// Days that have recorded data, marked with a dot. Compared by calendar day.
  final Set<DateTime> markedDates;

  /// Latest selectable day. Defaults to today.
  final DateTime? lastSelectableDate;

  const CalendarStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.markedDates = const {},
    this.lastSelectableDate,
  });

  @override
  State<CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<CalendarStrip> {
  /// The Sunday that starts the visible week.
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(widget.selectedDate);
  }

  @override
  void didUpdateWidget(covariant CalendarStrip old) {
    super.didUpdateWidget(old);
    // Follow an externally-driven selection into its week.
    if (!_sameDay(old.selectedDate, widget.selectedDate)) {
      final target = _startOfWeek(widget.selectedDate);
      if (!_sameDay(target, _weekStart)) _weekStart = target;
    }
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Week starts Sunday, matching the reference's Sun–Sat header.
  static DateTime _startOfWeek(DateTime d) =>
      _dayOnly(d).subtract(Duration(days: d.weekday % 7));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * weeks)));
  }

  @override
  Widget build(BuildContext context) {
    final last = _dayOnly(widget.lastSelectableDate ?? DateTime.now());
    final days = [
      for (var i = 0; i < 7; i++) _weekStart.add(Duration(days: i)),
    ];

    // Label the month the week mostly belongs to, so a week straddling a month
    // boundary doesn't flip its title on the first day.
    final midWeek = days[3];
    final nextWeekStart = _weekStart.add(const Duration(days: 7));
    final canGoForward = !nextWeekStart.isAfter(last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(midWeek),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineSmall,
              ),
            ),
            CircleIconButton(
              icon: Icons.chevron_left_rounded,
              size: 32,
              tooltip: 'Previous week',
              background: AppColors.surfaceWell,
              color: AppColors.textPrimary,
              onTap: () => _shiftWeek(-1),
            ),
            AppSpacing.hGapXxs,
            CircleIconButton(
              icon: Icons.chevron_right_rounded,
              size: 32,
              tooltip: 'Next week',
              background: canGoForward
                  ? AppColors.surfaceWell
                  : AppColors.surfaceWell.withValues(alpha: 0.45),
              color: canGoForward
                  ? AppColors.textPrimary
                  : AppColors.textTertiary,
              onTap: canGoForward ? () => _shiftWeek(1) : null,
            ),
          ],
        ),
        AppSpacing.gapSm,
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: _DayCell(
                  date: day,
                  isSelected: _sameDay(day, widget.selectedDate),
                  isToday: _sameDay(day, last),
                  isSelectable: !day.isAfter(last),
                  hasData: widget.markedDates.any((d) => _sameDay(d, day)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onDateSelected(day);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isSelectable;
  final bool hasData;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isSelectable,
    required this.hasData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('E').format(date);

    final Color numberColor;
    if (isSelected) {
      numberColor = Colors.white;
    } else if (!isSelectable) {
      numberColor = AppColors.textTertiary.withValues(alpha: 0.5);
    } else {
      numberColor = AppColors.textPrimary;
    }

    return Semantics(
      button: isSelectable,
      selected: isSelected,
      label: '${DateFormat('EEEE d MMMM').format(date)}'
          '${hasData ? ', has readings' : ''}',
      child: InkWell(
        onTap: isSelectable ? onTap : null,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelectable
                      ? AppColors.textSecondary
                      : AppColors.textTertiary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.gapXs,
              // A fixed 34px puck is safe here: the digit inside is at most two
              // characters and never scales past the circle.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: !isSelected && isToday
                      ? Border.all(color: AppColors.primary, width: 1.4)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: AppTypography.labelLarge.copyWith(
                      color: numberColor,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // Reserve the dot's row height always, so selecting a day with
              // data doesn't shift the strip by 5px.
              SizedBox(
                height: 5,
                child: hasData
                    ? Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.mintDeep,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
