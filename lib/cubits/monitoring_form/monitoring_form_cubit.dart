// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/monitoring/organism_monitoring_data.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/monitoring_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

part 'monitoring_form_state.dart';

class MonitoringFormCubit extends Cubit<MonitoringFormState> {
  MonitoringFormCubit({
    required MonitoringService monitoringService,
    required GraphNode node,
    required CurrentUser currentUserCubit,
    OrganismContext? organismContext,
  }) : organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       _monitoringService = monitoringService,
       _node = node,
       _currentUserCubit = currentUserCubit,
       super(const MonitoringFormState());

  final OrganismContext organismContext;
  final MonitoringService _monitoringService;
  final GraphNode _node;
  final CurrentUser _currentUserCubit;

  void healthStatusChanged(HealthStatus? status) {
    emit(state.copyWith(selectedHealthStatus: status, errorMessage: null));
  }

  void notesChanged(String value) {
    emit(state.copyWith(notes: value));
  }

  void tagChanged(String value) {
    emit(state.copyWith(tag: value));
  }

  Future<void> submit() async {
    if (state.submissionStatus == MonitoringFormSubmissionStatus.submitting) {
      return;
    }

    // CRITICAL: Set submitting status IMMEDIATELY to prevent double-submit
    emit(
      state.copyWith(
        submissionStatus: MonitoringFormSubmissionStatus.submitting,
        errorMessage: null,
      ),
    );

    // Now perform validation
    if (state.selectedHealthStatus == null) {
      emit(
        state.copyWith(
          errorMessage: 'Please select a health status',
          submissionStatus: MonitoringFormSubmissionStatus.failure,
        ),
      );
      return;
    }

    try {
      final currentUserState = _currentUserCubit.state;
      if (currentUserState is! CurrentUserLoaded) {
        emit(
          state.copyWith(
            submissionStatus: MonitoringFormSubmissionStatus.failure,
            errorMessage: 'User not loaded',
          ),
        );
        return;
      }

      await _node.awaitLoaded();
      if (isClosed) return;
      if (_node.state is! GraphLoadedState) {
        emit(
          state.copyWith(
            submissionStatus: MonitoringFormSubmissionStatus.failure,
            errorMessage: 'Node data not loaded',
          ),
        );
        return;
      }

      final record = (_node.state as GraphLoadedState).record;

      // Support both OrganismRecord and legacy Coral types
      String speciesId = '';
      String speciesName = 'Unknown Species';
      String? morphologyId;
      String? physicalFormId;
      String genetId = '';
      HealthStatus oldHealthStatus =
          state.selectedHealthStatus ?? HealthStatus.healthy;
      String? siteId;

      if (record is OrganismRecord) {
        speciesId = record.speciesId ?? '';
        final species = SpeciesRegistry.globalById(speciesId);
        speciesName = species?.name ?? speciesId;
        morphologyId = species?.morphologyId;
        physicalFormId = record.physicalForm?.formId;
        genetId = GenetIdResolver.resolve(record) ?? record.id;
        oldHealthStatus = HealthStatus.fromId(
          record.metadata?['healthStatus'] as String? ?? 'healthy',
        );
        siteId = record.siteId;
      }

      final trimmedTag = state.tag.trim();

      final monitoringData = OrganismMonitoringData(
        organismId: record.id,
        recordName: record.name,
        speciesId: speciesId,
        speciesName: speciesName,
        genetId: genetId.isNotEmpty ? genetId : record.id,
        siteId: siteId,
        oldHealthStatus: oldHealthStatus,
        newHealthStatus: state.selectedHealthStatus,
        comment: state.notes.isNotEmpty ? state.notes : null,
        monitoringDate: DateTime.now(),
        tagId: trimmedTag.isEmpty ? null : trimmedTag,
        physicalForm: physicalFormId,
        morphologyId: morphologyId,
      );

      final result = await _monitoringService.createMonitoringEvent(
        node: _node,
        data: monitoringData,
      );
      if (isClosed) return;

      if (result == null) {
        emit(
          state.copyWith(
            submissionStatus: MonitoringFormSubmissionStatus.failure,
            errorMessage: 'Failed to create monitoring event',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          submissionStatus: MonitoringFormSubmissionStatus.success,
          errorMessage: null,
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to submit monitoring form',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          submissionStatus: MonitoringFormSubmissionStatus.failure,
          errorMessage: 'Error: ${e.toString()}',
        ),
      );
    }
  }
}
