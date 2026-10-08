import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_segmented_control.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../shared/widgets/status_pill.dart';
import 'health_report_data.dart';
import 'report_service.dart';

/// Timeline picker + preview that generates the doctor-shareable PDF.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum _Phase { idle, generating, done, error }

class _ReportScreenState extends State<ReportScreen> {
  ReportRange _range = ReportRange.month;
  _Phase _phase = _Phase.idle;
  String? _savedPath;
  String? _error;

  final _service = const ReportService();
  final _sharer = const FileSharer();

  Future<void> _generate(PranaHealthController c) async {
    setState(() {
      _phase = _Phase.generating;
      _error = null;
    });
    try {
      final data = HealthReportData.fromController(c, range: _range);
      final path = await _service.generateAndSave(data);
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
    final ok = await _sharer.shareFile(path, subject: 'PRANA Health Report');
    if (!ok && mounted) _snack('Could not open the share sheet on this device.');
  }

  Future<void> _open() async {
    final path = _savedPath;
    if (path == null) return;
    final ok = await _sharer.openFile(path);
    if (!ok && mounted) _snack('No PDF viewer found to open the report.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final data = HealthReportData.fromController(controller, range: _range);

    return PranaScaffold(
      title: 'Doctor report',
      subtitle: 'A shareable PDF of the readings PRANA has recorded',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.navClearance,
        ),
        children: [
          FadeSlideIn(
            index: 0,
            child: _rangePicker(),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.isDemo) ...[
            FadeSlideIn(index: 1, child: _demoNotice()),
            const SizedBox(height: AppSpacing.md),
          ],
          FadeSlideIn(index: 2, child: _patientRecap(data)),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(index: 3, child: _includedCard(data)),
          const SizedBox(height: AppSpacing.md),
          FadeSlideIn(index: 4, child: _snapshotRecap(data)),
        ],
      ),
      footer: _footer(controller),
    );
  }

  Widget _rangePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Timeline',
          eyebrow: 'Choose a span',
          dense: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSegmentedControl(
          segments: ReportRange.values.map((r) => r.shortLabel).toList(),
          selectedIndex: ReportRange.values.indexOf(_range),
          onChanged: _phase == _Phase.generating
              ? (_) {}
              : (i) => setState(() {
                    _range = ReportRange.values[i];
                    if (_phase == _Phase.done || _phase == _Phase.error) {
                      _phase = _Phase.idle;
                      _savedPath = null;
                    }
                  }),
        ),
      ],
    );
  }

  Widget _demoNotice() {
    return AppCard(
      color: AppColors.mint.withValues(alpha: 0.5),
      showBorder: false,
      flat: true,
      child: Row(
        children: [
          IconChip(
            icon: Icons.science_rounded,
            color: AppColors.primary,
            background: AppColors.surface,
            size: 30,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Demo mode is on. The report will use simulated readings and note '
              'that on the PDF.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _patientRecap(HealthReportData d) {
    final p = d.profile;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: Icons.person_rounded,
                color: AppColors.primary,
                background: AppColors.primaryContainer,
                size: 38,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: AppTypography.titleMedium),
                    Text(
                      '${p.age} yrs · ${p.gender} · ${p.bloodGroup.isEmpty ? '—' : p.bloodGroup}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.medicalConditions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Conditions: ${p.medicalConditions.join(', ')}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _includedCard(HealthReportData d) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: "What's included",
            eyebrow: 'In the PDF',
            dense: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (d.hasDays)
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Days recorded',
                    value: '${d.daysRecorded}',
                    accent: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Avg heart rate',
                    value: d.avgHeartRate.toStringAsFixed(0),
                    unit: 'BPM',
                    accent: AppColors.heartRate,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Avg risk',
                    value: d.avgRiskScore.toStringAsFixed(0),
                    unit: '/100',
                    accent: AppColors.riskModerate,
                  ),
                ),
              ],
            )
          else
            Text(
              d.isDemo
                  ? 'No saved history yet — demo mode does not record days. The '
                      'PDF will still include patient details, the learned '
                      'baseline and the current snapshot.'
                  : 'No recorded days in this range yet. The PDF will still '
                      'include patient details, the learned baseline and the '
                      'current snapshot; trends fill in as the band records.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Patient details · learned baseline · period summary · daily trend '
            'graphs · daily readings table · current snapshot.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _snapshotRecap(HealthReportData d) {
    if (!d.hasLiveData) {
      return AppCard.well(
        child: Row(
          children: [
            IconChip(
              icon: Icons.sensors_off_rounded,
              color: AppColors.textSecondary,
              background: AppColors.surface,
              size: 30,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'No band connected. The report will note that no live snapshot '
                'was available.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final h = d.current;
    final r = d.currentRisk;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Current snapshot',
                  eyebrow: 'Live now',
                  dense: true,
                ),
              ),
              StatusPill(
                label: '${r.overallScore}/100 ${r.level.displayName}',
                color: r.level.color,
                backgroundColor: r.level.bgColor,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Heart rate',
                  value: h.heartRate.toStringAsFixed(0),
                  unit: 'BPM',
                  accent: AppColors.heartRate,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Blood oxygen',
                  value: h.spo2.toStringAsFixed(0),
                  unit: '%',
                  accent: AppColors.spo2,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Body temp',
                  value: h.bodyTemperature.toStringAsFixed(1),
                  unit: '°C',
                  accent: AppColors.temperature,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(PranaHealthController controller) {
    switch (_phase) {
      case _Phase.generating:
        return _GenerateButton(
          label: 'Generating PDF…',
          busy: true,
          onPressed: null,
        );
      case _Phase.done:
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
                    'Report saved',
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
              onPressed: () => _generate(controller),
              child: const Text('Regenerate'),
            ),
          ],
        );
      case _Phase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Could not generate the report. $_error',
              style: AppTypography.bodySmall.copyWith(color: AppColors.riskCritical),
            ),
            const SizedBox(height: AppSpacing.sm),
            _GenerateButton(
              label: 'Try again',
              onPressed: () => _generate(controller),
            ),
          ],
        );
      case _Phase.idle:
        return _GenerateButton(
          label: 'Generate PDF',
          onPressed: () => _generate(controller),
        );
    }
  }
}

class _GenerateButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const _GenerateButton({
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
          : const Icon(Icons.picture_as_pdf_rounded, size: 20),
      label: Text(label),
    );
  }
}
