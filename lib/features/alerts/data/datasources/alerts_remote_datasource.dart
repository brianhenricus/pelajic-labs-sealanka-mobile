import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/alerts/data/models/safety_alert_model.dart';

abstract class AlertsRemoteDataSource {
  Future<List<SafetyAlertModel>> getAlerts();
}

class AlertsRemoteDataSourceImpl implements AlertsRemoteDataSource {
  final Dio _dio;
  AlertsRemoteDataSourceImpl(this._dio);

  @override
  Future<List<SafetyAlertModel>> getAlerts() async {
    try {
      final response = await _dio.get(ApiEndpoints.safetyAlerts);
      final list = response.data as List<dynamic>;
      return list
          .map((e) => SafetyAlertModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException('Safety alerts unavailable', e.response?.statusCode);
    }
  }
}
