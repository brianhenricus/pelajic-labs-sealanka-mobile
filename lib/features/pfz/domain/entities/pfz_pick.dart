import 'package:equatable/equatable.dart';

/// One ranked, safety-gated pinpoint from the PFZ v5 model for a single
/// species/day (replaces the old circular "zone" shape — the real backend
/// has no radius_km/depth_m/multi-species list, just a ranked point).
class PfzPick extends Equatable {
  final String id;
  final String species;
  final DateTime day;
  final int rank;
  final double lat;
  final double lon;

  /// Suitability score, NOT a chance of catching fish (holdout AUC
  /// 0.62-0.79 depending on species) — never label this "catch probability".
  final double calibratedProbability;
  final double distCoastKm;
  final int historyCount;

  /// Beyond this species' typical fished-distance envelope — a caveat to
  /// surface prominently, not just a boolean to ignore.
  final bool longRange;
  final String modelVersion;

  const PfzPick({
    required this.id,
    required this.species,
    required this.day,
    required this.rank,
    required this.lat,
    required this.lon,
    required this.calibratedProbability,
    required this.distCoastKm,
    required this.historyCount,
    required this.longRange,
    required this.modelVersion,
  });

  bool get isHighProbability => calibratedProbability >= 0.7;
  bool get isMidProbability =>
      calibratedProbability >= 0.4 && calibratedProbability < 0.7;

  @override
  List<Object> get props => [
        id,
        species,
        day,
        rank,
        lat,
        lon,
        calibratedProbability,
        longRange,
      ];
}

/// The 4 species PFZ v5 actually predicts — display metadata lives with the
/// presentation layer (pfz_species_ui.dart), this is just the canonical id
/// list/labels shared wherever species need naming (filters, API params).
class PfzSpecies {
  PfzSpecies._();

  static const yellowfin = 'yellowfin';
  static const skipjack = 'skipjack';
  static const bigeye = 'bigeye';
  static const billfish = 'billfish';

  static const all = [yellowfin, skipjack, bigeye, billfish];

  static String label(String species) => switch (species) {
        yellowfin => 'Yellowfin',
        skipjack => 'Skipjack',
        bigeye => 'Bigeye',
        billfish => 'Billfish',
        _ => species,
      };
}
