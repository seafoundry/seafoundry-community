// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/cubits/location_selection/location_selection_cubit.dart';
import 'package:seafoundry_app/cubits/location_selection/location_selection_state.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog.dart';
import 'package:seafoundry_app/widgets/group_selector.dart';
import 'package:seafoundry_app/widgets/ui.dart';

import 'components/dialog_scroll_view.dart';

class LocationSelectionDialog extends StatelessWidget {
  const LocationSelectionDialog._({
    required this.siteNode,
    this.organismLabel,
    this.allowCreateStructure = true,
  });

  final SiteNode siteNode;
  final String? organismLabel;
  final bool allowCreateStructure;

  static Future<GroupNode?> show(
    BuildContext context, {
    required SiteNode siteNode,
    GroupNode? initialSelection,
    String? organismLabel,
    bool allowCreateStructure = true,
  }) {
    return showDialog<GroupNode>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) =>
            LocationSelectionCubit(initialSelection: initialSelection),
        child: LocationSelectionDialog._(
          siteNode: siteNode,
          organismLabel: organismLabel,
          allowCreateStructure: allowCreateStructure,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationSelectionCubit, LocationSelectionState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on),
              SizedBox(width: 8),
              Text('Select Location'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: 400,
            ),
            child: DialogScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organismLabel != null
                        ? 'Select a group to place the ${organismLabel!.toLowerCase()}:'
                        : 'Select a group to place the organism:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GroupSelectorWithCreate(
                      siteNode: siteNode,
                      selectedGroup: state.selectedGroup,
                      onGroupSelected: (group) {
                        context.read<LocationSelectionCubit>().selectGroup(
                          group,
                        );
                      },
                      allowCreateStructure: allowCreateStructure,
                    ),
                  ),
                  if (state.selectedGroup != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: UI.paddingMd,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${state.selectedGroup!.state.record.name}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: state.hasSelection
                  ? () {
                      if (context.mounted) {
                        Navigator.of(context).pop(state.selectedGroup);
                      }
                    }
                  : null,
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }
}

/// Enhanced group selector that supports creating new structures
class GroupSelectorWithCreate extends StatelessWidget {
  const GroupSelectorWithCreate({
    super.key,
    required this.siteNode,
    this.selectedGroup,
    required this.onGroupSelected,
    this.allowCreateStructure = true,
  });

  final SiteNode siteNode;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupSelected;
  final bool allowCreateStructure;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupSelector(
          siteNode: siteNode,
          selectedGroup: selectedGroup,
          onGroupSelected: onGroupSelected,
        ),
        if (allowCreateStructure) ...[
          const Divider(height: 1),
          _CreateStructureButton(
            siteNode: siteNode,
            selectedGroup: selectedGroup,
            onGroupCreated: onGroupSelected,
          ),
        ],
      ],
    );
  }
}

/// Button to create a new structure within the site or selected group
class _CreateStructureButton extends StatelessWidget {
  const _CreateStructureButton({
    required this.siteNode,
    required this.selectedGroup,
    required this.onGroupCreated,
  });

  final SiteNode siteNode;
  final GroupNode? selectedGroup;
  final ValueChanged<GroupNode> onGroupCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = selectedGroup != null;
    final buttonLabel = hasSelection
        ? 'Add Substructure to ${selectedGroup!.state.record.name}'
        : 'Add New Structure';
    final buttonSubtitle = hasSelection
        ? 'Create nested structure within selected group'
        : 'Create a new structure in this site';

    return InkWell(
      onTap: () => _handleCreateStructure(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buttonLabel,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    buttonSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateStructure(BuildContext context) async {
    // Show structure creation dialog
    // Use selectedGroup if available, otherwise use siteNode as parent
    final result = await StructureDialog.showForModelType(
      context,
      modelType: ModelType.group,
      parentNode: selectedGroup ?? siteNode as dynamic,
    );

    if (result == null || !context.mounted) return;

    // Refresh the site to show the new structure
    siteNode.add(const GraphNodeReloadRequested());

    // Wait for site to reload and find the new group
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Try to find and select the newly created group
    if (result is GroupNode && context.mounted) {
      onGroupCreated(result);
    }
  }
}
