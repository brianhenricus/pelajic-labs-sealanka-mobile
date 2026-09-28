import 'package:equatable/equatable.dart';

/// Gridded AIS fishing-effort presence for one grid cell/day/flag -- NOT a
/// live per-vessel position. The backend (Global Fishing Watch) has no raw
/// live-position endpoint; this is what's actually available. Replaces the
/// old dead `Vessel` entity (mmsi/speed/course), which described a shape
/// the backend never provided and no code ever populated.
class FishingEffortCell extends Equatable {
  final String date;
  final String flag;
  final double lat;
  final double lon;
  final double fishingHours;
  final int vesselCount;

  const FishingEffortCell({
    required this.date,
    required this.flag,
    required this.lat,
    required this.lon,
    required this.fishingHours,
    required this.vesselCount,
  });

  @override
  List<Object?> get props => [date, flag, lat, lon, fishingHours, vesselCount];
}

class VesselsSnapshot extends Equatable {
  final List<FishingEffortCell> cells;
  final DateTime? asOf;
  final String attribution;

  const VesselsSnapshot({
    required this.cells,
    required this.asOf,
    required this.attribution,
  });

  @override
  List<Object?> get props => [cells, asOf, attribution];
}
