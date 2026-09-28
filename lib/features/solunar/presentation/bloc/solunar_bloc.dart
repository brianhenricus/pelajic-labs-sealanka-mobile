import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/solunar/domain/entities/solunar_snapshot.dart';
import 'package:sea_lanka/features/solunar/domain/usecases/get_solunar_usecase.dart';

part 'solunar_event.dart';
part 'solunar_state.dart';

class SolunarBloc extends Bloc<SolunarEvent, SolunarState> {
  final GetSolunarUseCase getSolunar;

  SolunarBloc({required this.getSolunar}) : super(SolunarInitial()) {
    on<SolunarRequested>(_on);
  }

  Future<void> _on(SolunarRequested event, Emitter<SolunarState> emit) async {
    emit(SolunarLoading());
    final result = await getSolunar(lat: event.lat, lon: event.lon);
    result.fold(
      (failure) => emit(SolunarError(failure.message)),
      (snapshot) => emit(SolunarLoaded(snapshot)),
    );
  }
}
