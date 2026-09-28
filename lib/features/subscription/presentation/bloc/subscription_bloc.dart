import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sea_lanka/features/subscription/domain/entities/subscription_plan.dart';
import 'package:sea_lanka/features/subscription/domain/usecases/get_plans_usecase.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final GetPlansUseCase getPlans;

  SubscriptionBloc({required this.getPlans}) : super(SubscriptionInitial()) {
    on<PlansRequested>(_on);
  }

  Future<void> _on(
      PlansRequested event, Emitter<SubscriptionState> emit) async {
    emit(SubscriptionLoading());
    final result = await getPlans();
    result.fold(
      (failure) => emit(SubscriptionError(failure.message)),
      (result) => emit(SubscriptionLoaded(
          result.plans, result.trialEndsAt, result.isTrialActive)),
    );
  }
}
