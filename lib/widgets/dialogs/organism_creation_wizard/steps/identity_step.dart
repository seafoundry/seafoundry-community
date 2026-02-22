// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/utils/record_name_suggester.dart';
import 'package:seafoundry_app/widgets/common/inherited_species_display.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_creation_wizard/steps/identity_step_existing_genet_section.dart';
import 'package:seafoundry_app/widgets/dialogs/organism_creation_wizard/steps/identity_step_new_genet_section.dart';
import 'package:seafoundry_app/widgets/dialogs/local_id_selection_dialog.dart';
import 'package:seafoundry_app/widgets/forms/species_selector.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/widgets/inputs/organization_selector_field.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 2: Identity - Local ID text field + New/Org Genetic Library toggle
class IdentityStep extends StatelessWidget {
  const IdentityStep({
    super.key,
    required this.state,
  });

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();

    // Check if species is locked (inherited from source cohort in graduation)
    final isGraduation = state.provenanceType == ProvenanceType.graduatedIndividual;
    final isSpeciesLocked = isGraduation && state.species != null;

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Species',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (isSpeciesLocked)
            // Show locked species inherited from cohort
            InheritedSpeciesDisplay(
              species: state.species,
              lockTooltip: 'Inherited from cohort',
            )
          else
            SpeciesSelector(
              value: state.species,
              organismKind: state.organismKind ?? OrganismKind.coral,
              onChanged: (Species? species) {
                if (species != null) {
                  cubit.speciesChanged(species);
                }
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Genet Mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('New Genet'),
                icon: Icon(Icons.add_circle_outline),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Org Genetic Library'),
                icon: Icon(Icons.inventory),
              ),
            ],
            selected: {state.isNewGenet},
            onSelectionChanged: (Set<bool> selected) {
              cubit.isNewGenetChanged(selected.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            state.isNewGenet
                ? 'Creating a new genetic lineage with provenance tracking'
                : 'Adding to existing inventory (fragmentation, rescue, etc.)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          if (state.isNewGenet) ...[
            NewGenetProvenanceSection(state: state),
            const SizedBox(height: 24),
          ],
          Text(
            'Local ID',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _LocalIdSelector(state: state),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: state.recordName,
            decoration: InputDecoration(
              labelText: 'Record Name',
              hintText:
                  RecordNameSuggester.suggestFallback(state.effectiveLocalId) ??
                  'e.g., fuzz-apal-001',
              helperText: 'Optional. Defaults to a derived name if left blank.',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.auto_awesome),
            ),
            onChanged: cubit.recordNameChanged,
          ),
          if (!state.isNewGenet) ...[
            const SizedBox(height: 24),
            ExistingGenetProvenanceSection(state: state),
          ],
          const SizedBox(height: 24),
          Text(
            'Ownership (Optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _OwnershipFields(state: state),
        ],
      ),
    );
  }
}

/// Ownership fields for owner and managing organization.
/// Uses OrganizationSelectorField (Pro tier) when repository is available,
/// falling back to plain text fields for Community tier.
class _OwnershipFields extends StatelessWidget {
  const _OwnershipFields({required this.state});

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();
    final organizationRepository = context.safeRead<OrganizationRepository>();

    // If OrganizationRepository is not available, show simple text fields
    if (organizationRepository == null) {
      return Column(
        children: [
          TextFormField(
            key: ValueKey('owner-${state.ownerOrganizationId}'),
            initialValue: state.ownerOrganizationId,
            decoration: const InputDecoration(
              labelText: 'Owner Organization',
              hintText: 'e.g., AZA-Partner-001',
              helperText: 'Organization that owns this organism',
              border: OutlineInputBorder(),
            ),
            maxLength: 100,
            onChanged: cubit.ownerOrganizationIdChanged,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('manager-${state.managingOrganizationId}'),
            initialValue: state.managingOrganizationId,
            decoration: const InputDecoration(
              labelText: 'Managing Organization',
              hintText: 'Custodial org for day-to-day care',
              helperText: 'Organization responsible for daily care',
              border: OutlineInputBorder(),
            ),
            maxLength: 100,
            onChanged: cubit.managingOrganizationIdChanged,
          ),
        ],
      );
    }

    // Use OrganizationSelectorField when repository is available
    return Column(
      children: [
        OrganizationSelectorField(
          label: 'Owner Organization',
          value: state.ownerOrganizationId,
          onChanged: cubit.ownerOrganizationIdChanged,
          organizationRepository: organizationRepository,
          hintText: 'e.g., AZA-Partner-001',
          helperText: 'Organization that owns this organism',
        ),
        const SizedBox(height: 12),
        OrganizationSelectorField(
          label: 'Managing Organization',
          value: state.managingOrganizationId,
          onChanged: cubit.managingOrganizationIdChanged,
          organizationRepository: organizationRepository,
          hintText: 'Custodial org for day-to-day care',
          helperText: 'Organization responsible for daily care',
        ),
      ],
    );
  }
}

class _LocalIdSelector extends StatelessWidget {
  const _LocalIdSelector({required this.state});

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();
    final theme = Theme.of(context);
    final localId = state.localId?.trim() ?? '';
    final hasSelection = state.selectedGenet != null || localId.isNotEmpty;
    final displayText = state.selectedGenet?.name ?? localId;
    final suggested = state.suggestedLocalId?.trim();
    final hasSuggestion = suggested != null && suggested.isNotEmpty;

    String helperText;
    if (state.selectedGenet != null) {
      helperText = 'Linked to ${state.selectedGenet!.provenanceTypeId} genet';
    } else if (hasSuggestion) {
      helperText = 'Suggested: $suggested • Tap to customize';
    } else {
      helperText = 'Required • Tap to select existing or enter new ID';
    }

    return InkWell(
      onTap: () async {
        final result = await LocalIdSelectionDialog.show(
          context,
          currentLocalId: localId.isNotEmpty ? localId : suggested,
          speciesId: state.species?.id,
        );
        if (result == null) return;

        final effectiveLocalId = result.effectiveLocalId;
        if (result.hasSelectedGenet) {
          cubit.isNewGenetChanged(false);
          cubit.genetSelected(result.selectedGenet);
          cubit.localIdChanged(effectiveLocalId);
        } else {
          cubit.genetSelected(null);
          cubit.isNewGenetChanged(true);
          cubit.localIdChanged(effectiveLocalId);
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Local ID *',
          border: const OutlineInputBorder(),
          helperText: helperText,
          isDense: true,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSelection) ...[
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    cubit.genetSelected(null);
                    cubit.isNewGenetChanged(true);
                    cubit.localIdChanged(null);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Clear selection',
                ),
              ],
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        child: Row(
          children: [
            if (state.selectedGenet != null) ...[
              Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                hasSelection
                    ? displayText
                    : (hasSuggestion ? suggested : 'Select local ID'),
                style: TextStyle(
                  color: hasSelection
                      ? theme.textTheme.bodyLarge?.color
                      : theme.hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
