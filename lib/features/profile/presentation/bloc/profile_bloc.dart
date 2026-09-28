import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/profile/domain/entities/user_profile.dart';
import 'package:sea_lanka/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:sea_lanka/features/profile/domain/usecases/update_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase getProfile;
  final UpdateProfileUseCase updateProfile;

  ProfileBloc({required this.getProfile, required this.updateProfile})
      : super(ProfileInitial()) {
    on<ProfileRequested>(_onRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
  }

  Future<void> _onRequested(
      ProfileRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    final result = await getProfile();
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }

  Future<void> _onUpdateRequested(
      ProfileUpdateRequested event, Emitter<ProfileState> emit) async {
    emit(ProfileLoading());
    final result = await updateProfile(event.patch);
    result.fold(
      (failure) => emit(ProfileError(failure.message)),
      (profile) => emit(ProfileLoaded(profile)),
    );
  }
}
