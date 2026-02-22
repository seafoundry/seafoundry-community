// @tier: community
import 'package:flutter/material.dart';

import '../../../models/inventory/size_spec.dart';
import '../../../models/population_measurement.dart';
import '../../../models/provenance_life_stage_selection.dart';
import '../../../models/types/organism_kind.dart';
import '../../../models/types/provenance_type.dart';
import '../../common/five_axis_editor.dart';

/// Shared card that wraps [FiveAxisEditor] with a consistent title, helper text,
/// and padding so creation dialogs stay visually aligned.
class FiveAxisDialogSection extends StatelessWidget {
  const FiveAxisDialogSection({
    super.key,
    required this.organismKind,
    required this.initialSelection,
    required this.initialPhysicalFormId,
    required this.initialSizeSpec,
    required this.measurement,
    required this.onChanged,
    this.fieldKeyPrefix,
    this.title = 'Canonical provenance & physical form',
    this.helpText,
    this.allowedProvenanceTypes,
    this.sizeClassOptions,
  });

  final OrganismKind organismKind;
  final ProvenanceLifeStageSelection initialSelection;
  final String? initialPhysicalFormId;
  final SizeSpec initialSizeSpec;
  final PopulationMeasurement measurement;
  final ValueChanged<FiveAxisSelection> onChanged;
  final String? fieldKeyPrefix;
  final String title;
  final String? helpText;
  final List<ProvenanceType>? allowedProvenanceTypes;
  final List<String>? sizeClassOptions;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (helpText != null) ...[
              const SizedBox(height: 4),
              Text(
                helpText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FiveAxisEditor(
              organismKind: organismKind,
              fieldKeyPrefix: fieldKeyPrefix,
              initialSelection: initialSelection,
              initialPhysicalFormId: initialPhysicalFormId,
              initialSizeSpec: initialSizeSpec,
              measurement: measurement,
              onChanged: onChanged,
              allowedProvenanceTypes: allowedProvenanceTypes,
              sizeClassOptions: sizeClassOptions,
            ),
          ],
        ),
      ),
    );
  }
}
