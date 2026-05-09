// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/organism_split/organism_split_state.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/events/split_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class OrganismSplitBloc
    extends AsyncRecordFormBloc<OrganismRecord, OrganismSplitState> {
  OrganismSplitBloc({
    required OrganismRecord sourceOrganism,
    required OrganismRecordRepository organismRepository,
    required GraphRepository graphRepository,
  })  : _sourceOrganism = sourceOrganism,
        _organismRepository = organismRepository,
        _graphRepository = graphRepository,
        _logger = LoggingService.instance,
        super(
          OrganismSplitState(
            steps: [
              BaseRecordFormStep(
                title: 'Select Quantity',
                inputs: [const SplitQuantityInput.pure()],
              ),
              BaseRecordFormStep(
                title: 'Record Details',
                inputs: [
                  const SplitRecordNameInput.pure(),
                  const SplitReasonInput.pure(),
                  const SplitNotesInput.pure(),
                ],
              ),
              BaseRecordFormStep(
                title: 'Review & Confirm',
                inputs: const [],
              ),
            ],
          ),
        ) {
    on<SplitQuantityChanged>(_onQuantityChanged);
    on<SplitRecordNameChanged>(_onRecordNameChanged);
    on<SplitReasonChanged>(_onReasonChanged);
    on<SplitNotesChanged>(_onNotesChanged);
  }

  final OrganismRecord _sourceOrganism;
  final OrganismRecordRepository _organismRepository;
  final GraphRepository _graphRepository;
  final LoggingService _logger;

  @override
  OrganismSplitState get initialState => state;

  @override
  Future<OrganismSplitState> loadInitialData() async {
    // Default tagId for split: use source's localId or tagId
    final suggestedName = _sourceOrganism.localId ?? _sourceOrganism.tagId;

    final sourceQuantity = _sourceOrganism.measurement.value;
    final defaultSplitQuantity = (sourceQuantity / 2).floorToDouble().clamp(
      1.0,
      sourceQuantity - 1,
    );

    return state.copyWith(
      sourceOrganism: _sourceOrganism,
      suggestedRecordName: suggestedName,
      steps: state.steps.map((step) {
        if (step.inputsMap.containsKey(SplitQuantityChanged)) {
          return BaseRecordFormStep(
            title: step.title,
            inputs: [
              SplitQuantityInput.dirty(
                value: defaultSplitQuantity,
                minQuantity: 1.0,
                maxQuantity: sourceQuantity,
              ),
            ],
          );
        }
        if (step.inputsMap.containsKey(SplitRecordNameChanged)) {
          return BaseRecordFormStep(
            title: step.title,
            inputs: [
              SplitRecordNameInput.dirty(
                value: suggestedName,
                isRequired: true,
              ),
              const SplitReasonInput.pure(),
              const SplitNotesInput.pure(),
            ],
          );
        }
        return step;
      }).toList(),
    );
  }

  void _onQuantityChanged(
    SplitQuantityChanged event,
    Emitter<OrganismSplitState> emit,
  ) {
    final sourceQuantity = state.sourceOrganism?.measurement.value ?? 0.0;
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(SplitQuantityChanged)) {
            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                SplitQuantityInput.dirty(
                  value: event.value,
                  minQuantity: 1.0,
                  maxQuantity: sourceQuantity,
                ),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onRecordNameChanged(
    SplitRecordNameChanged event,
    Emitter<OrganismSplitState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(SplitRecordNameChanged)) {
            final currentNameInput = step.inputsMap[SplitRecordNameChanged]
                as SplitRecordNameInput?;
            final currentReasonInput = step.inputsMap[SplitReasonChanged]
                as SplitReasonInput?;
            final currentNotesInput = step.inputsMap[SplitNotesChanged]
                as SplitNotesInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                SplitRecordNameInput.dirty(
                  value: event.value,
                  existingNames: currentNameInput?.existingNames ?? const <String>{},
                ),
                currentReasonInput ?? const SplitReasonInput.pure(),
                currentNotesInput ?? const SplitNotesInput.pure(),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onReasonChanged(
    SplitReasonChanged event,
    Emitter<OrganismSplitState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(SplitReasonChanged)) {
            final currentNameInput = step.inputsMap[SplitRecordNameChanged]
                as SplitRecordNameInput?;
            final currentNotesInput = step.inputsMap[SplitNotesChanged]
                as SplitNotesInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                currentNameInput ?? const SplitRecordNameInput.pure(),
                SplitReasonInput.dirty(value: event.value),
                currentNotesInput ?? const SplitNotesInput.pure(),
              ],
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onNotesChanged(
    SplitNotesChanged event,
    Emitter<OrganismSplitState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(SplitNotesChanged)) {
            final currentNameInput = step.inputsMap[SplitRecordNameChanged]
                as SplitRecordNameInput?;
            final currentReasonInput = step.inputsMap[SplitReasonChanged]
                as SplitReasonInput?;

            return BaseRecordFormStep(
              title: step.title,
              inputs: [
                currentNameInput ?? const SplitRecordNameInput.pure(),
                currentReasonInput ?? const SplitReasonInput.pure(),
                SplitNotesInput.dirty(value: event.value),
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
    final sourceOrganism = state.sourceOrganism;
    if (sourceOrganism == null) {
      throw Exception('Source organism not loaded');
    }

    final splitQuantity = state.splitQuantity;
    final newRecordName = state.splitRecordName;
    if (newRecordName == null || newRecordName.isEmpty) {
      throw Exception('Record name is required');
    }

    final reason = state.splitReason;
    if (reason == null) {
      throw Exception('Reason is required');
    }
    
    final formattedNotes = [
      reason.name,
      if (state.splitNotes?.isNotEmpty == true) state.splitNotes,
    ].join(': ');

    final sourceQuantity = sourceOrganism.measurement.value;
    if (splitQuantity <= 0 || splitQuantity >= sourceQuantity) {
      throw Exception('Invalid split quantity');
    }

    _logger.debug(
      'Splitting organism ${sourceOrganism.id}: '
      'qty=$sourceQuantity -> split=$splitQuantity, remaining=${sourceQuantity - splitQuantity}',
    );

    // Use Firestore transaction for atomic split with optimistic locking
    final db = _organismRepository.db;
    final result = await db.runTransaction<OrganismRecord>((transaction) async {
      // Re-read source organism to check for concurrent modifications
      final sourceDoc = await transaction.get(
        _organismRepository.collectionRef.doc(sourceOrganism.id),
      );
      if (!sourceDoc.exists) {
        throw Exception('Source organism no longer exists');
      }

      final currentData = sourceDoc.data()!;
      final currentUpdatedAt = currentData['updatedAt'] as String?;
      if (currentUpdatedAt != sourceOrganism.updatedAt) {
        throw Exception(
          'Source organism was modified by another user. Please refresh and try again.',
        );
      }

      final now = DateTime.now().toIso8601String();
      final newOrganismId = generateId(firestore: db);
      final newSlug = await _organismRepository.nextSlugForModelType(
        _organismRepository.modelType,
      );

      // Create snapshot of source before split
      final sourceSnapshotBefore = sourceOrganism;

      // Calculate new quantities
      final remainingQuantity = sourceQuantity - splitQuantity;

      // Create measurement snapshot for split moment
      final splitMeasurementSnapshot = MeasurementSnapshot(
        measurement: sourceOrganism.measurement.copyWith(
          value: splitQuantity,
        ),
        recordedAt: DateTime.now().toUtc(),
        source: 'split',
        notes: 'Split from ${sourceOrganism.tagId}. $formattedNotes',
      );

      final sourceMeasurementSnapshot = MeasurementSnapshot(
        measurement: sourceOrganism.measurement.copyWith(
          value: remainingQuantity,
        ),
        recordedAt: DateTime.now().toUtc(),
        source: 'split',
        notes: 'Remaining after split to $newRecordName. $formattedNotes',
      );

      // Create new organism with split quantity
      // Inherits: localId, provenanceType, provenanceAttributes, genetId,
      // lifeStageHistory, measurementHistory, speciesId, lifeStage, physicalForm,
      // organismKind, siteId, groupId
      final newOrganism = sourceOrganism.copyWith(
        id: newOrganismId,
        slug: newSlug,
        tagId: newRecordName,
        urlPath: '${sourceOrganism.urlPath.substring(0, sourceOrganism.urlPath.lastIndexOf('/'))}/$newSlug',
        internalPath: '${sourceOrganism.internalPath.substring(0, sourceOrganism.internalPath.lastIndexOf('/'))}/$newOrganismId',
        measurement: sourceOrganism.measurement.copyWith(
          value: splitQuantity,
        ),
        measurementHistory: [
          ...sourceOrganism.measurementHistory,
          splitMeasurementSnapshot,
        ],
        createdAt: now,
        updatedAt: now,
        createdById: _organismRepository.user.id,
        updatedById: _organismRepository.user.id,
        metadata: {
          ...?sourceOrganism.metadata,
          'splitFromOrganismId': sourceOrganism.id,
          'splitAt': now,
        },
      );

      // Update source organism with reduced quantity
      final updatedSource = sourceOrganism.copyWith(
        measurement: sourceOrganism.measurement.copyWith(
          value: remainingQuantity,
        ),
        measurementHistory: [
          ...sourceOrganism.measurementHistory,
          sourceMeasurementSnapshot,
        ],
        updatedAt: now,
        updatedById: _organismRepository.user.id,
      );

      // Create SplitEvent
      final eventId = generateId(firestore: db);
      final eventSlug = await _organismRepository.nextSlugForModelType(
        ModelType.event,
      );
      final splitEvent = SplitEvent(
        id: eventId,
        eventTypeId: InventoryEventType.splitId,
        createdById: _organismRepository.user.id,
        createdAt: now,
        updatedAt: now,
        updatedById: _organismRepository.user.id,
        organizationId: sourceOrganism.organizationId,
        recordId: sourceOrganism.id,
        recordModelType: ModelType.organismRecord,
        snapshot: updatedSource,
        urlPath: '${sourceOrganism.urlPath}/events/$eventSlug',
        internalPath: '${sourceOrganism.internalPath}/events/$eventId',
        slug: eventSlug,
        sourceSnapshotBefore: sourceSnapshotBefore,
        targetOrganismId: newOrganismId,
        targetSnapshot: newOrganism,
        splitQuantity: splitQuantity,
        sourceQuantityBefore: sourceQuantity,
        sourceQuantityAfter: remainingQuantity,
        comment: 'Split ${splitQuantity.toStringAsFixed(0)} to $newRecordName. $formattedNotes',
      );

      // Perform all writes in transaction
      transaction.set(
        _organismRepository.collectionRef.doc(newOrganismId),
        newOrganism.toJson(),
      );
      transaction.update(
        _organismRepository.collectionRef.doc(sourceOrganism.id),
        updatedSource.toJson(),
      );
      transaction.set(
        db.collection('events').doc(eventId),
        splitEvent.toJson(),
      );

      _logger.info(
        'Split committed: created ${newOrganism.id} (${newOrganism.tagId}) '
        'with qty=$splitQuantity from ${sourceOrganism.id}',
      );

      return newOrganism;
    });

    // Reload the group node to reflect changes
    await _reloadGroupNode(sourceOrganism);

    return result;
  }

  Future<void> _reloadGroupNode(OrganismRecord organism) async {
    // Get parent group path
    final groupPath = organism.urlPath.substring(
      0,
      organism.urlPath.lastIndexOf('/'),
    );
    final node = await _graphRepository.getNodeForUrlPath(groupPath);
    node?.add(const GraphNodeReloadRequested());
  }
}
