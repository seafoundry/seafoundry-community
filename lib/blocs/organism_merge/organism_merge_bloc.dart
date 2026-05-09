// @tier: community
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/organism_merge/organism_merge_state.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/events/merge_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/mixins/life_stage_progression_mixin.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class OrganismMergeBloc
    extends AsyncRecordFormBloc<OrganismRecord, OrganismMergeState> {
  OrganismMergeBloc({
    required List<OrganismRecord> availableOrganisms,
    required OrganismRecordRepository organismRepository,
    required GraphRepository graphRepository,
    Set<String>? initialSelectedIds,
  })  : _availableOrganisms = availableOrganisms,
        _organismRepository = organismRepository,
        _graphRepository = graphRepository,
        _initialSelectedIds = initialSelectedIds,
        _logger = LoggingService.instance,
        super(
          OrganismMergeState(
            steps: [
              BaseRecordFormStep(
                title: 'Select Records & Target',
                inputs: [
                  const MergeRecordSelectionInput.pure(),
                  const MergeTargetInput.pure(),
                ],
              ),
              BaseRecordFormStep(
                title: 'Record Details',
                inputs: [
                  const MergeRecordNameInput.pure(),
                  const MergeReasonInput.pure(),
                  const MergeNotesInput.pure(),
                ],
              ),
              BaseRecordFormStep(
                title: 'Review & Confirm',
                inputs: const [],
              ),
            ],
          ),
        ) {
    on<MergeRecordSelectionChanged>(_onRecordSelectionChanged);
    on<MergeTargetChanged>(_onTargetChanged);
    on<MergeRecordNameChanged>(_onRecordNameChanged);
    on<MergeReasonChanged>(_onReasonChanged);
    on<MergeNotesChanged>(_onNotesChanged);
  }

  final List<OrganismRecord> _availableOrganisms;
  final OrganismRecordRepository _organismRepository;
  final GraphRepository _graphRepository;
  final Set<String>? _initialSelectedIds;
  final LoggingService _logger;

  @override
  OrganismMergeState get initialState => state;

  @override
  Future<OrganismMergeState> loadInitialData() async {
    // Compute eligibility for each organism
    final eligibilityErrors = <String, String>{};
    for (final organism in _availableOrganisms) {
      final error = _checkMergeEligibility(organism, _availableOrganisms);
      if (error != null) {
        eligibilityErrors[organism.id] = error;
      }
    }

    // Filter to only show eligible organisms
    final eligibleOrganisms = _availableOrganisms
        .where((o) => !eligibilityErrors.containsKey(o.id))
        .toList();

    // Apply initial selection if provided, otherwise select first 2 eligible
    final initialSelection = _initialSelectedIds != null &&
            _initialSelectedIds.length >= 2
        ? _initialSelectedIds
            .where((id) => eligibleOrganisms.any((o) => o.id == id))
            .toSet()
        : eligibleOrganisms.length >= 2
            ? {eligibleOrganisms[0].id, eligibleOrganisms[1].id}
            : <String>{};

    // Default target is first selected
    final initialTarget = initialSelection.isNotEmpty
        ? initialSelection.first
        : null;
    final targetOrganism = initialTarget != null
        ? eligibleOrganisms.firstWhere(
            (o) => o.id == initialTarget,
            orElse: () => eligibleOrganisms.first,
          )
        : null;

    return state.copyWith(
      availableOrganisms: _availableOrganisms,
      eligibilityErrors: eligibilityErrors,
      steps: state.steps.map((step) {
        if (step.inputsMap.containsKey(MergeRecordSelectionChanged)) {
          return BaseRecordFormStep(
            title: step.title,
            inputs: [
              MergeRecordSelectionInput.dirty(
                value: initialSelection,
                minSelection: 2,
              ),
              MergeTargetInput.dirty(
                value: initialTarget,
                validTargetIds: initialSelection,
              ),
            ],
          );
        }
        if (step.inputsMap.containsKey(MergeRecordNameChanged)) {
          return BaseRecordFormStep(
            title: step.title,
            inputs: [
              MergeRecordNameInput.dirty(
                value: targetOrganism?.tagId,
              ),
              const MergeReasonInput.pure(),
              const MergeNotesInput.pure(),
            ],
          );
        }
        return step;
      }).toList(),
    );
  }

  /// Check if an organism is eligible for merging.
  /// Returns null if eligible, error message if not.
  String? _checkMergeEligibility(
    OrganismRecord organism,
    List<OrganismRecord> allOrganisms,
  ) {
    // Find other organisms with same localId for comparison
    final sameLocalIdOrganisms = allOrganisms
        .where((o) => o.localId == organism.localId && o.id != organism.id)
        .toList();

    if (sameLocalIdOrganisms.isEmpty) {
      return 'No other records with same Local ID';
    }

    // All merge eligibility criteria:
    // - Same localId (checked above)
    // - Same lifeStage
    // - Same physicalForm
    // - Same speciesId
    // - Same organismKind
    // - Same measurement.unit

    for (final other in sameLocalIdOrganisms) {
      if (organism.lifeStage != other.lifeStage) {
        return 'Life stage differs from other records';
      }
      if (organism.physicalForm != other.physicalForm) {
        return 'Physical form differs from other records';
      }
      if (organism.speciesId != other.speciesId) {
        return 'Species differs from other records';
      }
      if (organism.organismKind != other.organismKind) {
        return 'Organism kind differs from other records';
      }
      if (organism.measurement.unit != other.measurement.unit) {
        return 'Measurement unit differs from other records';
      }
    }

    return null; // Eligible
  }

  void _onRecordSelectionChanged(
    MergeRecordSelectionChanged event,
    Emitter<OrganismMergeState> emit,
  ) {
    final selectedIds = event.value;
    final currentTarget = state.targetOrganismId;

    // If current target is no longer in selection, pick first selected as new target
    final newTarget = selectedIds.contains(currentTarget)
        ? currentTarget
        : selectedIds.isNotEmpty
            ? selectedIds.first
            : null;

    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeRecordSelectionChanged)) {
            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                MergeRecordSelectionInput.dirty(
                  value: selectedIds,
                  minSelection: 2,
                ),
                MergeTargetInput.dirty(
                  value: newTarget,
                  validTargetIds: selectedIds,
                ),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );

    // Update record name if target changed
    if (newTarget != currentTarget) {
      _updateRecordNameForTarget(newTarget, emit);
    }
  }

  void _onTargetChanged(
    MergeTargetChanged event,
    Emitter<OrganismMergeState> emit,
  ) {
    final selectedIds = state.selectedOrganismIds;
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeTargetChanged)) {
            return step.copyWith(
              copiedInput: MergeTargetInput.dirty(
                value: event.value,
                validTargetIds: selectedIds,
              ),
            );
          }
          return step;
        }).toList(),
      ),
    );

    // Update record name for new target
    _updateRecordNameForTarget(event.value, emit);
  }

  void _updateRecordNameForTarget(String? targetId, Emitter<OrganismMergeState> emit) {
    final targetOrganism = targetId != null
        ? _availableOrganisms.firstWhere(
            (o) => o.id == targetId,
            orElse: () => _availableOrganisms.first,
          )
        : null;

    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeRecordNameChanged)) {
            final currentInput = step.inputsMap[MergeRecordNameChanged]
                as MergeRecordNameInput?;
            return step.copyWith(
              copiedInput: MergeRecordNameInput.dirty(
                value: targetOrganism?.tagId,
                existingNames: currentInput?.existingNames ?? const <String>{},
              ),
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onRecordNameChanged(
    MergeRecordNameChanged event,
    Emitter<OrganismMergeState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeRecordNameChanged)) {
            final currentNameInput = step.inputsMap[MergeRecordNameChanged]
                as MergeRecordNameInput?;
            final currentReasonInput = step.inputsMap[MergeReasonChanged]
                as MergeReasonInput?;
            final currentNotesInput = step.inputsMap[MergeNotesChanged]
                as MergeNotesInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                  MergeRecordNameInput.dirty(
                    value: event.value,
                    existingNames: currentNameInput?.existingNames ?? const <String>{},
                  ),
                currentReasonInput ?? const MergeReasonInput.pure(),
                currentNotesInput ?? const MergeNotesInput.pure(),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onReasonChanged(
    MergeReasonChanged event,
    Emitter<OrganismMergeState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeReasonChanged)) {
            final currentNameInput = step.inputsMap[MergeRecordNameChanged]
                as MergeRecordNameInput?;
            final currentNotesInput = step.inputsMap[MergeNotesChanged]
                as MergeNotesInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                currentNameInput ?? const MergeRecordNameInput.pure(),
                MergeReasonInput.dirty(value: event.value),
                currentNotesInput ?? const MergeNotesInput.pure(),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onNotesChanged(
    MergeNotesChanged event,
    Emitter<OrganismMergeState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(MergeNotesChanged)) {
            final currentNameInput = step.inputsMap[MergeRecordNameChanged]
                as MergeRecordNameInput?;
            final currentReasonInput = step.inputsMap[MergeReasonChanged]
                as MergeReasonInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                currentNameInput ?? const MergeRecordNameInput.pure(),
                currentReasonInput ?? const MergeReasonInput.pure(),
                MergeNotesInput.dirty(value: event.value),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  @override
  Future<OrganismRecord?> createRecord() async {
    final targetOrganism = state.targetOrganism;
    if (targetOrganism == null) {
      throw Exception('Target organism not selected');
    }

    final absorbedOrganisms = state.absorbedOrganisms;
    if (absorbedOrganisms.isEmpty) {
      throw Exception('No organisms to absorb');
    }

    final newRecordName = state.mergedRecordName;
    if (newRecordName == null || newRecordName.isEmpty) {
      throw Exception('Record name is required');
    }

    final reason = state.mergeReason;
    if (reason == null) {
      throw Exception('Reason is required');
    }

    final formattedNotes = [
      reason.name,
      if (state.mergeNotes?.isNotEmpty == true) state.mergeNotes,
    ].join(': ');

    final recordsToMerge = state.selectedOrganismIds
        .map((id) => state.availableOrganisms.firstWhereOrNull((r) => r.id == id))
        .nonNulls
        .toList();

    _logger.debug(
      'Merging ${absorbedOrganisms.length} organisms into ${targetOrganism.id}',
    );

    final db = _organismRepository.db;
    final result = await db.runTransaction<OrganismRecord>((transaction) async {
      // Re-read all organisms to check for concurrent modifications
      final targetDoc = await transaction.get(
        _organismRepository.collectionRef.doc(targetOrganism.id),
      );
      if (!targetDoc.exists) {
        throw Exception('Target organism no longer exists');
      }

      final targetData = targetDoc.data()!;
      if (targetData['updatedAt'] != targetOrganism.updatedAt) {
        throw Exception(
          'Target organism was modified. Please refresh and try again.',
        );
      }

      // Verify absorbed organisms haven't changed
      for (final absorbed in absorbedOrganisms) {
        final absorbedDoc = await transaction.get(
          _organismRepository.collectionRef.doc(absorbed.id),
        );
        if (!absorbedDoc.exists) {
          throw Exception('Organism ${absorbed.tagId} no longer exists');
        }
        final absorbedData = absorbedDoc.data()!;
        if (absorbedData['updatedAt'] != absorbed.updatedAt) {
          throw Exception(
            'Organism ${absorbed.tagId} was modified. Please refresh.',
          );
        }
      }

      final now = DateTime.now().toIso8601String();
      final userId = _organismRepository.user.id;

      // Calculate merged quantity
      final totalQuantity = state.totalQuantityAfterMerge;

      // Union merge measurement histories
      final mergedMeasurementHistory = _unionMergeMeasurementHistory(
        targetOrganism,
        absorbedOrganisms,
      );

      // Union merge life stage histories
      final mergedLifeStageHistory = _unionMergeLifeStageHistory(
        targetOrganism,
        absorbedOrganisms,
      );

      // Add merge measurement snapshot
      final mergeMeasurementSnapshot = MeasurementSnapshot(
        measurement: targetOrganism.measurement.copyWith(
          value: totalQuantity,
        ),
        recordedAt: DateTime.now().toUtc(),
        source: 'merge',
        notes: 'Merged into $newRecordName. $formattedNotes',
      );

      // Check genetId - keep if all match, clear if any differ
      final allGenetIds = [
        targetOrganism.genetId,
        ...absorbedOrganisms.map((o) => o.genetId),
      ].whereType<String>().toSet();
      final mergedGenetId = allGenetIds.length == 1 ? allGenetIds.first : null;

      // Create updated target organism
      final updatedTarget = targetOrganism.copyWith(
        tagId: newRecordName,
        measurement: targetOrganism.measurement.copyWith(
          value: totalQuantity,
        ),
        measurementHistory: [
          ...mergedMeasurementHistory,
          mergeMeasurementSnapshot,
        ],
        lifeStageHistory: mergedLifeStageHistory,
        genetId: mergedGenetId,
        updatedAt: now,
        updatedById: userId,
        metadata: {
          ...?targetOrganism.metadata,
          'lastMergedAt': now,
          'mergedOrganismIds': absorbedOrganisms.map((o) => o.id).toList(),
        },
      );

      // Create snapshots of absorbed organisms before merge
      final absorbedSnapshots = absorbedOrganisms.toList();

      // Soft-delete absorbed organisms
      for (final absorbed in absorbedOrganisms) {
        final softDeletedOrganism = absorbed.copyWith(
          updatedAt: now,
          updatedById: userId,
          metadata: {
            ...?absorbed.metadata,
            'mergedIntoId': targetOrganism.id,
            'mergedAt': now,
            'archivedAt': now,
          },
        );

        transaction.update(
          _organismRepository.collectionRef.doc(absorbed.id),
          {
            ...softDeletedOrganism.toJson(),
            'isDeleted': true,
          },
        );
      }

      // Update target organism
      transaction.update(
        _organismRepository.collectionRef.doc(targetOrganism.id),
        updatedTarget.toJson(),
      );

      // Create MergeEvent
      final eventId = generateId(firestore: db);
      final eventSlug = await _organismRepository.nextSlugForModelType(
        ModelType.event,
      );

      final totalBefore = absorbedOrganisms.fold<double>(
        targetOrganism.measurement.value,
        (sum, o) => sum + o.measurement.value,
      );

      final mergeEvent = MergeEvent(
        id: eventId,
        eventTypeId: InventoryEventType.mergeId,
        createdById: userId,
        createdAt: now,
        updatedAt: now,
        updatedById: userId,
        organizationId: targetOrganism.organizationId,
        recordId: targetOrganism.id,
        recordModelType: ModelType.organismRecord,
        snapshot: updatedTarget,
        urlPath: '${targetOrganism.urlPath}/events/$eventSlug',
        internalPath: '${targetOrganism.internalPath}/events/$eventId',
        slug: eventSlug,
        absorbedOrganismIds: absorbedOrganisms.map((o) => o.id).toList(),
        absorbedSnapshots: absorbedSnapshots,
        targetSnapshotBefore: targetOrganism,
        totalQuantityBefore: totalBefore,
        totalQuantityAfter: totalQuantity,
        comment: 'Merged from ${recordsToMerge.length} records. $formattedNotes',
      );

      transaction.set(
        db.collection('events').doc(eventId),
        mergeEvent.toJson(),
      );

      _logger.info(
        'Merge committed: ${absorbedOrganisms.length} organisms '
        'merged into ${targetOrganism.id}',
      );

      return updatedTarget;
    });

    // Reload group node
    await _reloadGroupNode(targetOrganism);

    return result;
  }

  /// Union merge measurement histories from all organisms, deduplicated by timestamp
  List<MeasurementSnapshot> _unionMergeMeasurementHistory(
    OrganismRecord target,
    List<OrganismRecord> absorbed,
  ) {
    final allSnapshots = <MeasurementSnapshot>[
      ...target.measurementHistory,
      ...absorbed.expand((o) => o.measurementHistory),
    ];

    // Deduplicate by timestamp (keep first occurrence)
    final seen = <String>{};
    return allSnapshots.where((snapshot) {
      final key = snapshot.recordedAt?.toIso8601String() ?? '';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList()
      ..sort((a, b) => (a.recordedAt ?? DateTime(0))
          .compareTo(b.recordedAt ?? DateTime(0)));
  }

  /// Union merge life stage histories from all organisms, deduplicated by timestamp
  List<LifeStageTransition> _unionMergeLifeStageHistory(
    OrganismRecord target,
    List<OrganismRecord> absorbed,
  ) {
    final allEntries = <LifeStageTransition>[
      ...target.lifeStageHistory,
      ...absorbed.expand((o) => o.lifeStageHistory),
    ];

    // Deduplicate by timestamp
    final seen = <String>{};
    return allEntries.where((entry) {
      final key = entry.occurredAt?.toIso8601String() ?? '';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList()
      ..sort((a, b) =>
          (a.occurredAt ?? DateTime(0)).compareTo(b.occurredAt ?? DateTime(0)));
  }

  Future<void> _reloadGroupNode(OrganismRecord organism) async {
    final groupPath = organism.urlPath.substring(
      0,
      organism.urlPath.lastIndexOf('/'),
    );
    final node = await _graphRepository.getNodeForUrlPath(groupPath);
    node?.add(const GraphNodeReloadRequested());
  }
}
