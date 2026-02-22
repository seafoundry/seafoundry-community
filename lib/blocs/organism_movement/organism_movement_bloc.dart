// @tier: community
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/organism_movement/organism_movement_state.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/utils/record_name_suggester.dart';

class OrganismMovementBloc
    extends AsyncRecordFormBloc<OrganismRecord, OrganismMovementState> {
  OrganismMovementBloc({
    required Group sourceGroup,
    required OrganismRecordRepository organismRepository,
    required GroupRepository groupRepository,
    required GraphRepository graphRepository,
    required UniqueNameValidationService validationService,
    Set<String>? allowedOrganismIds,
    Set<String>? initialSelectedOrganismIds,
  })  : _sourceGroup = sourceGroup,
        _organismRepository = organismRepository,
        _groupRepository = groupRepository,
        _graphRepository = graphRepository,
        _validationService = validationService,
        _allowedOrganismIds = allowedOrganismIds,
        _initialSelectedOrganismIds = initialSelectedOrganismIds,
        _logger = LoggingService.instance,
        super(
          OrganismMovementState(
            steps: [
              BaseRecordFormStep(
                title: 'Select Organisms',
                inputs: [
                  const RecordIdSetInput.pure(isRequired: true),
                  const QuantityMapInput.pure(),
                ],
              ),
              BaseRecordFormStep(
                title: 'Select Target Structure',
                inputs: [const TargetGroupInput.pure(isRequired: true)],
              ),
              BaseRecordFormStep(
                title: 'Review & Confirm',
                inputs: const [],
              ),
            ],
          ),
        ) {
    on<RecordIdSetChanged>(_onSelectionChanged);
    on<QuantityMapChanged>(_onQuantitiesChanged);
    on<TargetGroupChanged>(_onTargetChanged);
  }

  final Group _sourceGroup;
  final OrganismRecordRepository _organismRepository;
  final GroupRepository _groupRepository;
  final GraphRepository _graphRepository;
  final UniqueNameValidationService _validationService;
  final Set<String>? _allowedOrganismIds;
  final Set<String>? _initialSelectedOrganismIds;
  final LoggingService _logger;

  @override
  OrganismMovementState get initialState => state;

  @override
  Future<OrganismMovementState> loadInitialData() async {
    final organisms = await _organismRepository.getAll();
    final groups = await _groupRepository.getAll();

    var availableOrganisms = organisms
        .where((organism) => organism.groupId == _sourceGroup.id)
        .toList();
    final allowedOrganismIds = _allowedOrganismIds;
    if (allowedOrganismIds != null) {
      availableOrganisms = availableOrganisms
          .where((organism) => allowedOrganismIds.contains(organism.id))
          .toList();
    }
    final availableGroups =
        groups.where((group) => group.id != _sourceGroup.id).toList();
    final initialSelectedIds =
        (_initialSelectedOrganismIds ?? const <String>{})
            .where((id) => availableOrganisms.any((o) => o.id == id))
            .toSet();
    final initialQuantities = <String, int>{
      for (final organism in availableOrganisms)
        if (initialSelectedIds.contains(organism.id))
          organism.id: organism.measurement.value.toInt(),
    };

    return state.copyWith(
      sourceGroup: _sourceGroup,
      availableOrganisms: availableOrganisms,
      availableGroups: availableGroups,
      steps: state.steps.mapIndexed((index, step) {
        if (index == 0 && step is BaseRecordFormStep) {
          final selectionInput = initialSelectedIds.isEmpty
              ? const RecordIdSetInput.pure(isRequired: true)
              : RecordIdSetInput.dirty(
                  value: initialSelectedIds,
                  isRequired: true,
                );
          final quantityInput = initialQuantities.isEmpty
              ? QuantityMapInput.pure(
                  allowZero: false,
                  maxForKey: (key) => availableOrganisms
                      .firstWhereOrNull((organism) => organism.id == key)
                      ?.measurement.value.toInt(),
                )
              : QuantityMapInput.dirty(
                  value: initialQuantities,
                  allowZero: false,
                  maxForKey: (key) => availableOrganisms
                      .firstWhereOrNull((organism) => organism.id == key)
                      ?.measurement.value.toInt(),
                );
          return BaseRecordFormStep(
            title: 'Select Organisms',
            inputs: [
              selectionInput,
              quantityInput,
            ],
          );
        }
        if (index == 1 && step is BaseRecordFormStep) {
          return BaseRecordFormStep(
            title: 'Select Target Structure',
            inputs: [const TargetGroupInput.pure(isRequired: true)],
          );
        }
        return step;
      }).toList(),
    );
  }

  void _onSelectionChanged(
    RecordIdSetChanged event,
    Emitter<OrganismMovementState> emit,
  ) {
    final selectedIds = event.value ?? <String>{};
    final quantities = state.selectedQuantities.value ?? const <String, int>{};
    final updatedQuantities = {
      for (final entry in quantities.entries)
        if (selectedIds.contains(entry.key)) entry.key: entry.value,
    };

    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(RecordIdSetChanged)) {
            return step.copyWith(
              copiedInput: RecordIdSetInput.dirty(value: selectedIds),
            );
          }
          if (step.inputsMap.containsKey(QuantityMapChanged)) {
            return step.copyWith(
              copiedInput: QuantityMapInput.dirty(value: updatedQuantities),
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onQuantitiesChanged(
    QuantityMapChanged event,
    Emitter<OrganismMovementState> emit,
  ) {
    final updated = event.value ?? const <String, int>{};
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(QuantityMapChanged)) {
            return step.copyWith(
              copiedInput: QuantityMapInput.dirty(value: updated),
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  void _onTargetChanged(
    TargetGroupChanged event,
    Emitter<OrganismMovementState> emit,
  ) {
    emit(
      state.copyWith(
        steps: state.steps.map((step) {
          if (step.inputsMap.containsKey(TargetGroupChanged)) {
            return step.copyWith(
              copiedInput: TargetGroupInput.dirty(value: event.value),
            );
          }
          return step;
        }).toList(),
      ),
    );
  }

  @override
  Future<OrganismRecord?> createRecord() async {
    final targetGroupId = state.targetGroupId;

    if (targetGroupId == null) {
      throw Exception('Select a target group');
    }

    final targetGroup = state.availableGroups
        .firstWhereOrNull((group) => group.id == targetGroupId);
    if (targetGroup == null) {
      throw Exception('Selected group not found');
    }

    final selectedIds = state.selectedOrganismIds.value ?? <String>{};
    if (selectedIds.isEmpty) {
      throw Exception('Select at least one organism to move');
    }

    final selectedOrganisms = state.availableOrganisms
        .where((organism) => selectedIds.contains(organism.id))
        .toList();
    final quantities = state.selectedQuantities.value ?? const <String, int>{};

    // Move organisms using the base repository moveRecord method
    // For now, we'll update each organism's groupId and siteId directly
    // This follows the same pattern as OrganismRecordRepository.moveOrganisms
    for (final organism in selectedOrganisms) {
      final currentQuantity = organism.measurement.value.toInt();
      final quantityToMove = () {
        final requested = quantities[organism.id];
        if (requested == null || requested <= 0) {
          return currentQuantity;
        }
        return requested.clamp(1, currentQuantity);
      }();

      _logger.debug(
        'moveOrganisms: ${organism.name} (${organism.id}) qty=$currentQuantity -> moving $quantityToMove to ${targetGroup.name}',
      );

      // Move the entire organism or split if partial quantity
      if (quantityToMove >= currentQuantity) {
        // Move entire organism - preserve provenance, add movement tracking
        final updatedOrganism = organism.copyWith(
          groupId: targetGroup.id,
          siteId: targetGroup.siteId,
          urlPath: '${targetGroup.urlPath}/${organism.slug}',
          internalPath: '${targetGroup.internalPath}/${organism.id}',
          updatedAt: DateTime.now().toIso8601String(),
          metadata: {
            ...?organism.metadata,
            'lastMovedAt': DateTime.now().toIso8601String(),
            'lastMovedFromGroupId': _sourceGroup.id,
            'lastMovedFromSiteId': _sourceGroup.siteId,
          },
        );
        await _organismRepository.updateRecord(updatedOrganism);
      } else {
        // Partial move - use batch for atomic create + update to prevent race conditions
        // where concurrent moves could create phantom quantities
        final batch = _organismRepository.db.batch();

        // Generate IDs and paths for the new organism at target
        final newOrganismId = generateId(firestore: _organismRepository.db);
        final newOrganismSlug = await _organismRepository.nextSlugForModelType(
          _organismRepository.modelType,
        );
        final now = DateTime.now().toIso8601String();

        // Generate unique recordName for split organism
        final splitRecordName = await RecordNameSuggester.suggestSplitRecordName(
          sourceRecordName: organism.recordName,
          organizationId: organism.organizationId,
          validationService: _validationService,
        );

        // Create new organism at target with partial quantity
        // Preserve provenance and track source organism
        final newOrganism = organism.copyWith(
          recordName: splitRecordName ?? organism.recordName,
          id: newOrganismId,
          slug: newOrganismSlug,
          urlPath: '${targetGroup.urlPath}/$newOrganismSlug',
          internalPath: '${targetGroup.internalPath}/$newOrganismId',
          measurement: organism.measurement.copyWith(
            value: quantityToMove.toDouble(),
          ),
          groupId: targetGroup.id,
          siteId: targetGroup.siteId,
          createdAt: now,
          updatedAt: now,
          createdById: _organismRepository.user.id,
          updatedById: _organismRepository.user.id,
          // provenanceType and provenanceAttributes preserved via copyWith
          // genetId and foreignKeys preserved via copyWith
          metadata: {
            ...?organism.metadata,
            'sourceOrganismId': organism.id,
            'sourceGroupId': _sourceGroup.id,
            'sourceSiteId': _sourceGroup.siteId,
            'splitFromAt': now,
          },
        );

        // Reduce source organism quantity
        final reducedOrganism = organism.copyWith(
          measurement: organism.measurement.copyWith(
            value: (currentQuantity - quantityToMove).toDouble(),
          ),
          updatedAt: now,
          updatedById: _organismRepository.user.id,
        );

        // Add both operations to batch - both must succeed or both fail
        batch.set(
          _organismRepository.collectionRef.doc(newOrganismId),
          newOrganism.toJson(),
        );
        batch.update(
          _organismRepository.collectionRef.doc(organism.id),
          reducedOrganism.toJson(),
        );

        // Commit atomically
        await batch.commit();

        _logger.debug(
          'Partial move committed atomically: created ${newOrganism.id}, reduced ${organism.id}',
        );
      }
    }

    await _reloadGroupNode(_sourceGroup);
    await _reloadGroupNode(targetGroup);

    _logger.info(
      'Moved ${selectedOrganisms.length} organisms from ${_sourceGroup.name} to ${targetGroup.name}',
    );

    return selectedOrganisms.isNotEmpty ? selectedOrganisms.first : null;
  }

  Future<void> _reloadGroupNode(Group group) async {
    final node = await _graphRepository.getNodeForUrlPath(group.urlPath);
    node?.add(const GraphNodeReloadRequested());
  }
}
