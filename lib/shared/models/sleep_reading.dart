/// Normalized Sleep & Recovery Record
class SleepReading {
  final int totalDurationMinutes;    // e.g. 450 mins (7.5 hrs)
  final int deepSleepMinutes;        // Deep restorative sleep
  final int remSleepMinutes;         // REM sleep (cognitive recovery)
  final int lightSleepMinutes;       // Light sleep
  final int awakeMinutes;            // Awake intervals
  final double sleepQualityScore;    // 0 - 100
  final double restingHeartRate;     // Resting HR during sleep (BPM)
  final double respiratoryRate;      // Breaths/min (normal: 12-20)
  final double recoveryIndex;        // 0 - 100 autonomic recovery
  final List<int> hypnogramStages;   // List of sleep stage samples [0:Awake, 1:Light, 2:Deep, 3:REM]
  final DateTime date;

  const SleepReading({
    required this.totalDurationMinutes,
    required this.deepSleepMinutes,
    required this.remSleepMinutes,
    required this.lightSleepMinutes,
    required this.awakeMinutes,
    required this.sleepQualityScore,
    required this.restingHeartRate,
    required this.respiratoryRate,
    required this.recoveryIndex,
    required this.hypnogramStages,
    required this.date,
  });

  factory SleepReading.fromJson(Map<String, dynamic> json) {
    return SleepReading(
      totalDurationMinutes: (json['totalDurationMinutes'] as num?)?.toInt() ?? 450,
      deepSleepMinutes: (json['deepSleepMinutes'] as num?)?.toInt() ?? 105,
      remSleepMinutes: (json['remSleepMinutes'] as num?)?.toInt() ?? 110,
      lightSleepMinutes: (json['lightSleepMinutes'] as num?)?.toInt() ?? 210,
      awakeMinutes: (json['awakeMinutes'] as num?)?.toInt() ?? 25,
      sleepQualityScore: (json['sleepQualityScore'] as num?)?.toDouble() ?? 82.0,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble() ?? 62.0,
      respiratoryRate: (json['respiratoryRate'] as num?)?.toDouble() ?? 15.2,
      recoveryIndex: (json['recoveryIndex'] as num?)?.toDouble() ?? 85.0,
      hypnogramStages: (json['hypnogramStages'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [0, 1, 1, 2, 2, 3, 1, 2, 3, 1, 0],
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDurationMinutes': totalDurationMinutes,
      'deepSleepMinutes': deepSleepMinutes,
      'remSleepMinutes': remSleepMinutes,
      'lightSleepMinutes': lightSleepMinutes,
      'awakeMinutes': awakeMinutes,
      'sleepQualityScore': sleepQualityScore,
      'restingHeartRate': restingHeartRate,
      'respiratoryRate': respiratoryRate,
      'recoveryIndex': recoveryIndex,
      'hypnogramStages': hypnogramStages,
      'date': date.toIso8601String(),
    };
  }
}
