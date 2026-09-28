import 'package:equatable/equatable.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';

class TripLog extends Equatable {
  final String id;
  final DateTime date;
  final String location;
  final double lat;
  final double lon;
  final List<CatchEntry> catches;
  final String? notes;
  final List<String> photoUrls;
  final Duration duration;
  final double? fuelLiters;
  final DateTime createdAt;

  /// Which PFZ pick (if any) this trip followed — the backend's feedback
  /// loop for measuring whether the model is worth anything against real
  /// catch. Null if the trip wasn't tied to a pick.
  final String? followedPredictionId;

  const TripLog({
    required this.id,
    required this.date,
    required this.location,
    required this.lat,
    required this.lon,
    required this.catches,
    this.notes,
    required this.photoUrls,
    required this.duration,
    this.fuelLiters,
    required this.createdAt,
    this.followedPredictionId,
  });

  double get totalCatchKg =>
      catches.fold(0, (sum, c) => sum + c.weightKg);

  @override
  List<Object?> get props => [id, date, location, catches, createdAt];
}
