import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node.dart';

class NavigationState extends Equatable {
  const NavigationState({
    required this.currentNode,
    required this.stack,
    this.isLoading = false,
    this.errorMessage,
    this.externalRoute,
  });

  factory NavigationState.initial(GraphNode? root) =>
      NavigationState(currentNode: root, stack: const <GraphNode>[]);

  final GraphNode? currentNode;
  final List<GraphNode> stack;
  final bool isLoading;
  final String? errorMessage;
  final String? externalRoute;

  NavigationState copyWith({
    GraphNode? currentNode,
    List<GraphNode>? stack,
    bool? isLoading,
    String? errorMessage,
    String? externalRoute,
  }) {
    return NavigationState(
      currentNode: currentNode ?? this.currentNode,
      stack: stack ?? this.stack,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      externalRoute: externalRoute,
    );
  }

  @override
  List<Object?> get props => [currentNode, stack, isLoading, errorMessage, externalRoute];
}
