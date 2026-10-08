import '../../core/constants/app_constants.dart';

/// Personalized Physiological Baseline learned continuously on-device.
/// Represents the user's specific normal physiological operating zone.
class UserBaseline {
  final double normalHrMin;        // User's lower normal HR bound (e.g. 68.0)
  final double normalHrMax;        // User's upper normal HR bound (e.g. 88.0)
  final double normalSpo2Min;      // User's baseline SpO₂ minimum (e.g. 96.0%)
  final double normalTempMin;      // User's baseline body temp lower (e.g. 36.4°C)
  final double normalTempMax;      // User's baseline body temp upper (e.g. 37.2°C)
  final double restingHrBaseline;  // Moving average resting HR
  final double sleepGoalHours;     // Target sleep duration
  final int totalReadingsLearned;  // Total datapoints incorporated
  final DateTime lastCalibrated;

  const UserBaseline({
    required this.normalHrMin,
    required this.normalHrMax,
    required this.normalSpo2Min,
    required this.normalTempMin,
    required this.normalTempMax,
    required this.restingHrBaseline,
    required this.sleepGoalHours,
    required this.totalReadingsLearned,
    required this.lastCalibrated,
  });

  factory UserBaseline.defaultBaseline() {
    return UserBaseline(
      normalHrMin: AppConstants.defaultHrMin,
      normalHrMax: AppConstants.defaultHrMax,
      normalSpo2Min: AppConstants.defaultSpo2Min,
      normalTempMin: AppConstants.defaultTempMin,
      normalTempMax: AppConstants.defaultTempMax,
      restingHrBaseline: AppConstants.defaultRestingHr,
      sleepGoalHours: AppConstants.defaultSleepGoalHours,
      totalReadingsLearned: 0,
      lastCalibrated: DateTime.now(),
    );
  }

  factory UserBaseline.fromJson(Map<String, dynamic> json) {
    return UserBaseline(
      normalHrMin: (json['normalHrMin'] as num?)?.toDouble() ?? AppConstants.defaultHrMin,
      normalHrMax: (json['normalHrMax'] as num?)?.toDouble() ?? AppConstants.defaultHrMax,
      normalSpo2Min: (json['normalSpo2Min'] as num?)?.toDouble() ?? AppConstants.defaultSpo2Min,
      normalTempMin: (json['normalTempMin'] as num?)?.toDouble() ?? AppConstants.defaultTempMin,
      normalTempMax: (json['normalTempMax'] as num?)?.toDouble() ?? AppConstants.defaultTempMax,
      restingHrBaseline: (json['restingHrBaseline'] as num?)?.toDouble() ?? AppConstants.defaultRestingHr,
      sleepGoalHours: (json['sleepGoalHours'] as num?)?.toDouble() ?? AppConstants.defaultSleepGoalHours,
      totalReadingsLearned: (json['totalReadingsLearned'] as num?)?.toInt() ?? 100,
      lastCalibrated: json['lastCalibrated'] != null
          ? DateTime.parse(json['lastCalibrated'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'normalHrMin': normalHrMin,
      'normalHrMax': normalHrMax,
      'normalSpo2Min': normalSpo2Min,
      'normalTempMin': normalTempMin,
      'normalTempMax': normalTempMax,
      'restingHrBaseline': restingHrBaseline,
      'sleepGoalHours': sleepGoalHours,
      'totalReadingsLearned': totalReadingsLearned,
      'lastCalibrated': lastCalibrated.toIso8601String(),
    };
  }

  UserBaseline copyWith({
    double? normalHrMin,
    double? normalHrMax,
    double? normalSpo2Min,
    double? normalTempMin,
    double? normalTempMax,
    double? restingHrBaseline,
    double? sleepGoalHours,
    int? totalReadingsLearned,
    DateTime? lastCalibrated,
  }) {
    return UserBaseline(
      normalHrMin: normalHrMin ?? this.normalHrMin,
      normalHrMax: normalHrMax ?? this.normalHrMax,
      normalSpo2Min: normalSpo2Min ?? this.normalSpo2Min,
      normalTempMin: normalTempMin ?? this.normalTempMin,
      normalTempMax: normalTempMax ?? this.normalTempMax,
      restingHrBaseline: restingHrBaseline ?? this.restingHrBaseline,
      sleepGoalHours: sleepGoalHours ?? this.sleepGoalHours,
      totalReadingsLearned: totalReadingsLearned ?? this.totalReadingsLearned,
      lastCalibrated: lastCalibrated ?? this.lastCalibrated,
    );
  }
}
