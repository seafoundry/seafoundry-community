// @tier: community
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/move_node/move_node_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/movement/partial_move_selection.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

class MoveNode extends SafeCubit<MoveNodeState> {
  final GraphRepository _graphRepository;
  final _logger = LoggingService.instance;

  MoveNode({required GraphRepository graphRepository})
    : _graphRepository = graphRepository,
      super(MoveNodeInitial());

  void start(GraphNode nodeToMove) {
    emit(MoveNodeSelection(nodeToMove: nodeToMove));
  }

  Future<void> selectParent(GraphNode? selectedParent) async {
    final current = state;
    if (current is! MoveNodeSelection) {
      return;
    }

    final needsCapacityCheck =
        selectedParent != null &&
        current.nodeToMove.initialRecord is Group &&
        selectedParent.initialRecord is Group;

    final updated = current.copyWith(
      selectedParent: selectedParent,
      clearSelection: selectedParent == null,
      resetCapacity: true,
      isCapacityCheckInProgress: needsCapacityCheck,
    );
    emit(updated);

    if (!needsCapacityCheck) {
      emit(updated.copyWith(isCapacityCheckInProgress: false));
      return;
    }

    final result = await _previewChildCapacity(
      movingNode: current.nodeToMove,
      selectedParent: selectedParent,
    );
    final latest = state;
    if (latest is! MoveNodeSelection) return;
    if (latest.selectedParent?.id != selectedParent.id) return;
    emit(
      latest.copyWith(capacityResult: result, isCapacityCheckInProgress: false),
    );
  }

  void confirm() {
    final state = this.state;
    if (state is MoveNodeSelection && state.canProceed) {
      emit(
        MoveNodeConfirmation(
          nodeToMove: state.nodeToMove,
          selectedParent: state.selectedParent!,
          partialSelection: state.partialSelection,
          capacityResult: state.capacityResult,
          permitId: state.permitId,
          permitType: state.permitType,
          issuingAuthority: state.issuingAuthority,
          permitAttachmentUrls: state.permitAttachmentUrls,
          permitValidFrom: state.permitValidFrom,
          permitValidTo: state.permitValidTo,
          moveReason: state.moveReason,
        ),
      );
    }
  }

  void back() {
    final state = this.state;
    if (state is MoveNodeConfirmation) {
      emit(
        MoveNodeSelection(
          nodeToMove: state.nodeToMove,
          selectedParent: state.selectedParent,
          partialSelection: state.partialSelection,
          permitId: state.permitId,
          permitType: state.permitType,
          issuingAuthority: state.issuingAuthority,
          permitAttachmentUrls: state.permitAttachmentUrls,
          permitValidFrom: state.permitValidFrom,
          permitValidTo: state.permitValidTo,
          moveReason: state.moveReason,
        ),
      );
    }
  }

  Future<void> execute() async {
    final currentState = state;
    if (currentState is! MoveNodeConfirmation) return;

    // Validate hierarchy before executing move
    if (currentState.nodeToMove.initialRecord is Group) {
      final childGroup = currentState.nodeToMove.initialRecord as Group;
      final parentRecord = currentState.selectedParent.initialRecord;
      if (parentRecord is Group) {
        final validChildren = parentRecord.groupType.validChildCategories;
        if (!validChildren.contains(childGroup.groupType.category)) {
          emit(MoveNodeError(
            'Cannot move ${childGroup.groupType.name} into ${parentRecord.groupType.name}',
          ));
          return;
        }
      }
    }

    final baseParams = _buildPermitBase(currentState);

    emit(
      MoveNodeMoving(
        nodeToMove: currentState.nodeToMove,
        selectedParent: currentState.selectedParent,
        partialSelection: currentState.partialSelection,
        permitId: currentState.permitId,
        permitType: currentState.permitType,
        issuingAuthority: currentState.issuingAuthority,
        permitAttachmentUrls: currentState.permitAttachmentUrls,
        permitValidFrom: currentState.permitValidFrom,
        permitValidTo: currentState.permitValidTo,
        moveReason: currentState.moveReason,
      ),
    );

    try {
      // Log partial selection details
      _logger.info('MoveNode executing with partial selection:');
      _logger.info('  - moveAll: ${currentState.partialSelection.moveAll}');
      _logger.info(
        '  - partialQuantities: ${currentState.partialSelection.partialQuantities}',
      );
      _logger.info(
        '  - selectedChildIds: ${currentState.partialSelection.selectedChildIds}',
      );

      await _graphRepository.moveNode(
        currentState.nodeToMove,
        newParent: currentState.selectedParent,
        partialSelection: currentState.partialSelection,
        moveReason: currentState.moveReason,
        base: baseParams,
      );

      emit(const MoveNodeSuccess());
    } on CapabilityConstraintError catch (error) {
      _logger.warning('Move blocked by capability guard', error);
      emit(MoveNodeError(error.message));
    } catch (e) {
      _logger.error('Failed to move node', e);
      emit(MoveNodeError('Failed to move node: ${e.toString()}'));
    }
  }

  void updatePartialSelection(PartialMoveSelection partialSelection) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(partialSelection: partialSelection));
    }
  }

  Future<StructureCapacityResult?> _previewChildCapacity({
    required GraphNode movingNode,
    required GraphNode selectedParent,
  }) async {
    final childRecord = movingNode.initialRecord;
    final parentRecord = selectedParent.initialRecord;
    if (childRecord is! Group) {
      return null;
    }
    if (parentRecord is! Group) {
      return null;
    }
    return _graphRepository.groupRepository.previewChildCapacity(
      parent: parentRecord,
      childTypeId: childRecord.groupTypeId,
      excludeRecordId: childRecord.id,
    );
  }

  void updatePermitId(String value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(permitId: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(permitId: value));
    }
  }

  void updatePermitType(String value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(permitType: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(permitType: value));
    }
  }

  void updateIssuingAuthority(String value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(issuingAuthority: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(issuingAuthority: value));
    }
  }

  void updatePermitAttachmentUrls(String value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(permitAttachmentUrls: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(permitAttachmentUrls: value));
    }
  }

  void updatePermitValidFrom(DateTime? value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(permitValidFrom: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(permitValidFrom: value));
    }
  }

  void updatePermitValidTo(DateTime? value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(permitValidTo: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(permitValidTo: value));
    }
  }

  void updateMoveReason(String value) {
    final state = this.state;
    if (state is MoveNodeSelection) {
      emit(state.copyWith(moveReason: value));
    } else if (state is MoveNodeConfirmation) {
      emit(state.copyWith(moveReason: value));
    }
  }

  EventBaseParams _buildPermitBase(MoveNodeConfirmation state) {
    final metadata = buildPermitMetadataFromTextInputs(
      permitIdText: state.permitId,
      permitTypeText: state.permitType,
      issuingAuthorityText: state.issuingAuthority,
      attachmentsText: state.permitAttachmentUrls,
      validFrom: state.permitValidFrom,
      validTo: state.permitValidTo,
      hadInitialPermit: false,
      isEditMode: false,
    );

    return metadata == null
        ? const EventBaseParams()
        : EventBaseParams(permitMetadata: metadata);
  }
}
