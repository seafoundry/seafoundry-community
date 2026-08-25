import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_events.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// A wrapper widget that safely handles GraphNode blocs that might be closed
class GraphNodeSafeWrapper<T extends GraphNode> extends StatelessWidget {
  final T node;
  final Widget Function(BuildContext context, GraphNodeState state) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? closedWidget;

  const GraphNodeSafeWrapper({
    super.key,
    required this.node,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.closedWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Check if the bloc is closed before trying to use it
    if (node.isClosed) {
      return closedWidget ?? const SizedBox.shrink();
    }

    // Request load only if not closed and in initial state
    if (node.state is GraphNodeInitial && !node.isClosed) {
      // Use addPostFrameCallback to avoid adding events during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!node.isClosed) {
          node.add(GraphNodeLoadRequested());
        }
      });
    }

    return BlocBuilder<T, GraphNodeState>(
      bloc: node,
      builder: (context, state) {
        // Double-check if bloc was closed during build
        if (node.isClosed) {
          return closedWidget ?? const SizedBox.shrink();
        }

        if (state is GraphNodeLoading || state is GraphNodeInitial) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }

        if (state is GraphNodeError) {
          return errorWidget ?? Center(
            child: Text('Error: ${state.error}'),
          );
        }

        // Wrap builder in try-catch to prevent unhandled exceptions from breaking UI
        try {
          return builder(context, state);
        } catch (e, stackTrace) {
          LoggingService.instance.error('GraphNodeSafeWrapper builder error', e, stackTrace);
          return errorWidget ?? Center(
            child: Text('Render error: $e'),
          );
        }
      },
    );
  }
}
