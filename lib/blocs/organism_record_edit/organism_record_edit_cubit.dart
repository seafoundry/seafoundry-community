// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/identity_edit_service.dart';
import 'package:seafoundry_app/services/life_stage_transition_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/measurement_metrics_service.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';
import 'package:seafoundry_app/services/provenance_id_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/validation/organism_constraints_service.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
import 'package:seafoundry_app/widgets/common/life_stage_transition_editor.dart';
import 'package:seafoundry_app/widgets/common/physical_form_change_editor.dart';
import 'package:seafoundry_app/widgets/common/quantity_change_editor.dart';
import 'package:seafoundry_app/widgets/dialogs/local_id_edit_scope_dialog.dart';

import 'organism_record_edit_state.dart';

class OrganismRecordEditCubit extends Cubit<OrganismRecordEditState>
    with ProvenanceSearchMixin<OrganismRecordEditState> {
  OrganismRecordEditCubit({
    required OrganismRecord originalRecord,
    required OrganismRecordChangeService changeService,
    required LifeStageTransitionService transitionService,
    required OrganismConstraintsService constraintsService,
    required OrganismRecordSaveCallback onSubmit,
    GenetRepository? genetRepository,
    OrganismRecordRepository? organismRecordRepository,
    this.provenanceLookupService,
    ProvenanceIdService? provenanceIdService,
    EventRepository? eventRepository,
    Organization? organization,
    List<MeasurementUnit>? quantityUnits,
  }) : _changeService = changeService,
       _transitionService = transitionService,
       _constraintsService = constraintsService,
       _onSubmit = onSubmit,
       _genetRepository = genetRepository,
       _organismRecordRepository = organismRecordRepository,
       _provenanceIdService = provenanceIdService,
       _eventRepository = eventRepository,
       _organization = organization,
       _quantityUnits =
           quantityUnits ?? MeasurementUnit.values.toList(growable: false),
       super(
         OrganismRecordEditState(
           originalRecord: originalRecord,
           pendingRecord: originalRecord,
           allowedFormIds: const [],
           changeSet: const OrganismRecordChangeSet(),
           quantityKind: QuantityChangeKind.gain,
           quantityUnit: originalRecord.measurement.unit,
           aliasEntries: _aliasEntriesFrom(originalRecord.aliases),
           ownerOrganizationIdInput: originalRecord.ownerOrganizationId ?? '',
           managingOrganizationIdInput:
               originalRecord.managingOrganizationId ??
               originalRecord.ownerOrganizationId ??
               '',
           currentOrganizationId: organization?.id,
           minimumStageInterval: originalRecord.customMinimumStageInterval,
           lastTransitionAt: originalRecord.lifeStageHistory.isEmpty
               ? null
               : originalRecord.lifeStageHistory.last.occurredAt,
         ),
       ) {
    _initializeAllowedFormIds();
    _initializeMeasurementFieldConfig();
    _loadUnderlyingGenet();
  }

  final OrganismRecordChangeService _changeService;
  final LifeStageTransitionService _transitionService;
  final OrganismConstraintsService _constraintsService;
  final OrganismRecordSaveCallback _onSubmit;
  final GenetRepository? _genetRepository;
  final OrganismRecordRepository? _organismRecordRepository;
  final ProvenanceIdService? _provenanceIdService;
  final EventRepository? _eventRepository;
  final Organization? _organization;
  @override
  final ProvenanceLookupService? provenanceLookupService;
  final List<MeasurementUnit> _quantityUnits;
  final IdentityEditService _identityEditService = const IdentityEditService();

  /// Counter to track async field config requests and prevent stale updates
  int _fieldConfigRequestId = 0;

  /// Counter to track async local ID suggestion requests and prevent stale updates
  int _localIdSuggestionRequestId = 0;

  /// Counter to track async PID preview requests and prevent stale updates
  int _pidPreviewRequestId = 0;

  bool _pendingProvenanceIdBlurReset = false;

  List<MeasurementUnit> get quantityUnits => _quantityUnits;

  @override
  String? get currentSpeciesCode => state.originalRecord.speciesId; // Respect species scoping

  @override
  ProvenanceSearchState get currentProvenanceSearch => state.provenanceSearch;

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    emit(state.copyWith(provenanceSearch: search));
    _maybeResetProvenanceIdAfterBlur();
  }

  Future<void> _loadUnderlyingGenet() async {
    // Compute initial transfer lock and external associations from organism record
    final initialLockInfo = _identityEditService.checkTransferLock(
      organismRecord: state.originalRecord,
    );
    final initialAssocInfo = _identityEditService.checkExternalAssociations(
      organismRecord: state.originalRecord,
    );

    if (_genetRepository == null) {
      if (!isClosed) {
        emit(
          state.copyWith(
            transferLockInfo: initialLockInfo,
            externalAssociationInfo: initialAssocInfo,
          ),
        );
      }
      return;
    }

    final resolvedGenetId = GenetIdResolver.resolve(state.originalRecord);
    if (resolvedGenetId == null || resolvedGenetId.isEmpty) {
      if (!isClosed) {
        emit(
          state.copyWith(
            transferLockInfo: initialLockInfo,
            externalAssociationInfo: initialAssocInfo,
          ),
        );
      }
      return;
    }

    try {
      final genet = await _genetRepository.getRecordForId(resolvedGenetId);
      if (genet != null && !isClosed) {
        // Compute transfer lock and external associations with genet data
        final lockInfo = _identityEditService.checkTransferLock(
          genet: genet,
          organismRecord: state.originalRecord,
        );
        final assocInfo = _identityEditService.checkExternalAssociations(
          genet: genet,
          organismRecord: state.originalRecord,
        );

        emit(
          state.copyWith(
            underlyingGenet: genet,
            // Initialize overrides with current values
            clonalIdOverride: genet.clonalId,
            accessionNumberOverride: genet.accessionNumber,
            provenanceIdOverride: genet.provenanceId,
            transferLockInfo: lockInfo,
            externalAssociationInfo: assocInfo,
          ),
        );
      }
    } catch (_) {
      // Ignore load errors for now, just editing won't be available
      if (!isClosed) {
        emit(
          state.copyWith(
            transferLockInfo: initialLockInfo,
            externalAssociationInfo: initialAssocInfo,
          ),
        );
      }
    }
  }

  void setClonalId(String value) {
    // Don't trim immediately to allow typing spaces
    // Use null if empty to keep state clean
    final normalized = value.isEmpty ? null : value;

    emit(state.copyWith(clonalIdOverride: normalized));

    // Trigger search (mixin handles debounce)
    onClonalIdSearchChanged(value);

    // Trigger local ID suggestion if appropriate
    _triggerLocalIdSuggestion();
  }

  void setAccessionNumber(String value) {
    final normalized = value.isEmpty ? null : value;

    emit(state.copyWith(accessionNumberOverride: normalized));

    // Trigger search
    onAccessionSearchChanged(value);
  }

  void setAliasId(String value) {
    final normalized = value.isEmpty ? null : value;
    emit(state.copyWith(aliasIdOverride: normalized));
    onAliasSearchChanged(value);
  }

  void setProvenanceId(String value) {
    final normalized = value.isEmpty ? null : value;
    emit(state.copyWith(provenanceIdOverride: normalized));
    onProvenanceIdSearchChanged(value);
  }

  void selectProvenanceSuggestion(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField field,
  ) {
    onProvenanceSuggestionSelected(suggestion, field);

    // Auto-populate ALL related fields from the suggestion, not just the searched field.
    // This ensures selecting a PID also fills in clonalId, alias, accessionNumber.

    // Resolve clonalId: prefer resolved from crosswalk, then masterClonalId, then
    // the searched alias value if searching by clonalId, finally fallback to display service
    String? resolvedClonalId = nonEmpty(suggestion.resolvedClonalId) ??
        nonEmpty(suggestion.masterClonalId);
    if (resolvedClonalId == null && field == ProvenanceMatchField.clonalId) {
      resolvedClonalId = nonEmpty(suggestion.aliasValue);
    }
    resolvedClonalId ??= ClonalIdDisplayService.resolveForSuggestion(suggestion);

    // Resolve accession: prefer resolved, fallback to searched value if searching by accession
    final resolvedAccession = nonEmpty(suggestion.resolvedAccessionNumber) ??
        (field == ProvenanceMatchField.accessionNumber
            ? nonEmpty(suggestion.aliasValue)
            : null);

    // Resolve alias: prefer resolved, fallback to searched value if searching by alias
    final resolvedAlias = nonEmpty(suggestion.resolvedAlias) ??
        (field == ProvenanceMatchField.alias
            ? nonEmpty(suggestion.aliasValue)
            : null);

    emit(
      state.copyWith(
        // Always update the PID
        provenanceIdOverride: suggestion.provenanceId,
        // Update clonalId with resolved value
        clonalIdOverride: resolvedClonalId,
        // Update accession: prefer resolved, fallback to current state
        accessionNumberOverride:
            resolvedAccession ?? state.accessionNumberOverride,
        // Update alias: prefer resolved, fallback to current state
        aliasIdOverride: resolvedAlias ?? state.aliasIdOverride,
      ),
    );

    // Trigger local ID suggestion if appropriate
    // We treat selecting a suggestion just like typing - if it implies a new identity, we suggest a local ID
    _triggerLocalIdSuggestion();
  }

  void clearProvenanceSelection() {
    onProvenanceSearchReset();
    final genet = state.selectedGenetOverride ?? state.underlyingGenet;
    emit(
      state.copyWith(
        clonalIdOverride: genet?.clonalId,
        accessionNumberOverride: genet?.accessionNumber,
        aliasIdOverride: null,
        provenanceIdOverride: genet?.provenanceId,
      ),
    );
  }

  void setActiveProvenanceField(ProvenanceMatchField field) {
    emitProvenanceSearch(currentProvenanceSearch.copyWith(activeField: field));
  }

  @override
  Future<void> close() {
    disposeProvenanceSearch();
    return super.close();
  }

  void _maybeResetProvenanceIdAfterBlur() {
    if (!_pendingProvenanceIdBlurReset) return;
    if (state.provenanceSearch.isSearchingProvenanceId) return;
    _pendingProvenanceIdBlurReset = false;
    _resetProvenanceIdIfUnmatched();
  }

  void _resetProvenanceIdIfUnmatched() {
    final search = state.provenanceSearch;
    final currentPid = state.provenanceIdOverride?.trim() ?? '';
    if (currentPid.isEmpty) {
      if (search.activeField == ProvenanceMatchField.provenanceId) {
        emitProvenanceSearch(search.copyWith(activeField: null));
      }
      return;
    }

    final hasMatch =
        search.provenanceIdMatch != null ||
        search.provenanceIdSuggestions.any(
          (suggestion) => suggestion.provenanceId == currentPid,
        );
    if (hasMatch) return;

    final defaultPid =
        (state.selectedGenetOverride ?? state.underlyingGenet)?.provenanceId;
    emit(state.copyWith(provenanceIdOverride: defaultPid));
    emitProvenanceSearch(
      search.copyWith(
        provenanceIdMatch: null,
        provenanceIdSuggestions: const [],
        isSearchingProvenanceId: false,
        activeField: search.activeField == ProvenanceMatchField.provenanceId
            ? null
            : search.activeField,
      ),
    );
  }

  Future<void> _triggerLocalIdSuggestion() async {
    // Increment request ID to track this suggestion request
    final requestId = ++_localIdSuggestionRequestId;

    // Only suggest if we have a repo and no manual override set yet
    if (_genetRepository == null) return;
    if (state.localIdOverride != null &&
        state.localIdOverride!.trim().isNotEmpty) {
      // User has manually entered a name, don't overwrite
      return;
    }

    // We also check against the original record - if the original name is "established" (not a temp)
    // we maybe shouldn't overwrite it automatically unless we are creating a "New" identity.
    // However, the user flow here is usually "Edit Identity -> define new Clonal ID -> expect Local ID".
    // If the Local ID was "Unkn-001" and we set Clonal ID to "Apal", we want "Apal-XXX".

    // If we have a selected Genet override, use its name?
    if (state.selectedGenetOverride != null) {
      // If a genet is explicitly selected, the setGenet method sets the name.
      // This method is called from setClonalId, which is usually for "Create new" flow or editing properties.
      // If selectedGenetOverride is set, we probably shouldn't be here or we are editing that genet's properties.
      return;
    }

    try {
      final speciesId = state.originalRecord.speciesId;
      if (speciesId == null) return;

      final suggestion = await _genetRepository.suggestNextLocalId(speciesId);

      // Guard against stale responses: if cubit is closed or a newer request
      // has been made, discard this result to prevent race conditions.
      if (isClosed || requestId != _localIdSuggestionRequestId) return;

      // If the user hasn't typed anything in the meantime
      if (state.localIdOverride == null ||
          state.localIdOverride!.trim().isEmpty) {
        setName(suggestion);
      }
    } catch (_) {
      // Ignore errors in suggestion
    }
  }

  void _initializeAllowedFormIds() {
    final formIds = _recomputeAllowedFormIds();
    if (isClosed) return;
    emit(state.copyWith(allowedFormIds: formIds));
  }

  Future<void> _initializeMeasurementFieldConfig() async {
    final record = state.originalRecord;
    if (record.physicalForm == null) return;

    final fieldConfig = MeasurementMetricsService.getFieldConfig(
      organismKind: record.organismKind,
      lifeStage: record.lifeStage.stage,
      physicalFormId: record.physicalForm!.formId,
      sizeBandId: record.physicalForm!.sizeBandId,
    );

    if (!isClosed) {
      emit(state.copyWith(measurementFieldConfig: fieldConfig));
    }
  }

  /// Sets the localGenetId (genet identifier, e.g., "ACER-001").
  /// This is the genetic lineage identifier that maps to PID.
  void setLocalId(String value) {
    final trimmed = value.trim();
    final current = state.originalRecord.localGenetId;
    final override = trimmed == current ? null : trimmed;
    // Clear pendingLocalIdScope since user is making a new localGenetId change
    // without explicitly choosing a scope via the scope dialog
    emit(
      state.copyWith(
        localIdOverride: override,
        localIdConflictError: null,
        pendingLocalIdScope: null,
      ),
    );
    _rebuildPendingRecord();
    // Trigger async conflict check
    if (override != null && override.isNotEmpty) {
      _checkLocalIdConflict(override);
    }
    // Trigger PID preview when localGenetId changes
    _loadPidPreview();
  }

  /// @deprecated Use setLocalId instead
  void setName(String value) => setLocalId(value);

  /// Counter for localID conflict check requests
  int _localIdConflictRequestId = 0;

  /// Check if the given localID conflicts with an existing genet.
  Future<void> _checkLocalIdConflict(String localGenetId) async {
    if (_genetRepository == null) return;

    final requestId = ++_localIdConflictRequestId;
    final normalized = localGenetId.trim();
    if (normalized.isEmpty) return;

    try {
      final existingGenet = await _genetRepository.getRecordByName(normalized);
      if (isClosed || requestId != _localIdConflictRequestId) return;

      // Only flag as conflict if it's a different genet than the one we're editing
      final underlyingGenetId = state.underlyingGenet?.id;
      if (existingGenet != null && existingGenet.id != underlyingGenetId) {
        emit(
          state.copyWith(
            localIdConflictError:
                'Local ID "$normalized" is already in use by another genet.',
          ),
        );
      } else {
        emit(state.copyWith(localIdConflictError: null));
      }
    } catch (_) {
      // Ignore errors in conflict check
    }
  }

  /// Loads a preview of the next PID that would be generated.
  /// Called when the local ID changes and a new genet might be created.
  Future<void> _loadPidPreview() async {
    if (_provenanceIdService == null) return;

    final speciesId = state.originalRecord.speciesId;
    if (speciesId == null || speciesId.isEmpty) {
      if (!isClosed) {
        emit(state.copyWith(previewedNewPid: null, isLoadingPidPreview: false));
      }
      return;
    }

    // Only show preview when:
    // 1. There's a localGenetId change AND
    // 2. We have an underlying genet (so there's a current PID to compare against) OR
    // 3. We would be creating a new genet
    final shouldPreview =
        state.hasLocalIdChange &&
        (state.underlyingGenet != null || state.selectedGenetOverride == null);
    if (!shouldPreview) {
      if (!isClosed) {
        emit(state.copyWith(previewedNewPid: null, isLoadingPidPreview: false));
      }
      return;
    }

    final requestId = ++_pidPreviewRequestId;

    if (!isClosed) {
      emit(state.copyWith(isLoadingPidPreview: true));
    }

    try {
      final preview = await _provenanceIdService.previewNextProvenanceId(
        speciesId: speciesId,
      );

      // Guard against stale responses
      if (isClosed || requestId != _pidPreviewRequestId) return;

      emit(
        state.copyWith(previewedNewPid: preview, isLoadingPidPreview: false),
      );
    } catch (_) {
      // Ignore errors in preview
      if (!isClosed && requestId == _pidPreviewRequestId) {
        emit(state.copyWith(previewedNewPid: null, isLoadingPidPreview: false));
      }
    }
  }

  void setRecordName(String value) {
    final trimmed = value.trim();
    final current = state.originalRecord.tagId;
    final override = trimmed == current ? null : trimmed;
    emit(state.copyWith(recordNameOverride: override));
    _rebuildPendingRecord();
  }

  void setGenet(Genet? genet) {
    if (genet == null) {
      // Clear genet selection, revert to custom name logic (handled by setName)
      emit(state.copyWith(selectedGenetOverride: null));
    } else {
      // Select genet, update name to match genet name
      emit(
        state.copyWith(
          selectedGenetOverride: genet,
          localIdOverride: genet.name,
        ),
      );
    }
    _rebuildPendingRecord();
  }

  void setLifeStage(LifeStage stage) {
    final currentStage = state.originalRecord.lifeStage.stage;
    final override = stage == currentStage ? null : stage;
    final validation = override == null
        ? null
        : _validateLifeStage(stage) ??
              (state.lifeStageReason == null
                  ? 'Select a reason for this transition.'
                  : null);
    emit(
      state.copyWith(
        lifeStageOverride: override,
        lifeStageValidationMessage: validation,
      ),
    );
    _recomputeAllowedFormIdsAsync();
    _rebuildPendingRecord();
  }

  void setLifeStageReason(LifeStageTransitionReason? reason) {
    final validation = state.lifeStageOverride == null
        ? null
        : (reason == null
              ? 'Select a reason for this transition.'
              : _validateLifeStage(state.lifeStageOverride!));
    emit(
      state.copyWith(
        lifeStageReason: reason,
        lifeStageValidationMessage: validation,
      ),
    );
  }

  void setPhysicalForm(String? formId) {
    final currentFormId = state.originalRecord.physicalForm?.formId;
    final override = formId == currentFormId ? null : formId;
    final validation =
        override != null && state.physicalFormChangeReason == null
        ? 'Select a reason for this change.'
        : null;
    emit(
      state.copyWith(
        formIdOverride: override,
        physicalFormValidationMessage: validation,
      ),
    );
    _rebuildPendingRecord();

    // Reload field config when form changes
    if (formId != null) {
      _reloadMeasurementFieldConfig(formId);
    }
  }

  Future<void> _reloadMeasurementFieldConfig(String formId) async {
    // Increment request counter and capture it to detect stale responses
    final requestId = ++_fieldConfigRequestId;
    final record = state.originalRecord;
    final lifeStage = state.lifeStageOverride ?? record.lifeStage.stage;

    final fieldConfig = MeasurementMetricsService.getFieldConfig(
      organismKind: record.organismKind,
      lifeStage: lifeStage,
      physicalFormId: formId,
      sizeBandId: record.physicalForm?.sizeBandId ?? 'medium',
    );

    // Skip if closed or if a newer request has been made (prevents race condition)
    if (isClosed || requestId != _fieldConfigRequestId) {
      return;
    }

    // Reset metrics that are disabled in the new field config
    final oldConfig = state.measurementFieldConfig;
    emit(
      state.copyWith(
        measurementFieldConfig: fieldConfig,
        // Reset count if it was enabled but is now disabled
        countOverride:
            (oldConfig?.enableCount == true && !fieldConfig.enableCount)
            ? null
            : state.countOverride,
      ),
    );
    _rebuildPendingRecord();
  }

  void setPhysicalFormChangeReason(PhysicalFormChangeReason? reason) {
    final validation = state.formIdOverride != null && reason == null
        ? 'Select a reason for this change.'
        : null;
    emit(
      state.copyWith(
        physicalFormChangeReason: reason,
        physicalFormValidationMessage: validation,
      ),
    );
  }

  void setQuantityKind(QuantityChangeKind kind) {
    emit(
      state.copyWith(
        quantityKind: kind,
        quantityReason: null,
        mortalityReason: null,
      ),
    );
    validateQuantity();
  }

  void setQuantityValue(double? value) {
    final current = state.originalRecord.measurement.value;
    final override = (value == null || value == current) ? null : value;
    emit(state.copyWith(quantityOverride: override));
    _rebuildPendingRecord();
    validateQuantity();
  }

  void setQuantityReason(QuantityChangeReason? reason) {
    emit(
      state.copyWith(
        quantityReason: reason,
        mortalityReason: reason?.id == 'mortality'
            ? state.mortalityReason
            : null,
      ),
    );
    validateQuantity();
  }

  void setMortalityReason(PopulationLossReason? reason) {
    emit(state.copyWith(mortalityReason: reason));
    validateQuantity();
  }

  void setQuantityComment(String value) {
    final trimmed = value.trim();
    emit(state.copyWith(quantityComment: trimmed.isEmpty ? null : trimmed));
    validateQuantity();
  }

  void addAliasEntry() {
    final updated = List<GenetAliasEntry>.from(state.aliasEntries)
      ..add(const GenetAliasEntry());
    emit(state.copyWith(aliasEntries: updated));
    _rebuildPendingRecord();
  }

  void removeAliasEntry(int index) {
    if (index < 0 || index >= state.aliasEntries.length) return;
    final updated = List<GenetAliasEntry>.from(state.aliasEntries)
      ..removeAt(index);
    emit(state.copyWith(aliasEntries: updated));
    _rebuildPendingRecord();
  }

  void updateAliasValue(int index, String value) {
    if (index < 0 || index >= state.aliasEntries.length) return;
    final updated = List<GenetAliasEntry>.from(state.aliasEntries);
    updated[index] = updated[index].copyWith(value: value);
    emit(state.copyWith(aliasEntries: updated));
    _rebuildPendingRecord();
  }

  void updateAliasSource(int index, String source) {
    if (index < 0 || index >= state.aliasEntries.length) return;
    final updated = List<GenetAliasEntry>.from(state.aliasEntries);
    updated[index] = updated[index].copyWith(sourceSystem: source);
    emit(state.copyWith(aliasEntries: updated));
    _rebuildPendingRecord();
  }

  void updateAliasLabel(int index, String label) {
    if (index < 0 || index >= state.aliasEntries.length) return;
    final updated = List<GenetAliasEntry>.from(state.aliasEntries);
    updated[index] = updated[index].copyWith(label: label);
    emit(state.copyWith(aliasEntries: updated));
    _rebuildPendingRecord();
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      emit(
        state.copyWith(
          submissionError: state.changeSet.hasChanges
              ? 'Resolve validation issues before saving.'
              : 'No changes to save.',
        ),
      );
      return;
    }

    // Validate 5-axis constraints before saving
    final validationError = state.pendingRecord.validateFiveAxisConstraints();
    if (validationError != null) {
      emit(state.copyWith(submissionError: validationError));
      return;
    }

    // Validate measurement metrics against field config using pendingRecord (the actual values to be saved)
    if (state.measurementFieldConfig != null) {
      final metricsError = MeasurementMetricsService.validateMetrics(
        config: state.measurementFieldConfig!,
        count: state.pendingRecord.sizeSpec.countOverride,
      );
      if (metricsError != null) {
        emit(state.copyWith(submissionError: metricsError));
        return;
      }
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        submissionError: null,
        submissionSucceeded: false,
      ),
    );

    try {
      // Note: Implicit genet creation has been removed.
      // Genets must be explicitly selected or created via the LocalIdField.
      // Provenance fields are read-only and managed at the genet level.

      final metadata = _buildEventMetadata();

      // Save OrganismRecord
      await _onSubmit(
        state.pendingRecord,
        eventMetadata: metadata.isEmpty ? null : metadata,
      );

      // Handle genet-wide localID update if requested
      int? genetWideCount;
      if (state.pendingLocalIdScope == LocalIdEditScope.genetWide &&
          state.localIdOverride != null &&
          state.underlyingGenet != null &&
          _organismRecordRepository != null) {
        try {
          genetWideCount = await _organismRecordRepository
              .updateLocalIdGenetWide(
                genetId: state.underlyingGenet!.id,
                newLocalId: state.localIdOverride!,
                updatedById: state.pendingRecord.updatedById,
              );
        } catch (e) {
          // Log but don't fail the entire submission if genet-wide update fails
          // The primary record was already saved successfully
          // Store warning to show user so they can manually update other records
          if (!isClosed) {
            emit(
              state.copyWith(
                genetWideUpdateWarning:
                    'Record saved, but failed to update other records in this genet. '
                    'You may need to update them manually.',
              ),
            );
          }
        }
      }

      // Update Genet if we have a new binding or property changes
      if (state.hasProvenanceChange && _genetRepository != null) {
        if (state.selectedGenetOverride != null &&
            state.selectedGenetOverride!.id != state.underlyingGenet?.id) {
          // We are relinking to a different genet (or the one we just created).
          // Nothing to update on the genet itself here.
        } else if (state.underlyingGenet != null) {
          // We are editing the existing genet's properties
          final originalGenet = state.underlyingGenet!;
          final resolvedPid = state.provenanceSearch.resolvedProvenanceId;
          final manualPid = state.provenanceIdOverride?.trim();
          final effectivePid = resolvedPid?.trim().isNotEmpty == true
              ? resolvedPid
              : (manualPid?.isNotEmpty == true ? manualPid : null);
          final updatedGenet = originalGenet.copyWith(
            clonalId: state.clonalIdOverride?.trim(),
            accessionNumber: state.accessionNumberOverride?.trim(),
            provenanceId: effectivePid ?? originalGenet.provenanceId,
          );

          if (updatedGenet != originalGenet) {
            await _genetRepository.updateGenet(
              original: originalGenet,
              updated: updatedGenet,
            );
          }
        }
      }

      // Emit identity change events after successful save
      await _emitIdentityChangeEvents(
        state.pendingRecord,
        state.originalRecord,
        genetWideCount,
      );

      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          submissionSucceeded: true,
          genetWideUpdateCount: genetWideCount,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isSubmitting: false,
          submissionSucceeded: false,
          submissionError: error.toString(),
        ),
      );
    }
  }

  Map<String, dynamic> _buildEventMetadata() {
    final metadata = <String, dynamic>{};
    if (state.lifeStageOverride != null && state.lifeStageReason != null) {
      metadata['lifeStageReason'] = state.lifeStageReason!.name;
    }
    if (state.formIdOverride != null &&
        state.physicalFormChangeReason != null) {
      metadata['physicalFormChangeReason'] =
          state.physicalFormChangeReason!.name;
    }
    if (state.quantityOverride != null || state.quantityUnitOverride != null) {
      if (state.quantityReason != null) {
        metadata['quantityReason'] = state.quantityReason!.id;
      }
      if (state.mortalityReason != null) {
        metadata['mortalityReasonId'] = state.mortalityReason!.id;
      }
      if (state.quantityComment != null) {
        metadata['quantityComment'] = state.quantityComment;
      }
    }
    return metadata;
  }

  /// Emits an identity change event for a single record.
  Future<void> _emitIdentityEvent({
    required EventType eventType,
    required String recordId,
    required Map<String, dynamic> metadata,
  }) async {
    if (_eventRepository == null || _organization == null) return;

    try {
      final now = DateTime.now();
      final eventId = '${now.millisecondsSinceEpoch}_${recordId.substring(
        0,
        recordId.length < 8 ? recordId.length : 8,
      )}';

      final event = Event.partial(
        id: eventId,
        organizationId: _organization.id,
        eventTypeId: eventType.id,
        recordId: recordId,
        recordModelType: ModelType.organismRecord,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        metadata: metadata,
      );

      await _eventRepository.createEvent(event);
      LoggingService.instance.info(
        'Emitted ${eventType.id} event for record $recordId',
      );
    } catch (e) {
      LoggingService.instance.warning('Failed to emit identity event: $e');
      // Best-effort - don't fail the main operation
    }
  }

  /// Emits an identity change event at the genet level.
  Future<void> _emitGenetIdentityEvent({
    required EventType eventType,
    required String? genetId,
    required Map<String, dynamic> metadata,
  }) async {
    if (_eventRepository == null || _organization == null || genetId == null) {
      return;
    }

    try {
      final now = DateTime.now();
      final eventId = '${now.millisecondsSinceEpoch}_${genetId.substring(
        0,
        genetId.length < 8 ? genetId.length : 8,
      )}';

      final event = Event.partial(
        id: eventId,
        organizationId: _organization.id,
        eventTypeId: eventType.id,
        recordId: genetId,
        recordModelType: ModelType.genet,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
        metadata: metadata,
      );

      await _eventRepository.createEvent(event);
      LoggingService.instance.info(
        'Emitted ${eventType.id} event for genet $genetId',
      );
    } catch (e) {
      LoggingService.instance.warning('Failed to emit genet identity event: $e');
    }
  }

  /// Emits identity change events for changes detected during save.
  Future<void> _emitIdentityChangeEvents(
    OrganismRecord savedRecord,
    OrganismRecord originalRecord,
    int? genetWideUpdateCount,
  ) async {
    // tagId change
    final recordNameChanged =
        state.recordNameOverride != null &&
        state.recordNameOverride != originalRecord.tagId;
    if (recordNameChanged) {
      await _emitIdentityEvent(
        eventType: EventType.recordNameChange,
        recordId: savedRecord.id,
        metadata: {
          'previousValue': originalRecord.tagId,
          'newValue': state.recordNameOverride,
        },
      );
    }

    // localGenetId change (record-level only)
    final localIdChanged =
        state.localIdOverride != null &&
        state.localIdOverride != originalRecord.localGenetId;
    final isGenetWide = state.pendingLocalIdScope == LocalIdEditScope.genetWide;

    if (localIdChanged && !isGenetWide) {
      await _emitIdentityEvent(
        eventType: EventType.localIdChange,
        recordId: savedRecord.id,
        metadata: {
          'previousValue': originalRecord.localGenetId,
          'newValue': state.localIdOverride,
          'scope': 'thisRecordOnly',
        },
      );
    }

    // genet-wide identity change
    final resolvedGenetId = GenetIdResolver.resolve(savedRecord);
    if (localIdChanged && isGenetWide && resolvedGenetId != null) {
      final externalAssociations = <String, dynamic>{};
      if (state.clonalIdOverride?.isNotEmpty == true) {
        externalAssociations['clonalId'] = state.clonalIdOverride;
      }
      if (state.accessionNumberOverride?.isNotEmpty == true) {
        externalAssociations['accessionNumber'] = state.accessionNumberOverride;
      }
      if (state.provenanceIdOverride?.isNotEmpty == true) {
        externalAssociations['provenanceId'] = state.provenanceIdOverride;
      }

      await _emitGenetIdentityEvent(
        eventType: EventType.genetIdentityChange,
        genetId: resolvedGenetId,
        metadata: {
          'previousLocalId': originalRecord.localGenetId,
          'newLocalId': state.localIdOverride,
          'scope': 'genetWide',
          'affectedRecordCount': genetWideUpdateCount ?? 1,
          if (externalAssociations.isNotEmpty)
            'externalAssociations': externalAssociations,
        },
      );
    }

    // ownership change
    final ownerChanged =
        state.ownerOrganizationIdInput != (originalRecord.ownerOrganizationId ?? '');
    final managerChanged =
        state.managingOrganizationIdInput !=
        (originalRecord.managingOrganizationId ??
            originalRecord.ownerOrganizationId ??
            '');

    if (ownerChanged || managerChanged) {
      await _emitIdentityEvent(
        eventType: EventType.ownershipChange,
        recordId: savedRecord.id,
        metadata: {
          'previousOwner': originalRecord.ownerOrganizationId,
          'newOwner': state.ownerOrganizationIdInput.isEmpty
              ? null
              : state.ownerOrganizationIdInput,
          'previousManager': originalRecord.managingOrganizationId,
          'newManager': state.managingOrganizationIdInput.isEmpty
              ? null
              : state.managingOrganizationIdInput,
          'source': 'manualEdit',
        },
      );
    }
  }

  List<String> _recomputeAllowedFormIds() {
    final lifeStage =
        state.lifeStageOverride ?? state.originalRecord.lifeStage.stage;
    final formIds = _constraintsService.allowedFormIds(
      organismKind: state.originalRecord.organismKind,
      lifeStage: lifeStage,
    );
    return formIds.toList(growable: false);
  }

  void _recomputeAllowedFormIdsAsync() {
    final formIds = _recomputeAllowedFormIds();
    if (isClosed) return;
    emit(state.copyWith(allowedFormIds: formIds));
  }

  void _rebuildPendingRecord() {
    final aliasPayload = _buildAliasPayload();
    final ownerInput = state.ownerOrganizationIdInput.trim();
    final managingInput = state.managingOrganizationIdInput.trim();
    final ownerResolved = ownerInput.isEmpty ? null : ownerInput;
    final managingResolved = managingInput.isEmpty
        ? ownerResolved
        : managingInput;
    final pending = state.originalRecord.copyWith(
      localGenetId: state.localIdOverride ?? state.originalRecord.localGenetId,
      tagId: state.recordNameOverride ?? state.originalRecord.tagId,
      lifeStage: _resolveLifeStageSpec(),
      physicalForm: _resolvePhysicalForm(),
      measurement: _resolveMeasurement(),
      sizeSpec: state.originalRecord.sizeSpec.copyWith(
        sizeClass:
            state.sizeClassOverride ?? state.originalRecord.sizeSpec.sizeClass,
        measuredDimension:
            state.measuredDimensionOverride ??
            state.originalRecord.sizeSpec.measuredDimension,
        dimensionUnit:
            state.dimensionUnitOverride ??
            state.originalRecord.sizeSpec.dimensionUnit,
        countOverride:
            state.countOverride ?? state.originalRecord.sizeSpec.countOverride,
      ),
      aliases: aliasPayload,
      ownerOrganizationId: ownerResolved,
      managingOrganizationId: managingResolved,
    );

    OrganismRecord finalPending = pending;
    if (state.selectedGenetOverride != null) {
      final newFks = Map<String, ForeignKeyReference>.from(pending.foreignKeys);
      newFks['genetId'] = ForeignKeyReference(
        id: state.selectedGenetOverride!.id,
        metadata: {'collection': 'genets'},
      );
      finalPending = pending.copyWith(foreignKeys: newFks);
    }

    final changeSet = _changeService.detectChanges(
      previous: state.originalRecord,
      next: finalPending,
    );

    emit(state.copyWith(pendingRecord: finalPending, changeSet: changeSet));
  }

  List<OrganismAlias> _buildAliasPayload() {
    if (state.aliasEntries.isEmpty) return const <OrganismAlias>[];
    return state.aliasEntries
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => entry.toOrganismAlias())
        .toList(growable: false);
  }

  static List<GenetAliasEntry> _aliasEntriesFrom(List<OrganismAlias> aliases) {
    if (aliases.isEmpty) return const <GenetAliasEntry>[];
    return aliases
        .map(GenetAliasEntry.fromOrganismAlias)
        .toList(growable: false);
  }

  LifeStageSpec _resolveLifeStageSpec() {
    final override = state.lifeStageOverride;
    if (override == null) return state.originalRecord.lifeStage;
    return state.originalRecord.lifeStage.copyWith(stage: override);
  }

  PhysicalFormInstance? _resolvePhysicalForm() {
    final override = state.formIdOverride;
    if (override == null) return state.originalRecord.physicalForm;
    // When physical form changes, keep existing sizeBandId or use 'medium' default
    final existingSizeBandId =
        state.originalRecord.physicalForm?.sizeBandId ?? 'medium';
    return PhysicalFormInstance(
      formId: override,
      sizeBandId: existingSizeBandId,
    );
  }

  PopulationMeasurement _resolveMeasurement() {
    final override = state.quantityOverride;
    final unitOverride = state.quantityUnitOverride;
    if (override == null && unitOverride == null) {
      return state.originalRecord.measurement;
    }
    final value = override ?? state.originalRecord.measurement.value;
    final unit = unitOverride ?? state.originalRecord.measurement.unit;
    return PopulationMeasurement(value: value, unit: unit);
  }

  String? _validateLifeStage(LifeStage nextStage) {
    final result = _transitionService.canTransition(
      record: state.originalRecord,
      targetStage: nextStage,
      minimumInterval: state.minimumStageInterval,
    );
    return result.isValid ? null : result.message;
  }

  void validateQuantity() {
    if (state.quantityOverride == null && state.quantityUnitOverride == null) {
      emit(state.copyWith(quantityValidationMessage: null));
      return;
    }
    if (state.quantityOverride != null && state.quantityOverride! < 0) {
      emit(state.copyWith(quantityValidationMessage: 'Quantity must be ≥ 0.'));
      return;
    }
    if (state.quantityReason == null) {
      emit(
        state.copyWith(
          quantityValidationMessage: 'Select a reason for the change.',
        ),
      );
      return;
    }
    if (state.quantityReason?.id == 'mortality' &&
        state.mortalityReason == null) {
      emit(
        state.copyWith(
          quantityValidationMessage:
              'Specify the mortality cause for audit logs.',
        ),
      );
      return;
    }
    emit(state.copyWith(quantityValidationMessage: null));
  }

  OrganismKind get organismKind => state.originalRecord.organismKind;
}
