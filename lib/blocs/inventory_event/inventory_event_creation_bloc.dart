// @tier: community
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:seafoundry_app/blocs/inventory_event/inventory_event_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/logging_service.dart';

enum InventoryEventFlow {
  population,
  sizeChange,
  propagationReady,
}

class InventoryEventCreationBloc
    extends RecordFormBloc<Event, InventoryEventFormState> {
  InventoryEventCreationBloc.populationLoss({
    required OrganismRecord organism,
    required OrganismRecordRepository organismRepository,
  }) : _organismRepository = organismRepository,
       _organism = organism,
       _flow = InventoryEventFlow.population,
       _initialState = InventoryEventFormState.populationLossOrganism(
         organism: organism,
       ),
       super(
         InventoryEventFormState.populationLossOrganism(organism: organism),
       );

  InventoryEventCreationBloc.organismSize({
    required OrganismRecordRepository organismRepository,
    required OrganismRecord organism,
    StatusEvent? ongoingEvent,
  }) : _organismRepository = organismRepository,
       _organism = organism,
       _flow = InventoryEventFlow.sizeChange,
       _initialState = InventoryEventFormState.organismSize(
         organism: organism,
         ongoingEvent: ongoingEvent,
       ),
       super(
         InventoryEventFormState.organismSize(
           organism: organism,
           ongoingEvent: ongoingEvent,
         ),
       );

  InventoryEventCreationBloc.organismPropagationReady({
    required OrganismRecordRepository organismRepository,
    required OrganismRecord organism,
    StatusEvent? ongoingEvent,
  }) : _organismRepository = organismRepository,
       _organism = organism,
       _flow = InventoryEventFlow.propagationReady,
       _initialState = InventoryEventFormState.organismPropagationReady(
         organism: organism,
         ongoingEvent: ongoingEvent,
       ),
       super(
         InventoryEventFormState.organismPropagationReady(
           organism: organism,
           ongoingEvent: ongoingEvent,
         ),
       );

  final OrganismRecordRepository _organismRepository;
  final OrganismRecord _organism;
  final InventoryEventFlow _flow;
  final InventoryEventFormState _initialState;

  /// The organism record being edited
  OrganismRecord get organism => _organism;

  /// The repository for organism record operations
  OrganismRecordRepository get organismRepository => _organismRepository;

  @override
  InventoryEventFormState get initialState {
    return _initialState;
  }

  @override
  Future<Event?> createRecord() async {
    switch (_flow) {
      case InventoryEventFlow.propagationReady:
        return _createPropagationReadyEvent();
      case InventoryEventFlow.sizeChange:
        return _createSizeChangeEvent();
      case InventoryEventFlow.population:
        return _createPopulationEvent();
    }
  }

  Future<Event?> _createPropagationReadyEvent() async {
    // Handle propagation ready status updates
    final isSetting = state.ongoingEvent == null && !_organism.readyForPropagation;

    final payload = await _organismRepository.updatePropagationReadyStatus(
      _organism,
      isSetting,
      comment: state.comment?.value,
    );

    return payload.event;
  }

  Future<Event?> _createSizeChangeEvent() async {
    if (kDebugMode) {
      LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent called - organism.id: ${_organism.id}, organism.slug: ${_organism.slug}, organism.organizationId: ${_organism.organizationId}');
    }

    final newSize = _buildSizeSpecFromState();
    if (kDebugMode) {
      LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - newSize: $newSize');
    }

    if (newSize.isEmpty) {
      if (kDebugMode) {
        LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - newSize is empty');
      }
      throw RepositoryError(
        message: 'Enter a size class before submitting.',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Enter a size class.',
      );
    }

    final currentSize = _organism.sizeSpec;
    if (kDebugMode) {
      LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - currentSize: $currentSize');
    }
    if (newSize == currentSize) {
      if (kDebugMode) {
        LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - newSize == currentSize');
      }
      throw RepositoryError(
        message: 'New size must differ from the current size.',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Change the size class.',
      );
    }

    if (newSize.measuredDimension != null &&
        newSize.dimensionUnit == null) {
      if (kDebugMode) {
        LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - measuredDimension without unit');
      }
      // Guard dimension unit when dimension is specified.
      throw RepositoryError(
        message: 'Measured values require a unit.',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Update the record to include a unit.',
      );
    }

    if (kDebugMode) {
      LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - Calling _organismRepository.updateSize...');
    }
    try {
      final payload = await _organismRepository.updateSize(
        _organism,
        newSize,
        comment: state.comment?.value,
      );
      if (kDebugMode) {
        LoggingService.instance.debug('InventoryEventCreationBloc._createSizeChangeEvent - updateSize succeeded, event.id: ${payload.event.id}');
      }

      updatedOrganismRecord = payload.updatedRecord;
      return payload.event;
    } catch (e, stackTrace) {
      LoggingService.instance.error('InventoryEventCreationBloc._createSizeChangeEvent - updateSize FAILED', e, stackTrace);
      rethrow;
    }
  }

  Future<Event?> _createPopulationEvent() async {
    // Handle population loss/gain
    final newQuantity = state.quantity!.value!;

    final payload = await _organismRepository.updatePopulation(
      _organism,
      newQuantity,
      lossReason: state.populationLossReason?.value,
      mortalityReason: state.mortalityReason?.value,
      diseaseType: state.diseaseType?.value,
      gainReason: state.populationGainReason?.value,
      comment: state.comment?.value,
    );

    // Store updated organism for external access
    updatedOrganismRecord = payload.updatedRecord;

    return payload.event;
  }

  /// Holds the updated organism after population changes for propagation
  OrganismRecord? updatedOrganismRecord;

  SizeSpec _buildSizeSpecFromState() {
    final sizeClass = state.sizeClass?.value?.trim();
    final measuredDimension = state.measuredDimension?.value;
    final unit = state.dimensionUnit?.value;

    // Prefer measuredDimension + dimensionUnit for size tracking; fall back to size class only.
    return SizeSpec(
      sizeClass: (sizeClass == null || sizeClass.isEmpty) ? null : sizeClass,
      measuredDimension: measuredDimension,
      dimensionUnit: measuredDimension != null ? unit : null,
    );
  }
}
