part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class ProfileRequested extends ProfileEvent {
  const ProfileRequested();
}

class ProfileUpdateRequested extends ProfileEvent {
  final Map<String, dynamic> patch;
  const ProfileUpdateRequested(this.patch);

  @override
  List<Object?> get props => [patch];
}
