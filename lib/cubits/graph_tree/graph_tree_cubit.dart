// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/cubits/graph_tree/graph_tree_state.dart';

/// Cubit to manage the graph tree expansion state
class GraphTreeCubit extends Cubit<GraphTreeState> {
  GraphTreeCubit() : super(const GraphTreeState.initial());

  /// Toggle expansion state for a node
  void toggleNode(GraphNode node) {
    final expandedNodes = Set<GraphNode>.from(state.expandedNodes);

    if (expandedNodes.contains(node)) {
      expandedNodes.remove(node);
    } else {
      expandedNodes.add(node);
    }

    emit(state.copyWith(expandedNodes: expandedNodes));
  }

  /// Expand a specific node
  void expandNode(GraphNode node) {
    if (!state.expandedNodes.contains(node)) {
      final expandedNodes = Set<GraphNode>.from(state.expandedNodes);
      expandedNodes.add(node);
      emit(state.copyWith(expandedNodes: expandedNodes));
    }
  }

  /// Collapse a specific node
  void collapseNode(GraphNode node) {
    if (state.expandedNodes.contains(node)) {
      final expandedNodes = Set<GraphNode>.from(state.expandedNodes);
      expandedNodes.remove(node);
      emit(state.copyWith(expandedNodes: expandedNodes));
    }
  }

  /// Expand path to a specific node
  void expandPathToNode(GraphNode targetNode) {
    final expandedNodes = Set<GraphNode>.from(state.expandedNodes);

    // Walk up the tree and expand all parent nodes
    GraphNode? current = targetNode.parent;
    while (current != null) {
      expandedNodes.add(current);
      current = current.parent;
    }

    emit(state.copyWith(expandedNodes: expandedNodes));
  }

  /// Collapse all nodes
  void collapseAll() {
    emit(state.copyWith(expandedNodes: {}));
  }

  /// Expand all loaded nodes
  void expandAll(GraphNode rootNode) {
    final expandedNodes = <GraphNode>{};

    void addNodeAndChildren(GraphNode node) {
      // Only add non-leaf nodes (nodes that might have children)
      final nodeState = node.state;
      if (nodeState is GraphLoadedState && nodeState.children.isNotEmpty) {
        expandedNodes.add(node);
        for (final child in nodeState.children) {
          addNodeAndChildren(child);
        }
      }
    }

    addNodeAndChildren(rootNode);
    emit(state.copyWith(expandedNodes: expandedNodes));
  }

  /// Check if a node is expanded
  bool isExpanded(GraphNode node) {
    return state.expandedNodes.contains(node);
  }
}
