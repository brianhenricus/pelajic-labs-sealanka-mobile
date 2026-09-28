import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sea_lanka/core/device/device_id_provider.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/network/api_client.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:sea_lanka/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:sea_lanka/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sea_lanka/features/auth/domain/repositories/auth_repository.dart';
import 'package:sea_lanka/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:sea_lanka/features/auth/domain/usecases/login_usecase.dart';
import 'package:sea_lanka/features/auth/domain/usecases/login_with_google_usecase.dart';
import 'package:sea_lanka/features/auth/domain/usecases/logout_usecase.dart';
import 'package:sea_lanka/features/auth/domain/usecases/signup_usecase.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sea_lanka/features/home/data/datasources/home_remote_datasource.dart';
import 'package:sea_lanka/features/home/data/repositories/home_repository_impl.dart';
import 'package:sea_lanka/features/home/domain/repositories/home_repository.dart';
import 'package:sea_lanka/features/home/domain/usecases/get_fishing_condition_usecase.dart';
import 'package:sea_lanka/features/home/domain/usecases/get_weather_summary_usecase.dart';
import 'package:sea_lanka/features/home/presentation/bloc/home_bloc.dart';
import 'package:sea_lanka/features/pfz/data/datasources/pfz_remote_datasource.dart';
import 'package:sea_lanka/features/pfz/data/repositories/pfz_repository_impl.dart';
import 'package:sea_lanka/features/pfz/domain/repositories/pfz_repository.dart';
import 'package:sea_lanka/features/pfz/domain/usecases/get_zone_detail_usecase.dart';
import 'package:sea_lanka/features/pfz/domain/usecases/get_zones_for_date_usecase.dart';
import 'package:sea_lanka/features/pfz/presentation/bloc/pfz_bloc.dart';
import 'package:sea_lanka/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:sea_lanka/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:sea_lanka/features/profile/domain/repositories/profile_repository.dart';
import 'package:sea_lanka/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:sea_lanka/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:sea_lanka/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:sea_lanka/features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'package:sea_lanka/features/alerts/data/repositories/alerts_repository_impl.dart';
import 'package:sea_lanka/features/alerts/domain/repositories/alerts_repository.dart';
import 'package:sea_lanka/features/alerts/domain/usecases/get_alerts_usecase.dart';
import 'package:sea_lanka/features/alerts/presentation/bloc/alerts_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  const storage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => storage);
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Core
  final apiClient = ApiClient(storage);
  sl.registerLazySingleton<Dio>(() => apiClient.dio);
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton<LocationService>(() => LocationServiceImpl());
  sl.registerLazySingleton<DeviceIdProvider>(() => DeviceIdProvider(sl()));

  // Hive box
  final userBox = await Hive.openBox('user');
  sl.registerLazySingleton(() => userBox);

  _registerAuth();
  _registerHome();
  _registerPfz();
  _registerProfile();
  _registerAlerts();
}

void _registerAlerts() {
  sl.registerFactory(() => AlertsBloc(getAlerts: sl()));
  sl.registerLazySingleton(() => GetAlertsUseCase(sl()));
  sl.registerLazySingleton<AlertsRepository>(
      () => AlertsRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()));
  sl.registerLazySingleton<AlertsRemoteDataSource>(
      () => AlertsRemoteDataSourceImpl(sl()));
}

void _registerProfile() {
  sl.registerFactory(() => ProfileBloc(getProfile: sl(), updateProfile: sl()));
  sl.registerLazySingleton(() => GetProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()));
  sl.registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(sl()));
}

void _registerAuth() {
  // BLoC
  sl.registerFactory(() => AuthBloc(
        loginUseCase: sl(),
        loginWithGoogleUseCase: sl(),
        signupUseCase: sl(),
        logoutUseCase: sl(),
        getCurrentUserUseCase: sl(),
      ));

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => LoginWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => SignupUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // Repository
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        networkInfo: sl(),
      ));

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl(), sl()));
  sl.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(sl(), sl()));
}

void _registerHome() {
  sl.registerFactory(() => HomeBloc(
        getWeatherSummary: sl(),
        getFishingCondition: sl(),
      ));

  sl.registerLazySingleton(() => GetWeatherSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetFishingConditionUseCase(sl()));

  sl.registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()));
  sl.registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(sl()));
}

void _registerPfz() {
  sl.registerFactory(() => PfzBloc(
        getZonesForDate: sl(),
        getZoneDetail: sl(),
      ));

  sl.registerLazySingleton(() => GetZonesForDateUseCase(sl()));
  sl.registerLazySingleton(() => GetZoneDetailUseCase(sl()));

  sl.registerLazySingleton<PfzRepository>(
      () => PfzRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()));
  sl.registerLazySingleton<PfzRemoteDataSource>(
      () => PfzRemoteDataSourceImpl(sl()));
}
