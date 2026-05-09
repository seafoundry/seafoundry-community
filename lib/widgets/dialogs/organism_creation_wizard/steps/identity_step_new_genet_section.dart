import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/widgets/common/pid_status_chip.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_field.dart';

/// Provenance autocomplete fields shown when creating a new genet lineage.
/// Displays clonal ID / accession number search fields and a PID status chip.
class NewGenetProvenanceSection extends StatefulWidget {
  const NewGenetProvenanceSection({super.key, required this.state});

  final OrganismCreationState state;

  @override
  State<NewGenetProvenanceSection> createState() =>
      _NewGenetProvenanceSectionState();
}

class _NewGenetProvenanceSectionState extends State<NewGenetProvenanceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrganismCreationCubit, OrganismCreationState>(
      builder: (context, state) {
        final cubit = context.read<OrganismCreationCubit>();
        final search = state.provenanceSearch;
        final hasSpecies = state.species != null;
        final activeField = search.activeField;
        final searchEnabled = hasSpecies;
        final pidLocked = (state.provenanceId ?? '').trim().isNotEmpty;
        final hasResolvedPid = search.resolvedProvenanceId != null;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Associate new genet with another alias or organization\'s ID',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!hasSpecies) ...[
              Text(
                'Select a species first to enable provenance search',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select External Aliases & IDs',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(_isExpanded ? 'Hide' : 'Show'),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              ProvenanceAutocompleteField(
                label: 'Provenance ID (PID)',
                hintText: 'e.g., PID-APAL-0007',
                icon: Icons.fingerprint,
                value: state.provenanceId ?? '',
                suggestions: search.provenanceIdSuggestions,
                isSearching: search.isSearchingProvenanceId,
                displayValueBuilder: (suggestion) => suggestion.provenanceId,
                showOtherAliases: false,
                enabled:
                    searchEnabled &&
                    !hasResolvedPid &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.provenanceId),
                onTextChanged: cubit.provenanceIdChanged,
                onSuggestionSelected: (suggestion) {
                  cubit.selectProvenanceSuggestion(
                    suggestion,
                    ProvenanceMatchField.provenanceId,
                  );
                },
                onEditingComplete: () {
                  if ((state.provenanceId ?? '').trim().isNotEmpty) {
                    cubit.setActiveProvenanceField(
                      ProvenanceMatchField.provenanceId,
                    );
                  }
                },
                onDisabledTap:
                    (hasResolvedPid ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.provenanceId))
                    ? cubit.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Alias',
                hintText: 'e.g., APAL-001',
                icon: Icons.label_outline,
                value: state.aliasId ?? '',
                suggestions: search.aliasSuggestions,
                isSearching: search.isSearchingAlias,
                displayValueBuilder: (suggestion) =>
                    ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                showOtherAliases: false,
                enabled:
                    searchEnabled &&
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.alias),
                onTextChanged: cubit.aliasIdChanged,
                onSuggestionSelected: (suggestion) {
                  cubit.selectProvenanceSuggestion(
                    suggestion,
                    ProvenanceMatchField.alias,
                  );
                },
                onEditingComplete: () {
                  if ((state.aliasId ?? '').trim().isNotEmpty) {
                    cubit.setActiveProvenanceField(ProvenanceMatchField.alias);
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.alias))
                    ? cubit.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Clonal ID',
                hintText: 'e.g., Apal-025',
                icon: Icons.content_copy,
                value: state.clonalId ?? '',
                suggestions: search.clonalIdSuggestions,
                isSearching: search.isSearchingClonalId,
                enabled:
                    searchEnabled &&
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.clonalId),
                onTextChanged: cubit.clonalIdChanged,
                onSuggestionSelected: (suggestion) {
                  cubit.selectProvenanceSuggestion(
                    suggestion,
                    ProvenanceMatchField.clonalId,
                  );
                },
                onEditingComplete: () {
                  if ((state.clonalId ?? '').trim().isNotEmpty) {
                    cubit.setActiveProvenanceField(
                      ProvenanceMatchField.clonalId,
                    );
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.clonalId))
                    ? cubit.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Accession Number',
                hintText: 'e.g., ACC-2024-001',
                icon: Icons.confirmation_number,
                value: state.accessionNumber ?? '',
                suggestions: search.accessionSuggestions,
                isSearching: search.isSearchingAccession,
                displayValueBuilder: (suggestion) =>
                    ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                showOtherAliases: false,
                enabled:
                    searchEnabled &&
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.accessionNumber),
                onTextChanged: cubit.accessionNumberChanged,
                onSuggestionSelected: (suggestion) {
                  cubit.selectProvenanceSuggestion(
                    suggestion,
                    ProvenanceMatchField.accessionNumber,
                  );
                },
                onEditingComplete: () {
                  if ((state.accessionNumber ?? '').trim().isNotEmpty) {
                    cubit.setActiveProvenanceField(
                      ProvenanceMatchField.accessionNumber,
                    );
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField !=
                                ProvenanceMatchField.accessionNumber))
                    ? cubit.clearProvenanceSelection
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            PidStatusChip(searchState: search),
          ],
        );
      },
    );
  }
}
