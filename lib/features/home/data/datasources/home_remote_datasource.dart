import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/home/data/models/fishing_condition_model.dart';
import 'package:sea_lanka/features/home/data/models/weather_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<WeatherSummaryModel> getWeatherSummary(
      {required double lat, required double lon});
  Future<FishingConditionModel> getFishingCondition(
      {required double lat, required double lon});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final Dio _dio;
  HomeRemoteDataSourceImpl(this._dio);

  @override
  Future<WeatherSummaryModel> getWeatherSummary(
      {required double lat, required double lon}) async {
    try {
      final response = await _dio.get(ApiEndpoints.weatherSummary,
          queryParameters: {'lat': lat, 'lon': lon});
      return WeatherSummaryModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Weather data unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<FishingConditionModel> getFishingCondition(
      {required double lat, required double lon}) async {
    try {
      final response = await _dio.get(ApiEndpoints.fishingCondition,
          queryParameters: {'lat': lat, 'lon': lon});
      return FishingConditionModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
          'Fishing condition unavailable', e.response?.statusCode);
    }
  }
}
