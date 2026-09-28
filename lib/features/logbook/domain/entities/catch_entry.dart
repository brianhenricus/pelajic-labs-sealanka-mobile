import 'package:equatable/equatable.dart';

class CatchEntry extends Equatable {
  final String species;
  final double weightKg;
  final int quantity;

  const CatchEntry({
    required this.species,
    required this.weightKg,
    required this.quantity,
  });

  @override
  List<Object?> get props => [species, weightKg, quantity];
}
