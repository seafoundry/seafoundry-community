import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';

/// Read-only display of an existing genet's provenance identity fields.
/// Shown when the user has toggled to EXISTING mode and selected a genet.
class ExistingGenetProvenanceSection extends StatelessWidget {
  const ExistingGenetProvenanceSection({super.key, required this.state});

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final genet = state.selectedGenet;
    if (genet == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final clonalId = ClonalIdDisplayService.resolveForGenet(genet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genet Provenance',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        // PID chip
        Chip(
          avatar: Icon(
            Icons.fingerprint,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          label: Text(
            genet.provenanceId,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          backgroundColor: theme.colorScheme.secondaryContainer,
        ),
        const SizedBox(height: 12),
        if (clonalId != null) ...[
          TextFormField(
            initialValue: clonalId,
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Clonal ID',
              prefixIcon: Icon(Icons.content_copy),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (genet.accessionNumber != null &&
            genet.accessionNumber!.isNotEmpty) ...[
          TextFormField(
            initialValue: genet.accessionNumber,
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Accession Number',
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
