import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/format.dart';
import '../../shared/models/device_info.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/hero_metric_card.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/info_row.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/stat_tile.dart';
import 'emergency_screen.dart';
import 'emergency_service.dart';

/// Live MPU6050 accelerometer trace and fall status.
///
/// Reads the same BLE motion stream every other screen uses — no second
/// connection, no simulated samples. Detection itself is the existing
/// [FallDetectionService]; this page only visualises it and hands a confirmed
/// fall to the existing emergency flow.
class FallDetectionScreen extends StatelessWidget {
  const FallDetectionScreen({super.key});

  // Axis colours come from the existing biometric palette — no new tokens.
  static const Color _xColor = AppColors.heartRate;
  static const Color _yColor = AppColors.activity;
  static const Color _zColor = AppColors.spo2;

  /// Warm wash for the hero when the band is being thrown around. Mint would
  /// read as "all fine" during the exact spike this screen exists to show.
  static const _activeGradient = [Color(0xFFFAE3CE), Color(0xFFEFBE93)];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final device = controller.currentDevice;
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;
    final isConnecting =
        device.connectionState == DeviceConnectionState.connecting;

    return PranaScaffold(
      title: 'Fall detection',
      subtitle: 'Live accelerometer from your band',
      body: !isConnected
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xxs,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              child: AppCard(
                child: EmptyState(
                  icon: Icons.sensors_off_rounded,
                  title: 'Device not connected',
                  subtitle:
                      'Fall detection reads the accelerometer inside your PRANA '
                      'band. With nothing connected there is no motion to watch.',
                  actionLabel: isConnecting ? null : 'Connect device',
                  onAction: isConnecting ? null : controller.startBleScan,
                  busy: isConnecting,
                ),
              ),
            )
          : ValueListenableBuilder<int>(
              // Repaints on each IMU packet without rebuilding other screens.
              valueListenable: controller.motionTick,
              builder: (context, _, child) => _ConnectedBody(
                controller: controller,
                xColor: _xColor,
                yColor: _yColor,
                zColor: _zColor,
                activeGradient: _activeGradient,
              ),
            ),
    );
  }
}

class _ConnectedBody extends StatelessWidget {
  final PranaHealthController controller;
  final Color xColor;
  final Color yColor;
  final Color zColor;
  final List<Color> activeGradient;

  const _ConnectedBody({
    required this.controller,
    required this.xColor,
    required this.yColor,
    required this.zColor,
    required this.activeGradient,
  });

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xxs,
    AppSpacing.md,
    AppSpacing.xl,
  );

  @override
  Widget build(BuildContext context) {
    final history = controller.motionHistory;

    if (history.isEmpty) {
      return const Padding(
        padding: _padding,
        child: AppCard(
          child: EmptyState(
            icon: Icons.sensors_rounded,
            iconColor: AppColors.primary,
            title: 'Waiting for sensor data',
            subtitle:
                'Your band is connected. Accelerometer readings appear here as '
                'soon as the first packet arrives.',
            busy: true,
          ),
        ),
      );
    }

    final latest = history.last;
    final emergencyState = controller.emergencyService.currentState;
    final isFallActive = emergencyState == EmergencyState.countdown ||
        emergencyState == EmergencyState.sosSent;
    final lastFallAt = controller.lastFallDetectedAt;

    // "Moving hard" starts well below the impact threshold so the hero reacts
    // to real motion rather than only to the fall itself.
    final threshold = AppConstants.fallAccelerationThresholdG;
    final isMovingHard = latest.vectorMagnitude > threshold * 0.65;

    var order = 0;

    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Live magnitude hero ──────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: HeroMetricCard(
              caption: 'Total movement right now',
              value: latest.vectorMagnitude.toStringAsFixed(2),
              unit: 'g',
              label: latest.activityState,
              badgeLabel: 'Impact at ${threshold.toStringAsFixed(1)} g',
              badgeColor: isMovingHard
                  ? AppColors.riskHigh
                  : AppColors.textSecondary,
              watermark: Icons.vibration_rounded,
              gradient:
                  isMovingHard ? activeGradient : AppColors.gradientMint,
            ),
          ),
          AppSpacing.gapSm,

          // ── Status ───────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: AppCard(
              accent:
                  isFallActive ? AppColors.riskCritical : AppColors.riskSafe,
              child: Row(
                children: [
                  IconChip(
                    icon: isFallActive
                        ? Icons.personal_injury_rounded
                        : Icons.shield_moon_rounded,
                    color: isFallActive
                        ? AppColors.riskCritical
                        : AppColors.riskSafe,
                    background: isFallActive
                        ? AppColors.riskCriticalBg
                        : AppColors.riskSafeBg,
                    size: 38,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFallActive ? 'Fall detected' : 'Watching',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isFallActive
                                ? AppColors.riskCritical
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFallActive
                              ? 'Impact followed by no movement.'
                              : lastFallAt != null
                                  ? 'Last possible fall '
                                      '${Fmt.ago(lastFallAt)}.'
                                  : 'No impact so far. Every packet is checked.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Alert (only while a fall is live) ────────────────────────────
          if (isFallActive) ...[
            AppSpacing.gapSm,
            FadeSlideIn(
              index: order++,
              child: AppCard(
                accent: AppColors.riskCritical,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergencyState == EmergencyState.sosSent
                          ? 'SOS raised on this phone'
                          : 'Emergency countdown running',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.riskCritical,
                      ),
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      emergencyState == EmergencyState.sosSent
                          ? 'The alert message is ready to copy and send. Open '
                              'the emergency screen to read or send it.'
                          : 'Open the emergency screen to cancel if you are all '
                              'right, or to raise it now.',
                      style: AppTypography.bodyMedium,
                    ),
                    AppSpacing.gapSm,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.riskCritical,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.sos_rounded, size: 18),
                        label: const Text('Open emergency'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EmergencyScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          AppSpacing.gapSm,

          // ── Live trace ───────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'Accelerometer',
              subtitle: 'Three axes, in g',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      _Legend(label: 'X', color: xColor),
                      _Legend(label: 'Y', color: yColor),
                      _Legend(label: 'Z', color: zColor),
                    ],
                  ),
                  AppSpacing.gapSm,
                  RepaintBoundary(
                    child: SizedBox(
                      height: 190,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _AxisTracePainter(
                          history: history,
                          windowSize:
                              PranaHealthController.motionHistoryLimit,
                          xColor: xColor,
                          yColor: yColor,
                          zColor: zColor,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapXs,
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _windowLabel(history),
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
            ),
          ),
          AppSpacing.gapSm,

          // ── Current values ───────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(title: 'Current reading'),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'X axis',
                      value: latest.accX.toStringAsFixed(2),
                      unit: 'g',
                      accent: xColor,
                      valueColor: xColor,
                      filled: true,
                    ),
                  ),
                  AppSpacing.hGapXs,
                  Expanded(
                    child: StatTile(
                      label: 'Y axis',
                      value: latest.accY.toStringAsFixed(2),
                      unit: 'g',
                      accent: yColor,
                      valueColor: yColor,
                      filled: true,
                    ),
                  ),
                  AppSpacing.hGapXs,
                  Expanded(
                    child: StatTile(
                      label: 'Z axis',
                      value: latest.accZ.toStringAsFixed(2),
                      unit: 'g',
                      accent: zColor,
                      valueColor: zColor,
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── What the detector is actually doing ──────────────────────────
          FadeSlideIn(
            index: order++,
            child: const SectionHeader(
              title: 'How a fall is decided',
              subtitle: 'The rule running on this phone, in order',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.riskHigh,
                    title: 'An impact spike',
                    subtitle: 'Total movement crosses '
                        '${threshold.toStringAsFixed(1)} g. Roughly a hard '
                        'knock — normal walking sits near 1 g.',
                    value: '${threshold.toStringAsFixed(1)} g',
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.motion_photos_off_rounded,
                    iconColor: AppColors.riskCritical,
                    title: 'Then stillness',
                    subtitle: 'Within 2 seconds of the spike, movement drops '
                        'below '
                        '${AppConstants.fallInactivityThresholdG.toStringAsFixed(2)} g '
                        'and stays there. A stumble you walk off never gets '
                        'this quiet.',
                    value:
                        '${AppConstants.fallInactivityThresholdG.toStringAsFixed(2)} g',
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.primary,
                    title: 'Then a countdown you can cancel',
                    subtitle:
                        'Both conditions together start the '
                        '${AppConstants.sosCountdownSeconds}-second emergency '
                        'countdown. Nothing leaves this phone by itself.',
                    value: '${AppConstants.sosCountdownSeconds}s',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Real elapsed time across the window, read off the packet timestamps.
  static String _windowLabel(List<MotionReading> history) {
    if (history.length < 2) return 'Starting';
    final seconds =
        history.last.timestamp.difference(history.first.timestamp).inSeconds;
    if (seconds < 1) return '${history.length} samples';
    if (seconds < 90) return '${seconds}s ago';
    return '${(seconds / 60).round()} min ago';
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;

  const _Legend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        AppSpacing.hGapXxs,
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Three straight polylines over a shared, auto-scaled y range.
///
/// Deliberately not smoothed — an accelerometer trace has to show the spikes
/// that trigger detection, and a bezier through them would round them off.
class _AxisTracePainter extends CustomPainter {
  final List<MotionReading> history;
  final int windowSize;
  final Color xColor;
  final Color yColor;
  final Color zColor;

  _AxisTracePainter({
    required this.history,
    required this.windowSize,
    required this.xColor,
    required this.yColor,
    required this.zColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (history.length < 2) return;

    double minV = double.infinity;
    double maxV = -double.infinity;
    for (final m in history) {
      minV = min(minV, min(m.accX, min(m.accY, m.accZ)));
      maxV = max(maxV, max(m.accX, max(m.accY, m.accZ)));
    }
    // A resting band is nearly flat; hold a minimum span so a still sensor
    // does not render as three lines pinned to the frame edges.
    if (maxV - minV < 0.6) {
      final mid = (maxV + minV) / 2;
      minV = mid - 0.3;
      maxV = mid + 0.3;
    }
    final pad = (maxV - minV) * 0.12;
    minV -= pad;
    maxV += pad;

    double yPos(double v) =>
        size.height - ((v - minV) / (maxV - minV)) * size.height;

    // Fixed-width window: the trace grows from the left, then scrolls, so
    // existing points do not slide sideways on every packet.
    final divisor = max(windowSize - 1, 1);
    final startIndex = max(0, windowSize - history.length);
    double xPos(int i) => ((startIndex + i) / divisor) * size.width;

    // Zero line, when it falls inside the visible range.
    if (minV < 0 && maxV > 0) {
      canvas.drawLine(
        Offset(0, yPos(0)),
        Offset(size.width, yPos(0)),
        Paint()
          ..color = AppColors.border
          ..strokeWidth = 1.0,
      );
    }

    void drawSeries(double Function(MotionReading) pick, Color color) {
      final path = Path()..moveTo(xPos(0), yPos(pick(history[0])));
      for (int i = 1; i < history.length; i++) {
        path.lineTo(xPos(i), yPos(pick(history[i])));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final lastIndex = history.length - 1;
      canvas.drawCircle(
        Offset(xPos(lastIndex), yPos(pick(history[lastIndex]))),
        2.6,
        Paint()..color = color,
      );
    }

    drawSeries((m) => m.accX, xColor);
    drawSeries((m) => m.accY, yColor);
    drawSeries((m) => m.accZ, zColor);

    _label(canvas, '${maxV.toStringAsFixed(1)} g', const Offset(0, 0));
    _label(
      canvas,
      '${minV.toStringAsFixed(1)} g',
      Offset(0, size.height - 12),
    );
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _AxisTracePainter old) =>
      old.history.length != history.length ||
      (history.isNotEmpty &&
          old.history.isNotEmpty &&
          old.history.last.timestamp != history.last.timestamp);
}
