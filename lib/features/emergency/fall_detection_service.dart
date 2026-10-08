import 'dart:async';
import '../../core/constants/app_constants.dart';
import '../../shared/models/motion_reading.dart';

/// Edge IMU Fall & Impact Anomaly Detector
class FallDetectionService {
  final _fallAlertController = StreamController<MotionReading>.broadcast();
  bool _hasImpactSpike = false;
  DateTime? _impactTime;

  Stream<MotionReading> get fallAlertStream => _fallAlertController.stream;

  void processMotion(MotionReading motion) {
    final now = DateTime.now();

    // 1. Direct hardware flag or manual injection
    if (motion.isFallSuspected) {
      _fallAlertController.add(motion);
      return;
    }

    // 2. High-G Impact spike detection (> 2.8g)
    if (motion.vectorMagnitude > AppConstants.fallAccelerationThresholdG) {
      _hasImpactSpike = true;
      _impactTime = now;
      return;
    }

    // 3. Post-impact stillness detection (Within 1.5s after spike, vector remains < 0.25g)
    if (_hasImpactSpike && _impactTime != null) {
      final elapsed = now.difference(_impactTime!).inMilliseconds;
      if (elapsed < 2000 && motion.vectorMagnitude < AppConstants.fallInactivityThresholdG) {
        _hasImpactSpike = false;
        _fallAlertController.add(motion);
      } else if (elapsed >= 2000) {
        _hasImpactSpike = false;
      }
    }
  }

  void dispose() {
    _fallAlertController.close();
  }
}
