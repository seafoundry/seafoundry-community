// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/widgets/common/pid_status_chip.dart';
import 'package:seafoundry_app/widgets/inputs/provenance_autocomplete_field.dart';

/// Provenance autocomplete fields and PID display chip for genet creation.
class GenetProvenanceSection extends StatefulWidget {
  const GenetProvenanceSection({super.key, required this.state});
  final GenetCreationInProgress state;

  @override
  State<GenetProvenanceSection> createState() => _GenetProvenanceSectionState();
}

class _GenetProvenanceSectionState extends State<GenetProvenanceSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GenetCreationBloc, GenetCreationState>(
      builder: (context, state) {
        if (state is! GenetCreationInProgress) {
          return const SizedBox.shrink();
        }

        final bloc = context.read<GenetCreationBloc>();
        final search = state.provenanceSearch;
        final activeField = search.activeField;
        final pidLocked = state.provenanceIdSearchValue.trim().isNotEmpty;
        final hasResolvedPid = search.resolvedProvenanceId != null;
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                value: state.provenanceIdSearchValue,
                suggestions: search.provenanceIdSuggestions,
                isSearching: search.isSearchingProvenanceId,
                displayValueBuilder: (suggestion) => suggestion.provenanceId,
                showOtherAliases: false,
                enabled:
                    !hasResolvedPid &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.provenanceId),
                onTextChanged: bloc.onProvenanceIdSearchValueChanged,
                onSuggestionSelected: (suggestion) {
                  bloc.onProvenanceSuggestionSelected(
                    suggestion,
                    ProvenanceMatchField.provenanceId,
                  );
                  bloc.onProvenanceIdSearchValueChanged(
                    suggestion.provenanceId,
                  );
                },
                onEditingComplete: () {
                  if (state.provenanceIdSearchValue.trim().isNotEmpty) {
                    bloc.setActiveProvenanceField(
                      ProvenanceMatchField.provenanceId,
                    );
                  }
                },
                onDisabledTap:
                    (hasResolvedPid ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.provenanceId))
                    ? bloc.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Alias',
                hintText: 'e.g., APAL-001',
                icon: Icons.label_outline,
                value: state.aliasSearchValue,
                suggestions: search.aliasSuggestions,
                isSearching: search.isSearchingAlias,
                displayValueBuilder: (suggestion) =>
                    ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                showOtherAliases: false,
                enabled:
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.alias),
                onTextChanged: bloc.onAliasSearchValueChanged,
                onSuggestionSelected: (suggestion) {
                  bloc.onProvenanceSuggestionSelected(
                    suggestion,
                    ProvenanceMatchField.alias,
                  );
                  bloc.onAliasSearchValueChanged(suggestion.aliasValue);
                },
                onEditingComplete: () {
                  if (state.aliasSearchValue.trim().isNotEmpty) {
                    bloc.setActiveProvenanceField(ProvenanceMatchField.alias);
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.alias))
                    ? bloc.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Clonal ID',
                hintText: 'e.g., Apal-025',
                icon: Icons.content_copy,
                value: state.formState.clonalId.value ?? '',
                suggestions: search.clonalIdSuggestions,
                isSearching: search.isSearchingClonalId,
                enabled:
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.clonalId),
                onTextChanged: bloc.onClonalIdChanged,
                onSuggestionSelected: (suggestion) {
                  bloc.onProvenanceSuggestionSelected(
                    suggestion,
                    ProvenanceMatchField.clonalId,
                  );
                  bloc.onClonalIdChanged(
                    ClonalIdDisplayService.resolveForSuggestion(suggestion),
                  );
                },
                onEditingComplete: () {
                  if ((state.formState.clonalId.value ?? '')
                      .trim()
                      .isNotEmpty) {
                    bloc.setActiveProvenanceField(
                      ProvenanceMatchField.clonalId,
                    );
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField != ProvenanceMatchField.clonalId))
                    ? bloc.clearProvenanceSelection
                    : null,
              ),
              const SizedBox(height: 16),
              ProvenanceAutocompleteField(
                label: 'Accession Number',
                hintText: 'e.g., ACC-2024-001',
                icon: Icons.confirmation_number,
                value: state.formState.accessionNumber.value ?? '',
                suggestions: search.accessionSuggestions,
                isSearching: search.isSearchingAccession,
                displayValueBuilder: (suggestion) =>
                    ClonalIdDisplayService.resolveAliasDisplay(suggestion),
                showOtherAliases: false,
                enabled:
                    !pidLocked &&
                    (activeField == null ||
                        activeField == ProvenanceMatchField.accessionNumber),
                onTextChanged: bloc.onAccessionNumberChanged,
                onSuggestionSelected: (suggestion) {
                  bloc.onProvenanceSuggestionSelected(
                    suggestion,
                    ProvenanceMatchField.accessionNumber,
                  );
                  bloc.onAccessionNumberChanged(suggestion.aliasValue);
                },
                onEditingComplete: () {
                  if ((state.formState.accessionNumber.value ?? '')
                      .trim()
                      .isNotEmpty) {
                    bloc.setActiveProvenanceField(
                      ProvenanceMatchField.accessionNumber,
                    );
                  }
                },
                onDisabledTap:
                    (pidLocked ||
                        (activeField != null &&
                            activeField !=
                                ProvenanceMatchField.accessionNumber))
                    ? bloc.clearProvenanceSelection
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
