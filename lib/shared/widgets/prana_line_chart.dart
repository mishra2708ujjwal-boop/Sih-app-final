import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/format.dart';
import 'app_card.dart';
import 'empty_state.dart';
import 'status_pill.dart';

class ChartDataPoint {
  final DateTime time;
  final double value;

  const ChartDataPoint({required this.time, required this.value});
}

/// A line chart over one metric, with the user's learned normal range shaded
/// behind it.
///
/// The axis labels are derived from the points' own timestamps. The previous
/// version printed a fixed "24h ago" caption under buffers that hold about a
/// minute of readings, which made a live stream look like a day of history.
class PranaLineChart extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;

  /// The shaded band. Usually the learned baseline; for a risk chart it is the
  /// range that counts as safe.
  final double baselineMin;
  final double baselineMax;

  final String unit;
  final Color lineColor;
  final Color? areaColor;
  final double height;
  final bool showBaselineBand;
  final String title;

  /// What the shaded band means, for the legend. Defaults to the baseline
  /// wording; pass e.g. 'Safe zone' when the band is not a personal baseline.
  final String bandLabel;

  /// Number of decimals on the "now" figure. Risk scores want none, body
  /// temperature wants one.
  final int valueDecimals;

  const PranaLineChart({
    super.key,
    required this.dataPoints,
    required this.baselineMin,
    required this.baselineMax,
    this.unit = '',
    this.lineColor = AppColors.primary,
    this.areaColor,
    this.height = 170.0,
    this.showBaselineBand = true,
    this.title = '',
    this.bandLabel = 'Your normal range',
    this.valueDecimals = 1,
  });

  @override
  Widget build(BuildContext context) {
    // One point cannot be drawn as a line, and an empty buffer has nothing to
    // say at all — both get a stated waiting state rather than a blank canvas.
    if (dataPoints.length < 2) {
      return AppCard(
        child: EmptyState(
          icon: Icons.show_chart_rounded,
          iconColor: lineColor,
          title: dataPoints.isEmpty ? 'No readings yet' : 'Collecting readings',
          subtitle: dataPoints.isEmpty
              ? 'This chart fills in as your sensor streams.'
              : 'One reading in so far. The line appears with the second.',
          compact: true,
        ),
      );
    }

    final latestValue = dataPoints.last.value;
    final isWithinBaseline =
        latestValue >= baselineMin && latestValue <= baselineMax;
    final deviation = latestValue > baselineMax
        ? latestValue - baselineMax
        : latestValue - baselineMin;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppSpacing.hGapXs,
                Text(
                  '${latestValue.toStringAsFixed(valueDecimals)}'
                  '${unit.isEmpty ? '' : ' $unit'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.metricSmall.copyWith(color: lineColor),
                ),
              ],
            ),
            AppSpacing.gapXs,
            // The pill and the legend wrap rather than share one Row — "Within
            // baseline 60–100 BPM" clipped at 360dp when they didn't.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  label: isWithinBaseline
                      ? 'Inside ${baselineMin.toStringAsFixed(0)}'
                          '–${baselineMax.toStringAsFixed(0)}'
                          '${unit.isEmpty ? '' : ' $unit'}'
                      : '${deviation > 0 ? '+' : ''}'
                          '${deviation.toStringAsFixed(valueDecimals)}'
                          '${unit.isEmpty ? '' : ' $unit'} outside',
                  color: isWithinBaseline
                      ? AppColors.riskSafe
                      : AppColors.riskHigh,
                  backgroundColor: isWithinBaseline
                      ? AppColors.riskSafeBg
                      : AppColors.riskHighBg,
                  dense: true,
                ),
                if (showBaselineBand)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.mintDeep.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AppSpacing.hGapXxs,
                      Text(bandLabel, style: AppTypography.bodySmall),
                    ],
                  ),
              ],
            ),
            AppSpacing.gapSm,
          ],
          RepaintBoundary(
            child: SizedBox(
              height: height,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ChartPainter(
                  dataPoints: dataPoints,
                  baselineMin: baselineMin,
                  baselineMax: baselineMax,
                  lineColor: lineColor,
                  areaColor: areaColor ?? lineColor.withValues(alpha: 0.12),
                  showBaselineBand: showBaselineBand,
                ),
              ),
            ),
          ),
          AppSpacing.gapXs,
          Row(
            children: [
              Flexible(
                child: Text(
                  Fmt.ago(dataPoints.first.time),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'now',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartDataPoint> dataPoints;
  final double baselineMin;
  final double baselineMax;
  final Color lineColor;
  final Color areaColor;
  final bool showBaselineBand;

  _ChartPainter({
    required this.dataPoints,
    required this.baselineMin,
    required this.baselineMax,
    required this.lineColor,
    required this.areaColor,
    required this.showBaselineBand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2 || size.width <= 0 || size.height <= 0) return;

    var minY = dataPoints.map((e) => e.value).reduce(min);
    var maxY = dataPoints.map((e) => e.value).reduce(max);

    // Pad by a fraction of the span rather than by a percentage of the value:
    // scaling by 0.95/1.05 collapsed to nothing when the values sat near zero,
    // which is exactly where a risk chart lives.
    if (showBaselineBand) {
      minY = min(minY, baselineMin);
      maxY = max(maxY, baselineMax);
    }
    final span = maxY - minY;
    final pad = span <= 0 ? 1.0 : span * 0.12;
    minY -= pad;
    maxY += pad;

    double yOf(double value) =>
        size.height - ((value - minY) / (maxY - minY)) * size.height;
    double xOf(int index) => (index / (dataPoints.length - 1)) * size.width;

    // 1. Grid.
    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. The shaded band.
    if (showBaselineBand) {
      final top = yOf(baselineMax);
      final bottom = yOf(baselineMin);
      canvas.drawRect(
        Rect.fromLTRB(0, top, size.width, bottom),
        Paint()..color = AppColors.mintDeep.withValues(alpha: 0.16),
      );
      final edge = Paint()
        ..color = AppColors.mintDeep.withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, top), Offset(size.width, top), edge);
      canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), edge);
    }

    // 3. Smoothed path plus its gradient wash.
    final path = Path();
    final fill = Path();
    final first = Offset(xOf(0), yOf(dataPoints[0].value));
    path.moveTo(first.dx, first.dy);
    fill.moveTo(first.dx, size.height);
    fill.lineTo(first.dx, first.dy);

    for (var i = 0; i < dataPoints.length - 1; i++) {
      final p0 = Offset(xOf(i), yOf(dataPoints[i].value));
      final p1 = Offset(xOf(i + 1), yOf(dataPoints[i + 1].value));
      final midX = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fill.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    fill.lineTo(xOf(dataPoints.length - 1), size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.20),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. The live end dot, ringed in the card colour so it reads on the wash.
    final last = Offset(
      xOf(dataPoints.length - 1),
      yOf(dataPoints.last.value),
    );
    canvas.drawCircle(last, 6.5, Paint()..color = AppColors.surface);
    canvas.drawCircle(last, 4.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    if (!identical(old.dataPoints, dataPoints)) return true;
    return old.baselineMin != baselineMin ||
        old.baselineMax != baselineMax ||
        old.lineColor != lineColor ||
        old.showBaselineBand != showBaselineBand;
  }
}
