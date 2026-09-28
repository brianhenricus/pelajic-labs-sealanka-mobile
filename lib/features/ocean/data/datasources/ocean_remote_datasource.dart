import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/ocean/data/models/ocean_current_model.dart';
import 'package:sea_lanka/features/ocean/data/models/tide_prediction_model.dart';

abstract class OceanRemoteDataSource {
  Future<OceanCurrentModel> getCurrent({required double lat, required double lon});
  Future<List<TidePredictionModel>> getTides({required double lat, required double lon});
}

class OceanRemoteDataSourceImpl implements OceanRemoteDataSource {
  final Dio _dio;
  OceanRemoteDataSourceImpl(this._dio);

  @override
  Future<OceanCurrentModel> getCurrent({required double lat, required double lon}) async {
    try {
      final response = await _dio.get(ApiEndpoints.oceanCurrents,
          queryParameters: {'lat': lat, 'lon': lon});
      return OceanCurrentModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
          'Ocean current unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<List<TidePredictionModel>> getTides({required double lat, required double lon}) async {
    try {
      final response = await _dio.get(ApiEndpoints.tidePredictions,
          queryParameters: {'lat': lat, 'lon': lon});
      return (response.data as List)
          .map((e) => TidePredictionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException(
          'Tide predictions unavailable', e.response?.statusCode);
    }
  }
}
