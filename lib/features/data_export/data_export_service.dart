import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ml/vitals_sample_store.dart';
import 'vitals_reading_decoder.dart';

/// Turns the on-device ML sample reservoir into a shareable CSV.
///
/// The samples are stored as normalized 16-feature vectors (the model's real
/// input); this service decodes each back to human units via [DecodedReading]
/// and writes a spreadsheet-friendly CSV to the temporary directory — the same
/// FileProvider-exposed location [ReportService] uses — so it can be opened or
/// shared through the existing `prana/files` channel. Pure Dart, no new deps.
class DataExportService {
  const DataExportService();

  /// Column headers, in output order. The trailing `raw_feature_vector` keeps
  /// the exact model input alongside the decoded values, so the export is
  /// self-verifying.
  static const List<String> columns = [
    'timestamp',
    'heart_rate_bpm',
    'spo2_pct',
    'body_temp_c',
    'activity',
    'hrv_rmssd_ms',
    'hr_trend_bpm_per_min',
    'sleep_hours',
    'sleep_quality',
    'ambient_temp_c',
    'humidity_pct',
    'aqi',
    'heat_index_c',
    'heat_exposure_hrs',
    'raw_feature_vector',
  ];

  /// Build the CSV text for [samples] (oldest-first, as stored). Pure and
  /// synchronous so it is trivially testable.
  String buildCsv(List<VitalsSample> samples) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss');
    final out = StringBuffer()..writeln(columns.map(_escape).join(','));
    for (final s in samples) {
      final d = DecodedReading.fromFeatures(s.features);
      final cells = <String>[
        ts.format(s.at.toLocal()),
        d.heartRateBpm.toStringAsFixed(0),
        d.spo2Pct.toStringAsFixed(0),
        d.bodyTempC.toStringAsFixed(1),
        d.activity,
        d.hrvRmssdMs.toStringAsFixed(0),
        d.hrTrendBpmPerMin.toStringAsFixed(2),
        d.sleepHours.toStringAsFixed(1),
        d.sleepQuality.toStringAsFixed(0),
        d.ambientTempC.toStringAsFixed(1),
        d.humidityPct.toStringAsFixed(0),
        d.aqi.toStringAsFixed(0),
        d.heatIndexC.toStringAsFixed(1),
        d.heatExposureHours.toStringAsFixed(1),
        s.features.map((v) => v.toStringAsFixed(4)).join(' '),
      ];
      out.writeln(cells.map(_escape).join(','));
    }
    return out.toString();
  }

  /// Write the CSV to a shareable temp file named by [generatedAt] and return
  /// the absolute path. Mirrors `ReportService.generateAndSave`.
  Future<String> exportCsv(
    List<VitalsSample> samples, {
    DateTime? generatedAt,
  }) async {
    final csv = buildCsv(samples);
    final dir = await getTemporaryDirectory();
    final stamp =
        DateFormat('yyyyMMdd_HHmm').format(generatedAt ?? DateTime.now());
    final file = File(p.join(dir.path, 'prana_readings_$stamp.csv'));
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  /// RFC-4180 CSV escaping: wrap a field in quotes and double any interior
  /// quote when it contains a comma, quote or newline.
  static String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
