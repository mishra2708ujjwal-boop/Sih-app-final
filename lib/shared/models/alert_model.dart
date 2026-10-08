import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum AlertSeverity {
  info,
  warning,
  critical;

  Color get color {
    switch (this) {
      case AlertSeverity.info:
        return AppColors.primaryLight;
      case AlertSeverity.warning:
        return AppColors.riskModerate;
      case AlertSeverity.critical:
        return AppColors.riskCritical;
    }
  }

  Color get bgColor {
    switch (this) {
      case AlertSeverity.info:
        return AppColors.primaryContainer;
      case AlertSeverity.warning:
        return AppColors.riskModerateBg;
      case AlertSeverity.critical:
        return AppColors.riskCriticalBg;
    }
  }
}

class AlertModel {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String category;          // 'Heat', 'Respiratory', 'Cardiac', 'Fall', 'Environment'
  final bool isAcknowledged;
  final DateTime timestamp;

  const AlertModel({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    this.isAcknowledged = false,
    required this.timestamp,
  });

  AlertModel copyWith({
    String? id,
    String? title,
    String? message,
    AlertSeverity? severity,
    String? category,
    bool? isAcknowledged,
    DateTime? timestamp,
  }) {
    return AlertModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'severity': severity.name,
        'category': category,
        'isAcknowledged': isAcknowledged,
        'timestamp': timestamp.toIso8601String(),
      };
}
