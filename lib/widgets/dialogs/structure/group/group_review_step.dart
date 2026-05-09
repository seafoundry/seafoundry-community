import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/components/structure_capacity_banner.dart';
import 'package:seafoundry_app/widgets/dialogs/structure/shared/review_field_row.dart';
import 'package:seafoundry_app/widgets/hierarchy_preview_widget.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Group review step widget for the group creation dialog.
///
/// Displays a summary of all entered group information before submission,
/// including parent, type, name, description, capacity, and a hierarchy
/// preview showing how the group fits in the organization structure.
///
/// Also integrates capacity checking to prevent over-capacity situations.
class GroupReviewStepWidget extends StatelessWidget {
  const GroupReviewStepWidget({
    super.key,
    required this.formState,
    required this.parentNode,
    required this.capacityResult,
    required this.isCapacityLoading,
  });

  final GroupFormState formState;
  final GraphNode parentNode;
  final StructureCapacityResult? capacityResult;
  final bool isCapacityLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UIText.h5('Review Your Group'),
          UI.spacingVerticalMd,
          ReviewFieldRow(
            label: 'Parent',
            value: parentNode.initialRecord.name,
          ),
          ReviewFieldRow(
            label: 'Type',
            value: formState.groupType.value?.name ?? '',
          ),
          ReviewFieldRow(
            label: 'Name',
            value: formState.name.value ?? '',
          ),
          if (formState.description.value?.isNotEmpty ?? false)
            ReviewFieldRow(
              label: 'Description',
              value: formState.description.value!,
            ),
          if (formState.capacity.value != null && formState.capacity.value! > 0)
            ReviewFieldRow(
              label: 'Capacity',
              value: formState.capacity.value.toString(),
            ),
          UI.spacingVerticalMd,
          StructureCapacityBanner(
            result: capacityResult,
            isLoading: isCapacityLoading,
          ),
          if (capacityResult?.isOverCapacity == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: UIText.bodySmall(
                'Select a different parent or adjust existing structures '
                'before creating this group.',
                color: AppColors.error,
              ),
            ),
          UI.spacingVerticalMd,
          const Divider(),
          UI.spacingVerticalMd,
          _buildHierarchyPreview(),
        ],
      ),
    );
  }

  Widget _buildHierarchyPreview() {
    // Defensive check for organization state - use fallback if not loaded
    final orgState = parentNode.organizationNode.state;
    final String organizationName = orgState is OrganizationLoadedState
        ? orgState.organization.name
        : orgState.record.name;
    final siteState = parentNode.siteNode?.state;
    final String siteName = siteState?.record.name ?? 'Site';
    final groupTypes = <GroupType>[];

    // Traverse parent chain with cycle detection to prevent infinite loops
    GraphNode? current = parentNode;
    final visitedIds = <String>{};
    const maxDepth = 20; // Reasonable max hierarchy depth
    var depth = 0;

    while (current != null &&
        current.initialRecord is Group &&
        depth < maxDepth) {
      final recordId = current.initialRecord.id;
      if (visitedIds.contains(recordId)) {
        // Cycle detected - break to prevent infinite loop
        break;
      }
      visitedIds.add(recordId);
      groupTypes.insert(0, (current.initialRecord as Group).groupType);
      current = current.parent;
      depth++;
    }

    if (formState.groupType.value != null) {
      groupTypes.add(formState.groupType.value!);
    }

    return HierarchyPreviewWidget(
      organizationName: organizationName,
      siteName: siteName,
      groupTypes: groupTypes,
      isSiteNew: false,
    );
  }
}
