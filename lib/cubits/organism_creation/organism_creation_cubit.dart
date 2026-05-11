import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_creation_result.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/measurement_metrics_service.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/utils/string_formatters.dart';
class OrganismCreationCubit extends Cubit<OrganismCreationState>
    with ProvenanceSearchMixin<OrganismCreationState> {
  // Request ID counter to track async form loading requests and prevent stale data
  int _formLoadRequestId = 0;
  // Request ID counter to track async field config requests and prevent race conditions
  int _fieldConfigRequestId = 0;
  // Request ID counter to track async local ID suggestions and prevent stale updates
  int _localIdSuggestionRequestId = 0;

  final PhysicalFormRegistry _physicalFormRegistry;
  final GenetRepository? _genetRepository;
  @override
  final ProvenanceLookupService? provenanceLookupService;

  OrganismCreationCubit({
    PhysicalFormRegistry? physicalFormRegistry,
    GenetRepository? genetRepository,
    this.provenanceLookupService,
    OrganismKind? initialOrganismKind,
    LifeStage? initialLifeStage,
    ProvenanceType? initialProvenanceType,
    String? initialDamProvenanceId,
    String? initialSireProvenanceId,
    String? initialSourceCohortId,
  }) : _physicalFormRegistry =
           physicalFormRegistry ?? PhysicalFormRegistry.instance,
       _genetRepository = genetRepository,
       super(
         OrganismCreationState(
           organismKind: initialOrganismKind ?? OrganismKind.coral,
           lifeStage: initialLifeStage ?? LifeStage.juvenile,
           provenanceType: initialProvenanceType ?? ProvenanceType.wild,
           damProvenanceId: initialDamProvenanceId,
           sireProvenanceId: initialSireProvenanceId,
           sourceCohortId: initialSourceCohortId,
         ),
       ) {
    _loadAvailablePhysicalForms(
      state.organismKind ?? OrganismKind.coral,
      state.lifeStage ?? LifeStage.juvenile,
    );
  }

  // _resolveInitialSourceCohortId removed in coral-only simplification

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
        error: null,
        // Always update the PID
        provenanceId: suggestion.provenanceId,
        // Update clonalId with resolved value
        clonalId: resolvedClonalId,
        // Update accession: prefer resolved, fallback to current state
        accessionNumber: resolvedAccession ?? state.accessionNumber,
        // Update alias: prefer resolved, fallback to current state
        aliasId: resolvedAlias ?? state.aliasId,
      ),
    );

    _triggerLocalIdSuggestion();
  }

  Future<void> _triggerLocalIdSuggestion() async {
    // Only suggest if we have a repo and no manual overwrite yet
    final repo = _genetRepository;
    if (repo == null) return;

    // Don't overwrite if user has already entered a valid Local ID manually
    final current = state.localGenetId?.trim();
    if (current != null &&
        current.isNotEmpty &&
        current != state.suggestedLocalId) {
      return;
    }

    // Determine the seed value (Clonal ID takes precedence)
    final seedValue = state.clonalId?.trim() ?? state.accessionNumber?.trim();
    if (seedValue == null || seedValue.isEmpty) return;

    // Use the seed as the candidate base name (e.g. "Apal-001" -> "Apal")
    final speciesId = state.species?.id;
    if (speciesId == null) return;

    try {
      final suggestion = await repo.suggestNextLocalId(speciesId);

      if (!isClosed) {
        suggestedLocalIdChanged(suggestion);
        localIdChanged(suggestion);
      }
    } catch (e) {
      // Ignore errors in suggestion (silent failure)
    }
  }

  Future<void> _suggestLocalIdForSpecies({
    required Species? species,
    bool force = false,
  }) async {
    final repo = _genetRepository;
    if (repo == null) return;
    if (species == null) return;

    final current = state.localGenetId?.trim();
    final currentSuggested = state.suggestedLocalId?.trim();
    if (!force &&
        current != null &&
        current.isNotEmpty &&
        current != currentSuggested) {
      return;
    }

    final requestId = ++_localIdSuggestionRequestId;
    try {
      final suggestion = await repo.suggestNextLocalId(species.id);
      if (isClosed || requestId != _localIdSuggestionRequestId) return;
      final normalized = suggestion.trim();
      if (normalized.isEmpty) return;
      final currentLocal = state.localGenetId?.trim();
      final currentSuggested = state.suggestedLocalId?.trim();
      if (currentLocal != null &&
          currentLocal.isNotEmpty &&
          currentLocal != currentSuggested) {
        return;
      }
      emit(
        state.copyWith(
          suggestedLocalId: normalized,
          localGenetId: normalized,
          error: null,
        ),
      );
    } catch (_) {
      // Ignore errors in suggestion (silent failure)
    }
  }

  Future<void> organismKindChanged(OrganismKind? kind) async {
    emit(
      state.copyWith(
        organismKind: kind,
        // Reset species when organism kind changes
        species: null,
        error: null,
      ),
    );
    if (kind != null && state.lifeStage != null) {
      await _loadAvailablePhysicalForms(kind, state.lifeStage!);
    }
  }

  void speciesChanged(Species? species) {
    final wasSpeciesId = state.species?.id;
    final isSpeciesChange = wasSpeciesId != species?.id;
    // Clear selected genet if species changes to a different species
    // (genet belongs to specific species, switching species invalidates selection)
    final shouldClearGenet =
        state.selectedGenet != null &&
        (species == null || species.id != state.selectedGenet!.speciesId);

    if (shouldClearGenet) {
      // Clear genet and reset provenance when species changes
      emit(
        state.copyWith(
          species: species,
          selectedGenet: null,
          provenanceType: ProvenanceType.wild,
          localGenetId: (isSpeciesChange && state.isNewGenet) ? null : state.localGenetId,
          suggestedLocalId: isSpeciesChange ? null : state.suggestedLocalId,
          error: null,
        ),
      );
    } else {
      // Just update species, keep existing genet and provenance
      emit(
        state.copyWith(
          species: species,
          localGenetId: (isSpeciesChange && state.isNewGenet) ? null : state.localGenetId,
          suggestedLocalId: isSpeciesChange ? null : state.suggestedLocalId,
          error: null,
        ),
      );
    }

    // Reset provenance search when species changes (PIDs are species-scoped)
    onProvenanceSearchReset();

    if (state.isNewGenet && species != null) {
      _suggestLocalIdForSpecies(species: species, force: true);
    }
  }

  Future<void> lifeStageChanged(LifeStage? lifeStage) async {
    emit(
      state.copyWith(
        lifeStage: lifeStage,
        error: null,
      ),
    );
    if (state.organismKind != null && lifeStage != null) {
      await _loadAvailablePhysicalForms(state.organismKind!, lifeStage);
    }
  }

  Future<void> _loadAvailablePhysicalForms(
    OrganismKind organismKind,
    LifeStage lifeStage,
  ) async {
    // Increment request ID to track this specific request
    final requestId = ++_formLoadRequestId;

    try {
      final forms = _physicalFormRegistry.getAvailableForms(
        organismKind,
        lifeStage,
      );

      // Discard stale responses - if requestId doesn't match current, a newer request was made
      if (isClosed || requestId != _formLoadRequestId) return;

      // Check if current physical form selection is still valid for the new forms
      PhysicalFormInstance? newSelection = state.physicalForm;
      MeasurementFieldConfig? fieldConfig;

      // Reset physical form if it's no longer in the available forms list
      if (newSelection != null) {
        final isStillValid = forms.any(
          (config) => config.id == newSelection!.formId,
        );
        if (!isStillValid) {
          // Current selection is invalid for new life stage, reset to null
          newSelection = null;
        }
      }

      // Auto-select first form if none selected (or was reset) and forms are available
      if (newSelection == null && forms.isNotEmpty) {
        final config = forms.first;
        if (config.defaultSizeBand != null) {
          newSelection = PhysicalFormInstance(
            formId: config.id,
            sizeBandId: config.defaultSizeBand!.id,
          );
        }
      }

      // Load field config if we have a physical form
      if (newSelection != null) {
        fieldConfig = MeasurementMetricsService.getFieldConfig(
          organismKind: organismKind,
          lifeStage: lifeStage,
          physicalFormId: newSelection.formId,
          sizeBandId: newSelection.sizeBandId,
        );
      }

      // Final stale check before emitting
      if (isClosed || requestId != _formLoadRequestId) return;

      emit(
        state.copyWith(
          availablePhysicalForms: forms,
          physicalForm: newSelection,
          measurementFieldConfig: fieldConfig,
        ),
      );
    } catch (e, stackTrace) {
      // Log error but don't block user flow
      LoggingService.instance.debug('Failed to load physical forms: $e', {
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  Future<void> physicalFormChanged(PhysicalFormInstance? physicalForm) async {
    // Increment request ID to track this specific request
    final requestId = ++_fieldConfigRequestId;

    emit(state.copyWith(physicalForm: physicalForm, error: null));

    // Reload field config when physical form changes
    if (physicalForm != null &&
        state.organismKind != null &&
        state.lifeStage != null) {
      final fieldConfig = MeasurementMetricsService.getFieldConfig(
        organismKind: state.organismKind!,
        lifeStage: state.lifeStage!,
        physicalFormId: physicalForm.formId,
        sizeBandId: physicalForm.sizeBandId,
      );

      // Discard stale responses - if requestId doesn't match current, a newer request was made
      if (isClosed || requestId != _fieldConfigRequestId) return;

      // Reset metrics that are disabled in the new field config
      final oldConfig = state.measurementFieldConfig;
      emit(
        state.copyWith(
          measurementFieldConfig: fieldConfig,
          // Reset count if it was enabled but is now disabled
          editingCount:
              (oldConfig?.enableCount == true && !fieldConfig.enableCount)
              ? null
              : state.editingCount,
        ),
      );
    }
  }

  void measurementChanged(PopulationMeasurement measurement) {
    emit(state.copyWith(measurement: measurement, error: null));
  }

  void sizeSpecChanged(SizeSpec sizeSpec) {
    emit(state.copyWith(sizeSpec: sizeSpec, error: null));
  }

  void physicalFormLabelChanged(String? physicalFormLabel) {
    emit(state.copyWith(physicalFormLabel: physicalFormLabel, error: null));
  }

  void editingCountChanged(int? count) {
    emit(state.copyWith(editingCount: count, error: null));
  }


  void provenanceTypeChanged(ProvenanceType? provenanceType) {
    final nextType = provenanceType;
    final nextState = state.copyWith(provenanceType: nextType, error: null);

    emit(
      nextState.copyWith(
        sireProvenanceId: null,
        damProvenanceId: null,
        sourceCohortId: null,
      ),
    );
  }

  void isNewGenetChanged(bool value) {
    // Determine the new active steps based on the new mode
    final newActiveSteps = _getActiveSteps(value);
    var newStep = state.currentStep;

    // Coerce step if current step is not in the new active steps
    if (!newActiveSteps.contains(state.currentStep)) {
      // Map provenance -> gainReason or vice versa, or fall back to identity
      if (state.currentStep == OrganismCreationStep.provenance) {
        newStep = OrganismCreationStep.gainReason;
      } else if (state.currentStep == OrganismCreationStep.gainReason) {
        newStep = OrganismCreationStep.identity;
      }
    }

    if (value) {
      // Switching to NEW mode: clear gainReason, restore default provenance
      emit(
        state.copyWith(
          isNewGenet: true,
          gainReason: null,
          provenanceType: ProvenanceType.wild,
          selectedGenet: null,
          localGenetId: null,
          suggestedLocalId: null,
          currentStep: newStep,
          error: null,
        ),
      );
      if (state.species != null) {
        _suggestLocalIdForSpecies(species: state.species, force: true);
      }
    } else {
      // Switching to EXISTING mode: clear provenance fields
      emit(
        state.copyWith(
          isNewGenet: false,
          provenanceType: null,
          sourceCohortId: null,
          wildCollectionMethod: null,
          collectionReefOrigin: null,
          collectionDate: null,
          collectionDepth: null,
          collectionHabitatType: null,
          collectionInstitution: null,
          collectionLatitude: null,
          collectionLongitude: null,
          sireProvenanceId: null,
          damProvenanceId: null,
          transferOrgId: null,
          transferEmail: null,
          currentStep: newStep,
          error: null,
        ),
      );
    }
  }

  void gainReasonChanged(PopulationGainReason? reason) {
    emit(state.copyWith(gainReason: reason, error: null));

    if (!state.isNewGenet && reason == PopulationGainReason.fragmentation) {
      final allowedStages = state.availableLifeStages;
      final currentStage = state.lifeStage;
      if (allowedStages.isNotEmpty &&
          (currentStage == null || !allowedStages.contains(currentStage))) {
        final fallback = allowedStages.contains(LifeStage.adult)
            ? LifeStage.adult
            : allowedStages.first;
        if (fallback != currentStage) {
          lifeStageChanged(fallback);
        }
      }
    }
  }

  void sourceCohortIdChanged(String? sourceCohortId) {
    // Normalize empty/whitespace strings to null for consistency
    final normalized = (sourceCohortId == null || sourceCohortId.trim().isEmpty)
        ? null
        : sourceCohortId.trim();
    emit(state.copyWith(sourceCohortId: normalized, error: null));
  }

  void wildCollectionMethodChanged(String? wildCollectionMethod) {
    // Normalize empty/whitespace strings to null for consistency
    final normalized =
        (wildCollectionMethod == null || wildCollectionMethod.trim().isEmpty)
        ? null
        : wildCollectionMethod.trim();
    emit(state.copyWith(wildCollectionMethod: normalized, error: null));
  }

  void collectionReefOriginChanged(String? reefOrigin) {
    final normalized = (reefOrigin == null || reefOrigin.trim().isEmpty)
        ? null
        : reefOrigin.trim();
    emit(state.copyWith(collectionReefOrigin: normalized, error: null));
  }

  void collectionDateChanged(DateTime? collectionDate) {
    emit(state.copyWith(collectionDate: collectionDate, error: null));
  }

  void collectionDepthChanged(String? depth) {
    final normalized = (depth == null || depth.trim().isEmpty)
        ? null
        : depth.trim();
    emit(state.copyWith(collectionDepth: normalized, error: null));
  }

  void collectionHabitatTypeChanged(String? habitatType) {
    final normalized = (habitatType == null || habitatType.trim().isEmpty)
        ? null
        : habitatType.trim();
    emit(state.copyWith(collectionHabitatType: normalized, error: null));
  }

  void collectionInstitutionChanged(String? institution) {
    final normalized = (institution == null || institution.trim().isEmpty)
        ? null
        : institution.trim();
    emit(state.copyWith(collectionInstitution: normalized, error: null));
  }

  void collectionLatitudeChanged(String? latitude) {
    final normalized = (latitude == null || latitude.trim().isEmpty)
        ? null
        : latitude.trim();
    emit(state.copyWith(collectionLatitude: normalized, error: null));
  }

  void collectionLongitudeChanged(String? longitude) {
    final normalized = (longitude == null || longitude.trim().isEmpty)
        ? null
        : longitude.trim();
    emit(state.copyWith(collectionLongitude: normalized, error: null));
  }

  /// Florida-specific founder metadata methods
  void flRegionChanged(String? region) {
    final normalized = (region == null || region.trim().isEmpty)
        ? null
        : region.trim();
    emit(state.copyWith(flRegion: normalized, error: null));
  }

  void flFounderTypeChanged(String? founderType) {
    final normalized = (founderType == null || founderType.trim().isEmpty)
        ? null
        : founderType.trim();
    emit(state.copyWith(flFounderType: normalized, error: null));
  }

  void flHabitatCollectionTypeChanged(String? habitatType) {
    final normalized = (habitatType == null || habitatType.trim().isEmpty)
        ? null
        : habitatType.trim();
    emit(state.copyWith(flHabitatCollectionType: normalized, error: null));
  }

  void sireProvenanceIdChanged(String? sireProvenanceId) {
    // Normalize empty/whitespace strings to null for consistency
    final normalized =
        (sireProvenanceId == null || sireProvenanceId.trim().isEmpty)
        ? null
        : sireProvenanceId.trim();
    emit(state.copyWith(sireProvenanceId: normalized, error: null));
  }

  void damProvenanceIdChanged(String? damProvenanceId) {
    // Normalize empty/whitespace strings to null for consistency
    final normalized =
        (damProvenanceId == null || damProvenanceId.trim().isEmpty)
        ? null
        : damProvenanceId.trim();
    emit(state.copyWith(damProvenanceId: normalized, error: null));
  }

  void transferOrgIdChanged(String? transferOrgId) {
    final normalized = (transferOrgId == null || transferOrgId.trim().isEmpty)
        ? null
        : transferOrgId.trim();
    emit(state.copyWith(transferOrgId: normalized, error: null));
  }

  void transferEmailChanged(String? transferEmail) {
    final normalized = (transferEmail == null || transferEmail.trim().isEmpty)
        ? null
        : transferEmail.trim();
    emit(state.copyWith(transferEmail: normalized, error: null));
  }

  void localIdChanged(String? localGenetId) {
    // Normalize empty/whitespace strings to null for consistency
    final normalized = (localGenetId == null || localGenetId.trim().isEmpty)
        ? null
        : localGenetId.trim();
    emit(state.copyWith(localGenetId: normalized, error: null));
  }

  /// Changes the required record name (individual specimen identifier).
  /// This is separate from localGenetId which identifies the genet.
  void recordNameChanged(String? tagId) {
    final normalized = (tagId == null || tagId.trim().isEmpty)
        ? null
        : tagId.trim();
    emit(state.copyWith(tagId: normalized, error: null));
  }

  void suggestedLocalIdChanged(String? suggestedLocalId) {
    emit(state.copyWith(suggestedLocalId: suggestedLocalId, error: null));
  }

  void genetSelected(Genet? genet) {
    if (genet != null) {
      // Inherit provenance from genet - require a valid provenanceTypeId
      final parsedType = ProvenanceTypeX.tryParse(genet.provenanceTypeId);
      final inheritedProvenance = parsedType;
      final provenance = genet.provenance ?? const <String, dynamic>{};
      final wildMethod = provenance['collectionMethod']?.toString().trim();
      emit(
        state.copyWith(
          selectedGenet: genet,
          // Sync provenance from genet so submit() uses correct value
          provenanceType: inheritedProvenance,
          wildCollectionMethod: (wildMethod?.isNotEmpty == true)
              ? wildMethod
              : null,
          error: null,
        ),
      );
    } else {
      // Deselecting genet - reset to default provenance so user can select
      emit(
        state.copyWith(
          selectedGenet: null,
          provenanceType: ProvenanceType.wild,
          error: null,
        ),
      );
    }
  }

  void aliasesChanged(List<OrganismAlias> aliases) {
    emit(state.copyWith(aliases: aliases, error: null));
  }

  // ==========================================================================
  // PROVENANCE ID SEARCH (only active when isNewGenet == true)
  // ==========================================================================

  // ---------------------------------------------------------------------------
  // ProvenanceSearchMixin abstract members
  // ---------------------------------------------------------------------------

  @override
  String? get currentSpeciesCode => state.species?.code;

  @override
  ProvenanceSearchState get currentProvenanceSearch => state.provenanceSearch;

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    emit(state.copyWith(provenanceSearch: search));
  }

  /// Called when user types in the clonalId field. Updates state and debounces search.
  void clonalIdChanged(String? clonalId) {
    emit(state.copyWith(clonalId: clonalId, error: null));
    if (state.isNewGenet && clonalId != null) {
      onClonalIdSearchChanged(clonalId);
    }
  }

  /// Called when user types in the accessionNumber field. Updates state and debounces search.
  void accessionNumberChanged(String? accessionNumber) {
    emit(state.copyWith(accessionNumber: accessionNumber, error: null));
    if (state.isNewGenet && accessionNumber != null) {
      onAccessionSearchChanged(accessionNumber);
    }
  }

  /// Called when user types in the alias field. Updates state and debounces search.
  void aliasIdChanged(String? aliasId) {
    emit(state.copyWith(aliasId: aliasId, error: null));
    if (state.isNewGenet && aliasId != null) {
      onAliasSearchChanged(aliasId);
    }
  }

  /// Called when user types in the PID field. Updates state and debounces search.
  void provenanceIdChanged(String? provenanceId) {
    emit(state.copyWith(provenanceId: provenanceId, error: null));
    if (state.isNewGenet && provenanceId != null) {
      onProvenanceIdSearchChanged(provenanceId);
    }
  }

  void clearProvenanceSelection() {
    onProvenanceSearchReset();
    emit(
      state.copyWith(
        clonalId: null,
        accessionNumber: null,
        aliasId: null,
        provenanceId: null,
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

  void setLoading(bool loading) {
    if (isClosed) return;
    emit(
      state.copyWith(isLoading: loading, error: loading ? null : state.error),
    );
  }

  void setError(String? error) {
    if (isClosed) return;
    emit(state.copyWith(error: error, isLoading: false));
  }

  void goToStep(OrganismCreationStep step) {
    emit(state.copyWith(currentStep: step, error: null));
  }

  void nextStep() {
    if (!state.canAdvanceFromCurrentStep) return;

    final steps = _getActiveSteps();
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex < steps.length - 1) {
      final completedSteps = {...state.completedSteps, state.currentStep};
      emit(
        state.copyWith(
          currentStep: steps[currentIndex + 1],
          completedSteps: completedSteps,
          error: null,
        ),
      );
    }
  }

  void previousStep() {
    final steps = _getActiveSteps();
    final currentIndex = steps.indexOf(state.currentStep);
    if (currentIndex > 0) {
      emit(state.copyWith(currentStep: steps[currentIndex - 1], error: null));
    }
  }

  List<OrganismCreationStep> _getActiveSteps([bool? isNewGenet]) {
    // Use provided parameter or fall back to current state
    final isNew = isNewGenet ?? state.isNewGenet;

    // Return different steps based on mode
    if (isNew) {
      return [
        OrganismCreationStep.identity,
        OrganismCreationStep.provenance,
        OrganismCreationStep.biometrics,
        OrganismCreationStep.measurements,
        OrganismCreationStep.review,
      ];
    } else {
      return [
        OrganismCreationStep.identity,
        OrganismCreationStep.gainReason,
        OrganismCreationStep.biometrics,
        OrganismCreationStep.measurements,
        OrganismCreationStep.review,
      ];
    }
  }

  List<OrganismCreationStep> get activeSteps => _getActiveSteps();

  /// Maps a PopulationGainReason to a creation reason string for metadata consistency.
  /// This allows downstream analytics to use a unified 'creationReason' field.
  String _gainReasonToCreationReason(PopulationGainReason reason) {
    // Map gain reasons to equivalent creation reason strings
    // These align with the provenance-derived reasons where applicable
    if (reason.id == PopulationGainReason.fragmentation.id) {
      return 'fragmentation';
    } else if (reason.id == PopulationGainReason.recruitment.id) {
      return 'recruitment';
    } else if (reason.id == PopulationGainReason.rescue.id) {
      return 'collection'; // Rescue/collection maps to 'collection'
    } else if (reason.id == PopulationGainReason.transferIn.id) {
      return 'transfer';
    } else {
      return 'other';
    }
  }

  Map<String, dynamic>? _buildFounderProvenanceMetadata() {
    if (!state.isNewGenet || state.provenanceType != ProvenanceType.wild) {
      return null;
    }

    final metadata = <String, dynamic>{};

    final reefOrigin = state.collectionReefOrigin?.trim();
    if (reefOrigin != null && reefOrigin.isNotEmpty) {
      metadata['reefOfOrigin'] = reefOrigin;
    }

    final depth = state.collectionDepth?.trim();
    if (depth != null && depth.isNotEmpty) {
      metadata['depth'] = depth;
    }

    final habitatType = state.collectionHabitatType?.trim();
    if (habitatType != null && habitatType.isNotEmpty) {
      metadata['habitatType'] = habitatType;
    }

    final institution = state.collectionInstitution?.trim();
    if (institution != null && institution.isNotEmpty) {
      metadata['collectingInstitution'] = institution;
    }

    final latitude = state.collectionLatitude?.trim();
    if (latitude != null && latitude.isNotEmpty) {
      metadata['latitude'] = latitude;
    }

    final longitude = state.collectionLongitude?.trim();
    if (longitude != null && longitude.isNotEmpty) {
      metadata['longitude'] = longitude;
    }

    final collectionDate = state.collectionDate;
    if (collectionDate != null) {
      metadata['collectionDate'] = _formatCollectionDate(collectionDate);
    }

    return metadata.isEmpty ? null : metadata;
  }

  String _formatCollectionDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Creates an OrganismRecord from the current state.
  /// Returns null if validation fails.
  OrganismCreationResult? submit({
    required String organizationId,
    required String createdById,
    String? groupName,
    String? siteId,
    String? groupId,
    Map<String, dynamic>? additionalMetadata,
  }) {
    // Location is required for creation.
    final hasLocation =
        (groupId != null && groupId.trim().isNotEmpty) ||
        (siteId != null && siteId.trim().isNotEmpty);
    if (!hasLocation) {
      setError('Location is required. Please select a site or group.');
      return null;
    }

    // Check validation issues directly, NOT canSubmit (which includes isLoading).
    // When this method is called, isLoading is already true from the caller.
    if (state.hasValidationErrors) {
      setError(state.missingFieldsDebug);
      return null;
    }

    // Block submit if provenance search has conflicting matches
    if (state.isNewGenet && state.provenanceSearch.hasConflict) {
      setError(
        state.provenanceSearch.conflictMessage ??
            'Conflicting provenance matches. Clear one field to resolve.',
      );
      return null;
    }

    // Validate measurement metrics against field config
    if (state.measurementFieldConfig != null) {
      final metricsError = MeasurementMetricsService.validateMetrics(
        config: state.measurementFieldConfig!,
        count: state.editingCount,
      );
      if (metricsError != null) {
        setError(metricsError);
        return null;
      }
    }

    try {
      final provenanceMetadata = _buildFounderProvenanceMetadata();

      // Build provenance attributes
      final provenanceAttributes = ProvenanceAttributes(
        wildCollectionMethod: state.wildCollectionMethod,
      );

      // Build metadata with creation/gain reason
      final metadata = <String, dynamic>{...?additionalMetadata};

      // Add creation reason based on mode:
      // - New genet mode: derive from provenance type (collection, spawning, etc.)
      // - Existing inventory mode: use the selected gain reason
      // Capture resolved crosswalk PID for type-safe return value.
      final resolvedPid = state.isNewGenet
          ? state.provenanceSearch.resolvedProvenanceId
          : null;

      if (state.isNewGenet) {
        // New genet mode: use creationReason derived from provenance type
        if (state.creationReason != null) {
          metadata['creationReason'] = state.creationReason;
        }
      } else {
        // Existing inventory mode: persist the required gainReason
        // This is critical for population-gain analytics and downstream logic
        if (state.gainReason != null) {
          metadata['gainReasonId'] = state.gainReason!.id;
          // Also set creationReason to a normalized value for consistency
          metadata['creationReason'] = _gainReasonToCreationReason(
            state.gainReason!,
          );
        }
      }

      if (state.provenanceType == ProvenanceType.transfer) {
        final transferOrgId = state.transferOrgId?.trim();
        final transferEmail = state.transferEmail?.trim();
        if (transferOrgId != null && transferOrgId.isNotEmpty) {
          metadata['sourceOrganizationId'] = transferOrgId;
        }
        if (transferEmail != null && transferEmail.isNotEmpty) {
          metadata['sourceOrganizationEmail'] = transferEmail;
        }
      }

      // Genet's local ID: selected genet name, explicit local ID, or suggested ID.
      // This is the genet's name (e.g., "ACER-001"), used for the genet record.
      final genetLocalId = state.effectiveLocalId;

      final tagId = (state.tagId?.trim().isNotEmpty ?? false)
          ? state.tagId!.trim()
          : (genetLocalId ?? 'Unknown');

      final resolvedLifeStage = state.lifeStage ?? LifeStage.unknown;

      final physicalForm =
          resolvedLifeStage == LifeStage.unknown && state.physicalForm == null
          ? const PhysicalFormInstance(
              formId: unknownPhysicalFormId,
              sizeBandId: unknownPhysicalFormSizeBandId,
            )
          : state.physicalForm;

      final record = OrganismRecord.create(
        id: genetLocalId,
        organismKind: state.organismKind ?? OrganismKind.coral,
        organizationId: organizationId,
        createdById: createdById,
        lifeStage: LifeStageSpec(stage: resolvedLifeStage),
        measurement: state.measurement,
        tagId: tagId,
        speciesId: state.species?.id,
        // Store the genet/local ID as the organism's primary display identifier
        localGenetId: genetLocalId,
        siteId: siteId,
        groupId: groupId,
        provenanceType: state.provenanceType ?? ProvenanceType.unknown,
        provenanceAttributes: provenanceAttributes,
        physicalForm: physicalForm,
        sizeSpec: state.sizeSpec.copyWith(
          countOverride: state.editingCount,
        ),
        aliases: state.aliases,
        genetRecordId: state.selectedGenet?.id,
        metadata: metadata.isNotEmpty ? metadata : null,
      );

      final normalizedClonalId = state.clonalId?.trim();
      final normalizedAccessionNumber = state.accessionNumber?.trim();
      return OrganismCreationResult(
        record: record,
        inheritedProvenanceId: resolvedPid,
        clonalValue: normalizedClonalId != null && normalizedClonalId.isNotEmpty
            ? normalizedClonalId
            : null,
        accessionValue:
            normalizedAccessionNumber != null &&
                normalizedAccessionNumber.isNotEmpty
            ? normalizedAccessionNumber
            : null,
        provenanceMetadata: provenanceMetadata,
      );
    } on StateError catch (e, stackTrace) {
      LoggingService.instance.error(
        'State error creating organism record: ${e.message}',
        e,
        stackTrace,
      );
      setError('Failed to create organism record: ${e.message}');
      return null;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create organism record',
        e,
        stackTrace,
      );
      setError('Failed to create organism record: $e');
      return null;
    }
  }
}
