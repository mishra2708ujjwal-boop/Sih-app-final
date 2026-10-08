import 'package:flutter/material.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/emergency/emergency_screen.dart';
import '../features/emergency/fall_detection_screen.dart';
import '../features/devices/device_screen.dart';
import '../features/history/history_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/demo/demo_lab_screen.dart';
import 'app.dart';

/// Named routes for every screen reachable outside the tab shell.
///
/// The four tab destinations are not listed here — they live inside
/// [MainNavigationShell]'s `IndexedStack` so their scroll positions survive tab
/// switches, and pushing them as routes would defeat that.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String mainShell = '/main';
  static const String emergency = '/emergency';
  static const String devices = '/devices';
  static const String privacy = '/privacy';
  static const String demoLab = '/demoLab';
  static const String fallDetection = '/fallDetection';
  static const String history = '/history';

  static Map<String, WidgetBuilder> get routes => {
        onboarding: (_) => const OnboardingScreen(),
        mainShell: (_) => const MainNavigationShell(),
        emergency: (_) => const EmergencyScreen(),
        devices: (_) => const DeviceScreen(),
        privacy: (_) => const PrivacyScreen(),
        demoLab: (_) => const DemoLabScreen(),
        fallDetection: (_) => const FallDetectionScreen(),
        history: (_) => const HistoryScreen(),
      };
}
