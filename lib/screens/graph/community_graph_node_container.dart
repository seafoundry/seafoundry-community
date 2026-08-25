import 'package:seafoundry_community/screens/graph/group_node_screen.dart';
import 'package:seafoundry_community/screens/graph/organism_node_screen.dart';
import 'package:seafoundry_community/screens/graph/organization_node_screen.dart';
import 'package:seafoundry_community/screens/graph/site_node_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/graph_node_events.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/graph/organization_node.dart';
import 'package:seafoundry_community/models/graph/site_node.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/widgets/common/error_details_widget.dart';

/// Container widget that provides graph node data to the screen.
///
/// Routes graph nodes to the appropriate screen based on record type.
class CommunityGraphNodeContainer extends StatelessWidget {
  final GraphNode node;

  const CommunityGraphNodeContainer({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    // Only request load if the node is not already loaded and not closed
    if (node.state is GraphNodeInitial && !node.isClosed) {
      node.add(GraphNodeLoadRequested());
    }

    switch (node.modelType) {
      case ModelType.organization:
        return BlocProvider<OrganizationNode>.value(
          value: node as OrganizationNode,
          child: BlocBuilder<OrganizationNode, GraphNodeState>(
            bloc: node as OrganizationNode,
            builder: _buildBody,
          ),
        );
      case ModelType.site:
        return BlocProvider<SiteNode>.value(
          value: node as SiteNode,
          child: BlocBuilder<SiteNode, GraphNodeState>(
            bloc: node as SiteNode,
            builder: _buildBody,
          ),
        );
      case ModelType.group:
        return BlocProvider<GroupNode>.value(
          value: node as GroupNode,
          child: BlocBuilder<GroupNode, GraphNodeState>(
            bloc: node as GroupNode,
            builder: _buildBody,
          ),
        );
      case ModelType.organismRecord:
        return BlocProvider<OrganismNode>.value(
          value: node as OrganismNode,
          child: BlocBuilder<OrganismNode, GraphNodeState>(
            bloc: node as OrganismNode,
            builder: _buildBody,
          ),
        );
      default:
        throw StateError('Invalid model type: ${node.modelType}');
    }
  }

  Widget _buildBody(BuildContext context, GraphNodeState nodeState) {
    if (nodeState is GraphNodeLoading || nodeState is GraphNodeInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (nodeState is GraphNodeError) {
      return ErrorDetailsWidget(
        error: nodeState.error,
        onRetry: () {
          if (!node.isClosed) {
            node.add(GraphNodeReloadRequested());
          }
        },
      );
    }

    final loadedState = nodeState as GraphLoadedState;
    switch (node.modelType) {
      case ModelType.organization:
        return OrganizationNodeScreen(
          loadedNodeState: loadedState as OrganizationLoadedState,
          graphNode: node,
        );
      case ModelType.site:
        return SiteNodeScreen(
          loadedNodeState: loadedState as SiteLoadedState,
          graphNode: node,
        );
      case ModelType.group:
        return GroupNodeScreen(
          loadedNodeState: loadedState as GroupLoadedState,
          graphNode: node,
        );
      case ModelType.organismRecord:
        return OrganismNodeScreen(
          loadedNodeState: loadedState as OrganismLoadedState,
          graphNode: node,
        );
      default:
        throw StateError('Unhandled model type: ${node.modelType}');
    }
  }

}
