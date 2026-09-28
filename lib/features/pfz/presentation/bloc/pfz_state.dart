part of 'pfz_bloc.dart';

abstract class PfzState extends Equatable {
  const PfzState();
  @override
  List<Object?> get props => [];
}

class PfzInitial extends PfzState {}

class PfzLoading extends PfzState {}

class PfzZonesLoaded extends PfzState {
  final List<PfzPick> zones;
  final DateTime selectedDate;
  final PfzPick? selectedZone;

  const PfzZonesLoaded({
    required this.zones,
    required this.selectedDate,
    this.selectedZone,
  });

  PfzZonesLoaded copyWith({
    List<PfzPick>? zones,
    DateTime? selectedDate,
    PfzPick? selectedZone,
  }) =>
      PfzZonesLoaded(
        zones: zones ?? this.zones,
        selectedDate: selectedDate ?? this.selectedDate,
        selectedZone: selectedZone ?? this.selectedZone,
      );

  @override
  List<Object?> get props => [zones, selectedDate, selectedZone];
}

class PfzError extends PfzState {
  final String message;
  const PfzError(this.message);
  @override
  List<Object> get props => [message];
}
