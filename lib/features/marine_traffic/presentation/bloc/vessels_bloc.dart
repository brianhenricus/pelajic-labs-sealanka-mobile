import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/marine_traffic/domain/entities/vessel.dart';
import 'package:sea_lanka/features/marine_traffic/domain/usecases/get_vessels_usecase.dart';

part 'vessels_event.dart';
part 'vessels_state.dart';

// This is a country-wide activity map (see marine_traffic_page.dart), not a
// "near me" view -- must reach at least as far as the PFZ map's EEZ box
// (lat ~2.5-11.5, lon ~77-85) from the Sri Lanka centroid used in
// marine_traffic_page.dart. 700km covers that with margin; the backend's
// ingested data (gfw_source.BBOX_GEOJSON) already spans this whole area.
const _defaultRadiusKm = 700.0;

class VesselsBloc extends Bloc<VesselsEvent, VesselsState> {
  final GetVesselsUseCase getVessels;

  VesselsBloc({required this.getVessels}) : super(VesselsInitial()) {
    on<VesselsRequested>(_on);
  }

  Future<void> _on(VesselsRequested event, Emitter<VesselsState> emit) async {
    emit(VesselsLoading());
    final result = await getVessels(lat: event.lat, lon: event.lon, radiusKm: _defaultRadiusKm);
    result.fold(
      (failure) => emit(VesselsError(failure.message)),
      (snapshot) => emit(VesselsLoaded(snapshot)),
    );
  }
}
