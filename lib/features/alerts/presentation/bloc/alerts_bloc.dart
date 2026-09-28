import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/alerts/domain/entities/safety_alert.dart';
import 'package:sea_lanka/features/alerts/domain/usecases/get_alerts_usecase.dart';

part 'alerts_event.dart';
part 'alerts_state.dart';

class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  final GetAlertsUseCase getAlerts;

  AlertsBloc({required this.getAlerts}) : super(AlertsInitial()) {
    on<AlertsRequested>(_onRequested);
  }

  Future<void> _onRequested(
      AlertsRequested event, Emitter<AlertsState> emit) async {
    emit(AlertsLoading());
    final result = await getAlerts();
    result.fold(
      (failure) => emit(AlertsError(failure.message)),
      (alerts) => emit(AlertsLoaded(alerts)),
    );
  }
}
