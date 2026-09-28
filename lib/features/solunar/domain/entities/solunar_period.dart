import 'package:equatable/equatable.dart';

class SolunarPeriod extends Equatable {
  final DateTime start;
  final DateTime end;
  final bool isMajor;
  final int rating;

  const SolunarPeriod({
    required this.start,
    required this.end,
    required this.isMajor,
    required this.rating,
  });

  @override
  List<Object> get props => [start, end, isMajor, rating];
}
