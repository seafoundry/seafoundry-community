// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/reporting_hub/funders_tab_state.dart';
import 'package:seafoundry_app/models/operations/funder.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';
import 'package:seafoundry_app/repositories/deliverable_repository.dart';
import 'package:seafoundry_app/repositories/funder_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit for managing funders list in the Reporting Hub Funders tab.
class FundersTabCubit extends Cubit<FundersTabState>
    with CubitStreamSubscriptionMixin {
  FundersTabCubit({
    required FunderRepository funderRepository,
    required DeliverableRepository deliverableRepository,
    required String organizationId,
  })  : _funderRepository = funderRepository,
        _deliverableRepository = deliverableRepository,
        _organizationId = organizationId,
        super(const FundersTabState());

  final FunderRepository _funderRepository;
  final DeliverableRepository _deliverableRepository;
  final String _organizationId;

  /// Start watching funders for the organization
  void watchFunders() {
    emit(state.copyWith(loading: true, errorMessage: null));
    listenWithKey<List<Funder>>(
      'funders',
      _funderRepository.watchFunders(_organizationId),
      onData: (funders) {
        if (!isClosed) {
          emit(state.copyWith(funders: funders, loading: false));
        }
      },
      onError: (error, stackTrace) {
        if (!isClosed) {
          LoggingService.instance.error(
            'FundersTabCubit: Error watching funders',
            error,
            stackTrace,
          );
          emit(state.copyWith(
            loading: false,
            errorMessage: 'Failed to load funders: $error',
          ));
        }
      },
    );
  }

  /// Toggle expansion state for a funder
  void toggleExpanded(String funderId) {
    final expanded = Set<String>.from(state.expandedFunderIds);
    if (expanded.contains(funderId)) {
      expanded.remove(funderId);
      // Cancel deliverable subscription when collapsing
      cancelSubscription('deliverables_$funderId');
    } else {
      expanded.add(funderId);
      // Start loading deliverables when expanding
      _watchFunderDeliverables(funderId);
    }
    emit(state.copyWith(expandedFunderIds: expanded));
  }

  /// Watch deliverables for a specific funder
  void _watchFunderDeliverables(String funderId) {
    final loadingSet = Set<String>.from(state.loadingDeliverables)
      ..add(funderId);
    emit(state.copyWith(loadingDeliverables: loadingSet));

    listenWithKey<List<Deliverable>>(
      'deliverables_$funderId',
      _deliverableRepository.watchByFunder(_organizationId, funderId),
      onData: (deliverables) {
        if (!isClosed) {
          final updatedMap =
              Map<String, List<Deliverable>>.from(state.funderDeliverables);
          updatedMap[funderId] = deliverables;

          final updatedLoading = Set<String>.from(state.loadingDeliverables)
            ..remove(funderId);

          emit(state.copyWith(
            funderDeliverables: updatedMap,
            loadingDeliverables: updatedLoading,
          ));
        }
      },
      onError: (error, stackTrace) {
        if (!isClosed) {
          LoggingService.instance.error(
            'FundersTabCubit: Error watching deliverables for funder $funderId',
            error,
            stackTrace,
          );
          final updatedLoading = Set<String>.from(state.loadingDeliverables)
            ..remove(funderId);
          emit(state.copyWith(loadingDeliverables: updatedLoading));
        }
      },
    );
  }
}
