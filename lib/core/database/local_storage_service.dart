import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../../shared/models/daily_summary.dart';
import '../../shared/models/user_baseline.dart';
import '../../shared/models/user_profile.dart';

/// Offline-First Local Data Storage Engine
/// Handles persistence of user baseline, biometric telemetry buffers, alarms, and privacy preferences.
class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  // --- User Baseline Persistence ---
  Future<void> saveUserBaseline(UserBaseline baseline) async {
    final jsonStr = jsonEncode(baseline.toJson());
    await _prefs.setString(AppConstants.keyUserBaseline, jsonStr);
  }

  UserBaseline getUserBaseline() {
    final jsonStr = _prefs.getString(AppConstants.keyUserBaseline);
    if (jsonStr == null || jsonStr.isEmpty) {
      return UserBaseline.defaultBaseline();
    }
    try {
      return UserBaseline.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return UserBaseline.defaultBaseline();
    }
  }

  // --- User Profile Persistence ---
  Future<void> saveUserProfile(UserProfile profile) async {
    final map = {
      'name': profile.name,
      'age': profile.age,
      'gender': profile.gender,
      'heightCm': profile.heightCm,
      'weightKg': profile.weightKg,
      'bloodGroup': profile.bloodGroup,
      'medicalConditions': profile.medicalConditions,
      'emergencyContacts': profile.emergencyContacts
          .map((e) => e.toJson())
          .toList(),
      'isVulnerableProfile': profile.isVulnerableProfile,
    };
    await _prefs.setString(AppConstants.keyUserProfile, jsonEncode(map));
  }

  UserProfile getUserProfile() {
    final jsonStr = _prefs.getString(AppConstants.keyUserProfile);
    if (jsonStr == null || jsonStr.isEmpty) {
      return UserProfile.defaultProfile();
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final contacts =
          (map['emergencyContacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          UserProfile.defaultProfile().emergencyContacts;

      return UserProfile(
        name: map['name'] as String? ?? 'User',
        age: map['age'] as int? ?? 28,
        gender: map['gender'] as String? ?? 'Male',
        heightCm: (map['heightCm'] as num?)?.toDouble() ?? 175.0,
        weightKg: (map['weightKg'] as num?)?.toDouble() ?? 70.0,
        bloodGroup: map['bloodGroup'] as String? ?? 'O+',
        medicalConditions:
            (map['medicalConditions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        emergencyContacts: contacts,
        isVulnerableProfile: map['isVulnerableProfile'] as bool? ?? false,
      );
    } catch (_) {
      return UserProfile.defaultProfile();
    }
  }

  // --- Onboarding State ---
  bool isOnboardingComplete() {
    return _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool complete) async {
    await _prefs.setBool(AppConstants.keyOnboardingComplete, complete);
  }

  // --- Mock Mode Persistence ---
  bool isMockModeEnabled() {
    return _prefs.getBool(AppConstants.keyMockModeEnabled) ?? false;
  }

  Future<void> setMockModeEnabled(bool enabled) async {
    await _prefs.setBool(AppConstants.keyMockModeEnabled, enabled);
  }

  // --- Privacy & Granular Data Sharing Preferences ---
  Map<String, bool> getPrivacySettings() {
    final jsonStr = _prefs.getString(AppConstants.keyPrivacySettings);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {
        'shareLocation': true,
        'shareFamily': false,
        'shareHealthcare': false,
        'shareEmergency': true,
        'cloudSync': false,
      };
    }
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {
        'shareLocation': true,
        'shareFamily': false,
        'shareHealthcare': false,
        'shareEmergency': true,
        'cloudSync': false,
      };
    }
  }

  Future<void> savePrivacySettings(Map<String, bool> settings) async {
    await _prefs.setString(
      AppConstants.keyPrivacySettings,
      jsonEncode(settings),
    );
  }

  // --- Local Data Reset (Privacy Wipe) ---
  Future<void> clearAllData() async {
    await _prefs.clear();
  }

  // --- Daily History Persistence ---
  //
  // Aggregates only, oldest-first, trimmed to
  // AppConstants.dailySummaryRetentionDays. Written at most once a minute by the
  // controller, so this never sits in the sensor hot path.

  List<DailySummary> getDailySummaries() {
    final jsonStr = _prefs.getString(AppConstants.keyDailySummaries);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(DailySummary.fromJson)
          .whereType<DailySummary>()
          .toList();
      parsed.sort((a, b) => a.date.compareTo(b.date));
      return parsed;
    } catch (_) {
      // A corrupt blob shouldn't cost the user their app — history is the one
      // thing here that is safe to lose.
      return [];
    }
  }

  Future<void> saveDailySummaries(List<DailySummary> summaries) async {
    final sorted = [...summaries]..sort((a, b) => a.date.compareTo(b.date));
    final trimmed = sorted.length > AppConstants.dailySummaryRetentionDays
        ? sorted.sublist(sorted.length - AppConstants.dailySummaryRetentionDays)
        : sorted;
    await _prefs.setString(
      AppConstants.keyDailySummaries,
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> clearDailySummaries() async {
    await _prefs.remove(AppConstants.keyDailySummaries);
  }
}
