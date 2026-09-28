import 'package:dio/dio.dart';
import 'package:sea_lanka/core/error/exceptions.dart';
import 'package:sea_lanka/core/network/api_endpoints.dart';
import 'package:sea_lanka/features/subscription/data/models/subscription_plan_model.dart';

abstract class SubscriptionRemoteDataSource {
  Future<SubscriptionPlansResultModel> getPlans();
  Future<MySubscriptionModel> getMySubscription();
  Future<void> subscribe(String planId, {String? paymentMethodToken});
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final Dio _dio;
  SubscriptionRemoteDataSourceImpl(this._dio);

  @override
  Future<SubscriptionPlansResultModel> getPlans() async {
    try {
      final response = await _dio.get(ApiEndpoints.subscriptionPlans);
      return SubscriptionPlansResultModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
          'Subscription plans unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<MySubscriptionModel> getMySubscription() async {
    try {
      final response = await _dio.get(ApiEndpoints.mySubscription);
      return MySubscriptionModel.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ServerException(
          'Subscription status unavailable', e.response?.statusCode);
    }
  }

  @override
  Future<void> subscribe(String planId, {String? paymentMethodToken}) async {
    try {
      await _dio.post(ApiEndpoints.subscribe, data: {
        'plan_id': planId,
        'payment_method_token': paymentMethodToken,
      });
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['detail'] ?? 'Subscription failed',
          e.response?.statusCode);
    }
  }
}
