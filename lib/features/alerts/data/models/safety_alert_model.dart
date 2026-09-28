import 'package:sea_lanka/features/alerts/domain/entities/safety_alert.dart';

class SafetyAlertModel extends SafetyAlert {
  const SafetyAlertModel({
    required super.id,
    required super.title,
    required super.description,
    required super.severity,
    required super.issuedAt,
    super.expiresAt,
    super.affectedArea,
  });

  factory SafetyAlertModel.fromJson(Map<String, dynamic> json) =>
      SafetyAlertModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        severity: _severityFromString(json['severity'] as String),
        issuedAt: DateTime.parse(json['issued_at'] as String),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String),
        affectedArea: json['affected_area'] as String?,
      );

  static AlertSeverity _severityFromString(String value) {
    switch (value) {
      case 'critical':
        return AlertSeverity.critical;
      case 'high':
        return AlertSeverity.high;
      case 'medium':
        return AlertSeverity.medium;
      case 'low':
        return AlertSeverity.low;
      default:
        return AlertSeverity.low;
    }
  }
}
