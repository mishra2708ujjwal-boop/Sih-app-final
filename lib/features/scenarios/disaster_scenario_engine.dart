import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Disaster and Extreme Climate Scenarios for SIH Demonstrations
enum DisasterScenario {
  normal,
  heatwave,
  airPollution,
  flood,
  cyclone,
  vulnerableElderly;

  String get displayName {
    switch (this) {
      case DisasterScenario.normal:
        return 'Normal Day';
      case DisasterScenario.heatwave:
        return 'Severe Heatwave';
      case DisasterScenario.airPollution:
        return 'Toxic Smog (AQI 385)';
      case DisasterScenario.flood:
        return 'Flood / High Humidity';
      case DisasterScenario.cyclone:
        return 'Cyclone Storm';
      case DisasterScenario.vulnerableElderly:
        return 'Vulnerable / Elderly';
    }
  }

  String get description {
    switch (this) {
      case DisasterScenario.normal:
        return 'Typical ambient conditions (24°C, AQI 42). Physiological vitals in normal baseline.';
      case DisasterScenario.heatwave:
        return 'Extreme heat (41.5°C, 72% humidity). Elevated HR (108 BPM) & hyperthermia (38.2°C).';
      case DisasterScenario.airPollution:
        return 'Hazardous particulates (AQI 385). Respiratory strain & hypoxemia (SpO₂ 92.5%).';
      case DisasterScenario.flood:
        return 'Saturated humidity (96%) with standing water. Dehydration & electrolyte risk.';
      case DisasterScenario.cyclone:
        return 'High wind pressure & extreme weather distress. Acute cardiac adrenaline spike.';
      case DisasterScenario.vulnerableElderly:
        return 'Pre-existing cardiovascular vulnerability in high ambient temperature (36°C).';
    }
  }

  IconData get icon {
    switch (this) {
      case DisasterScenario.normal:
        return Icons.wb_sunny_outlined;
      case DisasterScenario.heatwave:
        return Icons.local_fire_department_rounded;
      case DisasterScenario.airPollution:
        return Icons.cloud_outlined;
      case DisasterScenario.flood:
        return Icons.water_drop_rounded;
      case DisasterScenario.cyclone:
        return Icons.cyclone_rounded;
      case DisasterScenario.vulnerableElderly:
        return Icons.elderly_rounded;
    }
  }

  Color get badgeColor {
    switch (this) {
      case DisasterScenario.normal:
        return AppColors.riskSafe;
      case DisasterScenario.heatwave:
        return AppColors.riskHigh;
      case DisasterScenario.airPollution:
        return AppColors.aqi;
      case DisasterScenario.flood:
        return AppColors.humidity;
      case DisasterScenario.cyclone:
        return AppColors.riskModerate;
      case DisasterScenario.vulnerableElderly:
        return AppColors.riskCritical;
    }
  }

  Color get badgeBgColor {
    switch (this) {
      case DisasterScenario.normal:
        return AppColors.riskSafeBg;
      case DisasterScenario.heatwave:
        return AppColors.riskHighBg;
      case DisasterScenario.airPollution:
        return AppColors.aqiBg;
      case DisasterScenario.flood:
        return AppColors.humidityBg;
      case DisasterScenario.cyclone:
        return AppColors.riskModerateBg;
      case DisasterScenario.vulnerableElderly:
        return AppColors.riskCriticalBg;
    }
  }
}
