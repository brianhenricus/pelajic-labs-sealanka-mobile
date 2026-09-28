import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/logbook/data/models/catch_entry_model.dart';
import 'package:sea_lanka/features/logbook/data/models/trip_log_model.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';

abstract class LogbookRemoteDataSource {
  Future<List<TripLogModel>> getTrips();

  Future<TripLogModel> createTrip({
    required DateTime date,
    required String location,
    required double lat,
    required double lon,
    required List<CatchEntry> catches,
    String? notes,
    required List<String> photoUrls,
    required int durationMinutes,
    double? fuelLiters,
    String? followedPredictionId,
  });

  Future<String> uploadPhoto(String filePath);
}

class LogbookRemoteDataSourceImpl implements LogbookRemoteDataSource {
  final Dio _dio;
  LogbookRemoteDataSourceImpl(this._dio);

  @override
  Future<List<TripLogModel>> getTrips() async {
    try {
      final response = await _dio.get(ApiEndpoints.tripLogs);
      return (response.data as List<dynamic>)
          .map((e) => TripLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException('Trip logs unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<TripLogModel> createTrip({
    required DateTime date,
    required String location,
    required double lat,
    required double lon,
    required List<CatchEntry> catches,
    String? notes,
    required List<String> photoUrls,
    required int durationMinutes,
    double? fuelLiters,
    String? followedPredictionId,
  }) async {
    try {
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.post(ApiEndpoints.createTrip, data: {
        'date': dateStr,
        'location': location,
        'lat': lat,
        'lon': lon,
        'catches': catches
            .map((c) => CatchEntryModel(
                    species: c.species, weightKg: c.weightKg, quantity: c.quantity)
                .toJson())
            .toList(),
        'notes': notes,
        'photo_urls': photoUrls,
        'duration_minutes': durationMinutes,
        if (fuelLiters != null) 'fuel_liters': fuelLiters,
        if (followedPredictionId != null) 'followed_prediction_id': followedPredictionId,
      });
      return TripLogModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Trip could not be saved', e.response?.statusCode);
    }
  }

  @override
  Future<String> uploadPhoto(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(ApiEndpoints.logbookPhotos, data: formData);
      return response.data['url'] as String;
    } on DioException catch (e) {
      throw ServerException('Photo upload failed', e.response?.statusCode);
    }
  }
}
