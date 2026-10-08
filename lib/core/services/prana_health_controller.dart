import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/health_reading.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/sleep_reading.dart';
import '../../shared/models/user_baseline.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/risk_result.dart';
import '../../shared/models/alert_model.dart';
import '../../shared/models/daily_summary.dart';
import '../../shared/models/device_info.dart';
import '../../shared/widgets/prana_line_chart.dart';
import '../database/local_storage_service.dart';
import '../../features/devices/sensor_data_source.dart';
import '../../features/devices/mock_sensor_data_source.dart';
import '../../features/devices/bluetooth_sensor_data_source.dart';
import '../../features/baseline/baseline_service.dart';
import '../../features/ai/inference_service.dart';
import '../../features/ai/hr_trend_calculator.dart';
import '../../features/ai/mock_inference_service.dart';
import '../../features/ai/feature_processor.dart';
import '../../features/ai/prediction_model.dart';
import '../../features/risk/risk_engine.dart';
import '../../features/scenarios/disaster_scenario_engine.dart';
import '../../features/emergency/fall_detection_service.dart';
import '../../features/emergency/emergency_service.dart';
import '../../features/privacy/privacy_service.dart';
import '../../features/emergency/emergency_dispatcher.dart';

/// Central Reactive Controller & State Provider for PRANA
///
/// Implements the complete uninterrupted pipeline:
/// Sensor Input -> Local Baseline Evaluation -> 16-Point Feature Extraction ->
/// Local ML Inference -> Multi-Domain Risk Engine -> Recommendations & Alerting.
class PranaHealthController extends ChangeNotifier {
  final LocalStorageService storage;
  late final BaselineService baselineService;
  late final MLInferenceService mlService;
  late final RiskEngine riskEngine;
  late final FallDetectionService fallDetectionService;
  late final EmergencyService emergencyService;
  late final EmergencyDispatcher emergencyDispatcher;
  late final PrivacyService privacyService;

  SensorDataSource _sensorSource;
  bool _isMockMode = false;
  bool _hasLiveData = false;

  // Stream Subscriptions
  StreamSubscription? _healthSub;
  StreamSubscription? _motionSub;
  StreamSubscription? _envSub;
  StreamSubscription? _deviceSub;
  StreamSubscription? _fallSub;
  StreamSubscription? _emergencyStateSub;

  /// Guards against dispatching more than once per SOS episode: the service
  /// re-emits `sosSent` several times as the dispatch outcome is filled in.
  bool _emergencyDispatchStarted = false;

  // Current State Cache
  HealthReading _currentHealth = HealthReading(
    heartRate: 0.0,
    spo2: 0.0,
    bodyTemperature: 0.0,
    activityLevel: 'Awaiting sensor',
    steps: 0,
    restingHeartRate: 0.0,
    hrvRmssd: 0.0,
    timestamp: DateTime.now(),
  );

  EnvironmentReading _currentEnvironment = EnvironmentReading(
    temperature: 25.0,
    humidity: 50.0,
    aqi: 45,
    heatIndex: 25.0,
    aqiCategory: 'Good',
    weatherCondition: 'Clear',
    heatExposureHours: 0.0,
    timestamp: DateTime.now(),
  );

  MotionReading _currentMotion = MotionReading(
    accX: 0.0,
    accY: 0.0,
    accZ: 1.0,
    activityState: 'Stationary',
    timestamp: DateTime.now(),
  );

  /// Rolling IMU trace for the fall-detection page. Bounded so a long session
  /// cannot grow memory: the firmware streams motion at 10 Hz, so this holds
  /// the last ~15 seconds. The page derives its real time-axis label from the
  /// packet timestamps, so this staying a fixed count is fine.
  static const int motionHistoryLimit = 150;
  final List<MotionReading> _motionHistory = [];

  /// Repaint signal for the IMU trace only. The accelerometer arrives far more
  /// often than vitals do, so it gets its own notifier instead of calling
  /// notifyListeners() and rebuilding every screen watching this controller.
  final ValueNotifier<int> motionTick = ValueNotifier<int>(0);

  DateTime? _lastFallAt;

  /// Sample sleep data.
  ///
  /// This is a fixed literal, not a sensor read: the firmware in `firmware/`
  /// streams HR, SpO2, temperature and IMU, and nothing derives sleep staging
  /// from them. It exists so the Sleep screen has something to render in demo
  /// mode. Gate any UI that shows it on [hasSleepData] — presenting these
  /// numbers while a real band is connected would be a fabricated reading.
  final SleepReading _currentSleep = SleepReading(
    totalDurationMinutes: 445, // 7h 25m
    deepSleepMinutes: 110,
    remSleepMinutes: 105,
    lightSleepMinutes: 205,
    awakeMinutes: 25,
    sleepQualityScore: 84.0,
    restingHeartRate: 62.0,
    respiratoryRate: 15.0,
    recoveryIndex: 88.0,
    hypnogramStages: const [0, 1, 1, 2, 2, 3, 1, 2, 3, 1, 0],
    date: DateTime.now(),
  );

  PredictionResult _currentMlPrediction = PredictionResult.initial();
  RiskResult _currentRisk = RiskResult.initial();
  DeviceInfo _currentDevice = DeviceInfo.disconnected();
  DisasterScenario _currentScenario = DisasterScenario.normal;
  UserProfile _userProfile = UserProfile.defaultProfile();

  // Historical Telemetry Buffers for Charts
  final List<ChartDataPoint> _hrHistory = [];
  final List<ChartDataPoint> _spo2History = [];
  final List<ChartDataPoint> _tempHistory = [];
  final List<ChartDataPoint> _riskScoreHistory = [];
  final List<AlertModel> _activeAlerts = [];

  /// Day-by-day aggregates, oldest first, loaded from disk at startup.
  ///
  /// The chart buffers above hold minutes. This holds months — it is the only
  /// thing in the app that survives a restart, and it is what the History screen
  /// draws. Simulated readings never enter it; see [_recordDailyAggregate].
  final List<DailySummary> _dailySummaries = [];

  /// Throttle for the history write. Readings arrive at ~1 Hz and
  /// SharedPreferences serialises the whole blob on every write, so the summary
  /// is updated in memory every reading and flushed to disk at most once a
  /// minute.
  DateTime? _lastSummaryFlushAt;
  static const Duration _summaryFlushInterval = Duration(seconds: 60);

  PranaHealthController({
    required this.storage,
    SensorDataSource? customSensorSource,
    MLInferenceService? customMlService,
    EmergencyDispatcher? customEmergencyDispatcher,
  }) : _isMockMode = storage.isMockModeEnabled(),
       _sensorSource =
           customSensorSource ??
           (storage.isMockModeEnabled()
               ? MockSensorDataSource()
               : BluetoothSensorDataSource()) {
    baselineService = BaselineService(storage);
    // Calibrated on-device inference (5 logistic regressions) that returns
    // distinct, mostly-low per-domain probabilities. Replaces the autoencoder
    // TFLiteInferenceService, which copied one saturated reconstruction-error
    // anomaly score onto all six fields -> every prediction pinned to ~100%
    // and the risk score stuck in "critical". See assets/models/README.md.
    mlService = customMlService ?? MockInferenceService();
    riskEngine = RiskEngine();
    fallDetectionService = FallDetectionService();
    emergencyService = EmergencyService();
    emergencyDispatcher = customEmergencyDispatcher ?? const EmergencyDispatcher();
    privacyService = PrivacyService(storage);
    _userProfile = storage.getUserProfile();
    _dailySummaries.addAll(storage.getDailySummaries());

    if (_isMockMode) {
      _hasLiveData = true;
      _currentDevice = DeviceInfo(
        name: 'PRANA Band Pro (Simulator)',
        id: 'SIM:00:PRANA:BLE',
        firmwareVersion: 'v2.4.1-edge-sim',
        connectionState: DeviceConnectionState.connected,
        batteryLevel: 92,
        rssi: -54,
        isLocalProcessing: true,
        isHeartRateActive: true,
        isSpo2Active: true,
        isTemperatureActive: true,
        isMotionActive: true,
        lastSyncTime: DateTime.now(),
      );
      _initializeHistoricalSampleData();
    } else {
      _hasLiveData = false;
      _currentDevice = DeviceInfo.disconnected();
    }

    _bindStreams();
  }

  // --- Getters ---
  SensorDataSource get sensorSource => _sensorSource;
  HealthReading get currentHealth => _currentHealth;
  EnvironmentReading get currentEnvironment => _currentEnvironment;
  MotionReading get currentMotion => _currentMotion;
  List<MotionReading> get motionHistory => List.unmodifiable(_motionHistory);

  /// When the existing [FallDetectionService] last raised an alert, or null if
  /// it never has this session.
  DateTime? get lastFallDetectedAt => _lastFallAt;
  SleepReading get currentSleep => _currentSleep;

  /// Whether [currentSleep] represents anything measured.
  ///
  /// False on real hardware: no sensor or model in this app produces sleep
  /// staging, so [currentSleep] is sample data. True only in demo mode, where
  /// simulated values are explicitly labelled as such.
  bool get hasSleepData => _isMockMode;
  UserBaseline get currentBaseline => baselineService.currentBaseline;
  PredictionResult get currentMlPrediction => _currentMlPrediction;
  RiskResult get currentRisk => _currentRisk;
  DeviceInfo get currentDevice => _currentDevice;
  DisasterScenario get currentScenario => _currentScenario;
  UserProfile get userProfile => _userProfile;
  bool get isMockMode => _isMockMode;
  bool get hasLiveData => _hasLiveData;

  List<ChartDataPoint> get hrHistory => List.unmodifiable(_hrHistory);
  List<ChartDataPoint> get spo2History => List.unmodifiable(_spo2History);
  List<ChartDataPoint> get tempHistory => List.unmodifiable(_tempHistory);
  List<ChartDataPoint> get riskScoreHistory =>
      List.unmodifiable(_riskScoreHistory);
  List<AlertModel> get activeAlerts => List.unmodifiable(_activeAlerts);

  /// Persisted day-by-day history, oldest first.
  List<DailySummary> get dailySummaries => List.unmodifiable(_dailySummaries);

  /// The dates that have a recorded summary — what the History calendar marks.
  Set<DateTime> get recordedDates => _dailySummaries.map((s) => s.date).toSet();

  /// The summary for [day], or null if nothing was recorded then.
  DailySummary? summaryFor(DateTime day) {
    for (final s in _dailySummaries) {
      if (s.isSameDay(day)) return s;
    }
    return null;
  }

  /// Whether history is accumulating right now.
  ///
  /// False in demo mode: simulated vitals are deliberately kept out of the
  /// persisted record, so a demo run can never masquerade as a day the user
  /// actually wore the band.
  bool get isRecordingHistory => !_isMockMode;

  void _initializeHistoricalSampleData() {
    _hrHistory.clear();
    _spo2History.clear();
    _tempHistory.clear();
    _riskScoreHistory.clear();
    final now = DateTime.now();
    for (int i = 24; i >= 0; i--) {
      final time = now.subtract(Duration(hours: i));
      _hrHistory.add(ChartDataPoint(time: time, value: 70.0 + (i % 5) * 2.0));
      _spo2History.add(ChartDataPoint(time: time, value: 97.5 + (i % 3) * 0.5));
      _tempHistory.add(ChartDataPoint(time: time, value: 36.6 + (i % 4) * 0.1));
      _riskScoreHistory.add(
        ChartDataPoint(time: time, value: 16.0 + (i % 6) * 2.0),
      );
    }
  }

  void _bindStreams() {
    _healthSub = _sensorSource.healthStream.listen(_onHealthReadingReceived);
    _motionSub = _sensorSource.motionStream.listen(_onMotionReadingReceived);
    _envSub = _sensorSource.environmentStream.listen(
      _onEnvironmentReadingReceived,
    );
    _deviceSub = _sensorSource.deviceStatusStream.listen((dev) {
      _currentDevice = dev;
      notifyListeners();
    });

    _fallSub = fallDetectionService.fallAlertStream.listen((_) {
      _lastFallAt = DateTime.now();
      emergencyService.triggerFallDetected();
      _addAlert(
        title: 'POSSIBLE FALL DETECTED',
        message: 'Impact anomaly detected. Emergency countdown initiated.',
        severity: AlertSeverity.critical,
        category: 'Fall',
      );
    });

    _emergencyStateSub = emergencyService.stateStream.listen((state) {
      // Fire the automatic SMS + call exactly once, on the transition into
      // sosSent (the service re-emits sosSent as it records the outcome).
      if (state == EmergencyState.sosSent) {
        if (!_emergencyDispatchStarted) {
          _emergencyDispatchStarted = true;
          _dispatchEmergency();
        }
      } else if (state == EmergencyState.ready ||
          state == EmergencyState.cancelled) {
        _emergencyDispatchStarted = false;
      }
      notifyListeners();
    });
  }

  // --- Emergency auto-dispatch ---

  /// Pops the OS permission dialogs (SMS / phone / location) needed for the
  /// automatic fall dispatch. Called when the Emergency screen is first opened.
  Future<void> ensureEmergencyPermissions() =>
      emergencyDispatcher.requestPermissions();

  /// Runs the fully-automatic dispatch once an SOS is raised: capture the exact
  /// GPS location, then text and call the primary emergency contact. The outcome
  /// is written back onto [emergencyService] so the Emergency screen can show
  /// exactly what happened. Never throws — a failed leg degrades to the on-screen
  /// copy-the-message fallback.
  Future<void> _dispatchEmergency() async {
    final contacts = _userProfile.emergencyContacts;
    if (contacts.isEmpty) {
      emergencyService.completeDispatch(
        gpsText: null,
        smsSent: false,
        callStatus: 'skipped',
      );
      return;
    }
    final contact = contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => contacts.first,
    );

    emergencyService.beginDispatch();

    // 1. Exact location (best-effort; may be null if GPS is off/denied).
    final GpsFix? fix = await emergencyDispatcher.location();
    emergencyService.setDispatchedLocation(fix?.shortText, fix?.mapsLink);

    // 2. Build the alert body from the same source the screen displays.
    final message = buildEmergencyMessage(
      profile: _userProfile,
      health: _currentHealth,
      risk: _currentRisk,
      hasLiveData: _hasLiveData,
      raisedAt: emergencyService.dispatchedTimestamp ?? DateTime.now(),
      gpsText: fix?.shortText,
      mapsLink: fix?.mapsLink,
      contactName: contact.name,
    );

    // 3. Send the SMS, then place the call.
    final smsOk = await emergencyDispatcher.sendSms(contact.phone, message);
    final callStatus = await emergencyDispatcher.placeCall(contact.phone);

    emergencyService.completeDispatch(
      gpsText: fix?.shortText,
      smsSent: smsOk,
      callStatus: callStatus,
    );

    final callLabel = switch (callStatus) {
      'called' => 'call placed',
      'dialer' => 'dialler opened',
      _ => 'call failed',
    };
    _addAlert(
      title: 'EMERGENCY DISPATCHED',
      message: 'To ${contact.name}: SMS ${smsOk ? 'sent' : 'failed'}, '
          '$callLabel${fix != null ? ', location included' : ''}.',
      severity: AlertSeverity.critical,
      category: 'Emergency',
    );
  }

  // --- Real-Time Core Pipeline Execution ---
  void _onHealthReadingReceived(HealthReading reading) async {
    _hasLiveData = true;
    _currentHealth = reading;

    // 1. Buffer historical line chart data
    _hrHistory.add(
      ChartDataPoint(time: reading.timestamp, value: reading.heartRate),
    );
    if (_hrHistory.length > 50) _hrHistory.removeAt(0);

    _spo2History.add(
      ChartDataPoint(time: reading.timestamp, value: reading.spo2),
    );
    if (_spo2History.length > 50) _spo2History.removeAt(0);

    _tempHistory.add(
      ChartDataPoint(time: reading.timestamp, value: reading.bodyTemperature),
    );
    if (_tempHistory.length > 50) _tempHistory.removeAt(0);

    // 2. Personal Baseline evaluation & continuous learning (ONLY in real hardware mode)
    if (!_isMockMode) {
      baselineService.recordReading(reading);
    }
    final hrDev = baselineService.getHrDeviationPercent(reading.heartRate);
    final spo2Drop = baselineService.getSpo2DropPoints(reading.spo2);
    final tempElev = baselineService.getTempElevation(reading.bodyTemperature);

    // 3. 16-Dimensional Feature Extraction
    final hrTrendSlope = HrTrendCalculator.computeSlope(_hrHistory);
    final features = FeatureProcessor.extractFeatureVector(
      health: reading,
      environment: _currentEnvironment,
      baseline: baselineService.currentBaseline,
      sleep: _isMockMode ? _currentSleep : null,
      hrTrendSlope: hrTrendSlope,
    );

    // 4. On-Device Edge ML Forward Inference
    final prediction = await mlService.runInference(features);
    _currentMlPrediction = prediction;

    // 5. Multi-Domain Risk Engine Synthesis
    final risk = riskEngine.calculateRisk(
      health: reading,
      environment: _currentEnvironment,
      baseline: baselineService.currentBaseline,
      mlPrediction: prediction,
      hrDeviationPercent: hrDev,
      spo2DropPoints: spo2Drop,
      tempElevation: tempElev,
    );
    _currentRisk = risk;

    _riskScoreHistory.add(
      ChartDataPoint(
        time: reading.timestamp,
        value: risk.overallScore.toDouble(),
      ),
    );
    if (_riskScoreHistory.length > 50) _riskScoreHistory.removeAt(0);

    // 6b. Fold into today's persisted aggregate (real hardware only).
    _recordDailyAggregate(reading, risk);

    // 6. Generate alarms for high/critical levels
    if (risk.level == RiskLevel.critical || risk.level == RiskLevel.high) {
      _checkAndTriggerRiskAlert(risk);
    }

    notifyListeners();
  }

  void _onMotionReadingReceived(MotionReading motion) {
    _currentMotion = motion;
    _motionHistory.add(motion);
    if (_motionHistory.length > motionHistoryLimit) {
      _motionHistory.removeAt(0);
    }
    motionTick.value++;
    fallDetectionService.processMotion(motion);
  }

  void _onEnvironmentReadingReceived(EnvironmentReading env) {
    _currentEnvironment = env;
    notifyListeners();
  }

  // --- Local History Accumulation ---

  /// Folds one reading into today's [DailySummary].
  ///
  /// Skipped entirely in demo mode: the History screen is a record of what the
  /// user's body actually did, and mixing simulated days into it would make the
  /// whole record untrustworthy.
  void _recordDailyAggregate(HealthReading reading, RiskResult risk) {
    if (_isMockMode) return;

    final today = DailySummary.dayOf(reading.timestamp);
    final index = _dailySummaries.indexWhere((s) => s.isSameDay(today));

    if (index == -1) {
      // First reading of a new day — also a natural moment to flush, so the
      // previous day is on disk before this one starts growing.
      _dailySummaries.add(DailySummary.empty(today).withReading(reading, risk));
      _dailySummaries.sort((a, b) => a.date.compareTo(b.date));
      _flushDailySummaries(force: true);
      return;
    }

    _dailySummaries[index] = _dailySummaries[index].withReading(reading, risk);
    _flushDailySummaries();
  }

  /// Writes history to disk, at most once per [_summaryFlushInterval].
  ///
  /// Fire-and-forget: a slow disk must never stall the sensor pipeline, and a
  /// failed write only costs at most one interval of aggregation.
  void _flushDailySummaries({bool force = false}) {
    final now = DateTime.now();
    final last = _lastSummaryFlushAt;
    if (!force &&
        last != null &&
        now.difference(last) < _summaryFlushInterval) {
      return;
    }
    _lastSummaryFlushAt = now;
    storage.saveDailySummaries(_dailySummaries);
  }

  void _checkAndTriggerRiskAlert(RiskResult risk) {
    // Avoid spamming duplicate alerts if recent one is unacknowledged
    if (_activeAlerts.any(
      (a) => !a.isAcknowledged && a.severity == AlertSeverity.critical,
    )) {
      return;
    }

    if (risk.level == RiskLevel.critical) {
      _addAlert(
        title: 'CRITICAL HEALTH RISK (${risk.overallScore}/100)',
        message: risk.primaryRecommendation,
        severity: AlertSeverity.critical,
        category: 'Risk',
      );
    } else if (risk.level == RiskLevel.high) {
      _addAlert(
        title: 'HIGH HEALTH RISK WARNING',
        message: risk.primaryRecommendation,
        severity: AlertSeverity.warning,
        category: 'Risk',
      );
    }
  }

  void _addAlert({
    required String title,
    required String message,
    required AlertSeverity severity,
    required String category,
  }) {
    final alert = AlertModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      severity: severity,
      category: category,
      timestamp: DateTime.now(),
    );
    _activeAlerts.insert(0, alert);
    if (_activeAlerts.length > 20) _activeAlerts.removeLast();

    // Alerts are the part of history a user actually goes looking for, so they
    // are counted straight through rather than waiting on the flush throttle.
    if (!_isMockMode) {
      final today = DailySummary.dayOf(alert.timestamp);
      final index = _dailySummaries.indexWhere((s) => s.isSameDay(today));
      if (index == -1) {
        _dailySummaries.add(DailySummary.empty(today).withAlert());
        _dailySummaries.sort((a, b) => a.date.compareTo(b.date));
      } else {
        _dailySummaries[index] = _dailySummaries[index].withAlert();
      }
      _flushDailySummaries(force: true);
    }

    notifyListeners();
  }

  void acknowledgeAlert(String id) {
    final idx = _activeAlerts.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _activeAlerts[idx] = _activeAlerts[idx].copyWith(isAcknowledged: true);
      notifyListeners();
    }
  }

  // --- Disaster Scenario Demo Controls ---
  void selectDisasterScenario(DisasterScenario scenario) {
    _currentScenario = scenario;
    if (_sensorSource is MockSensorDataSource) {
      (_sensorSource as MockSensorDataSource).setScenario(scenario);
    }
    notifyListeners();
  }

  void triggerTestFall() {
    if (_sensorSource is MockSensorDataSource) {
      (_sensorSource as MockSensorDataSource).triggerSimulatedFall();
    } else {
      emergencyService.triggerFallDetected();
    }
  }

  // --- Hardware / Mock Mode Switching ---
  Future<void> toggleMockMode(bool enabled) async {
    _isMockMode = enabled;
    await storage.setMockModeEnabled(enabled);

    await _healthSub?.cancel();
    await _motionSub?.cancel();
    await _envSub?.cancel();
    await _deviceSub?.cancel();
    _sensorSource.dispose();

    // The IMU trace belongs to whichever source produced it — never carry
    // simulated samples over into a real hardware session, or the reverse.
    _motionHistory.clear();
    motionTick.value++;

    if (enabled) {
      _sensorSource = MockSensorDataSource();
      (_sensorSource as MockSensorDataSource).setScenario(_currentScenario);
      _hasLiveData = true;
      _initializeHistoricalSampleData();
    } else {
      _sensorSource = BluetoothSensorDataSource();
      _hasLiveData = false;
      _hrHistory.clear();
      _spo2History.clear();
      _tempHistory.clear();
      _riskScoreHistory.clear();
      _currentDevice = DeviceInfo.disconnected();
      _currentHealth = HealthReading(
        heartRate: 0.0,
        spo2: 0.0,
        bodyTemperature: 0.0,
        activityLevel: 'Awaiting sensor',
        steps: 0,
        restingHeartRate: 0.0,
        hrvRmssd: 0.0,
        timestamp: DateTime.now(),
      );
    }
    _bindStreams();
    notifyListeners();
  }

  // --- BLE Device Controls ---
  Future<void> startBleScan() async {
    if (_isMockMode) {
      await toggleMockMode(false);
    }
    await _sensorSource.startScanning();
    notifyListeners();
  }

  Future<void> stopBleScan() async {
    await _sensorSource.stopScanning();
    notifyListeners();
  }

  Future<void> connectBleDevice(String deviceId) async {
    await _sensorSource.connect(deviceId);
    notifyListeners();
  }

  Future<void> disconnectBleDevice() async {
    await _sensorSource.disconnect();
    notifyListeners();
  }

  // --- Privacy ---

  /// Erases every local record and resets in-memory state to match.
  ///
  /// Goes through the existing [PrivacyService], then clears the caches this
  /// controller holds — otherwise the next flush would write today's history
  /// straight back into a store the user just asked to be emptied.
  Future<void> wipeLocalData() async {
    await privacyService.wipeAllLocalData();
    _dailySummaries.clear();
    _activeAlerts.clear();
    _lastSummaryFlushAt = null;
    _hrHistory.clear();
    _spo2History.clear();
    _tempHistory.clear();
    _riskScoreHistory.clear();
    _userProfile = storage.getUserProfile();
    baselineService.updateBaseline(storage.getUserBaseline());
    notifyListeners();
  }

  // --- Profile & Baseline Updaters ---
  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    await storage.saveUserProfile(profile);
    notifyListeners();
  }

  void updateUserBaseline(UserBaseline baseline) {
    baselineService.updateBaseline(baseline);
    notifyListeners();
  }

  @override
  void dispose() {
    // Flush whatever the throttle was holding, so closing the app never costs
    // the last minute of the day's record.
    _flushDailySummaries(force: true);
    _healthSub?.cancel();
    _motionSub?.cancel();
    _envSub?.cancel();
    _deviceSub?.cancel();
    _fallSub?.cancel();
    _emergencyStateSub?.cancel();
    _sensorSource.dispose();
    mlService.dispose();
    fallDetectionService.dispose();
    emergencyService.dispose();
    motionTick.dispose();
    super.dispose();
  }
}
