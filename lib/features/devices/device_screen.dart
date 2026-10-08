import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/prana_health_controller.dart';
import '../../core/utils/format.dart';
import '../../shared/models/device_info.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/icon_chip.dart';
import '../../shared/widgets/prana_scaffold.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/info_row.dart';

/// Wearable device status and connection controls.
///
/// Nothing on this screen is invented: battery, signal and firmware only appear
/// on a live link, and the sensor rows read the flags the band itself reports.
/// While disconnected the screen says what PRANA is looking for rather than
/// filling the gaps with plausible numbers.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  static const _padding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xxs,
    AppSpacing.md,
    AppSpacing.xl,
  );

  /// Battery glyph matching the charge, so the icon carries information rather
  /// than decoration.
  static IconData _batteryIcon(int level) {
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 70) return Icons.battery_6_bar_rounded;
    if (level >= 50) return Icons.battery_4_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  /// −58 dBm is a strong link, −90 is barely there.
  static String _signalWord(int rssi) {
    if (rssi == 0) return 'No link';
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Good';
    if (rssi >= -88) return 'Weak';
    return 'Very weak';
  }

  Future<void> _scan(BuildContext context, PranaHealthController c) async {
    final messenger = ScaffoldMessenger.of(context);
    await c.startBleScan();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Looking for ${BleConstants.targetDeviceName} nearby…',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PranaHealthController>();
    final device = controller.currentDevice;
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;
    final isConnecting =
        device.connectionState == DeviceConnectionState.connecting;
    final isMock = controller.isMockMode;

    var order = 0;

    return PranaScaffold(
      title: 'Your band',
      subtitle: isConnected
          ? 'Connected and sending readings'
          : 'Sensor band and connection',
      body: ListView(
        padding: _padding,
        children: [
          // ── Connection hero ─────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: _ConnectionHero(
              device: device,
              isConnected: isConnected,
              isConnecting: isConnecting,
              isMock: isMock,
              onScan: () => _scan(context, controller),
              onDisconnect: () async {
                final messenger = ScaffoldMessenger.of(context);
                await controller.disconnectBleDevice();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Band disconnected.')),
                );
              },
            ),
          ),

          // ── Demo mode disclosure ────────────────────────────────────────────
          // The most important sentence on the screen when it applies: every
          // number in the app is being generated on this phone.
          if (isMock) ...[
            AppSpacing.gapSm,
            FadeSlideIn(
              index: order++,
              child: AppCard(
                color: AppColors.mint,
                showBorder: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconChip(
                          icon: Icons.science_rounded,
                          color: AppColors.primary,
                          background: Colors.white.withValues(alpha: 0.65),
                          size: 34,
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            'Demo mode is on',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'No band is connected. Every reading you see is generated '
                      'on this phone for demonstration, and none of it is saved '
                      'to your history.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    AppSpacing.gapSm,
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.mintDeep),
                        ),
                        icon: const Icon(Icons.power_settings_new_rounded,
                            size: 18),
                        label: const Text('Leave demo mode'),
                        onPressed: () => controller.toggleMockMode(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          AppSpacing.gapSm,

          // ── Sensors ─────────────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: 'Sensors',
              subtitle: isConnected
                  ? 'What your band is measuring right now'
                  : 'Available once the band connects',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _SensorRow(
                    icon: Icons.favorite_rounded,
                    title: 'Heart rate',
                    subtitle: 'Pulse and beat-to-beat variability',
                    isActive: device.isHeartRateActive,
                    color: AppColors.heartRate,
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  _SensorRow(
                    icon: Icons.water_drop_rounded,
                    title: 'Blood oxygen',
                    subtitle: 'Oxygen saturation in your blood',
                    isActive: device.isSpo2Active,
                    color: AppColors.spo2,
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  _SensorRow(
                    icon: Icons.thermostat_rounded,
                    title: 'Body temperature',
                    subtitle: 'Skin-contact thermometer',
                    isActive: device.isTemperatureActive,
                    color: AppColors.temperature,
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  _SensorRow(
                    icon: Icons.directions_run_rounded,
                    title: 'Movement',
                    subtitle: 'Steps and fall detection',
                    isActive: device.isMotionActive,
                    color: AppColors.activity,
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.gapSm,

          // ── The link itself ─────────────────────────────────────────────────
          FadeSlideIn(
            index: order++,
            child: SectionHeader(
              title: isConnected ? 'This connection' : 'What PRANA looks for',
              subtitle: isConnected
                  ? 'Read from the band, not stored anywhere'
                  : 'Set to match the firmware in this repository',
            ),
          ),
          FadeSlideIn(
            index: order++,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  InfoRow(
                    icon: Icons.bluetooth_rounded,
                    iconColor: AppColors.bleConnected,
                    title: 'Device name',
                    subtitle: isConnected
                        ? device.name
                        : 'Advertised as ${BleConstants.targetDeviceName}, or '
                            'anything starting '
                            '${BleConstants.fallbackDevicePrefix}',
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.numbers_rounded,
                    title: 'Address',
                    subtitle: isConnected ? device.id : 'Nothing paired yet',
                  ),
                  if (isConnected) ...[
                    const Divider(height: 1, color: AppColors.borderLight),
                    InfoRow(
                      icon: Icons.sync_rounded,
                      iconColor: AppColors.syncing,
                      title: 'Last packet',
                      subtitle: Fmt.ago(device.lastSyncTime),
                      value: _signalWord(device.rssi),
                    ),
                  ],
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.memory_rounded,
                    iconColor: AppColors.primary,
                    title: 'Where the analysis runs',
                    subtitle: device.isLocalProcessing
                        ? 'On this phone. The band sends raw readings; the '
                            'model, baseline and risk score are computed here.'
                        : 'On this phone.',
                  ),
                  const Divider(height: 1, color: AppColors.borderLight),
                  InfoRow(
                    icon: Icons.timer_outlined,
                    title: 'Scan timeout',
                    subtitle: 'How long PRANA looks before giving up',
                    value: '${BleConstants.scanTimeoutSeconds}s',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
/// Device identity, state and the one action that matters. Battery, signal and
/// firmware appear only on a live link — there is no '—' filler row.
class _ConnectionHero extends StatelessWidget {
  final DeviceInfo device;
  final bool isConnected;
  final bool isConnecting;
  final bool isMock;
  final VoidCallback onScan;
  final Future<void> Function() onDisconnect;

  const _ConnectionHero({
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    required this.isMock,
    required this.onScan,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      showBorder: false,
      radius: AppRadius.xl,
      gradient: const LinearGradient(
        colors: AppColors.gradientDark,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(
                icon: isConnected
                    ? Icons.watch_rounded
                    : Icons.watch_off_rounded,
                color: isConnected ? AppColors.accent : Colors.white70,
                background: Colors.white.withValues(alpha: 0.10),
                size: 44,
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected || isMock
                          ? device.name
                          : BleConstants.targetDeviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected || isMock ? device.id : 'Nothing paired yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          StatusPill(
            label: isConnected
                ? (isMock ? 'Simulated link' : 'Connected')
                : (isConnecting ? 'Searching' : 'Not connected'),
            color: isConnected
                ? (isMock ? AppColors.bleScanning : AppColors.accent)
                : (isConnecting ? AppColors.riskModerate : Colors.white70),
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            showDot: true,
            dense: true,
          ),

          // Battery / signal / firmware only mean something on a live link.
          if (isConnected) ...[
            AppSpacing.gapMd,
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _DarkStat(
                      label: 'Battery',
                      value: device.batteryLevel > 0
                          ? '${device.batteryLevel}'
                          : '—',
                      unit: device.batteryLevel > 0 ? '%' : '',
                      icon: device.batteryLevel > 0
                          ? DeviceScreen._batteryIcon(device.batteryLevel)
                          : Icons.battery_unknown_rounded,
                      alert: device.batteryLevel > 0 &&
                          device.batteryLevel < 20,
                    ),
                  ),
                  Expanded(
                    child: _DarkStat(
                      label: 'Signal',
                      value: device.rssi != 0 ? '${device.rssi}' : '—',
                      unit: device.rssi != 0 ? 'dBm' : '',
                      icon: Icons.wifi_rounded,
                    ),
                  ),
                  Expanded(
                    child: _DarkStat(
                      label: 'Firmware',
                      value: device.firmwareVersion.isNotEmpty
                          ? device.firmwareVersion
                          : '—',
                      icon: Icons.memory_rounded,
                      small: true,
                    ),
                  ),
                ],
              ),
            ),
          ],

          AppSpacing.gapMd,
          SizedBox(
            width: double.infinity,
            child: isConnected
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFCA5A5),
                      side: const BorderSide(color: Color(0x66FCA5A5)),
                    ),
                    onPressed: onDisconnect,
                    icon: const Icon(Icons.bluetooth_disabled_rounded,
                        size: 18),
                    label: const Text('Disconnect'),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    onPressed: isConnecting ? null : onScan,
                    icon: isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryDark,
                            ),
                          )
                        : const Icon(Icons.bluetooth_searching_rounded,
                            size: 18),
                    label: Text(isConnecting ? 'Searching…' : 'Connect band'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A stat tile for the dark hero. The shared StatTile is tuned for the cream
/// canvas, so this is a deliberately small dark twin rather than a theme
/// override.
class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final bool alert;
  final bool small;

  const _DarkStat({
    required this.label,
    required this.value,
    required this.icon,
    this.unit = '',
    this.alert = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = alert ? const Color(0xFFFCA5A5) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.55)),
          AppSpacing.gapXxs,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (small
                          ? AppTypography.labelMedium
                          : AppTypography.metricSmall)
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppTypography.metricUnit.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final Color color;

  const _SensorRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InfoRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: isActive ? color : AppColors.textTertiary,
      trailing: StatusPill(
        label: isActive ? 'Live' : 'Off',
        color: isActive ? AppColors.riskSafe : AppColors.textTertiary,
        backgroundColor:
            isActive ? AppColors.riskSafeBg : AppColors.surfaceWell,
        dense: true,
        showDot: isActive,
      ),
    );
  }
}
