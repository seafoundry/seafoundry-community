// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/propagation/propagation_flow_event.dart';
import 'package:seafoundry_app/blocs/propagation/propagation_form_inputs.dart';
import 'package:seafoundry_app/blocs/propagation/propagation_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/events/propagation/propagation_event.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class PropagationBloc extends RecordFormBloc<PropagationEvent, PropagationState> {
  PropagationBloc({
    required this.organism,
    required this.site,
    required this.eventRepository,
    required this.organismRepository,
    required this.genetRepository,
    this.defaultGroupNode,
  }) : super(PropagationState.initial(organism)) {
    // Add event handlers for PropagationEvent
    on<PropagationOrganismsLoaded>(_onOrganismsLoaded);
    on<PropagationOrganismsLoadFailed>(_onOrganismsLoadFailed);
    on<PropagationOrganismToggled>(_onOrganismToggled);
    on<PropagationOrganismQuantityChanged>(_onOrganismQuantityChanged);
    on<PropagationFragmentsPerInputChanged>(_onFragmentsPerInputChanged);
    on<PropagationNewOrganismRowAdded>(_onNewOrganismRowAdded);
    on<PropagationNewOrganismRowRemoved>(_onNewOrganismRowRemoved);
    on<PropagationNewOrganismQuantityChanged>(_onNewOrganismQuantityChanged);
    on<PropagationNewRecordNameChanged>(_onNewRecordNameChanged);
    on<PropagationNewOrganismLocationChanged>(_onNewOrganismLocationChanged);
    on<PropagationPermitIdChanged>(_onPermitIdChanged);
    on<PropagationPermitTypeChanged>(_onPermitTypeChanged);
    on<PropagationIssuingAuthorityChanged>(_onIssuingAuthorityChanged);
    on<PropagationPermitAttachmentUrlsChanged>(
      _onPermitAttachmentUrlsChanged,
    );
    on<PropagationPermitValidFromChanged>(_onPermitValidFromChanged);
    on<PropagationPermitValidToChanged>(_onPermitValidToChanged);
    on<PropagationFiveAxisChanged>(_onFiveAxisChanged);

    // Load organisms when bloc is created
    _loadPropagationReadyOrganisms();
  }

  final OrganismRecord organism;
  final Site site;
  final EventRepository eventRepository;
  final OrganismRecordRepository organismRepository;
  final GenetRepository genetRepository;
  final GroupNode? defaultGroupNode;

  @override
  Future<void> close() async {
    await super.close();
  }

  @override
  PropagationState get initialState => PropagationState.initial(organism);

  @override
  Future<void> onInputEvent(
    RecordFormInputEvent event,
    Emitter<PropagationState> emit,
  ) async {
    if (event is PropagationFragmentsPerInputChanged) {
      _onFragmentsPerInputChanged(event, emit);
    } else {
      super.onInputEvent(event, emit);
    }
  }

  Future<void> _loadPropagationReadyOrganisms() async {
    try {
      // Ensure loading state has a chance to render before data resolves
      await Future<void>.microtask(() {});

      // Get genet ID from organism (top-level genetId or foreignKeys fallback)
      final genetId = GenetIdResolver.resolve(organism);
      if (genetId == null) {
        throw StateError('Organism has no genet ID');
      }

      // Get propagation ready events for this genet within the site
      final propagationReadyEvents = await eventRepository.getPropagationReadyEvents(
        genetId: genetId,
        siteUrlPath: site.urlPath,
      );

      final allOrganisms = await organismRepository.getAll();
      final allGenetOrganisms = allOrganisms
          .where((record) =>
              record.genetId == genetId &&
              record.organismKind == organism.organismKind)
          .toList();

      final siteOrganisms = allGenetOrganisms
          .where((record) => record.siteId == site.id)
          .toList();

      // Filter by validation rules, but allow organisms explicitly marked ready.
      final organisms = siteOrganisms
          .where(
            (record) =>
                record.validateForPropagation() == null ||
                record.readyForPropagation,
          )
          .toList();

      if (organisms.length != siteOrganisms.length) {
        LoggingService.instance.warning(
          'Filtered ${siteOrganisms.length - organisms.length} organisms not valid or ready for propagation',
        );
      }

      if (organisms.isEmpty) {
        LoggingService.instance.info(
          'No organisms available for propagation for genet $genetId in site ${site.id}. '
          'Check life stage (adult/broodstock) or propagation-ready status.',
        );
      }

      // Load the genet
      final genet = await genetRepository.getRecordForId(genetId);
      if (genet == null) {
        throw StateError('Genet not found for ID: $genetId');
      }

      if (isClosed) return;
      add(PropagationOrganismsLoaded(organisms, propagationReadyEvents, genet));
    } catch (e) {
      if (isClosed) return;
      add(PropagationOrganismsLoadFailed(e.toString()));
    }
  }

  void _onOrganismsLoaded(
    PropagationOrganismsLoaded event,
    Emitter<PropagationState> emit,
  ) {
    // Start with genetics from genet, but use organism's life stage as default
    // since we are propagating the current organism state (e.g. Adult)
    final provenanceSelection = ProvenanceLifeStageSelection.fromGenet(
      event.genet,
    ).copyWith(lifeStage: organism.lifeStage.stage);

    final defaultPhysicalFormId = _derivePhysicalFormId(event.genet);
    final defaultSizeSpec = _deriveSizeSpec();
    final loadedState = state.loaded(
      allOrganisms: event.organisms,
      propagationReadyEvents: event.propagationReadyEvents,
      initialOrganism: organism,
      genet: event.genet,
      provenanceSelection: provenanceSelection,
      selectedPhysicalFormId: defaultPhysicalFormId,
      sizeSpec: defaultSizeSpec,
    );
    final startStep = loadedState.organismSelection.isValid ? 1 : 0;
    final seededState = _seedNewOrganismRows(
      loadedState.copyWith(
        currentStepIndex: startStep,
        fragmentsPerInput: const PropagationFragmentsPerInputInput.dirty(
          1,
          minFragmentsPerInput: 1,
        ),
      ),
    );
    emit(seededState);
  }

  void _onOrganismsLoadFailed(
    PropagationOrganismsLoadFailed event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.withLoadError(event.error));
  }

  void _onOrganismToggled(
    PropagationOrganismToggled event,
    Emitter<PropagationState> emit,
  ) {
    final newSelection = state.organismSelection.toggleOrganism(event.organism);
    emit(state.updateOrganismSelection(newSelection));
  }

  void _onOrganismQuantityChanged(
    PropagationOrganismQuantityChanged event,
    Emitter<PropagationState> emit,
  ) {
    final updatedSelection =
        state.organismSelection.updateQuantity(event.organism, event.quantity);
    emit(state.updateOrganismSelection(updatedSelection));
  }

  void _onFragmentsPerInputChanged(
    PropagationFragmentsPerInputChanged event,
    Emitter<PropagationState> emit,
  ) {
    final value = event.value;
    final updatedState = state.updateFragmentsPerInput(value);
    emit(_seedNewOrganismRows(updatedState));
  }

  PropagationState _seedNewOrganismRows(PropagationState updatedState) {
    if (defaultGroupNode == null) {
      return updatedState;
    }
    return updatedState.seedNewOrganismIfEmpty(
      totalOutput: updatedState.totalOutputCount,
      groupNode: defaultGroupNode,
    );
  }

  void _onNewOrganismRowAdded(
    PropagationNewOrganismRowAdded event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.addNewOrganism());
  }

  void _onNewOrganismRowRemoved(
    PropagationNewOrganismRowRemoved event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.removeNewOrganism(event.index));
  }

  void _onNewOrganismQuantityChanged(
    PropagationNewOrganismQuantityChanged event,
    Emitter<PropagationState> emit,
  ) {
    final currentOrganism = state.newOrganisms[event.index];
    final updatedOrganism = currentOrganism.copyWith(quantity: event.quantity);
    emit(state.updateNewOrganism(event.index, updatedOrganism));
  }

  void _onNewRecordNameChanged(
    PropagationNewRecordNameChanged event,
    Emitter<PropagationState> emit,
  ) {
    final currentOrganism = state.newOrganisms[event.index];
    final updatedOrganism = currentOrganism.copyWith(
      recordName: event.recordName,
    );
    emit(state.updateNewOrganism(event.index, updatedOrganism));
  }

  void _onNewOrganismLocationChanged(
    PropagationNewOrganismLocationChanged event,
    Emitter<PropagationState> emit,
  ) {
    final currentOrganism = state.newOrganisms[event.index];
    final updatedOrganism = currentOrganism.copyWith(groupNode: event.groupNode);
    emit(state.updateNewOrganism(event.index, updatedOrganism));
  }

  void _onPermitIdChanged(
    PropagationPermitIdChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(permitId: event.value));
  }

  void _onPermitTypeChanged(
    PropagationPermitTypeChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(permitType: event.value));
  }

  void _onIssuingAuthorityChanged(
    PropagationIssuingAuthorityChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(issuingAuthority: event.value));
  }

  void _onPermitAttachmentUrlsChanged(
    PropagationPermitAttachmentUrlsChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(permitAttachmentUrls: event.value));
  }

  void _onPermitValidFromChanged(
    PropagationPermitValidFromChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(permitValidFrom: event.value));
  }

  void _onPermitValidToChanged(
    PropagationPermitValidToChanged event,
    Emitter<PropagationState> emit,
  ) {
    emit(state.copyWith(permitValidTo: event.value));
  }

  void _onFiveAxisChanged(
    PropagationFiveAxisChanged event,
    Emitter<PropagationState> emit,
  ) {
    // Allow the UI-driven life stage + physical form selections to flow through.
    // The selectors already constrain options based on organism + life stage.
    emit(
      state.copyWith(
        provenanceSelection: event.selection,
        selectedPhysicalFormId: event.physicalFormId,
        sizeSpec: event.sizeSpec,
      ),
    );
  }

  @override
  Future<PropagationEvent?> createRecord() async {
    try {
      final selectedOrganisms = state.organismSelection.selectedOrganisms.toList();
      final selectedQuantities = <String, int>{
        for (final organism in selectedOrganisms)
          organism.id: state.organismSelection.quantityFor(organism),
      };
      final inputQuantity = selectedQuantities.values.fold(
        0,
        (sum, value) => sum + value,
      );
      final selectedIds = selectedOrganisms.map((organism) => organism.id).toSet();

      for (final event in state.propagationReadyEvents.where(
        (readyEvent) => selectedIds.contains(readyEvent.recordId),
      )) {
        final concludedEvent = event.copyWith(
          concludedAt: DateTime.now().toIso8601String(),
        );
        await eventRepository.updateRecord(concludedEvent);
      }

      final permitMetadata = buildPermitMetadataFromTextInputs(
        permitIdText: state.permitId,
        permitTypeText: state.permitType,
        issuingAuthorityText: state.issuingAuthority,
        attachmentsText: state.permitAttachmentUrls,
        validFrom: state.permitValidFrom,
        validTo: state.permitValidTo,
        hadInitialPermit: false,
        isEditMode: false,
      );

      final baseParams = permitMetadata == null
          ? const EventBaseParams()
          : EventBaseParams(permitMetadata: permitMetadata);

      final canonicalMetadata = _buildCanonicalMetadata(
        selection: state.provenanceSelection,
        physicalFormId: state.selectedPhysicalFormId,
      );

      final outputOrganisms = await Future.wait(
        state.newOrganisms.map((organismInput) async {
          final measurement = PopulationMeasurement(
            value: organismInput.quantity.toDouble(),
            unit: MeasurementUnit.count,
          );
          // Build metadata with source organism tracking
          final propagationMetadata = <String, dynamic>{
            ...?canonicalMetadata,
            'sourceOrganismId': organism.id,
            'propagationEventDate': DateTime.now().toIso8601String(),
          };
          // Use localId from the input if provided, otherwise fall back to source organism
          final effectiveLocalId = organismInput.localId.isNotEmpty
              ? organismInput.localId.trim()
              : organism.localId?.trim();

          final newOrganism = OrganismRecord.partial(
            organismKind: organism.organismKind,
            speciesId: organism.speciesId,
            recordName: organismInput.recordName.trim(),
            localId: effectiveLocalId,
            measurement: measurement,
            lifeStage: LifeStageSpec(stage: state.provenanceSelection.lifeStage),
            foreignKeys: organism.foreignKeys, // Preserve genet ID
            genetId: organism.genetId, // Explicitly preserve genetId
            provenanceType: state.provenanceSelection.provenanceType, // Set proper field
            provenanceAttributes: organism.provenanceAttributes, // Preserve provenance attributes
            physicalForm: state.sizeSpec.sizeBandId != null
                ? PhysicalFormInstance(
                    formId: state.selectedPhysicalFormId,
                    sizeBandId: state.sizeSpec.sizeBandId!,
                  )
                : null, // Set proper field
            physicalFormConfigVersion: organism.physicalFormConfigVersion,
            sizeSpec: state.sizeSpec, // Set proper field
            metadata: propagationMetadata,
            organizationId: organism.organizationId,
            siteId: organism.siteId,
            groupId: organismInput.groupNode!.id,
          );

          // Use createRecord with parent group node
          final parentGroup = organismInput.groupNode!;
          final createdOrganism = await organismRepository.createRecord(
            newOrganism,
            parentGroup.currentRecord,
            base: baseParams,
          );
          return createdOrganism;
        }).toList(),
      );

      final outputQuantity = outputOrganisms.fold(
        0,
        (sum, organism) => sum + organism.organismQuantity,
      );
      final fragmentsPerInput = inputQuantity > 0
          ? outputQuantity / inputQuantity
          : null;

      final propagationEvent = await eventRepository.createPropagationEvent(
        site: site,
        inputOrganisms: selectedOrganisms,
        outputOrganisms: outputOrganisms,
        inputQuantityOverride: inputQuantity,
        additionalMetadata: {
          if (organism.speciesId != null) 'speciesId': organism.speciesId,
          if (fragmentsPerInput != null) 'fragmentsPerInput': fragmentsPerInput,
        },
        base: baseParams,
      );

      // Reduce quantity to 0 for input organisms (they've been propagated)
      await Future.wait(
        selectedOrganisms.map((inputOrganism) async {
          final available = inputOrganism.measurement.value.toInt();
          final selectedQuantity = selectedQuantities[inputOrganism.id] ?? available;
          final remaining =
              (available - selectedQuantity).clamp(0, available).toInt();
          final updatedOrganism = inputOrganism.copyWith(
            measurement: PopulationMeasurement(
              value: remaining.toDouble(),
              unit: MeasurementUnit.count,
            ),
            metadata: {
              ...?inputOrganism.metadata,
              if (remaining == 0)
                'lossReason': PopulationLossReason.propagated.name,
            },
          );
          await organismRepository.updateRecord(updatedOrganism);

          // Create explicit loss event for consistency and visibility
          if (selectedQuantity > 0) {
            await eventRepository.createPopulationLossEvent(
              recordId: inputOrganism.id,
              recordUrlPath: inputOrganism.urlPath,
              recordInternalPath: inputOrganism.internalPath,
              snapshot: inputOrganism,
              oldPopulation: available,
              newPopulation: remaining,
              lossReasonId: PopulationLossReason.propagated.id,
              comment: 'Propagated to create ${outputOrganisms.length} new records',
            );
          }
        }),
      );

      return propagationEvent;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to create propagation records', e, stackTrace);
      rethrow;
    }
  }

  String _derivePhysicalFormId(Genet genet) {
    final Map<String, dynamic> metadata = genet.metadata;
    if (metadata.isEmpty) {
      return 'fragment';
    }
    final primary = metadata['physicalFormId'];
    if (primary is String && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    return 'fragment';
  }

  SizeSpec _deriveSizeSpec() {
    return const SizeSpec();
  }

  Map<String, dynamic>? _buildCanonicalMetadata({
    required ProvenanceLifeStageSelection selection,
    required String physicalFormId,
  }) {
    final metadata = <String, dynamic>{
      'provenanceTypeId': selection.provenanceType.id,
      'provenanceType': selection.provenanceType.name,
      'provenanceTypeLabel': selection.provenanceType.metadata.displayName,
      'lifeStageId': selection.lifeStage.id,
      'lifeStage': selection.lifeStage.name,
      'lifeStageLabel': selection.lifeStage.displayName,
      'provenanceKind': selection.provenanceType.defaultProvenanceKind.name,
    };
    metadata['physicalFormId'] = physicalFormId;
    return metadata;
  }
}
