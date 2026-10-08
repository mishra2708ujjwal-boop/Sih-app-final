/// Global Application Configuration and System Constants
class AppConstants {
  AppConstants._();

  static const String appName = 'PRANA';
  static const String appTagline = 'Offline-First Edge-AI Personal Health Companion';
  static const String appVersion = '1.0.0 (SIH Prototype)';

  // Baseline Defaults (Adult standard starting prior)
  static const double defaultHrMin = 65.0;
  static const double defaultHrMax = 88.0;
  static const double defaultSpo2Min = 95.0;
  static const double defaultTempMin = 36.4;
  static const double defaultTempMax = 37.3;
  static const double defaultRestingHr = 72.0;
  static const double defaultSleepGoalHours = 8.0;

  // Anomaly Thresholds
  static const double hrSevereHighThreshold = 120.0;
  static const double hrSevereLowThreshold = 45.0;
  static const double spo2CriticalThreshold = 90.0;
  static const double tempFeverThreshold = 38.0;
  static const double tempHeatStrokeThreshold = 39.5;

  // Emergency Timers
  static const int sosCountdownSeconds = 10;
  static const double fallAccelerationThresholdG = 2.8;
  static const double fallInactivityThresholdG = 0.25;

  // Storage Keys
  static const String keyUserBaseline = 'prana_user_baseline';
  static const String keyUserProfile = 'prana_user_profile';
  static const String keyPrivacySettings = 'prana_privacy_settings';
  static const String keyEmergencyContacts = 'prana_emergency_contacts';
  static const String keyMockModeEnabled = 'prana_mock_mode_enabled';
  static const String keyOnboardingComplete = 'prana_onboarding_complete';
  static const String keyDailySummaries = 'prana_daily_summaries';

  /// How many days of aggregated history to keep on the device. Roughly 20 KB
  /// of JSON at the cap, which SharedPreferences handles comfortably.
  static const int dailySummaryRetentionDays = 90;
}
