// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/common/alias_badges.dart';

import '../../common/organism_reference_links.dart';

/// Widget for selecting an organism record in batch outplant dialog
class OutplantOrganismSelectionRow extends StatelessWidget {
  const OutplantOrganismSelectionRow({
    super.key,
    required this.organism,
    required this.isSelected,
    required this.quantityController,
    required this.available,
    required this.isSubmitting,
    required this.onSelectionChanged,
    required this.onQuantityChanged,
    this.tagController,
    this.onTagChanged,
    this.selectedGroupId,
    this.availableGroups = const [],
    this.onGroupChanged,
    this.aliases = const [],
  });

  final OrganismRecord organism;
  final bool isSelected;
  final TextEditingController quantityController;
  final int available;
  final bool isSubmitting;
  final ValueChanged<bool?> onSelectionChanged;
  final ValueChanged<String> onQuantityChanged;
  final TextEditingController? tagController;
  final ValueChanged<String>? onTagChanged;

  /// Currently selected plot/patch group ID (null = site-level)
  final String? selectedGroupId;

  /// Available groups (plots/patches) for the selected site
  final List<Group> availableGroups;

  /// Callback when group selection changes
  final ValueChanged<String?>? onGroupChanged;

  /// Genet aliases for the organism (if available).
  final List<OrganismAlias> aliases;

  @override
  Widget build(BuildContext context) {
    // Get organism-specific label for units
    final unitLabel = organism.measurement.unit.name
        .toLowerCase(); // TODO(backlog): Use metadata.displayName when MeasurementUnit has metadata
    final readinessLabel = organism.readyForOutplant
        ? 'Ready for outplant'
        : 'Not ready for outplant';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: isSubmitting ? null : (val) => onSelectionChanged(val),
        title: OrganismReferenceLinks(
          tagId: organism.tagId,
          localGenetId: organism.localGenetId,
          urlPath: organism.urlPath,
          genetRecordId: organism.genetRecordId,
          showUnderline: false,
          disableNavigation: true,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available: $available $unitLabel | $readinessLabel'),
            if (aliases.isNotEmpty) ...[
              const SizedBox(height: 6),
              AliasBadges(aliases: aliases),
            ],
            if (isSelected) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: quantityController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: onQuantityChanged,
                    ),
                  ),
                  if (tagController != null && onTagChanged != null)
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: tagController,
                        enabled: !isSubmitting,
                        decoration: const InputDecoration(
                          hintText: 'Tag ID',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: onTagChanged,
                      ),
                    ),
                  if (availableGroups.isNotEmpty && onGroupChanged != null)
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        initialValue: selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'Plot/Patch',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Site Level'),
                          ),
                          ...availableGroups.map(
                            (group) => DropdownMenuItem<String?>(
                              value: group.id,
                              child: Text(
                                group.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: isSubmitting ? null : onGroupChanged,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
