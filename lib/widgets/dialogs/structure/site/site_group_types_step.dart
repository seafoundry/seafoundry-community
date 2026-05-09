import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/site_creation/site_creation_bloc.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/widgets/hierarchy_preview_widget.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import '../../components/dialog_scroll_view.dart';

/// Site group types selection step for the site creation dialog.
///
/// Allows users to select which group types (superstructures, structures,
/// substructures) will be available for this site. Includes a hierarchy
/// preview showing how the selected types will be organized.
class SiteGroupTypesStepWidget extends StatelessWidget {
  const SiteGroupTypesStepWidget({
    super.key,
    required this.formState,
    required this.organization,
  });

  final SiteFormState formState;
  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final siteType = formState.siteType.value;
    final availableGroups = siteType?.groupTypes ?? [];
    final selectedGroups = formState.groupTypes.value ?? [];

    // All tiers can use the full hierarchy: org -> site -> superstructure -> structure -> substructure
    // Substructures are no longer paywalled - users need them to organize organisms
    final filteredGroups = availableGroups;

    // Categorize available groups
    final superstructures =
        filteredGroups.where((g) => g.isSuperstructure).toList();
    final structures = filteredGroups.where((g) => g.isStructure).toList();
    final substructures = filteredGroups.where((g) => g.isSubstructure).toList();

    return DialogScrollView(
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UIText.bodyMedium(
              'Select the structure types for your site hierarchy:',
            ),
            UI.spacingVerticalMd,
            if (filteredGroups.isEmpty)
              const Text('No group types available for this site type')
            else ...[
              // Superstructures section (if any available)
              if (superstructures.isNotEmpty) ...[
                _CategorySection(
                  title: 'Superstructures',
                  subtitle: 'Top-level groupings (optional)',
                  groupTypes: superstructures,
                  selectedGroups: selectedGroups,
                  icon: Icons.account_tree,
                ),
                UI.spacingVerticalMd,
              ],
              // Structures section
              if (structures.isNotEmpty) ...[
                _CategorySection(
                  title: 'Structures',
                  subtitle: 'Primary containers for organisms',
                  groupTypes: structures,
                  selectedGroups: selectedGroups,
                  icon: Icons.inventory_2,
                ),
                UI.spacingVerticalMd,
              ],
              // Substructures section (if any available)
              if (substructures.isNotEmpty) ...[
                _CategorySection(
                  title: 'Substructures',
                  subtitle: 'Subdivisions within structures (optional)',
                  groupTypes: substructures,
                  selectedGroups: selectedGroups,
                  icon: Icons.grid_view,
                ),
                UI.spacingVerticalMd,
              ],
            ],
            if (selectedGroups.isNotEmpty) ...[
              const Divider(),
              UI.spacingVerticalSm,
              UIText.bodySmall(
                'Hierarchy Preview:',
                color: UI.textSecondaryColor,
              ),
              UI.spacingVerticalSm,
              HierarchyPreviewWidget(
                organizationName: organization.name,
                siteName: (formState.name.value?.isEmpty ?? true)
                    ? 'New Site'
                    : formState.name.value!,
                groupTypes: selectedGroups,
                isSiteNew: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.subtitle,
    required this.groupTypes,
    required this.selectedGroups,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<GroupType> groupTypes;
  final List<GroupType> selectedGroups;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon, color: Theme.of(context).primaryColor),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            dense: true,
          ),
          const Divider(height: 1),
          ...groupTypes.map((groupType) {
            final isSelected = selectedGroups.contains(groupType);
            return CheckboxListTile(
              title: Text(groupType.name),
              subtitle: _buildGroupTypeDescription(groupType),
              value: isSelected,
              dense: true,
              onChanged: (value) {
                final updated = List<GroupType>.from(selectedGroups);
                if (value ?? false) {
                  updated.add(groupType);
                } else {
                  updated.remove(groupType);
                }
                context.read<SiteCreationBloc>().add(
                  GroupTypesSelected(updated),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget? _buildGroupTypeDescription(GroupType groupType) {
    final description = _getGroupTypeDescription(groupType);
    if (description == null) return null;
    return Text(
      description,
      style: const TextStyle(fontSize: 12),
    );
  }

  String? _getGroupTypeDescription(GroupType groupType) {
    // Provide helpful descriptions for common group types
    final descriptions = <String, String>{
      GroupType.tank.id: 'Water containment for organisms',
      GroupType.raceway.id: 'Flow-through grow-out system',
      GroupType.tree.id: 'Nursery structure with branches',
      GroupType.dome.id: 'Dome structure for in-situ nursery',
      GroupType.reebarTable.id: 'Table structure for in-situ nursery',
      GroupType.cradle.id: 'Cradle structure for in-situ nursery',
      GroupType.aframe.id: 'A-frame structure for in-situ nursery',
      GroupType.group.id: 'General grouping container',
    };

    return descriptions[groupType.id];
  }
}