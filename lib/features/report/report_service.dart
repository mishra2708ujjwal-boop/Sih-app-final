import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'health_report_data.dart';
import 'report_pdf_builder.dart';

/// Generates the doctor report PDF and writes it to a shareable location.
///
/// Kept off the UI so the screen just awaits a path. The share/open steps go
/// through [FileSharer] (a native MethodChannel), mirroring the emergency
/// dispatcher's degrade-quietly pattern.
class ReportService {
  const ReportService();

  /// Builds the PDF for [data] and writes it to the temporary directory, whose
  /// files are exposed to the FileProvider. Returns the absolute file path.
  Future<String> generateAndSave(HealthReportData data) async {
    final Uint8List bytes = await buildHealthReportPdf(data);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(data.generatedAt);
    final file = File(p.join(dir.path, 'prana_health_report_$stamp.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// Thin Dart wrapper over the native `prana/files` MethodChannel
/// (see android/.../MainActivity.kt). On a platform without the channel or when
/// the OS refuses, each call degrades quietly to `false` rather than throwing.
class FileSharer {
  static const MethodChannel _channel = MethodChannel('prana/files');

  const FileSharer();

  /// Opens the system share sheet for the file at [path]. [mime] defaults to
  /// PDF (the doctor report); other callers pass their own (e.g. `text/csv`).
  /// Returns whether the chooser was launched.
  Future<bool> shareFile(
    String path, {
    String mime = 'application/pdf',
    String? subject,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        'mime': mime,
        'subject': ?subject,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the file at [path] in a suitable viewer for its [mime] type
  /// (defaults to a PDF viewer). Returns whether a viewer was launched.
  Future<bool> openFile(String path, {String mime = 'application/pdf'}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFile', {
        'path': path,
        'mime': mime,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
