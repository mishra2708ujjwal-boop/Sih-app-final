import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_spacing.dart';
import '../core/constants/app_colors.dart';
import '../core/services/prana_health_controller.dart';
import '../core/utils/format.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/health/health_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/environment/environment_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/emergency/emergency_service.dart';
import '../features/emergency/sos_action_button.dart';
import '../features/emergency/fall_detection_screen.dart';
import '../features/history/history_screen.dart';
import '../features/devices/device_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/demo/demo_lab_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/search/quick_search_sheet.dart';
import '../shared/models/device_info.dart';
import '../shared/widgets/prana_action_sheet.dart';
import 'routes.dart';

class PranaApp extends StatelessWidget {
  final bool initialOnboardingComplete;

  const PranaApp({super.key, required this.initialOnboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PRANA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Always open on the animated splash. When it finishes it replaces itself
      // with onboarding (first run) or the main shell (returning user).
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.splash) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => SplashScreen(
              nextRoute: initialOnboardingComplete
                  ? AppRoutes.mainShell
                  : AppRoutes.onboarding,
            ),
          );
        }
        return null;
      },
      routes: AppRoutes.routes,
      builder: (context, child) {
        // Clamp text scaling. The app is dense with fixed-height gauges and
        // charts; beyond ~1.3 those blow out their containers. Clamping keeps
        // large-font users in a readable layout instead of a broken one.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  /// Watches the shared emergency state machine so a fall surfaces the countdown
  /// no matter which tab is on screen.
  StreamSubscription? _emergencySub;
  bool _emergencyRouteOpen = false;

  @override
  void initState() {
    super.initState();
    // A detected fall starts the countdown in EmergencyService regardless of
    // the current tab. Surface the full-screen countdown (with its Cancel)
    // automatically, so the user gets the window to stop the automatic SMS +
    // call before it goes out.
    final controller = context.read<PranaHealthController>();
    _emergencySub = controller.emergencyService.stateStream.listen((state) {
      if (!mounted) return;
      final active = state == EmergencyState.countdown ||
          state == EmergencyState.sosSent;
      if (active) _openEmergencyRoute();
    });
  }

  @override
  void dispose() {
    _emergencySub?.cancel();
    super.dispose();
  }

  /// The four pill destinations. The raised centre button is Insights (index 4,
  /// human vitals only) and is NOT part of this list — it sits in the gap
  /// between index 1 and 2. Environment takes the slot that Insights used to
  /// hold. Tab indices below map 1:1 to `_screens` with no arithmetic anywhere.
  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.favorite_outline_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Vitals',
    ),
    _NavItem(
      icon: Icons.eco_outlined,
      activeIcon: Icons.eco_rounded,
      label: 'Environment',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Me',
    ),
  ];

  // Insights is last so the four pill tiles keep indices 0–3 (1:1 with
  // `_navItems`) while the raised centre button owns index 4.
  List<Widget> get _screens => [
        DashboardScreen(
          onNavigateToVitals: () => _navigateToIndex(1),
          onNavigateToInsights: () => _navigateToIndex(4),
          onNavigateToEnvironment: () => _navigateToIndex(2),
          onNavigateToProfile: () => _navigateToIndex(3),
          onOpenSearch: _openSearch,
          onOpenMenu: _openMenu,
        ),
        HealthScreen(initialSegment: _vitalsSegment),
        const EnvironmentScreen(),
        const ProfileScreen(),
        const InsightsScreen(),
      ];

  int _vitalsSegment = 0;

  void _navigateToIndex(int index, {int? vitalsSegment}) {
    setState(() {
      _currentIndex = index;
      if (vitalsSegment != null) _vitalsSegment = vitalsSegment;
    });
  }

  void _openEmergency() {
    HapticFeedback.mediumImpact();
    _openEmergencyRoute();
  }

  /// Pushes the Emergency screen at most once. Shared by the manual SOS button
  /// and the automatic fall watch in [initState], with [_emergencyRouteOpen]
  /// preventing a second push when a manually-opened screen then starts a
  /// countdown.
  void _openEmergencyRoute() {
    if (_emergencyRouteOpen) return;
    _emergencyRouteOpen = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const EmergencyScreen()))
        .then((_) {
      if (mounted) _emergencyRouteOpen = false;
    });
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // ── Quick search ───────────────────────────────────────────────────────────
  /// The shell owns search because it is the only thing that knows every
  /// destination. Live metric entries are only built when there is real data to
  /// put in their subtitle — searching "heart rate" with the band off jumps to
  /// Vitals without claiming a reading PRANA doesn't have.
  Future<void> _openSearch() async {
    final controller = context.read<PranaHealthController>();
    final health = controller.currentHealth;
    final env = controller.currentEnvironment;
    final risk = controller.currentRisk;
    final hasData = controller.hasLiveData;

    final entries = <QuickSearchEntry>[
      if (hasData) ...[
        QuickSearchEntry(
          title: 'Heart rate',
          subtitle: '${health.heartRate.toStringAsFixed(0)} BPM right now',
          icon: Icons.favorite_rounded,
          color: AppColors.heartRate,
          group: 'Your vitals',
          keywords: const ['bpm', 'pulse', 'hr', 'cardiac', 'beats'],
          onSelect: () => _navigateToIndex(1, vitalsSegment: 0),
        ),
        QuickSearchEntry(
          title: 'Blood oxygen',
          subtitle: '${health.spo2.toStringAsFixed(0)}% saturation',
          icon: Icons.water_drop_rounded,
          color: AppColors.spo2,
          group: 'Your vitals',
          keywords: const ['spo2', 'oxygen', 'o2', 'saturation', 'breathing'],
          onSelect: () => _navigateToIndex(1, vitalsSegment: 1),
        ),
        QuickSearchEntry(
          title: 'Body temperature',
          subtitle: '${health.bodyTemperature.toStringAsFixed(1)} °C',
          icon: Icons.thermostat_rounded,
          color: AppColors.temperature,
          group: 'Your vitals',
          keywords: const ['temp', 'fever', 'skin', 'celsius'],
          onSelect: () => _navigateToIndex(1, vitalsSegment: 2),
        ),
        QuickSearchEntry(
          title: 'Heart rate variability',
          subtitle: '${health.hrvRmssd.toStringAsFixed(0)} ms RMSSD',
          icon: Icons.monitor_heart_rounded,
          color: AppColors.spo2,
          group: 'Your vitals',
          keywords: const ['hrv', 'rmssd', 'recovery', 'stress'],
          onSelect: () => _navigateToIndex(1, vitalsSegment: 0),
        ),
        QuickSearchEntry(
          title: 'Steps',
          subtitle: '${Fmt.count(health.steps)} today · '
              '${health.activityLevel.toLowerCase()}',
          icon: Icons.directions_walk_rounded,
          color: AppColors.activity,
          group: 'Your vitals',
          keywords: const ['walk', 'activity', 'movement', 'exercise'],
          onSelect: () => _navigateToIndex(1, vitalsSegment: 0),
        ),
        QuickSearchEntry(
          title: 'Risk score',
          subtitle: '${risk.overallScore} · ${risk.level.displayName}',
          icon: Icons.shield_rounded,
          color: risk.level.color,
          group: 'Your vitals',
          keywords: const ['risk', 'score', 'health score', 'status'],
          onSelect: () => _navigateToIndex(4),
        ),
        QuickSearchEntry(
          title: 'Air quality',
          subtitle: 'AQI ${env.aqi} · ${env.aqiCategory}',
          icon: Icons.air_rounded,
          color: AppColors.aqi,
          group: 'Around you',
          keywords: const ['aqi', 'air', 'pollution', 'smog', 'pm2.5'],
          onSelect: () => _navigateToIndex(2),
        ),
        QuickSearchEntry(
          title: 'Heat index',
          subtitle: 'Feels like ${env.heatIndex.toStringAsFixed(0)} °C',
          icon: Icons.local_fire_department_rounded,
          color: AppColors.heatIndex,
          group: 'Around you',
          keywords: const ['heat', 'humidity', 'feels like', 'weather'],
          onSelect: () => _navigateToIndex(2),
        ),
      ],
      QuickSearchEntry(
        title: 'Home',
        subtitle: 'Risk score, vitals overview and advice',
        icon: Icons.home_rounded,
        color: AppColors.primary,
        group: 'Go to',
        keywords: const ['dashboard', 'overview', 'start'],
        onSelect: () => _navigateToIndex(0),
      ),
      QuickSearchEntry(
        title: 'Vitals',
        subtitle: 'Full history for every measured signal',
        icon: Icons.favorite_rounded,
        color: AppColors.heartRate,
        group: 'Go to',
        keywords: const ['health', 'readings', 'charts', 'trends'],
        onSelect: () => _navigateToIndex(1, vitalsSegment: 0),
      ),
      QuickSearchEntry(
        title: 'Sleep',
        subtitle: 'Stages, duration and quality',
        icon: Icons.bedtime_rounded,
        color: AppColors.sleep,
        group: 'Go to',
        keywords: const ['rest', 'bed', 'night', 'deep', 'rem'],
        onSelect: () => _navigateToIndex(1, vitalsSegment: 3),
      ),
      QuickSearchEntry(
        title: 'Insights',
        subtitle: 'What is driving your risk score',
        icon: Icons.insights_rounded,
        color: AppColors.primary,
        group: 'Go to',
        keywords: const ['analysis', 'drivers', 'why', 'explain', 'ml', 'model'],
        onSelect: () => _navigateToIndex(4),
      ),
      QuickSearchEntry(
        title: 'Environment',
        subtitle: 'Air, heat and humidity around you',
        icon: Icons.wb_sunny_rounded,
        color: AppColors.heatIndex,
        group: 'Go to',
        keywords: const ['weather', 'outside', 'conditions', 'aqi'],
        onSelect: () => _navigateToIndex(2),
      ),
      QuickSearchEntry(
        title: 'History',
        subtitle: 'Day by day, kept on this phone for 90 days',
        icon: Icons.calendar_month_rounded,
        color: AppColors.primary,
        group: 'Go to',
        keywords: const [
          'past',
          'log',
          'days',
          'week',
          'calendar',
          'yesterday',
          'record',
          'timeline',
          'alerts',
        ],
        onSelect: () => _push(const HistoryScreen()),
      ),
      QuickSearchEntry(
        title: 'Profile',
        subtitle: 'Your details, baseline and contacts',
        icon: Icons.person_rounded,
        color: AppColors.primary,
        group: 'Go to',
        keywords: const ['me', 'account', 'settings', 'baseline', 'name'],
        onSelect: () => _navigateToIndex(3),
      ),
      QuickSearchEntry(
        title: 'Sensor & device',
        subtitle: 'Pair, connect and check the band',
        icon: Icons.watch_rounded,
        color: AppColors.bleConnected,
        group: 'Go to',
        keywords: const [
          'bluetooth',
          'ble',
          'band',
          'pair',
          'connect',
          'battery',
          'esp32',
        ],
        onSelect: () => _push(const DeviceScreen()),
      ),
      QuickSearchEntry(
        title: 'Privacy',
        subtitle: 'What stays on this phone, and what you can erase',
        icon: Icons.lock_rounded,
        color: AppColors.primary,
        group: 'Go to',
        keywords: const ['data', 'offline', 'delete', 'export', 'audit', 'gdpr'],
        onSelect: () => _push(const PrivacyScreen()),
      ),
      QuickSearchEntry(
        title: 'Fall detection',
        subtitle: 'Motion sensitivity and the last detected fall',
        icon: Icons.personal_injury_rounded,
        color: AppColors.riskHigh,
        group: 'Go to',
        keywords: const ['fall', 'accelerometer', 'impact', 'motion', 'gyro'],
        onSelect: () => _push(const FallDetectionScreen()),
      ),
      QuickSearchEntry(
        title: 'Demo lab',
        subtitle: 'Replay scenarios without hardware',
        icon: Icons.science_rounded,
        color: AppColors.bleScanning,
        group: 'Go to',
        keywords: const ['demo', 'mock', 'simulate', 'test', 'scenario'],
        onSelect: () => _push(const DemoLabScreen()),
      ),
      QuickSearchEntry(
        title: 'Emergency SOS',
        subtitle: 'Alert your contacts and share your vitals',
        icon: Icons.sos_rounded,
        color: AppColors.riskCritical,
        group: 'Actions',
        keywords: const ['sos', 'help', 'emergency', '112', 'ambulance', 'call'],
        onSelect: _openEmergency,
      ),
    ];

    await showQuickSearch(context, entries: entries);
  }

  // ── Overflow menu ──────────────────────────────────────────────────────────
  Future<void> _openMenu() async {
    final controller = context.read<PranaHealthController>();
    final device = controller.currentDevice;
    final isConnected =
        device.connectionState == DeviceConnectionState.connected;

    await showPranaActionSheet(
      context,
      title: 'Quick actions',
      subtitle: 'Everything here runs on this phone. Nothing is uploaded.',
      actions: [
        PranaAction(
          icon: Icons.watch_rounded,
          label: isConnected ? 'Sensor connected' : 'Connect your sensor',
          subtitle: isConnected
              ? '${device.name} · ${device.batteryLevel}% battery'
              : 'Scan for a nearby PRANA band',
          color: AppColors.bleConnected,
          onTap: () => _push(const DeviceScreen()),
        ),
        PranaAction(
          icon: Icons.calendar_month_rounded,
          label: 'History',
          subtitle: controller.dailySummaries.isEmpty
              ? 'Nothing recorded yet — wear your band for a day'
              : '${controller.dailySummaries.length} day'
                  '${controller.dailySummaries.length == 1 ? '' : 's'} recorded '
                  'on this phone',
          onTap: () => _push(const HistoryScreen()),
        ),
        PranaAction(
          icon: Icons.tune_rounded,
          label: 'Baseline & profile',
          subtitle: 'Adjust what PRANA treats as normal for you',
          onTap: () => _navigateToIndex(3),
        ),
        PranaAction(
          icon: Icons.personal_injury_rounded,
          label: 'Fall detection',
          subtitle: 'Sensitivity, live motion and recent events',
          color: AppColors.riskHigh,
          onTap: () => _push(const FallDetectionScreen()),
        ),
        PranaAction(
          icon: Icons.lock_rounded,
          label: 'Privacy & data',
          subtitle: 'Export or erase everything stored locally',
          onTap: () => _push(const PrivacyScreen()),
        ),
        PranaAction(
          icon: Icons.science_rounded,
          label: 'Demo lab',
          subtitle: controller.isMockMode
              ? 'Demo mode is on — readings are simulated'
              : 'Replay scenarios without hardware',
          color: AppColors.bleScanning,
          onTap: () => _push(const DemoLabScreen()),
        ),
        PranaAction(
          icon: Icons.sos_rounded,
          label: 'Emergency SOS',
          subtitle: 'Opens the emergency screen — nothing is sent yet',
          destructive: true,
          onTap: _openEmergency,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;

    // Publish the guarded emergency launcher to the tab subtree so each
    // screen's header SOS button can reach it by context — no callback
    // threading through five constructors, and the fall-detection dedup in
    // `_openEmergencyRoute` still owns the single path to the screen.
    return EmergencyLauncher(
      open: _openEmergency,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        // IndexedStack preserves each tab's scroll position and controllers; the
        // wrapper only animates the tab that just became visible.
        body: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < screens.length; i++)
              _TabTransition(
                isActive: _currentIndex == i,
                child: screens[i],
              ),
          ],
        ),
        bottomNavigationBar: _PranaBottomNav(
          currentIndex: _currentIndex,
          navItems: _navItems,
          onItemTap: _navigateToIndex,
          onInsightsTap: () => _navigateToIndex(4),
          centerActive: _currentIndex == 4,
        ),
      ),
    );
  }
}

/// Fades and lifts a tab into place when it becomes the active destination.
/// Short enough (200ms) that fast tab-switching never feels laggy.
class _TabTransition extends StatefulWidget {
  final bool isActive;
  final Widget child;

  const _TabTransition({required this.isActive, required this.child});

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.isActive ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _TabTransition old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ─── Nav item data ───────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─── Bottom navigation bar ───────────────────────────────────────────────────
/// A floating pill that hovers over the page rather than a bar welded to the
/// bottom edge — the page's cream shows through around it, which is what makes
/// the layered, rounded look read.
///
/// The Insights button overhangs the top of the pill. That is deliberate:
/// Insights is the app's showcase — the on-device analysis of your own vitals —
/// so it gets a larger target and breaks the pill's silhouette. The nav row
/// leaves a fixed-width gap for it instead of letting it push the tabs around,
/// so tab positions stay identical at every screen width.
class _PranaBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> navItems;
  final void Function(int) onItemTap;

  /// Opens the raised centre Insights destination (screen index 4).
  final VoidCallback onInsightsTap;

  /// Whether Insights is the current tab, so the centre button shows selected.
  final bool centerActive;

  /// Height of the pill itself, excluding the centre button overhang.
  static const double _barHeight = 64;

  /// How far the centre circle rises above the pill's top edge.
  static const double _centerLift = 15;

  /// Width reserved in the tab row for the centre button.
  static const double _centerSlot = 74;

  const _PranaBottomNav({
    required this.currentIndex,
    required this.navItems,
    required this.onItemTap,
    required this.onInsightsTap,
    required this.centerActive,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      // On a gesture-nav phone the system inset already provides breathing
      // room, so only a little is added; on a button-nav phone it supplies all
      // of it.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        0,
        AppSpacing.sm + 2,
        bottomPad > 0 ? AppSpacing.xs : AppSpacing.sm + 2,
      ),
      child: SizedBox(
        height: _barHeight + _centerLift,
        child: Stack(
          // The centre circle and its glow both extend past the Stack's painted
          // bounds; without this they'd be sliced off at the top edge.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.brPill,
                  border: Border.all(color: AppColors.borderLight, width: 1),
                  boxShadow: AppShadows.floating,
                ),
                child: Row(
                  children: [
                    // Screen indices pass straight through — no remapping.
                    Expanded(
                      child: _NavTile(
                        index: 0,
                        currentIndex: currentIndex,
                        item: navItems[0],
                        onTap: onItemTap,
                      ),
                    ),
                    Expanded(
                      child: _NavTile(
                        index: 1,
                        currentIndex: currentIndex,
                        item: navItems[1],
                        onTap: onItemTap,
                      ),
                    ),
                    const SizedBox(width: _centerSlot),
                    Expanded(
                      child: _NavTile(
                        index: 2,
                        currentIndex: currentIndex,
                        item: navItems[2],
                        onTap: onItemTap,
                      ),
                    ),
                    Expanded(
                      child: _NavTile(
                        index: 3,
                        currentIndex: currentIndex,
                        item: navItems[3],
                        onTap: onItemTap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _InsightsCenterButton(
                  active: centerActive,
                  onTap: onInsightsTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final int index;
  final int currentIndex;
  final _NavItem item;
  final void Function(int) onTap;

  const _NavTile({
    required this.index,
    required this.currentIndex,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        onTap: () {
          if (isActive) return;
          HapticFeedback.selectionClick();
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Solid dark fill when selected — the same treatment the selected
            // day gets in the calendar strip, so "chosen" looks the same
            // everywhere in the app.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.brPill,
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                size: 21,
                color: isActive ? Colors.white : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
                letterSpacing: 0.1,
                height: 1.2,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised centre button. Opens Insights — the on-device analysis of the
/// wearer's own vitals — and is lifted proud of the pill because it is the
/// app's showcase destination. Filled in the brand green (never the critical
/// red of the header SOS), with an accent ring when Insights is the active tab.
class _InsightsCenterButton extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;

  const _InsightsCenterButton({required this.active, required this.onTap});

  @override
  State<_InsightsCenterButton> createState() => _InsightsCenterButtonState();
}

class _InsightsCenterButtonState extends State<_InsightsCenterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.active ? AppColors.accent : AppColors.background;
    final glowColor = widget.active
        ? AppColors.accent.withValues(alpha: 0.55)
        : AppColors.primary.withValues(alpha: 0.30);

    return Semantics(
      button: true,
      selected: widget.active,
      label: 'Insights',
      child: GestureDetector(
        onTap: () {
          if (widget.active) return;
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              // Cream ring so the button reads as sitting *in front of* the nav
              // pill; it warms to the accent colour when Insights is selected.
              border: Border.all(color: borderColor, width: 4),
              boxShadow: AppShadows.glow(glowColor),
            ),
            child: const Center(
              child: Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
