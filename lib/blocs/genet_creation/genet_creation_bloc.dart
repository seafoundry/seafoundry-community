// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';

/// Simple BLoC for genet creation with all community-dev features
/// Replaces 30+ custom events with simple methods
class GenetCreationBloc extends SafeCubit<GenetCreationState>
    with ProvenanceSearchMixin<GenetCreationState> {
  GenetCreationBloc({
    required this.genetRepository,
    required this.organizationRepository,
    required this.invitationRepository,
    this.provenanceLookupService,
  }) : super(GenetCreationInitial());

  final GenetRepository genetRepository;
  final OrganizationRepository organizationRepository;
  final InvitationRepository invitationRepository;
  @override
  final ProvenanceLookupService? provenanceLookupService;
  Genet? _editingGenet;
  Genet? get editingGenet => _editingGenet;

  /// Request ID counter to prevent stale name validation responses from
  /// being applied after newer requests have been made.
  int _nameValidationRequestId = 0;

  /// Convenience accessor for the in-progress state.
  GenetCreationInProgress? get _inProgress {
    final s = state;
    return s is GenetCreationInProgress ? s : null;
  }

  // ---------------------------------------------------------------------------
  // ProvenanceSearchMixin abstract members
  // ---------------------------------------------------------------------------

  @override
  String? get currentSpeciesCode => _inProgress?.formState.species.value?.code;

  @override
  ProvenanceSearchState get currentProvenanceSearch =>
      _inProgress?.provenanceSearch ?? const ProvenanceSearchState();

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    final current = _inProgress;
    if (current != null) {
      emit(current.copyWith(provenanceSearch: search));
    }
  }

  @override
  void onProvenanceSuggestionSelected(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField field,
  ) {
    super.onProvenanceSuggestionSelected(suggestion, field);
    final current = _inProgress;
    if (current != null &&
        current.provenanceIdSearchValue != suggestion.provenanceId) {
      emit(current.copyWith(provenanceIdSearchValue: suggestion.provenanceId));
    }
    _populateComplementaryProvenanceData(suggestion, field);
  }

  Future<void> _populateComplementaryProvenanceData(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField sourceField,
  ) async {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final service = provenanceLookupService;
    if (service == null) return;

    try {
      final record = await service.getProvenanceRecord(suggestion.provenanceId);
      if (record == null) return;

      // Re-read state after await
      final freshState = state;
      if (freshState is! GenetCreationInProgress) return;

      var updatedForm = freshState.formState;
      bool changed = false;

      // 1. Populate Accession Number if Clonal ID matched & Accession is empty
      if (sourceField == ProvenanceMatchField.clonalId) {
        if ((updatedForm.accessionNumber.value ?? '').isEmpty) {
          final accAlias = record.aliases.firstWhereOrNull(
            (a) => _isAccessionAliasType(
              ProvenanceAliasType.fromString(a.orgType),
            ),
          );
          if (accAlias != null) {
            updatedForm = updatedForm.copyWith(
              accessionNumber: GenetAccessionNumber.dirty(accAlias.id),
            );
            changed = true;
          }
        }
      }

      // 2. Populate Clonal ID if Accession Number matched & Clonal ID is empty
      if (sourceField == ProvenanceMatchField.accessionNumber) {
        if ((updatedForm.clonalId.value ?? '').isEmpty) {
          String? bestClonalId = record.masterClonalId;
          if (bestClonalId == null || bestClonalId.isEmpty) {
            final clonalAlias = record.aliases.firstWhereOrNull(
              (a) =>
                  ProvenanceAliasType.fromString(a.orgType) ==
                  ProvenanceAliasType.clonalId,
            );
            bestClonalId = clonalAlias?.id;
          }

          if (bestClonalId != null && bestClonalId.isNotEmpty) {
            updatedForm = updatedForm.copyWith(
              clonalId: GenetClonalId.dirty(bestClonalId),
            );
            changed = true;
          }
        }
      }

      if (changed) {
        emit(freshState.copyWith(formState: updatedForm));
      }
    } catch (e, stack) {
      LoggingService.instance.error(
        'Failed to populate complementary provenance data',
        e,
        stack,
      );
    }
  }

  bool _isAccessionAliasType(ProvenanceAliasType type) =>
      type == ProvenanceAliasType.accessionNumber ||
      type == ProvenanceAliasType.csr;

  /// Initialize with optional pre-selected values
  void initialize({
    Species? initialSpecies,
    ProvenanceType? initialProvenanceType,
    List<ProvenanceType>? allowedProvenanceTypes,
  }) {
    final allowedTypes =
        allowedProvenanceTypes ?? deriveAllowedProvenanceTypes();

    final candidateType =
        initialProvenanceType ??
        (allowedTypes.isNotEmpty ? allowedTypes.first : ProvenanceType.wild);

    final finalProvenanceType = allowedTypes.contains(candidateType)
        ? candidateType
        : allowedTypes.first;

    var formState = GenetFormState(allowedProvenanceTypes: allowedTypes);
    formState = _applyProvenanceSelection(
      formState,
      finalProvenanceType,
      resetLifeStage: true,
    );

    _editingGenet = null;
    emit(
      GenetCreationInProgress(
        formState: formState,
        isEditing: false,
        originalGenet: null,
      ),
    );

    if (!_supportsReadyForOutplant(finalProvenanceType)) {
      onReadyForOutplantChanged(false);
    }

    // Pre-select species if provided
    if (initialSpecies != null) {
      onSpeciesChanged(initialSpecies);
    }
  }

  void initializeForEdit(Genet genet, {int initialStep = 0}) {
    final resolvedInitialStep = initialStep.clamp(0, 3);
    final species = Species.lookupById(genet.speciesId);
    final aliasEntries = _aliasEntriesFrom(genet);
    final metadata = genet.metadata;
    final metadataLifeStage = LifeStageX.tryParse(
      metadata['lifeStageId']?.toString(),
    );
    final metadataProvenanceType = ProvenanceTypeX.tryParse(
      metadata['provenanceTypeId']?.toString(),
    );
    final resolvedProvenanceType =
        metadataProvenanceType ?? _inferProvenanceTypeFromGenet(genet);
    final resolvedLifeStage =
        metadataLifeStage ?? resolvedProvenanceType.defaultLifeStage;
    final allowedProvenanceTypes = _allowedProvenanceTypesForEdit(
      resolvedProvenanceType,
    );

    var formState = GenetFormState(
      name: GenetName.dirty(genet.name),
      species: species != null
          ? GenetSpeciesSelection.dirty(species)
          : const GenetSpeciesSelection.pure(),
      slug: genet.slug,
      clonalId: GenetClonalId.dirty(genet.clonalId),
      accessionNumber: GenetAccessionNumber.dirty(genet.accessionNumber),
      notes: GenetNotes.dirty(genet.notes ?? ''),
      allowedProvenanceTypes: allowedProvenanceTypes,
      provenanceType: GenetProvenanceTypeSelection.dirty(
        resolvedProvenanceType,
      ),
      lifeStage: GenetLifeStageSelection.dirty(resolvedLifeStage),
      readyForOutplant: GenetReadyForOutplant.dirty(genet.readyForOutplant),
      aliases: aliasEntries,
      heatTested: genet.heatTested,
      diseaseTested: genet.diseaseTested,
      heatTestingComment: genet.heatTestingComment ?? '',
      diseaseTestingComment: genet.diseaseTestingComment ?? '',
      currentStep: resolvedInitialStep,
    );

    final provenance = genet.provenance ?? const <String, dynamic>{};

    switch (resolvedProvenanceType) {
      case ProvenanceType.wild:
        final collectionDate = _parseDateString(
          _readProvenanceValue(provenance, [
            'collection_date',
            'collectionDate',
          ]),
        );
        final latitude = _readProvenanceValue(provenance, ['latitude', 'lat']);
        final longitude = _readProvenanceValue(provenance, [
          'longitude',
          'lng',
        ]);
        formState = formState.copyWith(
          provOrigin: ProvenanceText.dirty(
            _readProvenanceValue(provenance, [
              'reef_of_origin',
              'reefOfOrigin',
            ]),
          ),
          provLocation: ProvenanceText.dirty(
            _readProvenanceValue(provenance, ['location']),
          ),
          provCollector: ProvenanceText.dirty(
            _readProvenanceValue(provenance, ['collector']),
          ),
          provDepth: ProvenanceText.dirty(
            _readProvenanceValue(provenance, ['depth']),
          ),
          provHabitatType: ProvenanceText.dirty(
            _readProvenanceValue(provenance, ['habitat_type', 'habitatType']),
          ),
          provInstitution: ProvenanceText.dirty(
            _readProvenanceValue(provenance, [
              'collecting_institution',
              'collectingInstitution',
            ]),
          ),
          provLatitude: ProvenanceLatitude.dirty(latitude),
          provLongitude: ProvenanceLongitude.dirty(longitude),
          provCollectionDate: ProvenanceCollectionDate.dirty(collectionDate),
        );

        final transferOrg = _readProvenanceValue(provenance, [
          'sending_organization',
          'sendingOrganization',
        ]);
        final transferNotes = _readProvenanceValue(provenance, [
          'transfer_notes',
          'transferNotes',
        ]);
        final transferDate = _parseDateString(
          _readProvenanceValue(provenance, ['transfer_date', 'transferDate']),
        );
        final sendTransfer =
            transferOrg.isNotEmpty ||
            transferNotes.isNotEmpty ||
            transferDate != null;
        if (sendTransfer) {
          formState = formState.copyWith(
            sendTransfer: true,
            transferOrgId: transferOrg.isEmpty ? 'unknown' : transferOrg,
            transferNotes: TransferNotes.dirty(transferNotes),
            transferDate: TransferDateSelection.dirty(transferDate),
          );
        }
        break;
      case ProvenanceType.sexualCohort:
        final parentIds = List<String>.from(genet.parentGameteIds ?? const []);
        final damEntries = (genet.damGameteIds ?? const <String>[]).map(
          (id) => CrossGameteEntry(id: id, role: CrossGameteRole.dam),
        );
        final sireEntries = (genet.sireGameteIds ?? const <String>[]).map(
          (id) => CrossGameteEntry(id: id, role: CrossGameteRole.sire),
        );
        formState = formState.copyWith(
          parentGameteIds: GenetParentGameteIds.dirty(parentIds),
          crossGametes: GenetCrossGametes.dirty([
            ...damEntries,
            ...sireEntries,
          ]),
          crossDate: GenetCrossDate.dirty(genet.crossDate),
        );
        break;
      case ProvenanceType.graduatedIndividual:
        formState = formState.copyWith(
          parentCohortId: GenetParentCohortId.dirty(genet.parentCohortId ?? ''),
        );
        break;
      case ProvenanceType.transfer:
      case ProvenanceType.unknown:
        // No specific provenance fields for these types
        break;
    }

    // Handle gamete life stage separately
    if (resolvedLifeStage == LifeStage.gamete) {
      final spawnDate = _parseDateString(
        _readProvenanceValue(provenance, ['spawn_date', 'spawnDate']),
      );
      final sexValue = _readProvenanceValue(provenance, [
        'gamete_sex',
        'gameteSex',
      ]);
      final gameteSex = switch (sexValue.toLowerCase()) {
        'eggs' => GameteSex.eggs,
        'sperm' => GameteSex.sperm,
        _ => null,
      };
      formState = formState.copyWith(
        donorGenotypeId: GenetDonorGenotypeId.dirty(
          genet.donorGenotypeId ?? '',
        ),
        gameteSex: GameteSexSelection.dirty(gameteSex),
        gameteSpawnDate: GameteSpawnDateSelection.dirty(spawnDate),
      );
    }

    final ownerId =
        genet.metadata['ownerOrganizationId']?.toString().trim() ?? '';
    final managingId =
        genet.metadata['managingOrganizationId']?.toString().trim() ?? '';
    formState = formState.copyWith(
      ownerOrganizationId: ownerId,
      managingOrganizationId: managingId,
    );

    _editingGenet = genet;
    emit(
      GenetCreationInProgress(
        formState: formState,
        isEditing: true,
        originalGenet: genet,
      ),
    );
  }

  /// Helper method to populate collector and institution from current user/org
  GenetFormState _populateCollectorAndInstitution(GenetFormState formState) {
    final user = genetRepository.user;
    final organization = genetRepository.organization;

    return formState.copyWith(
      provCollector: formState.provCollector.value.isEmpty
          ? ProvenanceText.dirty(user.name)
          : formState.provCollector,
      provInstitution: formState.provInstitution.value.isEmpty
          ? ProvenanceText.dirty(organization.name)
          : formState.provInstitution,
    );
  }

  ProvenanceType _inferProvenanceTypeFromGenet(Genet genet) {
    // Infer from parent relationships
    if (genet.parentGameteIds != null && genet.parentGameteIds!.isNotEmpty) {
      return ProvenanceType.sexualCohort;
    }
    if (genet.parentCohortId != null && genet.parentCohortId!.isNotEmpty) {
      return ProvenanceType.graduatedIndividual;
    }

    // Check if it has wild collection provenance
    final provenance = genet.provenance ?? const <String, dynamic>{};
    if (provenance.containsKey('reef_of_origin') ||
        provenance.containsKey('reefOfOrigin') ||
        provenance.containsKey('collector')) {
      return ProvenanceType.wild;
    }

    // Default to wild for founder-like genets
    return ProvenanceType.wild;
  }

  GenetFormState _applyProvenanceSelection(
    GenetFormState formState,
    ProvenanceType type, {
    required bool resetLifeStage,
  }) {
    var workingForm = _ensureAllowedProvenanceTypes(formState);

    workingForm = workingForm.copyWith(
      provenanceType: GenetProvenanceTypeSelection.dirty(type),
    );

    final shouldResetLifeStage =
        resetLifeStage || workingForm.lifeStage.value == null;
    if (shouldResetLifeStage) {
      workingForm = workingForm.copyWith(
        lifeStage: GenetLifeStageSelection.dirty(type.defaultLifeStage),
      );
    }

    if (type == ProvenanceType.wild) {
      workingForm = _populateCollectorAndInstitution(workingForm);
    }

    return workingForm;
  }

  GenetFormState _ensureAllowedProvenanceTypes(GenetFormState formState) {
    final existing = formState.allowedProvenanceTypes;
    if (existing != null && existing.isNotEmpty) {
      return formState;
    }
    final derived = deriveAllowedProvenanceTypes();
    return formState.copyWith(allowedProvenanceTypes: derived);
  }

  List<ProvenanceType> _allowedProvenanceTypesForEdit(ProvenanceType type) {
    if (type == ProvenanceType.unknown || type == ProvenanceType.transfer) {
      return ProvenanceType.values;
    }
    return [type];
  }

  List<String> _aliasLabelsFrom(Genet genet) => genet.aliasLabels;

  List<GenetAliasEntry> _aliasEntriesFrom(Genet genet) {
    final raw = genet.aliases ?? const <Map<String, dynamic>>[];
    if (raw.isEmpty) return const [];
    return raw
        .map(
          (entry) => GenetAliasEntry(
            sourceSystem:
                entry['sourceSystem']?.toString() ??
                entry['source']?.toString() ??
                'custom',
            value:
                entry['value']?.toString() ?? entry['label']?.toString() ?? '',
            label: entry['label']?.toString(),
          ),
        )
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _readProvenanceValue(
    Map<String, dynamic> provenance,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = provenance[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return '';
  }

  DateTime? _parseDateString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      return DateTime.parse(trimmed);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _computeGenetChanges(Genet original, Genet updated) {
    final changes = <String, dynamic>{};
    const deepEquality = DeepCollectionEquality();

    void track(String field, dynamic before, dynamic after) {
      if (deepEquality.equals(before, after)) return;
      changes[field] = {'before': before, 'after': after};
    }

    track('name', original.name, updated.name);
    track('speciesId', original.speciesId, updated.speciesId);
    track(
      'provenanceTypeId',
      original.provenanceTypeId,
      updated.provenanceTypeId,
    );
    track('clonalId', original.clonalId, updated.clonalId);
    track('accessionNumber', original.accessionNumber, updated.accessionNumber);
    track('notes', original.notes, updated.notes);
    track(
      'provenance',
      original.provenance ?? const {},
      updated.provenance ?? const {},
    );
    track(
      'parentGameteIds',
      original.parentGameteIds ?? const <String>[],
      updated.parentGameteIds ?? const <String>[],
    );
    track(
      'damGameteIds',
      original.damGameteIds ?? const <String>[],
      updated.damGameteIds ?? const <String>[],
    );
    track(
      'sireGameteIds',
      original.sireGameteIds ?? const <String>[],
      updated.sireGameteIds ?? const <String>[],
    );
    track('parentCohortId', original.parentCohortId, updated.parentCohortId);
    track('donorGenotypeId', original.donorGenotypeId, updated.donorGenotypeId);
    track(
      'crossDate',
      original.crossDate?.toIso8601String(),
      updated.crossDate?.toIso8601String(),
    );
    track('aliases', _aliasLabelsFrom(original), _aliasLabelsFrom(updated));
    return changes;
  }

  // ==========================================================================
  // CORE FIELD UPDATES (Required for all genet types)
  // ==========================================================================

  /// Update species and auto-suggest name
  Future<void> onSpeciesChanged(Species species) async {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    if (current.isEditing) {
      emit(
        current.copyWith(
          formState: current.formState.copyWith(
            species: GenetSpeciesSelection.dirty(species),
          ),
          nameValidationError: null,
          suggestedName: null,
        ),
      );
      return;
    }

    // Species changed -- reset provenance search state since PIDs are
    // species-scoped and prior matches are now invalid.
    onProvenanceSearchReset();

    // Auto-suggest next available local genet ID
    String suggestedName;
    try {
      suggestedName = await genetRepository.suggestNextLocalId(species.id);
    } catch (e) {
      // Fallback to simple format
      final code = species.id.toLowerCase();
      final formattedCode = code[0].toUpperCase() + code.substring(1);
      suggestedName = '$formattedCode-1';
    }

    // Re-read state after the await -- onProvenanceSearchReset() emitted
    // an updated state above, so the original `current` is now stale.
    final fresh = _inProgress;
    if (fresh == null) return;

    // Update species and suggested name
    emit(
      fresh.copyWith(
        formState: fresh.formState.copyWith(
          species: GenetSpeciesSelection.dirty(species),
          name: GenetName.dirty(suggestedName),
        ),
        nameValidationError: null,
        suggestedName: null,
      ),
    );

    // Trigger validation for the suggested name to ensure uniqueness
    await onNameChanged(suggestedName);
  }

  Future<void> onNameChanged(String name) async {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final trimmedName = name.trim();

    // Determine whether async validation will proceed so we can set
    // nameValidationInProgress atomically in a single emit, closing
    // the race window where submit() could slip through between two
    // separate emits.
    final skipAsync =
        trimmedName.isEmpty ||
        trimmedName.length < 2 ||
        (_editingGenet != null &&
            trimmedName.toLowerCase() ==
                _editingGenet!.name.trim().toLowerCase());

    // Single emit: update the name and, when async validation will
    // proceed, set nameValidationInProgress in the same state update.
    emit(
      current.copyWith(
        formState: current.formState.copyWith(name: GenetName.dirty(name)),
        nameValidationError: null,
        suggestedName: null,
        nameValidationInProgress: skipAsync ? false : true,
      ),
    );

    if (skipAsync) return;

    // Increment request ID to track this validation request
    final requestId = ++_nameValidationRequestId;

    // Perform async uniqueness check
    try {
      final isUnique = await genetRepository.isGenetNameUnique(
        name: trimmedName,
        excludeRecordId: _editingGenet?.id,
      );

      // Guard against stale responses: if bloc is closed or a newer request
      // has been made, discard this result to prevent race conditions.
      if (isClosed || requestId != _nameValidationRequestId) return;

      final currentState = state;
      if (currentState is! GenetCreationInProgress) return;

      if (!isUnique) {
        // Name is duplicate - suggest next available name
        String suggestedName;
        try {
          final species = currentState.formState.species.value;
          if (species != null) {
            suggestedName = await genetRepository.suggestNextLocalId(
              species.id,
            );
          } else {
            // Fallback if no species selected yet
            final code = trimmedName.split('-').first.toLowerCase();
            final formattedCode = code[0].toUpperCase() + code.substring(1);
            suggestedName = '$formattedCode-1';
          }
        } catch (e) {
          // Fallback suggestion
          final code = trimmedName.split('-').first.toLowerCase();
          final formattedCode = code[0].toUpperCase() + code.substring(1);
          suggestedName = '$formattedCode-1';
        }

        // Re-check after second await for suggestion
        if (isClosed || requestId != _nameValidationRequestId) return;

        emit(
          currentState.copyWith(
            formState: currentState.formState.copyWith(
              name: GenetName.dirty(trimmedName),
            ),
            nameValidationError: GenetNameError.duplicate.message,
            suggestedName: suggestedName,
            nameValidationInProgress: false,
          ),
        );
      } else {
        // Name is unique - clear any previous errors
        emit(
          currentState.copyWith(
            formState: currentState.formState.copyWith(
              name: GenetName.dirty(trimmedName),
            ),
            nameValidationError: null,
            suggestedName: null,
            nameValidationInProgress: false,
          ),
        );
      }
    } catch (e) {
      // Guard against stale responses on error path as well
      if (isClosed || requestId != _nameValidationRequestId) return;

      // On error, don't block the user - validation will happen at submission
      final currentState = state;
      if (currentState is! GenetCreationInProgress) return;
      emit(
        currentState.copyWith(
          formState: currentState.formState.copyWith(
            name: GenetName.dirty(trimmedName),
          ),
          nameValidationError: null,
          suggestedName: null,
          nameValidationInProgress: false,
        ),
      );
    }
  }

  void onProvenanceTypeChanged(ProvenanceType type) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final allowed =
        current.formState.allowedProvenanceTypes ??
        deriveAllowedProvenanceTypes();

    var nextType = type;
    if (allowed.isNotEmpty && !allowed.contains(nextType)) {
      nextType = allowed.first;
    }

    final baseForm = current.formState.allowedProvenanceTypes == null
        ? current.formState.copyWith(allowedProvenanceTypes: allowed)
        : current.formState;

    final nextForm = _applyProvenanceSelection(
      baseForm,
      nextType,
      resetLifeStage: true,
    );

    emit(current.copyWith(formState: nextForm));

    if (!_supportsReadyForOutplant(nextType)) {
      onReadyForOutplantChanged(false);
    }
  }

  bool _supportsReadyForOutplant(ProvenanceType provenanceType) {
    // Cohorts and gametes cannot be marked as ready for outplant
    return provenanceType != ProvenanceType.sexualCohort;
  }

  void onClonalIdChanged(String clonalId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          clonalId: GenetClonalId.dirty(clonalId),
        ),
      ),
    );
    onClonalIdSearchChanged(clonalId);
  }

  void onAccessionNumberChanged(String accessionNumber) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          accessionNumber: GenetAccessionNumber.dirty(accessionNumber),
        ),
      ),
    );
    onAccessionSearchChanged(accessionNumber);
  }

  void onAliasSearchValueChanged(String aliasValue) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(current.copyWith(aliasSearchValue: aliasValue));
    onAliasSearchChanged(aliasValue);
  }

  void onProvenanceIdSearchValueChanged(String provenanceId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(current.copyWith(provenanceIdSearchValue: provenanceId));
    onProvenanceIdSearchChanged(provenanceId);
  }

  void clearProvenanceSelection() {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    onProvenanceSearchReset();
    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          clonalId: const GenetClonalId.dirty(''),
          accessionNumber: const GenetAccessionNumber.dirty(''),
        ),
        aliasSearchValue: '',
        provenanceIdSearchValue: '',
      ),
    );
  }

  void setActiveProvenanceField(ProvenanceMatchField field) {
    emitProvenanceSearch(currentProvenanceSearch.copyWith(activeField: field));
  }

  void onOwnerOrganizationChanged(String ownerOrgId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    emit(
      current.copyWith(
        formState: current.formState.copyWith(ownerOrganizationId: ownerOrgId),
      ),
    );
  }

  void onManagingOrganizationChanged(String managingOrgId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          managingOrganizationId: managingOrgId,
        ),
      ),
    );
  }

  void onAliasAdded() {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final updatedAliases = List<GenetAliasEntry>.from(current.formState.aliases)
      ..add(const GenetAliasEntry());
    emit(
      current.copyWith(
        formState: current.formState.copyWith(aliases: updatedAliases),
      ),
    );
  }

  void onAliasValueChanged(int index, String value) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    if (index < 0 || index >= current.formState.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(
      current.formState.aliases,
    );
    updatedAliases[index] = updatedAliases[index].copyWith(value: value);
    emit(
      current.copyWith(
        formState: current.formState.copyWith(aliases: updatedAliases),
      ),
    );
  }

  void onAliasSourceChanged(int index, String sourceSystem) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    if (index < 0 || index >= current.formState.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(
      current.formState.aliases,
    );
    updatedAliases[index] = updatedAliases[index].copyWith(
      sourceSystem: sourceSystem,
    );
    emit(
      current.copyWith(
        formState: current.formState.copyWith(aliases: updatedAliases),
      ),
    );
  }

  void onAliasLabelChanged(int index, String label) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    if (index < 0 || index >= current.formState.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(
      current.formState.aliases,
    );
    updatedAliases[index] = updatedAliases[index].copyWith(label: label);
    emit(
      current.copyWith(
        formState: current.formState.copyWith(aliases: updatedAliases),
      ),
    );
  }

  void onAliasRemoved(int index) {
    final current = state;
    if (current is! GenetCreationInProgress) return;
    if (index < 0 || index >= current.formState.aliases.length) return;

    final updatedAliases = List<GenetAliasEntry>.from(current.formState.aliases)
      ..removeAt(index);
    emit(
      current.copyWith(
        formState: current.formState.copyWith(aliases: updatedAliases),
      ),
    );
  }

  void onNotesChanged(String notes) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(notes: GenetNotes.dirty(notes)),
      ),
    );
  }

  void onHeatTestedToggled(bool value) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(heatTested: value),
      ),
    );
  }

  void onDiseaseTestedToggled(bool value) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(diseaseTested: value),
      ),
    );
  }

  void onHeatTestingCommentChanged(String comment) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(heatTestingComment: comment),
      ),
    );
  }

  void onDiseaseTestingCommentChanged(String comment) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(diseaseTestingComment: comment),
      ),
    );
  }

  @visibleForTesting
  void onReadyForOutplantChanged(bool value) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final formState = current.formState.copyWith(
      readyForOutplant: GenetReadyForOutplant.dirty(value),
    );

    emit(current.copyWith(formState: formState));
  }

  // ==========================================================================
  // PROVENANCE FIELDS (Only for Wild Collection - provenanceType == 'wild')
  // ==========================================================================

  void onProvOriginChanged(String origin) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provOrigin: ProvenanceText.dirty(origin),
        ),
      ),
    );
  }

  void onProvLocationChanged(String location) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provLocation: ProvenanceText.dirty(location),
        ),
      ),
    );
  }

  void onProvCollectorChanged(String collector) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provCollector: ProvenanceText.dirty(collector),
        ),
      ),
    );
  }

  void onProvDepthChanged(String depth) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provDepth: ProvenanceText.dirty(depth),
        ),
      ),
    );
  }

  void onProvHabitatTypeChanged(String habitatType) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provHabitatType: ProvenanceText.dirty(habitatType),
        ),
      ),
    );
  }

  void onProvInstitutionChanged(String institution) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provInstitution: ProvenanceText.dirty(institution),
        ),
      ),
    );
  }

  void onProvLatitudeChanged(String latitude) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provLatitude: ProvenanceLatitude.dirty(latitude),
        ),
      ),
    );
  }

  void onProvLongitudeChanged(String longitude) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provLongitude: ProvenanceLongitude.dirty(longitude),
        ),
      ),
    );
  }

  void onProvCollectionDateChanged(DateTime? collectionDate) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          provCollectionDate: ProvenanceCollectionDate.dirty(collectionDate),
        ),
      ),
    );
  }

  // ==========================================================================
  // CROSS TRACKING (Only for Sexual Cohorts - provenanceType == 'sexual_cohort')
  // ==========================================================================

  void onCrossGameteAdded() {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final currentEntries = current.formState.crossGametes.value;
    final newEntries = [
      ...currentEntries,
      const CrossGameteEntry(id: '', role: CrossGameteRole.dam),
    ];

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          crossGametes: GenetCrossGametes.dirty(newEntries),
        ),
      ),
    );
  }

  void onCrossGameteRemoved(int index) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final currentEntries = current.formState.crossGametes.value;
    final newEntries = List<CrossGameteEntry>.from(currentEntries)
      ..removeAt(index);

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          crossGametes: GenetCrossGametes.dirty(newEntries),
        ),
      ),
    );
  }

  void onCrossGameteUpdated(int index, String id) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final currentEntries = current.formState.crossGametes.value;
    final newEntries = List<CrossGameteEntry>.from(currentEntries);
    if (index >= 0 && index < newEntries.length) {
      newEntries[index] = newEntries[index].copyWith(id: id);
    }

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          crossGametes: GenetCrossGametes.dirty(newEntries),
        ),
      ),
    );
  }

  void onCrossGameteRoleChanged(int index, CrossGameteRole role) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final currentEntries = current.formState.crossGametes.value;
    final newEntries = List<CrossGameteEntry>.from(currentEntries);
    if (index >= 0 && index < newEntries.length) {
      newEntries[index] = newEntries[index].copyWith(role: role);
    }

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          crossGametes: GenetCrossGametes.dirty(newEntries),
        ),
      ),
    );
  }

  void onCrossDateChanged(DateTime? crossDate) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          crossDate: GenetCrossDate.dirty(crossDate),
        ),
      ),
    );
  }

  // ==========================================================================
  // GAMETE TRACKING (Only for Gametes - lifeStage == 'gamete')
  // ==========================================================================

  void onDonorGenotypeIdChanged(String donorGenotypeId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          donorGenotypeId: GenetDonorGenotypeId.dirty(donorGenotypeId),
        ),
      ),
    );
  }

  void onGameteSexChanged(GameteSex sex) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          gameteSex: GameteSexSelection.dirty(sex),
        ),
      ),
    );
  }

  void onGameteSpawnDateChanged(DateTime? date) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          gameteSpawnDate: GameteSpawnDateSelection.dirty(date),
        ),
      ),
    );
  }

  // ==========================================================================
  // GRADUATED INDIVIDUAL (Only for Graduated Individuals - provenanceType == 'graduated_individual')
  // ==========================================================================

  void onParentCohortIdChanged(String parentCohortId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          parentCohortId: GenetParentCohortId.dirty(parentCohortId),
        ),
      ),
    );
  }

  // ==========================================================================
  // TRANSFER WORKFLOWS (All genet types)
  // ==========================================================================

  void onSendTransferToggled(bool sendTransfer) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    var updatedForm = current.formState.copyWith(sendTransfer: sendTransfer);

    if (sendTransfer) {
      updatedForm = updatedForm.copyWith(
        transferOrgId: '',
        transferEmail: '',
        transferNotes: const TransferNotes.pure(),
        transferDate: const TransferDateSelection.pure(),
        provCollector: const ProvenanceText.dirty(''),
        provInstitution: const ProvenanceText.dirty(''),
      );
    } else {
      updatedForm = _populateCollectorAndInstitution(
        updatedForm.copyWith(
          transferOrgId: '',
          transferEmail: '',
          transferNotes: const TransferNotes.pure(),
          transferDate: const TransferDateSelection.pure(),
        ),
      );
    }

    emit(current.copyWith(formState: updatedForm));
  }

  void onTransferOrgChanged(String? organizationId) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final orgId = (organizationId ?? '').trim();

    if (orgId.isEmpty) {
      emit(
        current.copyWith(
          formState: current.formState.copyWith(transferOrgId: ''),
        ),
      );
      return;
    }

    // Special case: "unknown" auto-fills all provenance fields
    if (orgId == 'unknown') {
      emit(
        current.copyWith(
          formState: current.formState.copyWith(
            transferOrgId: orgId,
            // Auto-populate provenance fields with "unknown"
            provOrigin: const ProvenanceText.dirty('unknown'),
            provLocation: const ProvenanceText.dirty('unknown'),
            provCollector: const ProvenanceText.dirty('unknown'),
            provDepth: const ProvenanceText.dirty('unknown'),
            provHabitatType: const ProvenanceText.dirty('unknown'),
            provInstitution: const ProvenanceText.dirty('unknown'),
            provLatitude: const ProvenanceLatitude.dirty('unknown'),
            provLongitude: const ProvenanceLongitude.dirty('unknown'),
            notes: current.formState.notes.value.isEmpty
                ? const GenetNotes.dirty('Received from partner organization')
                : current.formState.notes,
          ),
        ),
      );
    } else {
      emit(
        current.copyWith(
          formState: current.formState.copyWith(transferOrgId: orgId),
        ),
      );
    }
  }

  void onTransferOrganizationSelected(Organization organization) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          transferOrgId: organization.id,
          provInstitution: ProvenanceText.dirty(organization.name),
        ),
      ),
    );
  }

  void onTransferOrgNameEdited(String organizationName) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          transferOrgId: organizationName.trim(),
          provInstitution: ProvenanceText.dirty(organizationName),
        ),
      ),
    );
  }

  void onTransferEmailChanged(String email) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(transferEmail: email.trim()),
      ),
    );
  }

  void onTransferDateChanged(DateTime? date) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          transferDate: TransferDateSelection.dirty(date),
        ),
      ),
    );
  }

  void onTransferNotesChanged(String notes) {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    emit(
      current.copyWith(
        formState: current.formState.copyWith(
          transferNotes: TransferNotes.dirty(notes),
        ),
      ),
    );
  }

  Future<void> _sendPartnerInvitation(String email) async {
    try {
      await invitationRepository.createInvitation(
        email: email,
        organizationId: genetRepository.organization.id,
        invitedById: genetRepository.user.id,
      );
    } catch (e, stack) {
      LoggingService.instance.error(
        'Failed to send partner invitation',
        e,
        stack,
      );
    }
  }

  // ==========================================================================
  // MULTI-STEP DIALOG NAVIGATION
  // ==========================================================================

  void onNextStep() {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final newStep = current.formState.currentStep + 1;
    emit(
      current.copyWith(
        formState: current.formState.copyWith(currentStep: newStep),
      ),
    );
  }

  void onPreviousStep() {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final newStep = (current.formState.currentStep - 1).clamp(0, 2);
    emit(
      current.copyWith(
        formState: current.formState.copyWith(currentStep: newStep),
      ),
    );
  }

  // ==========================================================================
  // SUBMISSION
  // ==========================================================================

  Future<void> submit() async {
    final current = state;
    if (current is! GenetCreationInProgress) return;

    final formState = current.formState;
    if (!formState.isFormValid) {
      final errorMessage =
          formState.validationErrorMessage ??
          'Please complete all required fields';
      _emitError(errorMessage);
      return;
    }

    // Block submit while async name validation is still running
    if (current.nameValidationInProgress) {
      _emitError(
        'Name validation is still in progress. Please wait a moment and try again.',
      );
      return;
    }

    // Check for duplicate name validation error
    if (current.nameValidationError != null) {
      _emitError(
        'Please use a unique genet ID. ${current.suggestedName != null ? "Suggested: ${current.suggestedName}" : ""}',
      );
      return;
    }

    // Block submit if provenance search has conflicting matches
    if (current.provenanceSearch.hasConflict) {
      _emitError(
        current.provenanceSearch.conflictMessage ??
            'Conflicting provenance matches. Clear one field to resolve.',
      );
      return;
    }

    try {
      final species = formState.species.value;
      if (species == null) {
        _emitError('Species is required');
        return;
      }

      final provenanceType = formState.provenanceType.value;
      if (provenanceType == null) {
        _emitError('Provenance type is required');
        return;
      }

      bool shouldInvitePartner = false;
      final trimmedEmail = formState.transferEmail.trim();
      if (formState.sendTransfer) {
        final transferIdentifier = formState.transferOrgId.trim();
        final partnerName = formState.provInstitution.value.trim();
        final isUnknownPartner = ProvenanceConstants.isUnknown(
          transferIdentifier,
        );

        if (transferIdentifier.isEmpty && partnerName.isEmpty) {
          _emitError(
            'Select or enter the collecting institution before submitting.',
          );
          return;
        }

        if (!isUnknownPartner) {
          final existingOrganization = await organizationRepository
              .resolveIdentifier(transferIdentifier);
          if (existingOrganization == null && partnerName.isNotEmpty) {
            shouldInvitePartner = true;
            if (trimmedEmail.isEmpty) {
              _emitError(
                'Partner email is required to invite a new organization.',
              );
              return;
            }
          }
        }
      }

      emit(
        current.copyWith(
          formState: formState.copyWith(
            isSubmissionInProgress: true,
            submissionError: null,
          ),
        ),
      );

      if (_editingGenet != null && current.isEditing) {
        final original = _editingGenet!;
        final updatedDraft = formState.applyEdits(original);
        final changes = _computeGenetChanges(original, updatedDraft);

        if (changes.isEmpty) {
          emit(GenetUpdateSuccess(original, changes: const {}));
          return;
        }

        final persisted = await genetRepository.updateGenet(
          original: original,
          updated: updatedDraft,
          changes: changes,
        );
        if (shouldInvitePartner) {
          await _sendPartnerInvitation(trimmedEmail);
        }
        _editingGenet = persisted;
        emit(GenetUpdateSuccess(persisted, changes: changes));
        return;
      }

      // Set submission in progress
      // Get auto-generated slug
      final slug = await genetRepository.nextSlugForModelType(ModelType.genet);

      // Convert form state to Genet
      final incompleteGenet = formState.toIncompleteGenet(slugOverride: slug);

      // Create via repository, passing inherited PID from crosswalk match
      final createdGenet = await genetRepository.createGenet(
        incompleteGenet,
        inheritedProvenanceId: current.provenanceSearch.resolvedProvenanceId,
      );
      if (shouldInvitePartner) {
        await _sendPartnerInvitation(trimmedEmail);
      }

      emit(GenetCreationSuccess(createdGenet));
    } on FirebaseException catch (e, stack) {
      // Handle Firebase-specific errors with proper error codes
      final operation = _editingGenet != null ? 'update' : 'create';

      LoggingService.instance.error(
        'Genet $operation failed (Firebase: ${e.code})',
        e,
        stack,
      );

      String failureMessage;
      switch (e.code) {
        case 'permission-denied':
          failureMessage =
              'Permission denied while trying to $operation genet.\n\n'
              'This may be due to:\n'
              '• Session expired - try signing out and back in\n'
              '• Insufficient permissions for this organization\n'
              '• A required field is missing or invalid\n\n'
              'Technical details: ${e.message ?? 'No additional details'}';
        case 'unavailable':
          failureMessage =
              'Firebase service is temporarily unavailable.\n'
              'Please wait a moment and try again.';
        case 'deadline-exceeded':
          failureMessage =
              'The request timed out.\n'
              'Please check your connection and try again.';
        case 'already-exists':
          failureMessage =
              'A genet with this identifier already exists.\n'
              'Please use a different name.';
        case 'not-found':
          failureMessage =
              'The requested resource was not found.\n'
              'The organization or related data may have been deleted.';
        case 'resource-exhausted':
          failureMessage =
              'Too many requests. Please wait a moment and try again.';
        default:
          failureMessage =
              'Failed to $operation genet.\n\n'
              'Error code: ${e.code}\n'
              'Details: ${e.message ?? 'No additional details'}';
      }

      _emitError(failureMessage);
    } on domainErrors.RepositoryError catch (e, stack) {
      // Handle domain-specific repository errors
      final operation = _editingGenet != null ? 'update' : 'create';

      LoggingService.instance.error(
        'Genet $operation failed (Repository)',
        e,
        stack,
      );

      final buffer = StringBuffer(e.message);
      if (e.technicalDetails != null) {
        buffer.write('\n\nTechnical details: ${e.technicalDetails}');
      }
      if (e.recoverySuggestion != null) {
        buffer.write('\n\n${e.recoverySuggestion}');
      }

      _emitError(buffer.toString());
    } catch (e, stack) {
      // Handle any other unexpected errors
      final operation = _editingGenet != null ? 'update' : 'create';

      LoggingService.instance.error(
        'Genet $operation failed (Unexpected)',
        e,
        stack,
      );

      final failureMessage =
          'Failed to $operation genet.\n\n'
          'Error: ${e.toString()}\n\n'
          'If this persists, please try signing out and back in.';

      _emitError(failureMessage);
    }
  }

  @override
  Future<void> close() {
    disposeProvenanceSearch();
    return super.close();
  }

  void _emitError(String failureMessage) {
    final currentState = state;
    if (currentState is GenetCreationInProgress) {
      emit(
        currentState.copyWith(
          formState: currentState.formState.copyWith(
            isSubmissionInProgress: false,
            submissionError: failureMessage,
          ),
        ),
      );
    } else {
      emit(GenetCreationError(failureMessage));
    }
  }
}
