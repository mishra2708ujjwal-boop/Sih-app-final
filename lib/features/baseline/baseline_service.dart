import 'dart:math';
import '../../shared/models/health_reading.dart';
import '../../shared/models/user_baseline.dart';
import '../../core/database/local_storage_service.dart';

/// Personal Baseline Engine
///
/// Continuously learns and refines the user's personal physiological bounds locally on-device.
/// Rather than comparing against generic population thresholds (e.g. standard 60-100 BPM),
/// PRANA detects subtle individual anomalies (e.g. an individual whose normal is 64-78 BPM
/// experiencing an abnormal 92 BPM resting spike).
class BaselineService {
  final LocalStorageService _storage;
  UserBaseline _currentBaseline;

  // Rolling buffers for continuous on-device learning
  final List<double> _restingHrBuffer = [];
  final List<double> _spo2Buffer = [];
  final List<double> _tempBuffer = [];

  BaselineService(this._storage) : _currentBaseline = _storage.getUserBaseline();

  UserBaseline get currentBaseline => _currentBaseline;

  /// Incorporate new sensor reading into personal baseline calculation
  void recordReading(HealthReading reading) {
    // Only incorporate readings when user is at Rest or Moderate activity to avoid skewing baseline
    if (reading.activityLevel.toLowerCase().contains('rest') ||
        reading.activityLevel.toLowerCase().contains('low')) {
      _restingHrBuffer.add(reading.heartRate);
      _spo2Buffer.add(reading.spo2);
      _tempBuffer.add(reading.bodyTemperature);

      // Keep buffer bounded to last 200 samples
      if (_restingHrBuffer.length > 200) _restingHrBuffer.removeAt(0);
      if (_spo2Buffer.length > 200) _spo2Buffer.removeAt(0);
      if (_tempBuffer.length > 200) _tempBuffer.removeAt(0);

      // Recalibrate baseline periodically (every 20 resting samples)
      if (_restingHrBuffer.length % 20 == 0) {
        _recalibrate();
      }
    }
  }

  void _recalibrate() {
    if (_restingHrBuffer.isEmpty) return;

    final hrMean = _calculateMean(_restingHrBuffer);
    final hrStd = _calculateStdDev(_restingHrBuffer, hrMean);

    final spo2Mean = _calculateMean(_spo2Buffer);
    final tempMean = _calculateMean(_tempBuffer);
    final tempStd = _calculateStdDev(_tempBuffer, tempMean);

    // Personal 90% confidence bounds (Mean +/- 1.645 * StdDev)
    final newHrMin = max(48.0, hrMean - max(8.0, 1.645 * hrStd));
    final newHrMax = min(110.0, hrMean + max(10.0, 1.645 * hrStd));
    final newSpo2Min = min(98.0, max(92.0, spo2Mean - 2.0));
    final newTempMin = double.parse((tempMean - max(0.4, 1.5 * tempStd)).toStringAsFixed(2));
    final newTempMax = double.parse((tempMean + max(0.5, 1.5 * tempStd)).toStringAsFixed(2));

    _currentBaseline = _currentBaseline.copyWith(
      normalHrMin: double.parse(newHrMin.toStringAsFixed(1)),
      normalHrMax: double.parse(newHrMax.toStringAsFixed(1)),
      normalSpo2Min: double.parse(newSpo2Min.toStringAsFixed(1)),
      normalTempMin: newTempMin,
      normalTempMax: newTempMax,
      restingHrBaseline: double.parse(hrMean.toStringAsFixed(1)),
      totalReadingsLearned: _currentBaseline.totalReadingsLearned + 20,
      lastCalibrated: DateTime.now(),
    );

    _storage.saveUserBaseline(_currentBaseline);
  }

  /// Heart Rate deviation percentage relative to personal normal upper bound
  /// Returns +18.5% if HR is 18.5% above baseline max, or 0.0 if within normal range.
  double getHrDeviationPercent(double currentHr) {
    if (currentHr > _currentBaseline.normalHrMax) {
      return ((currentHr - _currentBaseline.normalHrMax) / _currentBaseline.normalHrMax) * 100.0;
    } else if (currentHr < _currentBaseline.normalHrMin) {
      return ((currentHr - _currentBaseline.normalHrMin) / _currentBaseline.normalHrMin) * 100.0;
    }
    return 0.0;
  }

  /// SpO2 baseline drop (in percentage points below user's baseline minimum)
  double getSpo2DropPoints(double currentSpo2) {
    if (currentSpo2 < _currentBaseline.normalSpo2Min) {
      return _currentBaseline.normalSpo2Min - currentSpo2;
    }
    return 0.0;
  }

  /// Temperature deviation above user's normal upper bound (°C)
  double getTempElevation(double currentTemp) {
    if (currentTemp > _currentBaseline.normalTempMax) {
      return currentTemp - _currentBaseline.normalTempMax;
    }
    return 0.0;
  }

  /// Manual update or profile calibration override
  void updateBaseline(UserBaseline newBaseline) {
    _currentBaseline = newBaseline;
    _storage.saveUserBaseline(newBaseline);
  }

  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateStdDev(List<double> values, double mean) {
    if (values.length < 2) return 1.0;
    final sumSquaredDiff = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / (values.length - 1));
  }
}
