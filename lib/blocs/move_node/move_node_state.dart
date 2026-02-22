// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/constants/schema.dart';
import 'package:seafoundry_app/models/movement/partial_move_selection.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

abstract class MoveNodeState extends Equatable {
  const MoveNodeState();

  @override
  List<Object?> get props => [];
}

class MoveNodeInitial extends MoveNodeState {}

class MoveNodeSelection extends MoveNodeState {
  final GraphNode nodeToMove;
  final GraphNode? selectedParent;
  final PartialMoveSelection partialSelection;
  final StructureCapacityResult? capacityResult;
  final bool isCapacityCheckInProgress;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final String moveReason;

  const MoveNodeSelection({
    required this.nodeToMove,
    this.selectedParent,
    this.partialSelection = const PartialMoveSelection(),
    this.capacityResult,
    this.isCapacityCheckInProgress = false,
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.moveReason = moveReasonCorrection,
  });

  MoveNodeSelection copyWith({
    GraphNode? selectedParent,
    bool clearSelection = false,
    PartialMoveSelection? partialSelection,
    StructureCapacityResult? capacityResult,
    bool resetCapacity = false,
    bool? isCapacityCheckInProgress,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    DateTime? permitValidFrom,
    DateTime? permitValidTo,
    String? moveReason,
  }) {
    return MoveNodeSelection(
      nodeToMove: nodeToMove,
      selectedParent: clearSelection
          ? null
          : (selectedParent ?? this.selectedParent),
      partialSelection: partialSelection ?? this.partialSelection,
      capacityResult: resetCapacity
          ? null
          : (capacityResult ?? this.capacityResult),
      isCapacityCheckInProgress:
          isCapacityCheckInProgress ?? this.isCapacityCheckInProgress,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom ?? this.permitValidFrom,
      permitValidTo: permitValidTo ?? this.permitValidTo,
      moveReason: moveReason ?? this.moveReason,
    );
  }

  bool get isOverCapacity => capacityResult?.isOverCapacity ?? false;

  bool get canProceed =>
      selectedParent != null &&
      selectedParent! != nodeToMove.parent &&
      !isCapacityCheckInProgress &&
      !isOverCapacity &&
      moveReason.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    nodeToMove,
    selectedParent,
    partialSelection,
    capacityResult,
    isCapacityCheckInProgress,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    moveReason,
  ];
}

class MoveNodeConfirmation extends MoveNodeState {
  final GraphNode nodeToMove;
  final GraphNode selectedParent;
  final PartialMoveSelection partialSelection;
  final StructureCapacityResult? capacityResult;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final String moveReason;

  const MoveNodeConfirmation({
    required this.nodeToMove,
    required this.selectedParent,
    required this.partialSelection,
    this.capacityResult,
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.moveReason = moveReasonCorrection,
  });

  MoveNodeConfirmation copyWith({
    GraphNode? selectedParent,
    PartialMoveSelection? partialSelection,
    StructureCapacityResult? capacityResult,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    DateTime? permitValidFrom,
    DateTime? permitValidTo,
    String? moveReason,
  }) {
    return MoveNodeConfirmation(
      nodeToMove: nodeToMove,
      selectedParent: selectedParent ?? this.selectedParent,
      partialSelection: partialSelection ?? this.partialSelection,
      capacityResult: capacityResult ?? this.capacityResult,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom ?? this.permitValidFrom,
      permitValidTo: permitValidTo ?? this.permitValidTo,
      moveReason: moveReason ?? this.moveReason,
    );
  }

  @override
  List<Object?> get props => [
    nodeToMove,
    selectedParent,
    partialSelection,
    capacityResult,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    moveReason,
  ];
}

class MoveNodeMoving extends MoveNodeState {
  final GraphNode nodeToMove;
  final GraphNode selectedParent;
  final PartialMoveSelection partialSelection;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final String moveReason;

  const MoveNodeMoving({
    required this.nodeToMove,
    required this.selectedParent,
    required this.partialSelection,
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.moveReason = moveReasonCorrection,
  });

  @override
  List<Object?> get props => [
    nodeToMove,
    selectedParent,
    partialSelection,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    moveReason,
  ];
}

class MoveNodeSuccess extends MoveNodeState {
  const MoveNodeSuccess();
}

class MoveNodeError extends MoveNodeState {
  final String error;

  const MoveNodeError(this.error);

  @override
  List<Object?> get props => [error];
}
