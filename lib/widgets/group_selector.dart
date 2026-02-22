// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/cubits/group_selector/group_selector_cubit.dart';
import 'package:seafoundry_app/cubits/group_selector/group_selector_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/utils/extensions.dart';
import 'package:seafoundry_app/utils/human_sort.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog.dart';

/// Widget for selecting a group within a site for coral placement
class GroupSelector extends StatelessWidget {
  const GroupSelector({
    super.key,
    required this.siteNode,
    this.selectedGroup,
    required this.onGroupSelected,
    this.allowCreateSubstructure = false,
    this.onSubstructureCreated,
  });

  final SiteNode siteNode;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupSelected;

  /// Whether to show "Add Substructure" option within expanded groups
  final bool allowCreateSubstructure;

  /// Callback when a new substructure is created
  final ValueChanged<GroupNode>? onSubstructureCreated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GroupSelectorCubit(),
      child: _GroupSelectorView(
        siteNode: siteNode,
        selectedGroup: selectedGroup,
        onGroupSelected: onGroupSelected,
        allowCreateSubstructure: allowCreateSubstructure,
        onSubstructureCreated: onSubstructureCreated,
      ),
    );
  }
}

class _GroupSelectorView extends StatelessWidget {
  const _GroupSelectorView({
    required this.siteNode,
    required this.selectedGroup,
    required this.onGroupSelected,
    this.allowCreateSubstructure = false,
    this.onSubstructureCreated,
  });

  final SiteNode siteNode;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupSelected;
  final bool allowCreateSubstructure;
  final ValueChanged<GroupNode>? onSubstructureCreated;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: BlocBuilder<SiteNode, GraphNodeState<Site>>(
          bloc: siteNode,
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state is! SiteLoadedState)
                  const Center(child: CircularProgressIndicator.adaptive())
                else
                  ..._sortedGroupNodes(state.groupNodes).map(
                    (group) => _GroupNodeTile(
                      node: group,
                      level: 0,
                      selectedGroup: selectedGroup,
                      onGroupSelected: onGroupSelected,
                      allowCreateSubstructure: allowCreateSubstructure,
                      onSubstructureCreated: onSubstructureCreated,
                      siteNode: siteNode,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupNodeTile extends StatelessWidget {
  const _GroupNodeTile({
    required this.node,
    required this.level,
    required this.selectedGroup,
    required this.onGroupSelected,
    this.allowCreateSubstructure = false,
    this.onSubstructureCreated,
    this.siteNode,
  });

  final GroupNode node;
  final int level;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupSelected;
  final bool allowCreateSubstructure;
  final ValueChanged<GroupNode>? onSubstructureCreated;
  final SiteNode? siteNode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupNode, GraphNodeState<Group>>(
      bloc: node,
      builder: (context, state) {
        return _GroupNodeTileWithState(
          node: node,
          level: level,
          nodeState: state,
          selectedGroup: selectedGroup,
          onGroupSelected: onGroupSelected,
          allowCreateSubstructure: allowCreateSubstructure,
          onSubstructureCreated: onSubstructureCreated,
          siteNode: siteNode,
        );
      },
    );
  }
}

class _GroupNodeTileWithState extends StatelessWidget {
  const _GroupNodeTileWithState({
    required this.node,
    required this.level,
    required this.nodeState,
    required this.selectedGroup,
    required this.onGroupSelected,
    this.allowCreateSubstructure = false,
    this.onSubstructureCreated,
    this.siteNode,
  });

  final GroupNode node;
  final int level;
  final GraphNodeState<Group> nodeState;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupSelected;
  final bool allowCreateSubstructure;
  final ValueChanged<GroupNode>? onSubstructureCreated;
  final SiteNode? siteNode;

  @override
  Widget build(BuildContext context) {
    final loadedState = nodeState.asOrNull<GroupLoadedState>();
    final children = loadedState?.groupNodes;
    final canContainGroups = loadedState?.groupType.canContainGroups ?? true;

    return BlocBuilder<GroupSelectorCubit, GroupSelectorState>(
      builder: (context, cubitState) {
        final isExpanded = cubitState.isExpanded(nodeState.record.id);
        final isSelected = selectedGroup?.id == nodeState.record.id;
        final hasChildrenOrCanCreate =
            (children != null && children.isNotEmpty) ||
            (allowCreateSubstructure && canContainGroups);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: EdgeInsets.only(left: level * Spacing.md),
              child: Card(
                elevation: isSelected ? 3 : 1,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : null,
                child: InkWell(
                  onTap: () => onGroupSelected(node),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm * 1.5,
                      vertical: Spacing.sm * 1.5,
                    ),
                    child: Row(
                      children: [
                        if (loadedState == null)
                          const CircularProgressIndicator.adaptive()
                        else if (hasChildrenOrCanCreate)
                          InkWell(
                            onTap: () => context
                                .read<GroupSelectorCubit>()
                                .toggleExpanded(node.id),
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
                        const SizedBox(width: Spacing.sm),
                        Icon(
                          Icons.folder,
                          color: AppColors.groupColor,
                          size: 20,
                        ),
                        const SizedBox(width: Spacing.sm * 1.5),
                        Expanded(
                          child: Text(
                            nodeState.record.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                        if (isSelected)
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
            if (isExpanded) ...[
              if (children != null && children.isNotEmpty)
                ..._sortedGroupNodes(children).map(
                  (child) => _GroupNodeTile(
                    node: child,
                    level: level + 1,
                    selectedGroup: selectedGroup,
                    onGroupSelected: onGroupSelected,
                    allowCreateSubstructure: allowCreateSubstructure,
                    onSubstructureCreated: onSubstructureCreated,
                    siteNode: siteNode,
                  ),
                ),
              if (allowCreateSubstructure && canContainGroups)
                _AddSubstructureTile(
                  parentNode: node,
                  level: level + 1,
                  siteNode: siteNode,
                  onSubstructureCreated: onSubstructureCreated,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Tile to add a new substructure within a group
class _AddSubstructureTile extends StatelessWidget {
  const _AddSubstructureTile({
    required this.parentNode,
    required this.level,
    this.siteNode,
    this.onSubstructureCreated,
  });

  final GroupNode parentNode;
  final int level;
  final SiteNode? siteNode;
  final ValueChanged<GroupNode>? onSubstructureCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(left: level * Spacing.md),
      child: InkWell(
        onTap: () => _handleCreateSubstructure(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm * 1.5,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              const SizedBox(width: 28), // Align with folder icons
              const SizedBox(width: Spacing.sm),
              Icon(
                Icons.add_circle_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: Spacing.sm * 1.5),
              Text(
                'Add Substructure',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateSubstructure(BuildContext context) async {
    final result = await StructureDialog.showForModelType(
      context,
      modelType: ModelType.group,
      parentNode: parentNode,
    );

    if (result == null || !context.mounted) return;

    // Refresh the parent node to show the new structure
    parentNode.add(const GraphNodeReloadRequested());

    // Also refresh the site if available
    siteNode?.add(const GraphNodeReloadRequested());

    // Notify callback if provided
    if (result is GroupNode) {
      onSubstructureCreated?.call(result);
    }
  }
}

List<GroupNode> _sortedGroupNodes(List<GroupNode> nodes) {
  final sorted = List<GroupNode>.from(nodes);
  sorted.sort((a, b) {
    final nameA = a.state.record.name;
    final nameB = b.state.record.name;
    return compareHumanReadable(nameA, nameB);
  });
  return sorted;
}
