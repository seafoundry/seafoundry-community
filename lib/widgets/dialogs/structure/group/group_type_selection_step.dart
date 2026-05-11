import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/cubits/group_creation/group_creation_bloc.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import '../../components/dialog_scroll_view.dart';

/// Group type selection step widget for the group creation dialog.
///
/// Displays available group types based on the parent context (Site or Group).
/// Filters types according to hierarchy rules:
/// - Site parent: shows superstructures and structures
/// - Superstructure parent: shows structures and substructures
/// - Structure parent: shows substructures only
/// - Substructure parent: shows informational message (cannot add children)
class GroupTypeSelectionStepWidget extends StatelessWidget {
  const GroupTypeSelectionStepWidget({
    super.key,
    required this.formState,
    required this.parentNode,
  });

  final GroupFormState formState;
  final GraphNode parentNode;

  @override
  Widget build(BuildContext context) {
    final selectedGroupType = formState.groupType.value;
    final site = parentNode.siteNode?.initialRecord;
    final availableTypes = _resolveGroupTypes(site);

    // Get context-aware label based on parent type
    final parentRecord = parentNode.initialRecord;
    final parentCategory =
        parentRecord is Group ? parentRecord.groupType.category : null;

    // Early return if parent is a substructure - cannot add nested groups
    if (parentCategory == GroupTypeCategory.substructure) {
      return SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            UI.spacingVerticalMd,
            UIText.bodyMedium(
              'Cannot add structures to a substructure',
              textAlign: TextAlign.center,
            ),
            UI.spacingVerticalSm,
            UIText.bodySmall(
              'Substructures can only contain organisms directly. '
              'To add more structure levels, create them under the parent '
              'structure instead.',
              color: UI.textSecondaryColor,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final (stepTitle, stepSubtitle) = _getStepTitleForParent(parentCategory);

    return DialogScrollView(
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UIText.bodyMedium(stepTitle),
            if (stepSubtitle != null) ...[
              UI.spacingVerticalSm,
              UIText.bodySmall(stepSubtitle, color: UI.textSecondaryColor),
            ],
            UI.spacingVerticalMd,
            if (availableTypes.isEmpty)
              const Center(child: Text('No structure types available'))
            else
              ...availableTypes.map((groupType) {
                final isSelected = selectedGroupType?.id == groupType.id;
                return _GroupTypeCard(
                  groupType: groupType,
                  isSelected: isSelected,
                  onTap: () {
                    final bloc = context.read<GroupCreationBloc>();
                    bloc.add(GroupTypeSelected(groupType));
                    bloc.add(const RecordFormNextStep());
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  (String title, String? subtitle) _getStepTitleForParent(
    GroupTypeCategory? parentCategory,
  ) {
    switch (parentCategory) {
      case null:
        // Parent is Site - can add superstructures or structures
        return (
          'Select the type of structure to create:',
          'Structures contain organisms directly. Superstructures group '
              'structures together.',
        );
      case GroupTypeCategory.superstructure:
        // Parent is Superstructure - can only add structures
        return (
          'Select the type of structure to add:',
          'Structures contain organisms or substructures.',
        );
      case GroupTypeCategory.structure:
        // Parent is Structure - can only add substructures
        return (
          'Select the type of substructure to add:',
          'Substructures organize organisms within this structure.',
        );
      case GroupTypeCategory.substructure:
        // Parent is Substructure - cannot add more groups
        return (
          'Cannot add nested structures:',
          'Add organisms directly to this substructure instead.',
        );
    }
  }

  /// Resolves available group types based on site configuration and parent.
  ///
  /// Filtering behavior:
  /// 1. Sources group types from site's hierarchy, site type config, or
  ///    fallback defaults
  /// 2. Filters based on parent's category:
  ///    - Site parent: returns superstructures and structures
  ///    - Group parent: returns only types valid as children of that category
  /// 3. Returns unfiltered list if parent is neither Site nor Group
  List<GroupType> _resolveGroupTypes(Site? site) {
    // Get all available types from site hierarchy
    List<GroupType> allTypes;
    if (site != null && site.groupTypeHierarchy.isNotEmpty) {
      allTypes = site.groupTypeHierarchy;
    } else if (site != null && site.siteType.groupTypes.isNotEmpty) {
      allTypes = site.siteType.groupTypes;
    } else {
      // Final fallback: expose a minimal set so the dialog is never empty
      allTypes = const [GroupType.tank, GroupType.group];
    }

    // Filter based on parent's category
    final parentRecord = parentNode.initialRecord;

    if (parentRecord is Site) {
      // Parent is Site - can add superstructures or structures
      return allTypes
          .where((g) => g.isSuperstructure || g.isStructure)
          .toList();
    }

    if (parentRecord is Group) {
      final validChildCategories = parentRecord.groupType.validChildCategories;

      // Filter to only show valid child types
      return allTypes
          .where((g) => validChildCategories.contains(g.category))
          .toList();
    }

    return allTypes;
  }
}

class _GroupTypeCard extends StatelessWidget {
  const _GroupTypeCard({
    required this.groupType,
    required this.isSelected,
    required this.onTap,
  });

  final GroupType groupType;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).secondaryHeaderColor : null,
      child: ListTile(
        leading: Icon(
          getGroupTypeIcon(groupType.id),
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
        title: Text(groupType.name),
        subtitle: _getGroupTypeSubtitle(groupType),
        selected: isSelected,
        onTap: onTap,
      ),
    );
  }

  Widget? _getGroupTypeSubtitle(GroupType groupType) {
    if (groupType.isSuperstructure) {
      return Text(
        'Can contain: ${groupType.validChildCategories.map((c) => c.name).join(', ')}',
        style: const TextStyle(fontSize: 12),
      );
    }
    if (groupType.isStructure) {
      return const Text(
        'Can contain organisms or substructures',
        style: TextStyle(fontSize: 12),
      );
    }
    if (groupType.isSubstructure) {
      return const Text(
        'Can contain organisms only',
        style: TextStyle(fontSize: 12),
      );
    }
    return null;
  }
}

/// Returns the appropriate icon for a group type.
IconData getGroupTypeIcon(String groupTypeId) {
  if (groupTypeId == GroupType.reebarTable.id) {
    return Icons.table_chart;
  } else if (groupTypeId == GroupType.tank.id) {
    return Icons.water_drop;
  }
  return Icons.folder;
}