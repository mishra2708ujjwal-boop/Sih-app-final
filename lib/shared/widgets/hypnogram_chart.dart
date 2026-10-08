import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/format.dart';
import 'app_card.dart';

/// The four sleep stages, in the order a hypnogram stacks them — lightest at the
/// top, deepest at the bottom.
///
/// The palette is a violet ramp rather than the old navy/blue/red mix, which
/// read as three unrelated charts once the app moved to cream. Awake is amber,
/// not red: waking up in the night is normal, and red would imply otherwise.
enum SleepStage {
  awake(0, 'Awake', Color(0xFFD99518)),
  rem(3, 'REM', Color(0xFF9A87D4)),
  light(1, 'Light', Color(0xFF6F5FB0)),
  deep(2, 'Deep', Color(0xFF453A73));

  /// The code used in [SleepReading.hypnogramStages].
  final int code;
  final String label;
  final Color color;

  const SleepStage(this.code, this.label, this.color);

  static SleepStage? fromCode(int code) {
    for (final s in SleepStage.values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Stepped hypnogram — one lane per stage, with the night's path drawn across
/// them.
///
/// Replaces the old bar chart, where stage was encoded as bar *height* and so
/// couldn't be read without the legend. Lanes make the shape of the night
/// legible: you can see a deep block early and fragmentation late.
///
/// [startTime] and [totalMinutes] are required rather than defaulted, because
/// the previous version printed a fixed "11:00 PM / 03:30 AM / 07:00 AM" axis
/// under whatever data it was given.
class HypnogramChart extends StatelessWidget {
  /// Stage codes in time order. See [SleepStage.code].
  final List<int> stages;

  /// When the recorded sleep began.
  final DateTime startTime;

  /// Total length of the recording, used for the closing axis label.
  final int totalMinutes;

  final double height;

  const HypnogramChart({
    super.key,
    required this.stages,
    required this.startTime,
    required this.totalMinutes,
    this.height = 132.0,
  });

  @override
  Widget build(BuildContext context) {
    final endTime = startTime.add(Duration(minutes: totalMinutes));
    final midTime = startTime.add(Duration(minutes: totalMinutes ~/ 2));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sleep architecture', style: AppTypography.titleMedium),
          const SizedBox(height: 2),
          Text(
            'How the night moved between stages',
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.gapSm,
          if (stages.isEmpty)
            SizedBox(
              height: height,
              child: Center(
                child: Text(
                  'No stage data for this night',
                  style: AppTypography.bodySmall,
                ),
              ),
            )
          else
            SizedBox(
              height: height,
              child: Row(
                children: [
                  // Lane labels live outside the painter so they scale with the
                  // user's text size instead of being baked into the canvas.
                  SizedBox(
                    width: 42,
                    child: Column(
                      children: [
                        for (final stage in SleepStage.values)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                stage.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelCaps.copyWith(
                                  fontSize: 9,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _HypnogramPainter(stages: stages),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          AppSpacing.gapXs,
          Padding(
            // Align the axis with the painter, not the lane labels.
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Fmt.clock(startTime), style: AppTypography.bodySmall),
                Text(Fmt.clock(midTime), style: AppTypography.bodySmall),
                Text(Fmt.clock(endTime), style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  final List<int> stages;

  _HypnogramPainter({required this.stages});

  @override
  void paint(Canvas canvas, Size size) {
    if (stages.isEmpty || size.width <= 0 || size.height <= 0) return;

    final laneCount = SleepStage.values.length;
    final laneHeight = size.height / laneCount;
    final bucketWidth = size.width / stages.length;
    // The drawn segment is thinner than its lane so adjacent lanes stay
    // visually separate at small chart heights.
    final barHeight = (laneHeight * 0.46).clamp(4.0, 14.0);
    final radius = Radius.circular(barHeight / 2);

    // Faint lane guides, so an empty lane still reads as a lane.
    final guide = Paint()
      ..color = AppColors.surfaceWell
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < laneCount; i++) {
      final y = laneHeight * (i + 0.5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    double laneCentre(int laneIndex) => laneHeight * (laneIndex + 0.5);

    int? laneOf(int code) {
      final stage = SleepStage.fromCode(code);
      return stage == null ? null : SleepStage.values.indexOf(stage);
    }

    // Vertical connectors first, so the stage blocks paint over their ends.
    final connector = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < stages.length; i++) {
      final from = laneOf(stages[i - 1]);
      final to = laneOf(stages[i]);
      if (from == null || to == null || from == to) continue;
      final x = bucketWidth * i;
      canvas.drawLine(
        Offset(x, laneCentre(from)),
        Offset(x, laneCentre(to)),
        connector,
      );
    }

    // Merge consecutive identical stages into one block, so a long stretch of
    // deep sleep is one bar rather than a dotted line of separate buckets.
    var runStart = 0;
    for (var i = 0; i <= stages.length; i++) {
      final atEnd = i == stages.length;
      if (!atEnd && stages[i] == stages[runStart]) continue;

      final stage = SleepStage.fromCode(stages[runStart]);
      if (stage != null) {
        final lane = SleepStage.values.indexOf(stage);
        final left = bucketWidth * runStart;
        final right = bucketWidth * i;
        final centre = laneCentre(lane);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              left + 1,
              centre - barHeight / 2,
              right - 1,
              centre + barHeight / 2,
            ),
            radius,
          ),
          Paint()..color = stage.color,
        );
      }
      runStart = i;
    }
  }

  @override
  bool shouldRepaint(_HypnogramPainter old) =>
      !identical(old.stages, stages) ||
      old.stages.length != stages.length ||
      _differs(old.stages, stages);

  static bool _differs(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}
