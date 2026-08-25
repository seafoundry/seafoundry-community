import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/navigation/community_graph_scaffold.dart';
import 'package:seafoundry_community/screens/graph/graph_node_section.dart';
import 'package:seafoundry_community/theme/spacing.dart';
import 'package:seafoundry_community/widgets/dialogs/inventory_action_sheet.dart';
import 'package:seafoundry_community/widgets/dialogs/structure_dialog.dart';
import 'package:seafoundry_community/widgets/graph_node/graph_node_events_section.dart';
import 'package:seafoundry_community/widgets/navigation/bottom_action_bar.dart';

/// Community version of group/tank node screen.
///
/// Shows child organisms and sub-groups with actions to add more.
class GroupNodeScreen extends StatelessWidget {
  const GroupNodeScreen({
    super.key,
    required this.loadedNodeState,
    required this.graphNode,
  });

  final GroupLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  Widget build(BuildContext context) {
    final group = loadedNodeState.group;

    return CommunitySimpleGraphScreenScaffold(
      bottomActions: [
        BottomAction(
          label: 'Inventory',
          icon: Icons.inventory_2_outlined,
          onPressed: () => InventoryActionSheet.show(
            context,
            node: graphNode,
          ),
        ),
        BottomAction(
          label: 'Edit Record',
          icon: Icons.edit,
          onPressed: () => StructureDialog.show(
            context,
            type: StructureType.group,
            parentNode: graphNode.parent,
            existingGroup: group,
          ),
        ),
      ],
      body: _GroupNodeBody(
        loadedNodeState: loadedNodeState,
        graphNode: graphNode,
      ),
    );
  }
}

class _GroupNodeBody extends StatelessWidget {
  const _GroupNodeBody({
    required this.loadedNodeState,
    required this.graphNode,
  });

  final GroupLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  Widget build(BuildContext context) {
    final group = loadedNodeState.group;
    final organismNodes = loadedNodeState.organismNodes;
    final groupNodes = loadedNodeState.groupNodes;
    final hasChildren = organismNodes.isNotEmpty || groupNodes.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group info card
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _groupTypeIcon(group.groupType.name),
                        size: 28,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              group.groupType.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.sm),
                  // Summary stats row
                  Row(
                    children: [
                      _StatChip(
                        label: 'Organisms',
                        value: '${organismNodes.length}',
                        icon: Icons.spa,
                      ),
                      SizedBox(width: Spacing.sm),
                      if (groupNodes.isNotEmpty)
                        _StatChip(
                          label: 'Sub-groups',
                          value: '${groupNodes.length}',
                          icon: Icons.folder_open,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Spacing.md),
          if (hasChildren) ...[
            if (groupNodes.isNotEmpty) ...[
              GraphNodeSection(
                title: 'Sub-groups',
                children: groupNodes,
              ),
              SizedBox(height: Spacing.sm),
            ],
            if (organismNodes.isNotEmpty)
              GraphNodeSection(
                title: 'Organisms',
                children: organismNodes,
                initiallyExpanded: true,
              ),
          ] else
            Center(
              child: Padding(
                padding: EdgeInsets.all(Spacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: Spacing.sm),
                    Text(
                      'No organisms yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: Spacing.xs),
                    Text(
                      'Use "Add Organism" below to get started',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: Spacing.md),
          GraphNodeEventsSection(events: loadedNodeState.events),
        ],
      ),
    );
  }

  IconData _groupTypeIcon(String typeName) {
    final lower = typeName.toLowerCase();
    if (lower.contains('tank')) return Icons.water;
    if (lower.contains('raceway')) return Icons.water;
    if (lower.contains('tree')) return Icons.park;
    if (lower.contains('dome')) return Icons.bubble_chart;
    if (lower.contains('table') || lower.contains('reebar')) return Icons.table_chart;
    if (lower.contains('cradle')) return Icons.child_care;
    if (lower.contains('frame') || lower.contains('aframe')) return Icons.architecture;
    if (lower.contains('patch')) return Icons.grid_on;
    return Icons.folder;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: Spacing.xs),
          Text(
            '$value $label',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
