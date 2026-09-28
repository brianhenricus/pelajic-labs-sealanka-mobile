import 'package:sea_lanka/features/logbook/data/models/catch_entry_model.dart';
import 'package:sea_lanka/features/logbook/domain/entities/trip_log.dart';

class TripLogModel extends TripLog {
  const TripLogModel({
    required super.id,
    required super.date,
    required super.location,
    required super.lat,
    required super.lon,
    required super.catches,
    super.notes,
    required super.photoUrls,
    required super.duration,
    super.fuelLiters,
    required super.createdAt,
    super.followedPredictionId,
  });

  factory TripLogModel.fromJson(Map<String, dynamic> json) => TripLogModel(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        location: json['location'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        catches: (json['catches'] as List<dynamic>)
            .map((e) => CatchEntryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: json['notes'] as String?,
        photoUrls: (json['photo_urls'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        duration: Duration(minutes: json['duration_minutes'] as int),
        fuelLiters: (json['fuel_liters'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        followedPredictionId: json['followed_prediction_id'] as String?,
      );
}
