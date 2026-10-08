import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/format.dart';
import '../../shared/models/daily_summary.dart';
import '../../shared/models/risk_result.dart';
import 'health_report_data.dart';

/// `PdfColor` copies of the app palette ([AppColors]) so the printed report
/// reads as the same product as the Vitals screen it came from. AppColors ints
/// are `0xAARRGGBB`, which is exactly what [PdfColor.fromInt] parses.
class _Palette {
  static final background = PdfColor.fromInt(0xFFF2EEE6);
  static final surface = PdfColor.fromInt(0xFFFDFBF7);
  static final surfaceWell = PdfColor.fromInt(0xFFEAE5DA);
  static final primary = PdfColor.fromInt(0xFF2F5D50);
  static final primaryDark = PdfColor.fromInt(0xFF1E3D34);
  static final mint = PdfColor.fromInt(0xFFD9E8CE);
  static final mintDeep = PdfColor.fromInt(0xFF8FB585);
  static final heartRate = PdfColor.fromInt(0xFFE11D48);
  static final spo2 = PdfColor.fromInt(0xFF2D7A99);
  static final temperature = PdfColor.fromInt(0xFFC87137);
  static final activity = PdfColor.fromInt(0xFF4F8A3F);
  static final riskSafe = PdfColor.fromInt(0xFF43855A);
  static final riskModerate = PdfColor.fromInt(0xFFD99518);
  static final riskHigh = PdfColor.fromInt(0xFFF97316);
  static final riskCritical = PdfColor.fromInt(0xFFEF4444);
  static final riskSafeBg = PdfColor.fromInt(0xFFE9F1E4);
  static final riskModerateBg = PdfColor.fromInt(0xFFFBF2DF);
  static final riskHighBg = PdfColor.fromInt(0xFFFCEBDD);
  static final riskCriticalBg = PdfColor.fromInt(0xFFFBE7E4);
  static final border = PdfColor.fromInt(0xFFE5DFD2);
  static final borderLight = PdfColor.fromInt(0xFFEFEAE0);
  static final textPrimary = PdfColor.fromInt(0xFF1C2118);
  static final textSecondary = PdfColor.fromInt(0xFF6F6F62);
  static final textTertiary = PdfColor.fromInt(0xFF9C9A8E);
}

const double _marginH = 32;
const double _marginV = 30;
final double _contentWidth = PdfPageFormat.a4.width - _marginH * 2;
const double _cardPad = 13;
// A few px of slack under the card's inner width so the fixed-size canvas can
// never overflow the padded/bordered box.
final double _chartWidth = _contentWidth - _cardPad * 2 - 4;
const double _chartHeight = 118;

/// Builds the doctor-shareable health report as PDF bytes. Pure function of
/// [data]; performs no I/O beyond encoding.
Future<Uint8List> buildHealthReportPdf(HealthReportData data) async {
  final doc = pw.Document(
    title: 'PRANA Health Report',
    author: 'PRANA',
    creator: 'PRANA',
    subject: 'Health summary for ${_safe(data.profile.name)}',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(
        horizontal: _marginH,
        vertical: _marginV,
      ),
      maxPages: 50,
      header: (ctx) => _header(data, ctx),
      footer: (ctx) => _footer(ctx),
      build: (ctx) {
        final w = <pw.Widget>[];
        w.add(_hero(data));
        w.add(pw.SizedBox(height: 14));

        if (data.isDemo) {
          w.add(_demoBanner());
          w.add(pw.SizedBox(height: 14));
        }

        w.add(_block('Patient', 'Patient details', _patientCard(data)));
        w.add(pw.SizedBox(height: 14));

        w.add(_block('Baseline', 'Learned baseline', _baselineCard(data)));
        w.add(pw.SizedBox(height: 14));

        if (data.hasDays) {
          w.add(_block('Overview', 'Period summary', _summaryGrid(data)));
          w.add(pw.SizedBox(height: 14));

          w.add(_sectionHeader('Trends', 'Daily trends'));
          w.add(pw.SizedBox(height: 8));
          for (final card in _trendCards(data)) {
            w.add(card);
            w.add(pw.SizedBox(height: 10));
          }
          w.add(pw.SizedBox(height: 4));

          w.add(_sectionHeader('Log', 'Daily readings'));
          w.add(pw.SizedBox(height: 8));
          w.add(_tableWidget(data));
          w.add(pw.SizedBox(height: 14));
        } else {
          w.add(_block('Trends', 'Daily trends', _noDaysCard(data)));
          w.add(pw.SizedBox(height: 14));
        }

        w.add(_block('Now', 'Current snapshot', _snapshotCard(data)));
        w.add(pw.SizedBox(height: 14));

        w.add(_disclaimerCard());
        return w;
      },
    ),
  );

  return doc.save();
}

// ── Text + layout helpers ─────────────────────────────────────────────────────

/// The built-in Helvetica used for the PDF covers Latin-1 (WinAnsi) only, so
/// map the handful of typographic characters a profile might carry and drop
/// anything outside the range rather than letting layout throw.
String _safe(String s) {
  final buf = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x2013 || r == 0x2014 || r == 0x2022) {
      buf.write('-');
    } else if (r == 0x2018 || r == 0x2019) {
      buf.write("'");
    } else if (r == 0x201C || r == 0x201D) {
      buf.write('"');
    } else if (r == 0x2026) {
      buf.write('...');
    } else if (r <= 0xFF) {
      buf.writeCharCode(r);
    } else {
      buf.write('?');
    }
  }
  return buf.toString();
}

pw.TextStyle _ts({
  double size = 10,
  PdfColor? color,
  bool bold = false,
  double? letterSpacing,
  double? lineSpacing,
}) =>
    pw.TextStyle(
      fontSize: size,
      color: color ?? _Palette.textPrimary,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      letterSpacing: letterSpacing,
      lineSpacing: lineSpacing,
    );

pw.Widget _text(
  String s, {
  double size = 10,
  PdfColor? color,
  bool bold = false,
  double? letterSpacing,
  double? lineSpacing,
}) =>
    pw.Text(
      _safe(s),
      style: _ts(
        size: size,
        color: color,
        bold: bold,
        letterSpacing: letterSpacing,
        lineSpacing: lineSpacing,
      ),
    );

pw.Widget _card({
  required pw.Widget child,
  PdfColor? color,
  PdfColor? border,
  double pad = _cardPad,
}) =>
    pw.Container(
      width: _contentWidth,
      padding: pw.EdgeInsets.all(pad),
      decoration: pw.BoxDecoration(
        color: color ?? _Palette.surface,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: border ?? _Palette.borderLight, width: 1),
      ),
      child: child,
    );

pw.Widget _sectionHeader(String eyebrow, String title) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          eyebrow.toUpperCase(),
          size: 7.5,
          color: _Palette.textTertiary,
          bold: true,
          letterSpacing: 1.3,
        ),
        pw.SizedBox(height: 2),
        _text(title, size: 13.5, bold: true),
      ],
    );

pw.Widget _block(String eyebrow, String title, pw.Widget card) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader(eyebrow, title),
        pw.SizedBox(height: 8),
        card,
      ],
    );

pw.Widget _pair(String label, String value, {PdfColor? valueColor}) =>
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          label.toUpperCase(),
          size: 7,
          color: _Palette.textTertiary,
          bold: true,
          letterSpacing: 0.8,
        ),
        pw.SizedBox(height: 2),
        _text(value, size: 10.5, color: valueColor, bold: true),
      ],
    );

/// Lays out [pairs] two per row.
pw.Widget _pairGrid(List<pw.Widget> pairs) {
  final rows = <pw.Widget>[];
  for (var i = 0; i < pairs.length; i += 2) {
    final right = i + 1 < pairs.length ? pairs[i + 1] : pw.SizedBox();
    rows.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pairs[i]),
            pw.SizedBox(width: 14),
            pw.Expanded(child: right),
          ],
        ),
      ),
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: rows,
  );
}

pw.Widget _kpi(String label, String value, {String? unit, PdfColor? accent}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: pw.BoxDecoration(
        color: _Palette.surfaceWell,
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            label.toUpperCase(),
            size: 6.8,
            color: _Palette.textTertiary,
            bold: true,
            letterSpacing: 0.6,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _text(value, size: 15, color: accent ?? _Palette.textPrimary,
                  bold: true),
              if (unit != null) ...[
                pw.SizedBox(width: 2),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1.5),
                  child: _text(unit, size: 7.5, color: _Palette.textTertiary),
                ),
              ],
            ],
          ),
        ],
      ),
    );

/// Lays out [tiles] in rows of [perRow], each cell an equal Expanded.
pw.Widget _grid(List<pw.Widget> tiles, {int perRow = 3, double gap = 8}) {
  final rows = <pw.Widget>[];
  for (var i = 0; i < tiles.length; i += perRow) {
    final cells = <pw.Widget>[];
    for (var j = 0; j < perRow; j++) {
      if (j > 0) cells.add(pw.SizedBox(width: gap));
      final idx = i + j;
      cells.add(pw.Expanded(child: idx < tiles.length ? tiles[idx] : pw.SizedBox()));
    }
    if (rows.isNotEmpty) rows.add(pw.SizedBox(height: gap));
    rows.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: cells));
  }
  return pw.Column(children: rows);
}

pw.Widget _pill(String label, PdfColor color, PdfColor bg) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: _text(label, size: 8.5, color: color, bold: true, letterSpacing: 0.4),
    );

pw.Widget _dot(PdfColor color, {double size = 8}) => pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
    );

RiskLevel _levelForScore(num score) {
  if (score < 30) return RiskLevel.safe;
  if (score < 60) return RiskLevel.moderate;
  if (score < 80) return RiskLevel.high;
  return RiskLevel.critical;
}

PdfColor _riskColor(RiskLevel l) {
  switch (l) {
    case RiskLevel.safe:
      return _Palette.riskSafe;
    case RiskLevel.moderate:
      return _Palette.riskModerate;
    case RiskLevel.high:
      return _Palette.riskHigh;
    case RiskLevel.critical:
      return _Palette.riskCritical;
  }
}

PdfColor _riskBg(RiskLevel l) {
  switch (l) {
    case RiskLevel.safe:
      return _Palette.riskSafeBg;
    case RiskLevel.moderate:
      return _Palette.riskModerateBg;
    case RiskLevel.high:
      return _Palette.riskHighBg;
    case RiskLevel.critical:
      return _Palette.riskCriticalBg;
  }
}

// ── Page furniture ────────────────────────────────────────────────────────────

pw.Widget _header(HealthReportData d, pw.Context ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 0.8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _dot(_Palette.primary, size: 9),
          pw.SizedBox(width: 6),
          _text('PRANA', size: 13, color: _Palette.primary, bold: true,
              letterSpacing: 1.5),
          pw.SizedBox(width: 8),
          _text('Health Report', size: 10, color: _Palette.textSecondary),
          pw.Spacer(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _text(d.profile.name, size: 9.5, bold: true),
              _text(d.rangeLabel, size: 7.5, color: _Palette.textTertiary),
            ],
          ),
        ],
      ),
    );

pw.Widget _footer(pw.Context ctx) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _Palette.borderLight, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text('Generated on-device - private to this phone', size: 7.5,
              color: _Palette.textTertiary),
          _text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', size: 7.5,
              color: _Palette.textTertiary),
        ],
      ),
    );

// ── Sections ──────────────────────────────────────────────────────────────────

String _periodText(HealthReportData d) {
  if (!d.hasDays) return 'No recorded days in this range yet';
  final f = DateFormat('d MMM');
  final fy = DateFormat('d MMM yyyy');
  final sameYear = d.from.year == d.to.year;
  final fromStr = sameYear ? f.format(d.from) : fy.format(d.from);
  final toStr = fy.format(d.to);
  final unit = d.daysRecorded == 1 ? 'day' : 'days';
  return '$fromStr to $toStr - ${d.daysRecorded} $unit recorded';
}

pw.Widget _hero(HealthReportData d) {
  final gen = DateFormat('d MMM yyyy, HH:mm').format(d.generatedAt);
  return pw.Container(
    width: _contentWidth,
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: _Palette.primary,
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text('DOCTOR REPORT', size: 8, color: _Palette.mint, bold: true,
            letterSpacing: 1.6),
        pw.SizedBox(height: 6),
        _text('Health summary', size: 21, color: PdfColors.white, bold: true),
        pw.SizedBox(height: 7),
        _text('Prepared for ${d.profile.name}  -  ${d.rangeLabel}',
            size: 10.5, color: _Palette.mint),
        pw.SizedBox(height: 3),
        _text('${_periodText(d)}  -  generated $gen',
            size: 8.5, color: _Palette.mint),
      ],
    ),
  );
}

pw.Widget _demoBanner() => pw.Container(
      width: _contentWidth,
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _Palette.mint,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _dot(_Palette.primary, size: 8),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _text(
              'Demo mode was on when this report was generated. The readings '
              'shown are simulated and are not written to saved history.',
              size: 9,
              color: _Palette.primaryDark,
            ),
          ),
        ],
      ),
    );

pw.Widget _patientCard(HealthReportData d) {
  final p = d.profile;
  final pairs = <pw.Widget>[
    _pair('Name', p.name),
    _pair('Age / Sex', '${p.age} yrs  -  ${p.gender}'),
    _pair('Blood group', p.bloodGroup.isEmpty ? '-' : p.bloodGroup),
    _pair('Height / Weight',
        '${p.heightCm.toStringAsFixed(0)} cm  -  ${p.weightKg.toStringAsFixed(0)} kg'),
    _pair('BMI', d.bmi == null ? '-' : d.bmi!.toStringAsFixed(1)),
    _pair('Vulnerable profile', p.isVulnerableProfile ? 'Yes' : 'No'),
  ];
  final contact = d.primaryContact;
  if (contact != null) {
    pairs.add(_pair('Emergency contact',
        '${contact.name}${contact.relation.isEmpty ? '' : ' (${contact.relation})'}'));
    pairs.add(_pair('Contact phone', contact.phone.isEmpty ? '-' : contact.phone));
  }
  final conditions =
      p.medicalConditions.isEmpty ? 'None on record' : p.medicalConditions.join(', ');
  return _card(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pairGrid(pairs),
        pw.SizedBox(height: 2),
        _pair('Medical conditions', conditions),
      ],
    ),
  );
}

pw.Widget _baselineCard(HealthReportData d) {
  final b = d.baseline;
  final cal = DateFormat('d MMM yyyy').format(b.lastCalibrated);
  final pairs = <pw.Widget>[
    _pair('Normal heart rate',
        '${b.normalHrMin.toStringAsFixed(0)} - ${b.normalHrMax.toStringAsFixed(0)} BPM'),
    _pair('Resting heart rate', '${b.restingHrBaseline.toStringAsFixed(0)} BPM'),
    _pair('Blood oxygen floor', '${b.normalSpo2Min.toStringAsFixed(0)} %'),
    _pair('Normal body temp',
        '${b.normalTempMin.toStringAsFixed(1)} - ${b.normalTempMax.toStringAsFixed(1)} C'),
    _pair('Sleep goal', '${b.sleepGoalHours.toStringAsFixed(1)} h'),
    _pair('Readings learned', Fmt.count(b.totalReadingsLearned)),
  ];
  return _card(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pairGrid(pairs),
        pw.SizedBox(height: 2),
        _text(
          'Baseline last calibrated $cal. The trends below are read against '
          'these personal normals, not textbook population ranges.',
          size: 8,
          color: _Palette.textTertiary,
        ),
      ],
    ),
  );
}

pw.Widget _summaryGrid(HealthReportData d) {
  final avgLevel = _levelForScore(d.avgRiskScore);
  final peakLevel = _levelForScore(d.peakRiskScore);
  final tiles = <pw.Widget>[
    _kpi('Avg heart rate', d.avgHeartRate.toStringAsFixed(0),
        unit: 'BPM', accent: _Palette.heartRate),
    _kpi('Peak heart rate', d.peakHeartRate.toStringAsFixed(0),
        unit: 'BPM', accent: _Palette.heartRate),
    _kpi('Min blood oxygen', d.minSpo2 > 0 ? d.minSpo2.toStringAsFixed(0) : '-',
        unit: '%', accent: _Palette.spo2),
    _kpi('Peak temp',
        d.peakTemperature > 0 ? d.peakTemperature.toStringAsFixed(1) : '-',
        unit: 'C', accent: _Palette.temperature),
    _kpi('Avg risk', d.avgRiskScore.toStringAsFixed(0),
        unit: '/100', accent: _riskColor(avgLevel)),
    _kpi('Peak risk', '${d.peakRiskScore}',
        unit: '/100', accent: _riskColor(peakLevel)),
    _kpi('Avg steps / day', Fmt.count(d.avgSteps), accent: _Palette.activity),
    _kpi('Total steps', Fmt.count(d.totalSteps), accent: _Palette.activity),
    _kpi('Alerts logged', '${d.alertTotal}', accent: _Palette.riskModerate),
  ];
  return _grid(tiles, perRow: 3);
}

List<pw.Widget> _trendCards(HealthReportData d) {
  final cards = <pw.Widget>[];
  final b = d.baseline;

  List<DailySummary> where(bool Function(DailySummary) p) =>
      d.days.where(p).toList(growable: false);

  final hrDays = where((s) => s.avgHeartRate > 0);
  if (hrDays.isNotEmpty) {
    cards.add(_chartCard(
      title: 'Heart rate',
      subtitle: 'Daily average & peak - BPM',
      color: _Palette.heartRate,
      primary: hrDays.map((s) => s.avgHeartRate).toList(),
      secondary: hrDays.map((s) => s.peakHeartRate).toList(),
      dates: hrDays.map((s) => s.date).toList(),
      bandLow: b.normalHrMin,
      bandHigh: b.normalHrMax,
      legend:
          'Solid = daily average, faint = daily peak. Shaded = personal normal '
          '${b.normalHrMin.toStringAsFixed(0)}-${b.normalHrMax.toStringAsFixed(0)} BPM.',
    ));
  }

  final spo2Days = where((s) => s.minSpo2 > 0);
  if (spo2Days.isNotEmpty) {
    cards.add(_chartCard(
      title: 'Blood oxygen',
      subtitle: 'Daily minimum - %',
      color: _Palette.spo2,
      primary: spo2Days.map((s) => s.minSpo2).toList(),
      dates: spo2Days.map((s) => s.date).toList(),
      bandLow: b.normalSpo2Min,
      bandHigh: 100,
      legend:
          'Line = lowest reading each day. Shaded = healthy zone at or above '
          '${b.normalSpo2Min.toStringAsFixed(0)}%.',
    ));
  }

  final tempDays = where((s) => s.peakTemperature > 0);
  if (tempDays.isNotEmpty) {
    cards.add(_chartCard(
      title: 'Body temperature',
      subtitle: 'Daily peak - C',
      color: _Palette.temperature,
      primary: tempDays.map((s) => s.peakTemperature).toList(),
      dates: tempDays.map((s) => s.date).toList(),
      bandLow: b.normalTempMin,
      bandHigh: b.normalTempMax,
      legend:
          'Line = highest reading each day. Shaded = personal normal '
          '${b.normalTempMin.toStringAsFixed(1)}-${b.normalTempMax.toStringAsFixed(1)} C.',
    ));
  }

  // Risk always has a value; plot every recorded day.
  cards.add(_chartCard(
    title: 'PRANA risk score',
    subtitle: 'Daily average & peak - /100',
    color: _Palette.riskModerate,
    primary: d.days.map((s) => s.avgRiskScore).toList(),
    secondary: d.days.map((s) => s.peakRiskScore.toDouble()).toList(),
    dates: d.days.map((s) => s.date).toList(),
    bandLow: 0,
    bandHigh: 30,
    bandColor: _Palette.riskSafe,
    legend: 'Solid = daily average, faint = daily peak. Shaded = safe zone (<30).',
  ));

  // Steps as daily bars.
  cards.add(_chartCard(
    title: 'Steps',
    subtitle: 'Daily total',
    color: _Palette.activity,
    primary: d.days.map((s) => s.steps.toDouble()).toList(),
    dates: d.days.map((s) => s.date).toList(),
    bars: true,
    legend: 'Bars = steps recorded each day.',
  ));

  return cards;
}

pw.Widget _chartCard({
  required String title,
  required String subtitle,
  required PdfColor color,
  required List<double> primary,
  required List<DateTime> dates,
  List<double>? secondary,
  double? bandLow,
  double? bandHigh,
  PdfColor? bandColor,
  bool bars = false,
  required String legend,
}) {
  final f = DateFormat('d MMM');
  final startLabel = dates.isEmpty ? '' : f.format(dates.first);
  final endLabel = dates.isEmpty ? '' : f.format(dates.last);
  final middle = dates.length == 1 ? 'single day' : '${dates.length} days';
  return _card(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _dot(color, size: 8),
            pw.SizedBox(width: 6),
            _text(title, size: 11, bold: true),
            pw.Spacer(),
            _text(subtitle, size: 8, color: _Palette.textTertiary),
          ],
        ),
        pw.SizedBox(height: 8),
        _chartCanvas(
          primary: primary,
          secondary: secondary,
          color: color,
          bandLow: bandLow,
          bandHigh: bandHigh,
          bandColor: bandColor,
          bars: bars,
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _text(startLabel, size: 7, color: _Palette.textTertiary),
            _text(middle, size: 7, color: _Palette.textTertiary),
            _text(endLabel, size: 7, color: _Palette.textTertiary),
          ],
        ),
        pw.SizedBox(height: 4),
        _text(legend, size: 7, color: _Palette.textTertiary),
      ],
    ),
  );
}

/// The themed vector chart. PDF's canvas origin is bottom-left with y going up,
/// so — unlike the Flutter painter this mirrors — higher values map to larger y
/// with no inversion.
pw.Widget _chartCanvas({
  required List<double> primary,
  required PdfColor color,
  List<double>? secondary,
  double? bandLow,
  double? bandHigh,
  PdfColor? bandColor,
  bool bars = false,
  double height = _chartHeight,
}) {
  return pw.SizedBox(
    width: _chartWidth,
    height: height,
    child: pw.CustomPaint(
      size: PdfPoint(_chartWidth, height),
      painter: (canvas, size) {
        final w = size.x;
        final h = size.y;
        if (primary.isEmpty) return;

        double minY;
        double maxY;
        if (bars) {
          minY = 0;
          maxY = primary.reduce(math.max);
          if (maxY <= 0) maxY = 1;
          maxY *= 1.15;
        } else {
          final all = <double>[
            ...primary,
            ...?secondary,
          ];
          minY = all.reduce(math.min);
          maxY = all.reduce(math.max);
          if (bandLow != null) minY = math.min(minY, bandLow);
          if (bandHigh != null) maxY = math.max(maxY, bandHigh);
          final span = maxY - minY;
          final pad = span <= 0 ? (maxY.abs() * 0.1 + 1) : span * 0.12;
          minY -= pad;
          maxY += pad;
        }
        final range = (maxY - minY) == 0 ? 1.0 : (maxY - minY);
        double yOf(double v) => ((v - minY) / range) * h;
        double xOf(int i, int n) => n <= 1 ? w / 2 : (i / (n - 1)) * w;

        // Grid.
        canvas
          ..setStrokeColor(_Palette.borderLight)
          ..setLineWidth(0.6);
        for (var i = 1; i <= 3; i++) {
          final y = h * (i / 4);
          canvas.drawLine(0, y, w, y);
        }
        canvas.strokePath();

        // Baseline band.
        if (bandLow != null && bandHigh != null) {
          final top = yOf(bandHigh);
          final bot = yOf(bandLow);
          canvas
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(fillOpacity: 0.16))
            ..setFillColor(bandColor ?? _Palette.mintDeep)
            ..drawRect(0, bot, w, top - bot)
            ..fillPath()
            ..restoreContext()
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(strokeOpacity: 0.45))
            ..setStrokeColor(bandColor ?? _Palette.mintDeep)
            ..setLineWidth(0.7)
            ..drawLine(0, top, w, top)
            ..drawLine(0, bot, w, bot)
            ..strokePath()
            ..restoreContext();
        }

        if (bars) {
          final n = primary.length;
          final slot = w / n;
          canvas
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(fillOpacity: 0.55))
            ..setFillColor(color);
          for (var i = 0; i < n; i++) {
            final bx = slot * i + slot * 0.22;
            final bw = slot * 0.56;
            final bh = yOf(primary[i]);
            canvas.drawRect(bx, 0, bw, bh <= 0.5 ? 0.5 : bh);
          }
          canvas
            ..fillPath()
            ..restoreContext();
          return;
        }

        final n = primary.length;

        // Secondary (peak) line — faint, drawn first so it sits behind.
        if (secondary != null && secondary.length == primary.length) {
          canvas
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(strokeOpacity: 0.4))
            ..setStrokeColor(color)
            ..setLineWidth(1.1)
            ..setLineCap(PdfLineCap.round)
            ..setLineJoin(PdfLineJoin.round);
          _pathThrough(canvas, secondary, xOf, yOf);
          canvas
            ..strokePath()
            ..restoreContext();
        }

        // Primary area wash.
        if (n >= 2) {
          canvas
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(fillOpacity: 0.14))
            ..setFillColor(color)
            ..moveTo(xOf(0, n), 0)
            ..lineTo(xOf(0, n), yOf(primary[0]));
          for (var i = 0; i < n - 1; i++) {
            final x0 = xOf(i, n);
            final y0 = yOf(primary[i]);
            final x1 = xOf(i + 1, n);
            final y1 = yOf(primary[i + 1]);
            final midX = x0 + (x1 - x0) / 2;
            canvas.curveTo(midX, y0, midX, y1, x1, y1);
          }
          canvas
            ..lineTo(xOf(n - 1, n), 0)
            ..fillPath()
            ..restoreContext();
        }

        // Primary line.
        canvas
          ..setStrokeColor(color)
          ..setLineWidth(1.8)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        _pathThrough(canvas, primary, xOf, yOf);
        canvas.strokePath();

        // End dot.
        final lx = xOf(n - 1, n);
        final ly = yOf(primary[n - 1]);
        canvas
          ..setFillColor(_Palette.surface)
          ..drawEllipse(lx, ly, 3.2, 3.2)
          ..fillPath()
          ..setFillColor(color)
          ..drawEllipse(lx, ly, 2.1, 2.1)
          ..fillPath();
      },
    ),
  );
}

/// Builds a mid-point-smoothed path through [vals]. Leaves it as the current
/// path for the caller to stroke.
void _pathThrough(
  PdfGraphics canvas,
  List<double> vals,
  double Function(int, int) xOf,
  double Function(double) yOf,
) {
  final n = vals.length;
  if (n == 1) {
    final x = xOf(0, 1);
    final y = yOf(vals[0]);
    canvas
      ..moveTo(x - 5, y)
      ..lineTo(x + 5, y);
    return;
  }
  canvas.moveTo(xOf(0, n), yOf(vals[0]));
  for (var i = 0; i < n - 1; i++) {
    final x0 = xOf(i, n);
    final y0 = yOf(vals[i]);
    final x1 = xOf(i + 1, n);
    final y1 = yOf(vals[i + 1]);
    final midX = x0 + (x1 - x0) / 2;
    canvas.curveTo(midX, y0, midX, y1, x1, y1);
  }
}

pw.Widget _tableWidget(HealthReportData d) {
  final f = DateFormat('d MMM');
  final headers = <String>[
    'Date',
    'Rdg',
    'HR avg/pk',
    'SpO2',
    'Temp',
    'Risk avg/pk',
    'Steps',
    'Alerts',
    'Level',
  ];
  final rows = d.days
      .map((s) => <String>[
            f.format(s.date),
            '${s.readings}',
            '${s.avgHeartRate.toStringAsFixed(0)}/${s.peakHeartRate.toStringAsFixed(0)}',
            s.minSpo2 > 0 ? s.minSpo2.toStringAsFixed(0) : '-',
            s.peakTemperature > 0 ? s.peakTemperature.toStringAsFixed(1) : '-',
            '${s.avgRiskScore.toStringAsFixed(0)}/${s.peakRiskScore}',
            Fmt.count(s.steps),
            '${s.alertCount}',
            s.peakLevel.displayName,
          ])
      .toList();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.all(color: _Palette.borderLight, width: 0.5),
    headerStyle: _ts(size: 8, color: PdfColors.white, bold: true),
    headerDecoration: pw.BoxDecoration(color: _Palette.primary),
    headerHeight: 18,
    cellHeight: 15,
    cellStyle: _ts(size: 8),
    headerAlignment: pw.Alignment.centerLeft,
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.5),
      1: const pw.FlexColumnWidth(0.8),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FlexColumnWidth(0.9),
      4: const pw.FlexColumnWidth(1.0),
      5: const pw.FlexColumnWidth(1.5),
      6: const pw.FlexColumnWidth(1.2),
      7: const pw.FlexColumnWidth(0.9),
      8: const pw.FlexColumnWidth(1.4),
    },
  );
}

pw.Widget _noDaysCard(HealthReportData d) {
  final tail = d.isDemo
      ? 'Demo mode does not write to saved history, so run PRANA on the real '
          'band to start building a history a doctor can review.'
      : 'Keep the band connected across the day and the daily trends and table '
          'will fill in automatically.';
  return _card(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text('No recorded days in this range yet.', size: 11, bold: true),
        pw.SizedBox(height: 4),
        _text(tail, size: 9, color: _Palette.textSecondary, lineSpacing: 1.5),
      ],
    ),
  );
}

pw.Widget _snapshotCard(HealthReportData d) {
  if (!d.hasLiveData) {
    return _card(
      child: _text(
        'No band connected, so there is no live snapshot to include. Connect '
        'the PRANA band on the Vitals screen to capture the current heart '
        'rate, blood oxygen and temperature.',
        size: 9.5,
        color: _Palette.textSecondary,
        lineSpacing: 1.5,
      ),
    );
  }

  final h = d.current;
  final r = d.currentRisk;
  final captured = DateFormat('d MMM yyyy, HH:mm').format(h.timestamp);
  final children = <pw.Widget>[
    _grid([
      _kpi('Heart rate', h.heartRate.toStringAsFixed(0),
          unit: 'BPM', accent: _Palette.heartRate),
      _kpi('Blood oxygen', h.spo2.toStringAsFixed(0),
          unit: '%', accent: _Palette.spo2),
      _kpi('Body temp', h.bodyTemperature.toStringAsFixed(1),
          unit: 'C', accent: _Palette.temperature),
    ], perRow: 3),
    pw.SizedBox(height: 10),
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _pill('RISK ${r.overallScore}/100 - ${r.level.displayName}',
            _riskColor(r.level), _riskBg(r.level)),
        pw.Spacer(),
        _text('Captured $captured', size: 8, color: _Palette.textTertiary),
      ],
    ),
  ];

  if (d.hrPoints.length >= 2) {
    children.add(pw.SizedBox(height: 12));
    children.add(_text('Recent live heart rate (${d.hrPoints.length} readings)',
        size: 8, color: _Palette.textTertiary));
    children.add(pw.SizedBox(height: 6));
    children.add(_chartCanvas(
      primary: d.hrPoints.map((p) => p.value).toList(),
      color: _Palette.heartRate,
      height: 62,
    ));
  }

  if (d.activeAlerts.isNotEmpty) {
    final titles = d.activeAlerts.take(3).map((a) => a.title).join('; ');
    children.add(pw.SizedBox(height: 10));
    children.add(_text(
      '${d.activeAlerts.length} active alert${d.activeAlerts.length == 1 ? '' : 's'} this session: $titles',
      size: 8,
      color: _Palette.riskModerate,
    ));
  }

  return _card(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    ),
  );
}

pw.Widget _disclaimerCard() => _card(
      color: _Palette.background,
      border: _Palette.border,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text('About this report', size: 9, bold: true,
              color: _Palette.textSecondary),
          pw.SizedBox(height: 3),
          _text(
            'PRANA is a wellness aid. This report was generated on-device from '
            'consumer-grade wearable estimates and a personal learned baseline. '
            'It is not a diagnostic device and does not replace clinical '
            'measurement or professional medical judgement. Readings can be '
            'affected by sensor placement, motion and skin contact.',
            size: 8,
            color: _Palette.textTertiary,
            lineSpacing: 1.6,
          ),
        ],
      ),
    );
