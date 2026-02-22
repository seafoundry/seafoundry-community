// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/reporting_hub/permits_tab_state.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/repositories/permit_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit for managing permits list in the Reporting Hub Permits tab.
class PermitsTabCubit extends Cubit<PermitsTabState>
    with CubitStreamSubscriptionMixin {
  PermitsTabCubit({
    required PermitRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const PermitsTabState());

  final PermitRepository _repository;
  final String _organizationId;

  /// Start watching permits for the organization
  void watchPermits() {
    emit(state.copyWith(loading: true, errorMessage: null));
    listenWithKey<List<Permit>>(
      'permits',
      _repository.watchPermits(_organizationId),
      onData: (permits) {
        if (!isClosed) {
          emit(state.copyWith(permits: permits, loading: false));
        }
      },
      onError: (error, stackTrace) {
        if (!isClosed) {
          LoggingService.instance.error(
            'PermitsTabCubit: Error watching permits',
            error,
            stackTrace,
          );
          emit(state.copyWith(
            loading: false,
            errorMessage: 'Failed to load permits: $error',
          ));
        }
      },
    );
  }
}
