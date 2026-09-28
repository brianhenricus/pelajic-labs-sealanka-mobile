import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/pfz/data/models/pfz_pick_model.dart';

abstract class PfzRemoteDataSource {
  /// species omitted returns all 4 species for that day. An empty list is a
  /// valid, expected response (nothing passed the model's safety gates that
  /// day) — not an error.
  Future<List<PfzPickModel>> getPicksForDate(DateTime date, {String? species});
  Future<PfzPickModel> getPickDetail(String pickId);
}

class PfzRemoteDataSourceImpl implements PfzRemoteDataSource {
  final Dio _dio;
  PfzRemoteDataSourceImpl(this._dio);

  @override
  Future<List<PfzPickModel>> getPicksForDate(DateTime date, {String? species}) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await _dio.get(ApiEndpoints.pfzZones, queryParameters: {
        'date': dateStr,
        if (species != null) 'species': species,
      });
      final list = response.data as List<dynamic>;
      return list
          .map((e) => PfzPickModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException('PFZ data unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<PfzPickModel> getPickDetail(String pickId) async {
    try {
      final response = await _dio
          .get(ApiEndpoints.pfzZoneDetail.replaceAll('{id}', pickId));
      return PfzPickModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException('Pick detail unavailable', e.response?.statusCode);
    }
  }
}
