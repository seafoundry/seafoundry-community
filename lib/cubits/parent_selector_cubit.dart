// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';

/// State for the parent selector widget
class ParentSelectorState extends Equatable {
  final Set<GraphNode> expandedNodes;

  const ParentSelectorState({this.expandedNodes = const {}});

  ParentSelectorState copyWith({Set<GraphNode>? expandedNodes}) {
    return ParentSelectorState(expandedNodes: expandedNodes ?? this.expandedNodes);
  }

  @override
  List<Object?> get props => [expandedNodes];
}

/// Cubit for managing parent selector widget state
class ParentSelectorCubit extends Cubit<ParentSelectorState> {
  ParentSelectorCubit() : super(const ParentSelectorState());

  /// Initialize with expanded nodes for the given node and graph
  void initialize(GraphNode nodeToMove, GraphNode root) {
    final expanded = <GraphNode>{};

    // Always expand the organization root
    expanded.add(root);

    // Expand the path to the current parent
    GraphNode? current = nodeToMove.parent;
    while (current != null) {
      expanded.add(current);
      current = current.parent;
    }

    emit(state.copyWith(expandedNodes: expanded));
  }

  /// Toggle expansion state of a node
  void toggleNode(GraphNode node) {
    final newExpanded = Set<GraphNode>.from(state.expandedNodes);

    if (newExpanded.contains(node)) {
      newExpanded.remove(node);
    } else {
      newExpanded.add(node);
    }

    emit(state.copyWith(expandedNodes: newExpanded));
  }

  /// Check if a node is expanded
  bool isExpanded(GraphNode node) {
    return state.expandedNodes.contains(node);
  }
}
