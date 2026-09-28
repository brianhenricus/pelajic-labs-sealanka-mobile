import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/solunar/data/models/solunar_snapshot_model.dart';

abstract class SolunarRemoteDataSource {
  Future<SolunarSnapshotModel> getSolunar(
      {required double lat, required double lon, DateTime? date});
}

class SolunarRemoteDataSourceImpl implements SolunarRemoteDataSource {
  final Dio _dio;
  SolunarRemoteDataSourceImpl(this._dio);

  @override
  Future<SolunarSnapshotModel> getSolunar(
      {required double lat, required double lon, DateTime? date}) async {
    try {
      final d = date ?? DateTime.now();
      final dateStr =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final response = await _dio.get(ApiEndpoints.solunarData,
          queryParameters: {'lat': lat, 'lon': lon, 'date': dateStr});
      return SolunarSnapshotModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Solunar data unavailable', e.response?.statusCode);
    }
  }
}
