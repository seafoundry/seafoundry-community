// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'base_event_details.dart';

/// Widget for displaying outplant event details
class OutplantEventDetails extends BaseEventDetails {
  const OutplantEventDetails({super.key, required OutplantEvent event})
    : super(event: event, icon: Icons.park_outlined, title: 'Outplant Event');

  OutplantEvent get outplantEvent => event as OutplantEvent;

  @override
  EventColors getDefaultColors() => EventColors.fromBaseColor(Colors.green);

  @override
  Widget buildEventContent(BuildContext context) {
    // Group allocations by species and plot/tag
    final groupedBySpecies = <String, List<OutplantAllocation>>{};
    final groupedByLocation = <String, List<OutplantAllocation>>{};

    for (final allocation in outplantEvent.allocations) {
      final speciesId = allocation.speciesId.isNotEmpty
          ? allocation.speciesId
          : 'Unknown Species';
      groupedBySpecies.putIfAbsent(speciesId, () => []).add(allocation);

      final location = allocation.tagName ?? allocation.tagPath ?? 'Site Root';
      groupedByLocation.putIfAbsent(location, () => []).add(allocation);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(
          label: 'Total Corals Outplanted',
          value: outplantEvent.totalQuantity.toString(),
          icon: Icons.park,
        ),
        if (outplantEvent.percentCover != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Percent Cover',
            value: '${outplantEvent.percentCover!.toStringAsFixed(1)}%',
            icon: Icons.area_chart,
          ),
        ],
        if (outplantEvent.percentBleaching != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Percent Bleaching',
            value: '${outplantEvent.percentBleaching!.toStringAsFixed(1)}%',
            icon: Icons.palette,
          ),
        ],
        if (outplantEvent.percentDisease != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Percent Disease',
            value: '${outplantEvent.percentDisease!.toStringAsFixed(1)}%',
            icon: Icons.medical_services,
          ),
        ],
        if (outplantEvent.comment != null &&
            outplantEvent.comment!.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIText.caption('Comment:', color: AppColors.textSecondary),
              SizedBox(height: Spacing.xs),
              UIText.bodyMedium(outplantEvent.comment!),
            ],
          ),
        ],
        SizedBox(height: Spacing.md),
        Text(
          'Allocations by Species',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: Spacing.xs),
        ...groupedBySpecies.entries.map((entry) {
          final speciesId = entry.key;
          final species = SpeciesRegistry.globalById(speciesId);
          final speciesName = species?.name ?? speciesId;
          final totalQty = entry.value.fold<int>(
            0,
            (sum, a) => sum + a.quantity,
          );
          return Padding(
            padding: EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                Icon(Icons.category, size: 16, color: AppColors.textSecondary),
                SizedBox(width: Spacing.sm),
                Expanded(child: UIText.bodyMedium('$speciesName: $totalQty')),
              ],
            ),
          );
        }),
        if (groupedByLocation.length > 1) ...[
          SizedBox(height: Spacing.md),
          Text(
            'Allocations by Location',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: Spacing.xs),
          ...groupedByLocation.entries.map((entry) {
            final location = entry.key;
            final totalQty = entry.value.fold<int>(
              0,
              (sum, a) => sum + a.quantity,
            );
            return Padding(
              padding: EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: Spacing.sm),
                  Expanded(child: UIText.bodyMedium('$location: $totalQty')),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
