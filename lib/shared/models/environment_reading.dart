/// Normalized Environmental Sensor Reading
class EnvironmentReading {
  final double temperature;        // Ambient Temperature (°C)
  final double humidity;           // Relative Humidity (%)
  final int aqi;                   // Air Quality Index (0 - 500)
  final double heatIndex;          // Apparent Heat Exposure Index (°C)
  final String aqiCategory;        // 'Good', 'Moderate', 'Unhealthy', 'Hazardous'
  final String weatherCondition;   // 'Clear', 'Heatwave', 'Smog', 'Monsoon Rain', 'High Winds'
  final double heatExposureHours;  // Continuous heat exposure duration
  final DateTime timestamp;

  const EnvironmentReading({
    required this.temperature,
    required this.humidity,
    required this.aqi,
    required this.heatIndex,
    required this.aqiCategory,
    required this.weatherCondition,
    required this.heatExposureHours,
    required this.timestamp,
  });

  /// Calculate Rothfusz Heat Index regression
  static double calculateHeatIndex(double tempC, double humidity) {
    if (tempC < 27.0) return tempC;
    final t = tempC * 9 / 5 + 32; // Convert to Fahrenheit
    final r = humidity;
    final hiF = -42.379 +
        2.04901523 * t +
        10.14333127 * r -
        0.22475541 * t * r -
        0.00683783 * t * t -
        0.05481717 * r * r +
        0.00122874 * t * t * r +
        0.00085282 * t * r * r -
        0.00000199 * t * t * r * r;
    return (hiF - 32) * 5 / 9; // Return in Celsius
  }

  static String categorizeAqi(int aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  factory EnvironmentReading.fromJson(Map<String, dynamic> json) {
    final temp = (json['envTemp'] as num?)?.toDouble() ??
        (json['ambientTemp'] as num?)?.toDouble() ??
        (json['temperature'] as num?)?.toDouble() ??
        26.0;
    final hum = (json['envHumidity'] as num?)?.toDouble() ??
        (json['humidity'] as num?)?.toDouble() ??
        50.0;
    final aqiVal = (json['aqi'] as num?)?.toInt() ?? 45;
    return EnvironmentReading(
      temperature: temp,
      humidity: hum,
      aqi: aqiVal,
      heatIndex: (json['heatIndex'] as num?)?.toDouble() ?? calculateHeatIndex(temp, hum),
      aqiCategory: json['aqiCategory'] as String? ?? categorizeAqi(aqiVal),
      weatherCondition: json['weatherCondition'] as String? ?? 'Clear',
      heatExposureHours: (json['heatExposureHours'] as num?)?.toDouble() ?? 0.5,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'aqi': aqi,
      'heatIndex': heatIndex,
      'aqiCategory': aqiCategory,
      'weatherCondition': weatherCondition,
      'heatExposureHours': heatExposureHours,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  EnvironmentReading copyWith({
    double? temperature,
    double? humidity,
    int? aqi,
    double? heatIndex,
    String? aqiCategory,
    String? weatherCondition,
    double? heatExposureHours,
    DateTime? timestamp,
  }) {
    final newTemp = temperature ?? this.temperature;
    final newHum = humidity ?? this.humidity;
    final newAqi = aqi ?? this.aqi;
    return EnvironmentReading(
      temperature: newTemp,
      humidity: newHum,
      aqi: newAqi,
      heatIndex: heatIndex ?? calculateHeatIndex(newTemp, newHum),
      aqiCategory: aqiCategory ?? categorizeAqi(newAqi),
      weatherCondition: weatherCondition ?? this.weatherCondition,
      heatExposureHours: heatExposureHours ?? this.heatExposureHours,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
