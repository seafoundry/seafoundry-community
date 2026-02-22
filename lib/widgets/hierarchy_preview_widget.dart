// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// A reusable widget for displaying the organization hierarchy as connected pills
/// The hierarchy always follows: Organization -> Site -> [Groups] -> Organisms
class HierarchyPreviewWidget extends StatelessWidget {
  final String organizationName;
  final String siteName;
  final List<GroupType> groupTypes;
  final bool isSiteNew;

  const HierarchyPreviewWidget({
    super.key,
    required this.organizationName,
    required this.siteName,
    required this.groupTypes,
    this.isSiteNew = false,
  });

  static const Color organizationColor = AppColors.organizationColor;
  static const Color siteColor = AppColors.siteColor;
  static const Color groupColor = AppColors.groupColor;
  static const Color organismColor = AppColors.coralColor;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    // Organization
    widgets.add(_buildHierarchyPill(organizationName, color: organizationColor));
    widgets.add(Container(width: 2, height: 20, color: AppColors.divider));

    // Site
    widgets.add(_buildHierarchyPill(siteName, color: siteColor, isNew: isSiteNew));
    widgets.add(Container(width: 2, height: 20, color: AppColors.divider));

    // Group types
    for (int i = 0; i < groupTypes.length; i++) {
      // When not creating a new site, the last group is the new one being added
      final isNewGroup = !isSiteNew && i == groupTypes.length - 1;

      widgets.add(_buildHierarchyPill(groupTypes[i].name, color: groupColor, isNew: isNewGroup));
      widgets.add(Container(width: 2, height: 20, color: AppColors.divider));
    }

    // Organisms at the end
    widgets.add(_buildHierarchyPill('Organisms', color: organismColor));

    return Column(children: widgets);
  }

  Widget _buildHierarchyPill(String text, {required Color color, bool isNew = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: isNew ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isNew) ...[const Icon(Icons.add, size: 16), const SizedBox(width: Spacing.xs)],
          Text(text, style: isNew ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );
  }
}
