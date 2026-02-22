// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/reporting_hub/deliverables_tab_state.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';
import 'package:seafoundry_app/repositories/deliverable_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit for managing deliverables list in the Reporting Hub Deliverables tab.
class DeliverablesTabCubit extends Cubit<DeliverablesTabState>
    with CubitStreamSubscriptionMixin {
  DeliverablesTabCubit({
    required DeliverableRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const DeliverablesTabState());

  final DeliverableRepository _repository;
  final String _organizationId;

  /// Start watching deliverables for the organization
  void watchDeliverables() {
    emit(state.copyWith(loading: true, errorMessage: null));
    listenWithKey<List<Deliverable>>(
      'deliverables',
      _repository.watchDeliverablesForOrg(_organizationId),
      onData: (deliverables) {
        if (!isClosed) {
          emit(state.copyWith(deliverables: deliverables, loading: false));
        }
      },
      onError: (error, stackTrace) {
        if (!isClosed) {
          LoggingService.instance.error(
            'DeliverablesTabCubit: Error watching deliverables',
            error,
            stackTrace,
          );
          emit(state.copyWith(
            loading: false,
            errorMessage: 'Failed to load deliverables: $error',
          ));
        }
      },
    );
  }

  /// Set status filter (null to show all)
  void setStatusFilter(DeliverableStatus? status) {
    if (status == null) {
      emit(state.copyWith(clearStatusFilter: true));
    } else {
      emit(state.copyWith(statusFilter: status));
    }
  }

  /// Mark report as generated for a deliverable
  Future<void> markReportGenerated(String deliverableId) async {
    try {
      await _repository.markReportGenerated(deliverableId);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'DeliverablesTabCubit: Failed to mark report generated',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Mark deliverable as complete
  Future<void> markComplete(String deliverableId) async {
    try {
      await _repository.updateDeliverableStatus(
        deliverableId,
        DeliverableStatus.completed,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'DeliverablesTabCubit: Failed to mark complete',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
