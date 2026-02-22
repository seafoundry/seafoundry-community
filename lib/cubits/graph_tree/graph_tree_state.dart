// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';

/// State for the graph tree expansion
class GraphTreeState extends Equatable {
  final Set<GraphNode> expandedNodes;
  final bool autoExpandToSelected;

  const GraphTreeState({required this.expandedNodes, this.autoExpandToSelected = true});

  const GraphTreeState.initial() : expandedNodes = const {}, autoExpandToSelected = true;

  GraphTreeState copyWith({Set<GraphNode>? expandedNodes, bool? autoExpandToSelected}) {
    return GraphTreeState(
      expandedNodes: expandedNodes ?? this.expandedNodes,
      autoExpandToSelected: autoExpandToSelected ?? this.autoExpandToSelected,
    );
  }

  @override
  List<Object?> get props => [expandedNodes, autoExpandToSelected];
}
