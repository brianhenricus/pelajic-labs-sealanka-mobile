import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/wind/data/models/wind_data_model.dart';

abstract class WindRemoteDataSource {
  Future<WindDataModel> getCurrentWind({required double lat, required double lon});
}

class WindRemoteDataSourceImpl implements WindRemoteDataSource {
  final Dio _dio;
  WindRemoteDataSourceImpl(this._dio);

  @override
  Future<WindDataModel> getCurrentWind({required double lat, required double lon}) async {
    try {
      final response = await _dio.get(ApiEndpoints.windData,
          queryParameters: {'lat': lat, 'lon': lon});
      return WindDataModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Wind data unavailable', e.response?.statusCode);
    }
  }
}
