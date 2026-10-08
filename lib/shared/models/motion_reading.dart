import 'dart:math';

/// Normalized 3-Axis IMU Motion Reading for Activity & Fall Detection
class MotionReading {
  final double accX;               // G-force X
  final double accY;               // G-force Y
  final double accZ;               // G-force Z
  final String activityState;      // 'Stationary', 'Walking', 'Running', 'Impact'
  final double vectorMagnitude;    // sqrt(x^2 + y^2 + z^2)
  final bool isFallSuspected;
  final DateTime timestamp;

  MotionReading({
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.activityState,
    double? vectorMagnitude,
    this.isFallSuspected = false,
    required this.timestamp,
  }) : vectorMagnitude = vectorMagnitude ?? sqrt(accX * accX + accY * accY + accZ * accZ);

  factory MotionReading.fromJson(Map<String, dynamic> json) {
    final x = (json['accX'] as num?)?.toDouble() ?? 0.0;
    final y = (json['accY'] as num?)?.toDouble() ?? 0.0;
    final z = (json['accZ'] as num?)?.toDouble() ?? 1.0;
    return MotionReading(
      accX: x,
      accY: y,
      accZ: z,
      activityState: json['activityState'] as String? ?? 'Stationary',
      isFallSuspected: json['isFallSuspected'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accX': accX,
      'accY': accY,
      'accZ': accZ,
      'activityState': activityState,
      'vectorMagnitude': vectorMagnitude,
      'isFallSuspected': isFallSuspected,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
