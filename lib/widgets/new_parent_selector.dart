// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/components/nodes/node_icon.dart';
import 'package:seafoundry_app/cubits/parent_selector_cubit.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/utils/extensions.dart';

/// Widget for selecting a new parent node when moving nodes in the graph
class NewParentSelector extends StatelessWidget {
  final GraphNode nodeToMove;
  final GraphNode? selectedParent;
  final Function(GraphNode) onParentSelected;
  final GraphNode<Organization>? organizationNode;

  const NewParentSelector({
    super.key,
    required this.nodeToMove,
    this.selectedParent,
    required this.onParentSelected,
    this.organizationNode,
  });

  /// Check if a node is a valid parent for the node being moved.
  /// [site] is the Site record if potentialParent is a SiteNode, or the
  /// ancestor Site if potentialParent is a GroupNode within a monitoring-only site.
  bool _isValidParent(GraphNode potentialParent, {Site? site}) {
    // Can't move to an organism (they can't have children)
    if (potentialParent is OrganismNode) return false;

    // Can't move to self
    if (potentialParent == nodeToMove) return false;

    // Can't move to own descendants
    if (potentialParent.isDescendantOf(nodeToMove)) return false;

    // Check if site can receive transfers (excludes monitoring-only sites)
    if (site != null) {
      final capabilities = SiteCapabilities.resolve(site.siteType);
      if (!capabilities.canReceiveTransfers) {
        return false;
      }
    }

    // Check type-specific rules
    if (nodeToMove is GroupNode) {
      // Groups can move to Sites or other Groups
      if (potentialParent is SiteNode) {
        return true;
      }
      if (potentialParent is GroupNode) {
        // Validate category hierarchy for Group→Group relationships
        final movingGroupType = (nodeToMove.initialRecord as Group).groupType;
        final parentGroupType = potentialParent.initialRecord.groupType;
        if (!parentGroupType.validChildCategories
            .contains(movingGroupType.category)) {
          return false;
        }
        return true;
      }
      return false;
    } else if (nodeToMove is OrganismNode) {
      // Organisms can only move to Groups
      return potentialParent is GroupNode;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final orgNode = organizationNode ?? nodeToMove.organizationNode;

    return BlocProvider(
      create: (context) =>
          ParentSelectorCubit()..initialize(nodeToMove, orgNode),
      child: BlocBuilder<GraphNode<Organization>, GraphNodeState>(
        bloc: orgNode,
        builder: (context, state) {
          if (state is! OrganizationLoadedState) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          return BlocBuilder<ParentSelectorCubit, ParentSelectorState>(
            builder: (context, selectorState) {
              return Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show sites directly as top level (skip organization)
                      ...state.siteNodes.map(
                        (site) => _buildNodeTile(
                          context,
                          site,
                          selectorState,
                          level: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNodeTile(
    BuildContext context,
    GraphNode node,
    ParentSelectorState selectorState, {
    required int level,
    Site? ancestorSite,
  }) {
    return BlocBuilder<GraphNode, GraphNodeState>(
      bloc: node,
      builder: (context, state) {
        return _buildNodeTileWithState(
          context,
          node,
          selectorState,
          state,
          level: level,
          ancestorSite: ancestorSite,
        );
      },
    );
  }

  Widget _buildNodeTileWithState(
    BuildContext context,
    GraphNode node,
    ParentSelectorState selectorState,
    GraphNodeState nodeState, {
    required int level,
    Site? ancestorSite,
  }) {
    if (node.id == nodeToMove.id ||
        node.isDescendantOf(nodeToMove) ||
        node is OrganismNode) {
      return const SizedBox.shrink();
    }

    // Get the site record for capability checking
    Site? site = ancestorSite;
    if (node is SiteNode) {
      final loadedState = nodeState.asOrNull<GraphLoadedState<Site>>();
      site = loadedState?.record ?? node.initialRecord;

      // Skip rendering monitoring-only sites entirely
      final capabilities = SiteCapabilities.resolve(site.siteType);
      if (!capabilities.canReceiveTransfers) {
        return const SizedBox.shrink();
      }
    }

    final isExpanded = selectorState.expandedNodes.contains(node);
    final loadedState = nodeState.asOrNull<GraphLoadedState>();
    final children = loadedState?.children.whereType<GroupNode>().toSet().toList(); // De-duplicate children
    final isSelected = selectedParent?.id == node.id;
    final isCurrentParent = nodeToMove.parent?.id == node.id;
    final isValidParent = _isValidParent(node, site: site);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Node tile
        Container(
          margin: EdgeInsets.only(left: level * Spacing.md),
          child: Card(
            elevation: isSelected ? 3 : 1,
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : isCurrentParent
                ? AppColors.disabled.withValues(alpha: 0.1)
                : null,
            shape: isCurrentParent
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(
                      color: AppColors.disabled.withValues(alpha: 0.5),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  )
                : null,
            child: InkWell(
              onTap: isValidParent ? () => onParentSelected(node) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm * 1.5,
                  vertical: Spacing.sm * 1.5,
                ),
                child: Row(
                  children: [
                    // Expand/collapse button
                    if (children?.isNotEmpty ?? false)
                      InkWell(
                        onTap: () {
                          context.read<ParentSelectorCubit>().toggleNode(node);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.xs),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_right,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 28),

                    // Node icon
                    const SizedBox(width: Spacing.sm),
                    NodeIcon(modelType: node.modelType, size: 20),

                    // Node name
                    const SizedBox(width: Spacing.sm * 1.5),
                    Expanded(
                      child: Text(
                        nodeState.record.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),

                    // Current parent indicator
                    if (isCurrentParent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.disabled.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),

                    // Selected indicator
                    if (isSelected && !isCurrentParent)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Children (if expanded)
        if (isExpanded && (children?.isNotEmpty ?? false))
          ...children!.map(
            (child) => _buildNodeTile(
              context,
              child,
              selectorState,
              level: level + 1,
              ancestorSite: site,
            ),
          ),
      ],
    );
  }
}
