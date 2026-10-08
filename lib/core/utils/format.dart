import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.
///
/// These exist because the same three conversions were being re-implemented per
/// screen with slightly different rounding, so a step count could read "8420"
/// on Home and "8,420" on Vitals in the same session.
class Fmt {
  Fmt._();

  /// 8420 → "8,420". Grouped so a five-figure count stays scannable.
  static String count(int value) {
    final negative = value < 0;
    final s = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  /// 445 → "7h 25m". Minutes are dropped for whole hours ("8h", not "8h 0m").
  static String duration(int minutes) {
    if (minutes < 0) return '—';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// 445 → "7.4" — for a big display numeral that needs a unit beside it.
  static String hoursDecimal(int minutes) =>
      (minutes / 60).toStringAsFixed(1);

  /// "14:32". 24-hour, because a timestamp on a medical reading should not be
  /// ambiguous about am/pm.
  static String clock(DateTime t) => DateFormat('HH:mm').format(t);

  /// "12 Mar" / "12 Mar 2024" when the year differs from [reference].
  static String date(DateTime t, {DateTime? reference}) {
    final ref = reference ?? t;
    return t.year == ref.year
        ? DateFormat('d MMM').format(t)
        : DateFormat('d MMM y').format(t);
  }

  /// "just now" / "4 min ago" / "3 h ago" / "Yesterday" / "12 Mar".
  ///
  /// [now] is a parameter rather than a `DateTime.now()` call so callers on a
  /// 1 Hz rebuild can pass one clock read instead of taking a new one per row.
  static String ago(DateTime then, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = ref.difference(then);
    if (d.isNegative) return 'just now';
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return '${d.inDays} days ago';
    return date(then, reference: ref);
  }

  /// Signed percentage for a delta pill: 4.2 → "+4.2%", -0.8 → "-0.8%".
  static String signedPercent(double value, {int decimals = 1}) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(decimals)}%';
  }
}
