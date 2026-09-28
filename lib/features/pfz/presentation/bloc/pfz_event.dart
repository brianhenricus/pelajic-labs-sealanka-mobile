part of 'pfz_bloc.dart';

abstract class PfzEvent extends Equatable {
  const PfzEvent();
  @override
  List<Object?> get props => [];
}

class PfzZonesRequested extends PfzEvent {
  final DateTime date;
  final String? species;
  const PfzZonesRequested(this.date, {this.species});
  @override
  List<Object?> get props => [date, species];
}

class PfzZoneDetailRequested extends PfzEvent {
  final String zoneId;
  const PfzZoneDetailRequested(this.zoneId);
  @override
  List<Object> get props => [zoneId];
}
