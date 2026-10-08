import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_tile.dart';
import '../ml/vitals_sample_store.dart';
import '../report/report_service.dart' show FileSharer;
import 'data_export_service.dart';
import 'vitals_reading_decoder.dart';

/// Shows the calm vitals readings PRANA has recorded on this phone — the exact
/// data its on-device model trains on — and exports them as a shareable CSV.
///
/// Deliberately read-only over the ML store (via a plain [Provider]); the write
/// path is untouched. Mirrors the doctor-report screen's generate → open/share
/// state machine, but the artefact is a decoded per-reading CSV rather than a
/// daily-summary PDF.
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

enum _Phase { idle, generating, done, error }

class _DataExportScreenState extends State<DataExportScreen> {
  final _service = const DataExportService();
  final _sharer = const FileSharer();

  bool _loading = true;
  String? _loadError;
  List<VitalsSample> _samples = const [];

  _Phase _phase = _Phase.idle;
  String? _savedPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // read() (not watch()) — the store is not a Listenable and we load once.
      final store = context.read<VitalsSampleStore>();
      final samples = await store.allSamples();
      if (!mounted) return;
      setState(() {
        _samples = samples;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    setState(() {
      _phase = _Phase.generating;
      _error = null;
    });
    try {
      final path = await _service.exportCsv(_samples);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _savedPath = path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _share() async {
    final path = _savedPath;
    if (path == null) return;
    final ok = await _sharer.shareFile(
      path,
      mime: 'text/csv',
      subject: 'PRANA recorded readings',
    );
    if (!ok && mounted) _snack('Could not open the share sheet on this device.');
  }

  Future<void> _open() async {
    final path = _savedPath;
    if (path == null) return;
    final ok = await _sharer.openFile(path, mime: 'text/csv');
    if (!ok && mounted) _snack('No app found to open a CSV on this device.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PranaScaffold(
      title: 'Recorded readings',
      subtitle: 'The on-device data your model learns from',
      body: _body(),
      footer: (_loading || _loadError != null || _samples.isEmpty)
          ? null
          : _footer(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: EmptyState(
          icon: Icons.storage_rounded,
          title: 'Reading your on-device data',
          subtitle: 'Loading the readings PRANA has recorded on this phone…',
          busy: true,
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.riskCritical,
          title: 'Could not read the data',
          subtitle: _loadError!,
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }
    if (_samples.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: 'No calm readings yet',
          subtitle:
              'PRANA records a reading whenever your vitals are calm and on '
              'baseline. Wear your band for a while and they will appear here, '
              'ready to export.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.navClearance,
      ),
      children: [
        FadeSlideIn(index: 0, child: _introCard()),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(index: 1, child: _statsCard()),
        const SizedBox(height: AppSpacing.md),
        FadeSlideIn(index: 2, child: _previewCard()),
      ],
    );
  }

  Widget _introCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.dataset_rounded,
                color: AppColors.primary,
                background: AppColors.primaryContainer,
                size: 38,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your own recorded data',
                  style: AppTypography.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These are the calm vitals PRANA has recorded on this phone — the '
            'exact readings its on-device model learns your baseline from. '
            'Each is stored as a 16-feature vector; export decodes them back to '
            'real units (heart rate, SpO₂, temperature and more) as a CSV you '
            'can open or share. Nothing here has ever left the device.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    final first = _samples.first.at.toLocal();
    final last = _samples.last.at.toLocal();
    final dayFmt = DateFormat('MMM d');
    return AppCard.well(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Readings',
                  value: '${_samples.length}',
                  accent: AppColors.primary,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'First logged',
                  value: dayFmt.format(first),
                  accent: AppColors.spo2,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Latest',
                  value: dayFmt.format(last),
                  accent: AppColors.heartRate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Calm readings only · recorded on this phone · never uploaded',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    // Newest first, most recent handful — enough to show a judge the shape of
    // the data without turning the screen into a spreadsheet.
    final preview = _samples.reversed.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Latest readings',
          eyebrow: 'Decoded preview',
          dense: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              const _PreviewHeader(),
              const Divider(height: AppSpacing.md),
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.md),
                _PreviewRow(sample: preview[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    switch (_phase) {
      case _Phase.generating:
        return const _ExportButton(
          label: 'Preparing CSV…',
          busy: true,
          onPressed: null,
        );
      case _Phase.done:
        final name = _savedPath?.split(RegExp(r'[\\/]')).last ?? 'readings.csv';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.riskSafe),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _open,
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _export,
              child: const Text('Export again'),
            ),
          ],
        );
      case _Phase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Could not create the CSV. $_error',
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.riskCritical),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ExportButton(label: 'Try again', onPressed: _export),
          ],
        );
      case _Phase.idle:
        return _ExportButton(
          label: 'Export & share CSV',
          onPressed: _export,
        );
    }
  }
}

/// Column labels above the decoded preview rows.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelCaps.copyWith(
      color: AppColors.textTertiary,
      fontSize: 10,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text('When', style: style)),
        Expanded(
          flex: 2,
          child: Text('HR', style: style, textAlign: TextAlign.end),
        ),
        Expanded(
          flex: 2,
          child: Text('SpO₂', style: style, textAlign: TextAlign.end),
        ),
        Expanded(
          flex: 2,
          child: Text('Temp', style: style, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

/// One decoded reading in the preview: when it was captured, plus the three
/// headline vitals in real units.
class _PreviewRow extends StatelessWidget {
  final VitalsSample sample;

  const _PreviewRow({required this.sample});

  @override
  Widget build(BuildContext context) {
    final d = DecodedReading.fromFeatures(sample.features);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            DateFormat('MMM d · HH:mm').format(sample.at.toLocal()),
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        _Metric(
          value: d.heartRateBpm.toStringAsFixed(0),
          unit: 'BPM',
          color: AppColors.heartRate,
        ),
        _Metric(
          value: d.spo2Pct.toStringAsFixed(0),
          unit: '%',
          color: AppColors.spo2,
        ),
        _Metric(
          value: d.bodyTempC.toStringAsFixed(1),
          unit: '°C',
          color: AppColors.temperature,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String unit;
  final Color color;

  const _Metric({required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: AppTypography.labelLarge
                .copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary action, matching the doctor report's generate button.
class _ExportButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const _ExportButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.table_view_rounded, size: 20),
      label: Text(label),
    );
  }
}
