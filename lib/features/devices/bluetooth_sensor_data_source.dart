import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'sensor_data_source.dart';
import 'sensor_parser.dart';
import 'ble_config.dart';
import '../../core/constants/ble_constants.dart';
import '../../shared/models/health_reading.dart';
import '../../shared/models/motion_reading.dart';
import '../../shared/models/environment_reading.dart';
import '../../shared/models/device_info.dart';

/// Production Bluetooth Low Energy Sensor Data Source
/// Connects to real wearable hardware (ESP32-S3, Arduino, nRF52) via BLE GATT.
class BluetoothSensorDataSource implements SensorDataSource {
  final BleConfig config;
  final _healthController = StreamController<HealthReading>.broadcast();
  final _motionController = StreamController<MotionReading>.broadcast();
  final _environmentController =
      StreamController<EnvironmentReading>.broadcast();
  final _deviceStatusController = StreamController<DeviceInfo>.broadcast();

  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  final List<StreamSubscription> _charSubs = [];

  // Internal state cache for GATT building
  DeviceInfo _deviceInfo = DeviceInfo.disconnected();
  double _lastHr = 72.0;
  double _lastSpo2 = 98.0;
  double _lastTemp = 36.7;
  int _lastBattery = 0;

  BluetoothSensorDataSource({this.config = const BleConfig()});

  @override
  Stream<HealthReading> get healthStream => _healthController.stream;
  @override
  Stream<MotionReading> get motionStream => _motionController.stream;
  @override
  Stream<EnvironmentReading> get environmentStream =>
      _environmentController.stream;
  @override
  Stream<DeviceInfo> get deviceStatusStream => _deviceStatusController.stream;

  @override
  Future<void> startScanning() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _deviceInfo = _deviceInfo.copyWith(
        connectionState: DeviceConnectionState.connecting,
      );
      _deviceStatusController.add(_deviceInfo);

      // Nothing can be found while the phone's radio is off, and startScan()
      // would simply throw. Ask for it (Android shows the system prompt), then
      // wait briefly for the adapter to come up.
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint("PRANA BLE: turnOn() unavailable: $e");
        }
        final state = await FlutterBluePlus.adapterState
            .firstWhere((s) => s == BluetoothAdapterState.on)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => BluetoothAdapterState.off,
            );
        if (state != BluetoothAdapterState.on) {
          debugPrint("PRANA BLE: Bluetooth is off — scan aborted.");
          _deviceInfo = _deviceInfo.copyWith(
            connectionState: DeviceConnectionState.error,
          );
          _deviceStatusController.add(_deviceInfo);
          return;
        }
      }

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          for (ScanResult r in results) {
            final deviceName = r.device.advName.isNotEmpty
                ? r.device.advName
                : r.device.platformName;

            final isTargetName = deviceName == config.targetDeviceName ||
                deviceName == "ESP32_DISTANCE_DEVICE" ||
                deviceName.startsWith(BleConstants.fallbackDevicePrefix);

            final hasTargetService = r.advertisementData.serviceUuids
                .any((uuid) => uuid.str.toLowerCase() == config.serviceUuid.toLowerCase());

            if (isTargetName || hasTargetService) {
              debugPrint("PRANA BLE: Match found -> $deviceName (${r.device.remoteId.str})");
              stopScanning();
              connect(r.device.remoteId.str, name: deviceName, rssi: r.rssi);
              break;
            }
          }
        },
        onError: (err) {
          debugPrint("PRANA BLE Scan Error: $err");
          _deviceInfo = _deviceInfo.copyWith(
            connectionState: DeviceConnectionState.error,
          );
          _deviceStatusController.add(_deviceInfo);
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );

      // A scan that finds nothing used to leave the state on 'connecting'
      // forever, which hides the Connect button. Fall back to disconnected once
      // the scan window has closed without a match.
      Future.delayed(
        const Duration(seconds: BleConstants.scanTimeoutSeconds + 1),
        () {
          if (_deviceStatusController.isClosed) return;
          if (_connectedDevice == null &&
              _deviceInfo.connectionState ==
                  DeviceConnectionState.connecting) {
            debugPrint("PRANA BLE: Scan finished, no PRANA device found.");
            _deviceInfo = _deviceInfo.copyWith(
              connectionState: DeviceConnectionState.disconnected,
            );
            _deviceStatusController.add(_deviceInfo);
          }
        },
      );
    } catch (e) {
      debugPrint("PRANA BLE: Start Scan Exception: $e");
      _deviceInfo = _deviceInfo.copyWith(
        connectionState: DeviceConnectionState.error,
      );
      _deviceStatusController.add(_deviceInfo);
    }
  }

  @override
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  Future<void> connect(String deviceId, {String? name, int? rssi}) async {
    await stopScanning();
    await _cleanupConn();

    _connectedDevice = BluetoothDevice.fromId(deviceId);
    _deviceInfo = _deviceInfo.copyWith(
      id: deviceId,
      name: name ?? _connectedDevice?.platformName ?? 'PRANA Band (ESP32)',
      rssi: rssi ?? -60,
      connectionState: DeviceConnectionState.connecting,
    );
    _deviceStatusController.add(_deviceInfo);

    _connStateSub = _connectedDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _deviceInfo = _deviceInfo.copyWith(
          id: deviceId,
          connectionState: DeviceConnectionState.connected,
          lastSyncTime: DateTime.now(),
        );
        _deviceStatusController.add(_deviceInfo);
        _discoverAndSubscribe();
      } else if (state == BluetoothConnectionState.disconnected) {
        _deviceInfo = _deviceInfo.copyWith(
          connectionState: DeviceConnectionState.disconnected,
          isHeartRateActive: false,
          isSpo2Active: false,
          isTemperatureActive: false,
          isMotionActive: false,
        );
        _deviceStatusController.add(_deviceInfo);
        _cleanupCharSubs();
      }
    });

    try {
      await _connectedDevice!.connect(
        autoConnect: false,
        timeout: const Duration(seconds: BleConstants.connectionTimeoutSeconds),
      );

      // Request higher MTU for JSON payloads
      try {
        await _connectedDevice!.requestMtu(256);
      } catch (e) {
        debugPrint("PRANA BLE: MTU request note: $e");
      }
    } catch (e) {
      debugPrint("PRANA BLE Connect Exception: $e");
      _deviceInfo = _deviceInfo.copyWith(
        connectionState: DeviceConnectionState.error,
      );
      _deviceStatusController.add(_deviceInfo);
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_connectedDevice == null) return;
    try {
      final services = await _connectedDevice!.discoverServices();

      bool hasHr = false;
      bool hasSpo2 = false;
      bool hasTemp = false;
      bool hasMotion = false;
      bool hasTelemetry = false;

      for (var service in services) {
        for (var char in service.characteristics) {
          final uuid = char.uuid.str.toLowerCase();

          // 1. JSON Telemetry Stream Characteristic
          if (uuid == config.telemetryStreamCharacteristicUuid.toLowerCase()) {
            hasTelemetry = true;
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _onTelemetryPacketReceived(Uint8List.fromList(value));
                }
              });
              _charSubs.add(sub);
            }
          }

          // 2. Standard Heart Rate (0x2A37)
          if (uuid == config.heartRateCharacteristicUuid.toLowerCase() ||
              uuid.contains('2a37')) {
            hasHr = true;
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _lastHr = SensorParser.parseGattHeartRate(Uint8List.fromList(value));
                  _emitGattHealthReading();
                }
              });
              _charSubs.add(sub);
            }
          }

          // 3. Standard SpO2 (0x2A5F)
          if (uuid == config.spo2CharacteristicUuid.toLowerCase() ||
              uuid.contains('2a5f')) {
            hasSpo2 = true;
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _lastSpo2 = SensorParser.parseGattSpo2(Uint8List.fromList(value));
                  _emitGattHealthReading();
                }
              });
              _charSubs.add(sub);
            }
          }

          // 4. Standard Health Thermometer (0x2A1C)
          if (uuid == config.temperatureCharacteristicUuid.toLowerCase() ||
              uuid.contains('2a1c')) {
            hasTemp = true;
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _lastTemp = SensorParser.parseGattTemperature(Uint8List.fromList(value));
                  _emitGattHealthReading();
                }
              });
              _charSubs.add(sub);
            }
          }

          // 5. Battery Level (0x2A19)
          if (uuid == config.batteryCharacteristicUuid.toLowerCase() ||
              uuid.contains('2a19')) {
            if (char.properties.read) {
              final val = await char.read();
              if (val.isNotEmpty) {
                _lastBattery = SensorParser.parseGattBatteryLevel(Uint8List.fromList(val));
                _deviceInfo = _deviceInfo.copyWith(batteryLevel: _lastBattery);
                _deviceStatusController.add(_deviceInfo);
              }
            }
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((val) {
                if (val.isNotEmpty) {
                  _lastBattery = SensorParser.parseGattBatteryLevel(Uint8List.fromList(val));
                  _deviceInfo = _deviceInfo.copyWith(batteryLevel: _lastBattery);
                  _deviceStatusController.add(_deviceInfo);
                }
              });
              _charSubs.add(sub);
            }
          }

          // 6. Motion / IMU Characteristic
          if (uuid == config.motionCharacteristicUuid.toLowerCase()) {
            hasMotion = true;
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              final sub = char.lastValueStream.listen((val) {
                if (val.isNotEmpty) {
                  final motion = SensorParser.parseGattMotion(Uint8List.fromList(val));
                  _motionController.add(motion);
                }
              });
              _charSubs.add(sub);
            }
          }
        }
      }

      _deviceInfo = _deviceInfo.copyWith(
        isHeartRateActive: hasHr || hasTelemetry,
        isSpo2Active: hasSpo2 || hasTelemetry,
        isTemperatureActive: hasTemp || hasTelemetry,
        isMotionActive: hasMotion || hasTelemetry,
      );
      _deviceStatusController.add(_deviceInfo);
    } catch (e) {
      debugPrint("PRANA BLE Discover Services Exception: $e");
    }
  }

  void _emitGattHealthReading() {
    final reading = HealthReading(
      heartRate: _lastHr,
      spo2: _lastSpo2,
      bodyTemperature: _lastTemp,
      activityLevel: 'Moderate',
      steps: 0,
      restingHeartRate: _lastHr,
      hrvRmssd: 45.0,
      timestamp: DateTime.now(),
    );
    _healthController.add(reading);
  }

  void _onTelemetryPacketReceived(Uint8List packetBytes) {
    try {
      final jsonString = utf8.decode(packetBytes);
      final jsonMap = SensorParser.parseJsonTelemetry(jsonString);
      if (jsonMap != null) {
        // Only emit a stream that the packet actually carries data for. Every
        // `fromJson` fills missing fields with plausible defaults (75 BPM,
        // 98%, 25 °C), so emitting unconditionally would publish invented
        // readings for whatever the firmware left out — a motion-only packet
        // would show as a full set of vitals.
        bool has(List<String> keys) => keys.any((k) => jsonMap[k] != null);

        if (has(const ['heartRate', 'hr', 'spo2', 'temperature', 'temp',
            'bodyTemperature'])) {
          _healthController.add(SensorParser.toHealthReading(jsonMap));
        }
        if (has(const ['accX', 'ax', 'accY', 'ay', 'accZ', 'az'])) {
          _motionController.add(SensorParser.toMotionReading(jsonMap));
        }
        if (has(const ['envTemp', 'envHumidity', 'aqi'])) {
          _environmentController.add(SensorParser.toEnvironmentReading(jsonMap));
        }

        if (jsonMap['battery'] != null) {
          _lastBattery = (jsonMap['battery'] as num).toInt();
          _deviceInfo = _deviceInfo.copyWith(
            batteryLevel: _lastBattery,
            lastSyncTime: DateTime.now(),
          );
          _deviceStatusController.add(_deviceInfo);
        }
      }
    } catch (e) {
      debugPrint("PRANA BLE: JSON parsing error: $e");
    }
  }

  @override
  Future<void> disconnect() async {
    await stopScanning();
    await _cleanupConn();
    _deviceInfo = _deviceInfo.copyWith(
      connectionState: DeviceConnectionState.disconnected,
    );
    _deviceStatusController.add(_deviceInfo);
  }

  Future<void> _cleanupConn() async {
    _cleanupCharSubs();
    await _connStateSub?.cancel();
    _connStateSub = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
  }

  void _cleanupCharSubs() {
    for (var sub in _charSubs) {
      sub.cancel();
    }
    _charSubs.clear();
  }

  @override
  void dispose() {
    stopScanning();
    _cleanupConn();
    _healthController.close();
    _motionController.close();
    _environmentController.close();
    _deviceStatusController.close();
  }
}
