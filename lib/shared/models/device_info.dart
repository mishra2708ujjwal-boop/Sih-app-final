enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class DeviceInfo {
  final String name;
  final String id;
  final String firmwareVersion;
  final DeviceConnectionState connectionState;
  final int batteryLevel;          // 0 - 100%
  final int rssi;                  // Signal strength in dBm (e.g. -62 dBm)
  final bool isLocalProcessing;    // Edge AI active flag
  final bool isHeartRateActive;
  final bool isSpo2Active;
  final bool isTemperatureActive;
  final bool isMotionActive;
  final DateTime lastSyncTime;

  const DeviceInfo({
    required this.name,
    required this.id,
    required this.firmwareVersion,
    required this.connectionState,
    required this.batteryLevel,
    required this.rssi,
    required this.isLocalProcessing,
    required this.isHeartRateActive,
    required this.isSpo2Active,
    required this.isTemperatureActive,
    required this.isMotionActive,
    required this.lastSyncTime,
  });

  factory DeviceInfo.disconnected() {
    return DeviceInfo(
      name: 'PRANA Band (ESP32)',
      id: 'Not paired',
      firmwareVersion: 'v2.4.1',
      connectionState: DeviceConnectionState.disconnected,
      batteryLevel: 0,
      rssi: 0,
      isLocalProcessing: true,
      isHeartRateActive: false,
      isSpo2Active: false,
      isTemperatureActive: false,
      isMotionActive: false,
      lastSyncTime: DateTime.now(),
    );
  }

  factory DeviceInfo.defaultDevice() {
    return DeviceInfo(
      name: 'PRANA Band Pro (ESP32-S3)',
      id: 'D4:8A:FC:9B:32:1A',
      firmwareVersion: 'v2.4.1-edge-ai',
      connectionState: DeviceConnectionState.connected,
      batteryLevel: 88,
      rssi: -58,
      isLocalProcessing: true,
      isHeartRateActive: true,
      isSpo2Active: true,
      isTemperatureActive: true,
      isMotionActive: true,
      lastSyncTime: DateTime.now(),
    );
  }

  DeviceInfo copyWith({
    String? name,
    String? id,
    String? firmwareVersion,
    DeviceConnectionState? connectionState,
    int? batteryLevel,
    int? rssi,
    bool? isLocalProcessing,
    bool? isHeartRateActive,
    bool? isSpo2Active,
    bool? isTemperatureActive,
    bool? isMotionActive,
    DateTime? lastSyncTime,
  }) {
    return DeviceInfo(
      name: name ?? this.name,
      id: id ?? this.id,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      connectionState: connectionState ?? this.connectionState,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      isLocalProcessing: isLocalProcessing ?? this.isLocalProcessing,
      isHeartRateActive: isHeartRateActive ?? this.isHeartRateActive,
      isSpo2Active: isSpo2Active ?? this.isSpo2Active,
      isTemperatureActive: isTemperatureActive ?? this.isTemperatureActive,
      isMotionActive: isMotionActive ?? this.isMotionActive,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
