import 'package:equatable/equatable.dart';

class OceanCurrent extends Equatable {
  final double speedKnots;
  final double directionDeg;
  // Nullable: no SST/salinity source may be cached yet, or (for salinity)
  // none exists at all -- the backend never fabricates a reading, so
  // neither does this model. Null means "unknown," not zero.
  final double? seaSurfaceTempC;
  final double? salinityPpt;
  final DateTime updatedAt;

  const OceanCurrent({
    required this.speedKnots,
    required this.directionDeg,
    required this.seaSurfaceTempC,
    required this.salinityPpt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [speedKnots, directionDeg, seaSurfaceTempC, salinityPpt];
}
