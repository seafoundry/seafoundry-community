// @tier: community
import 'package:equatable/equatable.dart';

class GroupSelectorState extends Equatable {
  const GroupSelectorState({this.expandedNodeIds = const {}});

  final Set<String> expandedNodeIds;

  bool isExpanded(String nodeId) => expandedNodeIds.contains(nodeId);

  GroupSelectorState copyWith({Set<String>? expandedNodeIds}) {
    return GroupSelectorState(
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
    );
  }

  @override
  List<Object?> get props => [expandedNodeIds];
}
