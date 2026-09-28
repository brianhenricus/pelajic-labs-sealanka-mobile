import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';

class CatchEntryModel extends CatchEntry {
  const CatchEntryModel({
    required super.species,
    required super.weightKg,
    required super.quantity,
  });

  factory CatchEntryModel.fromJson(Map<String, dynamic> json) =>
      CatchEntryModel(
        species: json['species'] as String,
        weightKg: (json['weight_kg'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {
        'species': species,
        'weight_kg': weightKg,
        'quantity': quantity,
      };
}
