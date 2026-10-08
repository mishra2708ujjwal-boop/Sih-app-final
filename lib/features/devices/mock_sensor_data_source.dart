import 'dart:async';
import 'dart:math';
import 'sensor_data_source.dart';
import '../../shared/models/health_reading.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/device_info.dart';
import '../scenarios/disaster_scenario_engine.dart';

/// Realistic Continuous Physiological and Environmental Sensor Simulator
///
/// Implements realistic non-linear biometrics, cardiac variability, and reacts
/// dynamically to simulated disaster scenarios for Smart India Hackathon demonstrations.
class MockSensorDataSource implements SensorDataSource {
  final _healthController = StreamController<HealthReading>.broadcast();
  final _motionController = StreamController<MotionReading>.broadcast();
  final _environmentController = StreamController<EnvironmentReading>.broadcast();
  final _deviceStatusController = StreamController<DeviceInfo>.broadcast();

  Timer? _ticker;
  final Random _random = Random();
  double _timeStep = 0.0;

  // Active Environmental Scenario Modifier
  DisasterScenario _currentScenario = DisasterScenario.normal;

  // Internal Biometric State
  double _currentHeartRate = 74.0;
  double _currentSpo2 = 98.0;
  double _currentTemperature = 36.7;
  int _dailySteps = 4280;
  final int _battery = 92;
  bool _isConnected = true;

  MockSensorDataSource() {
    _startSimulationLoop();
  }

  @override
  Stream<HealthReading> get healthStream => _healthController.stream;

  @override
  Stream<MotionReading> get motionStream => _motionController.stream;

  @override
  Stream<EnvironmentReading> get environmentStream => _environmentController.stream;

  @override
  Stream<DeviceInfo> get deviceStatusStream => _deviceStatusController.stream;

  void setScenario(DisasterScenario scenario) {
    _currentScenario = scenario;
    _emitCurrentState();
  }

  void triggerSimulatedFall() {
    // High-G spike followed by immobility
    final fallMotion = MotionReading(
      accX: 1.8,
      accY: 2.4,
      accZ: 0.2,
      activityState: 'Impact',
      vectorMagnitude: 3.01,
      isFallSuspected: true,
      timestamp: DateTime.now(),
    );
    _motionController.add(fallMotion);
  }

  void _startSimulationLoop() {
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      _timeStep += 0.1;
      _tick();
    });
  }

  void _tick() {
    if (!_isConnected) return;

    // 1. Compute Base Environment depending on Scenario
    double targetEnvTemp;
    double targetHumidity;
    int targetAqi;
    double targetHr;
    double targetSpo2;
    double targetBodyTemp;
    String weatherCondition;

    switch (_currentScenario) {
      case DisasterScenario.normal:
        // Resting demo: keep the swing tiny so the risk score reads rock-steady
        // in the "Safe" band on stage. The disaster scenarios below keep their
        // larger dynamics.
        targetEnvTemp = 24.5 + sin(_timeStep * 0.2) * 0.6;
        targetHumidity = 47.0 + cos(_timeStep * 0.2) * 1.5;
        targetAqi = 40 + _random.nextInt(3);
        targetHr = 70.0 + sin(_timeStep * 0.5) * 1.5;
        targetSpo2 = 98.0;
        targetBodyTemp = 36.7 + sin(_timeStep * 0.1) * 0.05;
        weatherCondition = 'Clear';
        break;

      case DisasterScenario.heatwave:
        targetEnvTemp = 41.5 + sin(_timeStep * 0.2) * 1.2;
        targetHumidity = 72.0 + cos(_timeStep * 0.2) * 4.0;
        targetAqi = 85 + _random.nextInt(10);
        targetHr = 108.0 + sin(_timeStep * 0.6) * 6.0; // Significant tachycardia
        targetSpo2 = 94.0 + (_random.nextDouble() - 0.5);
        targetBodyTemp = 38.2 + sin(_timeStep * 0.1) * 0.15; // Heat stress hyperthermia
        weatherCondition = 'Severe Heatwave';
        break;

      case DisasterScenario.airPollution:
        targetEnvTemp = 28.0;
        targetHumidity = 55.0;
        targetAqi = 385 + _random.nextInt(20); // Severe hazardous smog
        targetHr = 96.0 + sin(_timeStep * 0.4) * 4.0;
        targetSpo2 = 92.5 + (_random.nextDouble() - 0.5); // Respiratory hypoxemia
        targetBodyTemp = 36.9;
        weatherCondition = 'Toxic Smog';
        break;

      case DisasterScenario.flood:
        targetEnvTemp = 33.5;
        targetHumidity = 96.0 + _random.nextDouble() * 2.0; // Saturated humidity
        targetAqi = 65;
        targetHr = 92.0 + sin(_timeStep * 0.3) * 5.0;
        targetSpo2 = 96.0;
        targetBodyTemp = 37.4;
        weatherCondition = 'Monsoon Inundation';
        break;

      case DisasterScenario.cyclone:
        targetEnvTemp = 26.0;
        targetHumidity = 88.0;
        targetAqi = 50;
        targetHr = 102.0 + sin(_timeStep * 0.8) * 8.0; // Adrenaline / distress spike
        targetSpo2 = 95.5;
        targetBodyTemp = 36.8;
        weatherCondition = 'Gale Storm';
        break;

      case DisasterScenario.vulnerableElderly:
        targetEnvTemp = 36.0;
        targetHumidity = 65.0;
        targetAqi = 140;
        targetHr = 114.0 + sin(_timeStep * 0.5) * 7.0; // Extreme cardiovascular strain
        targetSpo2 = 91.5;
        targetBodyTemp = 38.6;
        weatherCondition = 'High Heat Alert';
        break;
    }

    // Smooth exponential approach towards targets + physiological micro-noise
    _currentHeartRate += (targetHr - _currentHeartRate) * 0.25 + (_random.nextDouble() - 0.5) * 1.2;
    _currentSpo2 += (targetSpo2 - _currentSpo2) * 0.25 + (_random.nextDouble() - 0.5) * 0.2;
    _currentTemperature += (targetBodyTemp - _currentTemperature) * 0.15 + (_random.nextDouble() - 0.5) * 0.03;

    _currentSpo2 = _currentSpo2.clamp(80.0, 100.0);
    _currentHeartRate = _currentHeartRate.clamp(45.0, 180.0);
    _currentTemperature = _currentTemperature.clamp(35.0, 42.0);

    _dailySteps += _random.nextInt(3);

    _emitCurrentState(
      envTemp: targetEnvTemp,
      humidity: targetHumidity,
      aqi: targetAqi,
      weather: weatherCondition,
    );
  }

  void _emitCurrentState({
    double envTemp = 26.0,
    double humidity = 50.0,
    int aqi = 45,
    String weather = 'Clear',
  }) {
    final now = DateTime.now();

    // 1. Emit Health Reading
    final health = HealthReading(
      heartRate: double.parse(_currentHeartRate.toStringAsFixed(1)),
      spo2: double.parse(_currentSpo2.toStringAsFixed(1)),
      bodyTemperature: double.parse(_currentTemperature.toStringAsFixed(2)),
      activityLevel: _currentHeartRate > 100 ? 'Low (Stressed)' : 'Moderate',
      steps: _dailySteps,
      restingHeartRate: 68.0,
      hrvRmssd: _currentHeartRate > 100 ? 24.0 : 52.0,
      timestamp: now,
    );
    _healthController.add(health);

    // 2. Emit Motion Reading
    final motion = MotionReading(
      accX: (_random.nextDouble() - 0.5) * 0.15,
      accY: (_random.nextDouble() - 0.5) * 0.15,
      accZ: 0.98 + (_random.nextDouble() - 0.5) * 0.05,
      activityState: 'Normal',
      timestamp: now,
    );
    _motionController.add(motion);

    // 3. Emit Environment Reading
    final heatIndex = EnvironmentReading.calculateHeatIndex(envTemp, humidity);
    final env = EnvironmentReading(
      temperature: double.parse(envTemp.toStringAsFixed(1)),
      humidity: double.parse(humidity.toStringAsFixed(1)),
      aqi: aqi,
      heatIndex: double.parse(heatIndex.toStringAsFixed(1)),
      aqiCategory: EnvironmentReading.categorizeAqi(aqi),
      weatherCondition: weather,
      heatExposureHours: _currentScenario == DisasterScenario.normal ? 0.5 : 2.4,
      timestamp: now,
    );
    _environmentController.add(env);

    // 4. Emit Device Info
    final devInfo = DeviceInfo(
      name: 'PRANA Band Pro (Simulator)',
      id: 'SIM:00:PRANA:BLE',
      firmwareVersion: 'v2.4.1-edge-sim',
      connectionState: _isConnected ? DeviceConnectionState.connected : DeviceConnectionState.disconnected,
      batteryLevel: _battery,
      rssi: -54 + _random.nextInt(6),
      isLocalProcessing: true,
      isHeartRateActive: true,
      isSpo2Active: true,
      isTemperatureActive: true,
      isMotionActive: true,
      lastSyncTime: now,
    );
    _deviceStatusController.add(devInfo);
  }

  @override
  Future<void> connect(String deviceId) async {
    _isConnected = true;
    _emitCurrentState();
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _deviceStatusController.add(
      DeviceInfo.defaultDevice().copyWith(connectionState: DeviceConnectionState.disconnected),
    );
  }

  @override
  Future<void> startScanning() async {}

  @override
  Future<void> stopScanning() async {}

  @override
  void dispose() {
    _ticker?.cancel();
    _healthController.close();
    _motionController.close();
    _environmentController.close();
    _deviceStatusController.close();
  }
}
