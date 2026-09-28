import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/marine_traffic/data/models/vessels_snapshot_model.dart';

abstract class VesselsRemoteDataSource {
  Future<VesselsSnapshotModel> getVessels({
    required double lat,
    required double lon,
    required double radiusKm,
  });
}

class VesselsRemoteDataSourceImpl implements VesselsRemoteDataSource {
  final Dio _dio;
  VesselsRemoteDataSourceImpl(this._dio);

  @override
  Future<VesselsSnapshotModel> getVessels({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    try {
      final response = await _dio.get(ApiEndpoints.vessels, queryParameters: {
        'lat': lat,
        'lon': lon,
        'radius_km': radiusKm,
      });
      return VesselsSnapshotModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Vessel data unavailable', e.response?.statusCode);
    }
  }
}
