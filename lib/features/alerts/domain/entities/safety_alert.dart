import 'package:equatable/equatable.dart';

enum AlertSeverity { critical, high, medium, low }

class SafetyAlert extends Equatable {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String? affectedArea;

  const SafetyAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.issuedAt,
    this.expiresAt,
    this.affectedArea,
  });

  bool get isActive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

  @override
  List<Object?> get props => [id, title, severity, issuedAt];
}
