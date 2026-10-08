/// Normalized Physiological Sensor Reading
class HealthReading {
  final double heartRate;          // Beats Per Minute (BPM)
  final double spo2;               // Blood Oxygen Saturation (%)
  final double bodyTemperature;    // Celsius (°C)
  final String activityLevel;      // 'Rest', 'Low', 'Moderate', 'High', 'Vigorous'
  final int steps;                 // Cumulative daily steps
  final double restingHeartRate;   // Resting baseline estimate (BPM)
  final double hrvRmssd;           // Heart Rate Variability RMSSD (ms)
  final DateTime timestamp;

  const HealthReading({
    required this.heartRate,
    required this.spo2,
    required this.bodyTemperature,
    required this.activityLevel,
    required this.steps,
    required this.restingHeartRate,
    required this.hrvRmssd,
    required this.timestamp,
  });

  factory HealthReading.fromJson(Map<String, dynamic> json) {
    return HealthReading(
      heartRate: (json['heartRate'] as num?)?.toDouble() ?? 75.0,
      spo2: (json['spo2'] as num?)?.toDouble() ?? 98.0,
      bodyTemperature: (json['bodyTemperature'] as num?)?.toDouble() ??
          (json['temperature'] as num?)?.toDouble() ??
          36.7,
      activityLevel: json['activityLevel'] as String? ?? 'Moderate',
      steps: json['steps'] as int? ?? 0,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble() ?? 70.0,
      hrvRmssd: (json['hrvRmssd'] as num?)?.toDouble() ?? 48.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heartRate': heartRate,
      'spo2': spo2,
      'bodyTemperature': bodyTemperature,
      'activityLevel': activityLevel,
      'steps': steps,
      'restingHeartRate': restingHeartRate,
      'hrvRmssd': hrvRmssd,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  HealthReading copyWith({
    double? heartRate,
    double? spo2,
    double? bodyTemperature,
    String? activityLevel,
    int? steps,
    double? restingHeartRate,
    double? hrvRmssd,
    DateTime? timestamp,
  }) {
    return HealthReading(
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      bodyTemperature: bodyTemperature ?? this.bodyTemperature,
      activityLevel: activityLevel ?? this.activityLevel,
      steps: steps ?? this.steps,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrvRmssd: hrvRmssd ?? this.hrvRmssd,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
