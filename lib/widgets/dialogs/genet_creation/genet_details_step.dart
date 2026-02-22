// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/common/alias_editor.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/genet_provenance_section.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import '../components/dialog_scroll_view.dart';

class GenetDetailsStep extends StatelessWidget {
  const GenetDetailsStep({super.key, required this.state});

  final GenetCreationInProgress state;

  @override
  Widget build(BuildContext context) {
    final formState = state.formState;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final viewInsets = views.isNotEmpty
        ? MediaQueryData.fromView(views.first).viewInsets
        : MediaQuery.of(context).viewInsets;

    return DialogScrollView(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<CurrentUser, CurrentUserState>(
            builder: (context, userState) {
              if (userState is! CurrentUserLoaded) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final organization = userState.organization;
              final registry =
                  SpeciesRegistry.globalInstance ?? SpeciesRegistry();
              final selectedSpecies = formState.species.value;
              final selectedSpeciesId = SpeciesRegistry.normalizeId(
                selectedSpecies?.id,
              );
              final resolvedSelected = selectedSpeciesId == null
                  ? null
                  : registry.byId(selectedSpeciesId) ??
                        SpeciesRegistry.globalById(
                          selectedSpeciesId,
                          allowFallback: false,
                        ) ??
                        selectedSpecies;

              final orgSpeciesIds = <String>{};
              final organizationSpeciesIds = <String>{};
              final organizationSpecies = <Species>[];
              for (final speciesId in organization.speciesIds) {
                final normalizedId = SpeciesRegistry.normalizeId(speciesId);
                if (normalizedId == null || normalizedId.isEmpty) {
                  continue;
                }
                if (!orgSpeciesIds.add(normalizedId)) {
                  continue;
                }
                final species =
                    registry.byId(normalizedId) ??
                    SpeciesRegistry.globalById(
                      normalizedId,
                      allowFallback: false,
                    );
                if (species != null) {
                  organizationSpecies.add(species);
                  organizationSpeciesIds.add(species.id.trim().toLowerCase());
                }
              }

              if (resolvedSelected != null &&
                  selectedSpeciesId != null &&
                  orgSpeciesIds.contains(selectedSpeciesId) &&
                  !organizationSpeciesIds.contains(selectedSpeciesId)) {
                organizationSpecies.add(resolvedSelected);
                organizationSpeciesIds.add(selectedSpeciesId);
              }

              // Sort organization species by code
              organizationSpecies.sort((a, b) => a.code.compareTo(b.code));

              final items = <DropdownMenuItem<Species?>>[
                DropdownMenuItem<Species?>(
                  enabled: false,
                  value: null,
                  child: Text(
                    '${organization.domain.toUpperCase()} SPECIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                ...organizationSpecies.map(
                  (species) => DropdownMenuItem<Species?>(
                    value: species,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            species.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            species.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DropdownMenuItem<Species?>(
                  enabled: false,
                  value: null,
                  child: Text(
                    'ALL SPECIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ];

              final otherSpecies = registry.all
                  .where(
                    (species) => !orgSpeciesIds.contains(
                      species.id.trim().toLowerCase(),
                    ),
                  )
                  .toList();

              if (resolvedSelected != null &&
                  selectedSpeciesId != null &&
                  !orgSpeciesIds.contains(selectedSpeciesId) &&
                  !otherSpecies.any((species) => species == resolvedSelected)) {
                otherSpecies.add(resolvedSelected);
              }

              // Sort other species by code
              otherSpecies.sort((a, b) => a.code.compareTo(b.code));

              items.addAll(
                otherSpecies.map(
                  (species) => DropdownMenuItem<Species?>(
                    value: species,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            species.code,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            species.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return DropdownButtonFormField<Species?>(
                decoration: InputDecoration(
                  labelText: 'Species',
                  prefixIcon: const Icon(Icons.science),
                  border: const OutlineInputBorder(),
                  suffixIcon: const InfoTooltipIcon(
                    message:
                        'Select the species associated with this genet record.',
                  ),
                  errorText: state.formState.species.displayError?.message,
                ),
                items: items,
                initialValue: resolvedSelected,
                isExpanded: true,
                menuMaxHeight: 400,
                onChanged: (species) {
                  if (species != null) {
                    context.read<GenetCreationBloc>().onSpeciesChanged(species);
                  }
                },
              );
            },
          ),
          UI.spacingVerticalMd,
          UIText.bodyMedium('Identity'),
          UI.spacingVerticalMd,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Local Genet ID *',
                  hintText: 'e.g., Apal-1 (suggested)',
                  helperText:
                      'Organization-specific identifier (can be customized)',
                  prefixIcon: const Icon(Icons.label),
                  border: const OutlineInputBorder(),
                  suffixIcon: const InfoTooltipIcon(
                    message:
                        'Local identifier shown throughout your organization. Must be unique within the org.',
                  ),
                  errorText:
                      state.nameValidationError ??
                      formState.name.displayError?.message,
                  errorMaxLines: 3,
                ),
                initialValue: formState.name.value,
                onChanged: (value) =>
                    context.read<GenetCreationBloc>().onNameChanged(value),
                autofocus: true,
              ),
              if (state.nameValidationError != null &&
                  state.suggestedName != null) ...[
                UI.spacingVerticalSm,
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    UI.spacingHorizontalSm,
                    Expanded(
                      child: Text(
                        'Suggested name: ${state.suggestedName}',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<GenetCreationBloc>().onNameChanged(
                          state.suggestedName!,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Use this'),
                    ),
                  ],
                ),
              ],
            ],
          ),
          UI.spacingVerticalMd,
          Builder(
            builder: (context) {
              final allowedTypes =
                  (formState.allowedProvenanceTypes?.isNotEmpty ?? false)
                  ? formState.allowedProvenanceTypes!
                  : ProvenanceType.values;
              final initialType =
                  formState.provenanceType.value ?? allowedTypes.first;

              return ProvenanceTypeSelector(
                key: ValueKey(initialType),
                selected: formState.provenanceType.value,
                availableTypes: allowedTypes,
                onChanged: (value) {
                  if (value != null) {
                    context.read<GenetCreationBloc>().onProvenanceTypeChanged(
                      value,
                    );
                  }
                },
              );
            },
          ),
          UI.spacingVerticalMd,
          GenetProvenanceSection(state: state),
          UI.spacingVerticalMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: UIText.bodyMedium('Aliases')),
              const InfoTooltipIcon(
                message:
                    'Tag SeaFoundry IDs, AZA Tracks IDs, CSR accessions, etc. '
                    'Duplicates will be flagged immediately.',
              ),
            ],
          ),
          UI.spacingVerticalSm,
          AliasEditorList(
            aliases: formState.aliases,
            onAddAlias: () => context.read<GenetCreationBloc>().onAliasAdded(),
            onRemoveAlias: (index) =>
                context.read<GenetCreationBloc>().onAliasRemoved(index),
            onValueChanged: (index, value) => context
                .read<GenetCreationBloc>()
                .onAliasValueChanged(index, value),
            onSourceChanged: (index, source) => context
                .read<GenetCreationBloc>()
                .onAliasSourceChanged(index, source),
            onLabelChanged: (index, label) => context
                .read<GenetCreationBloc>()
                .onAliasLabelChanged(index, label),
            excludedSystems: kReservedAliasSystems,
          ),
          UI.spacingVerticalMd,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: UIText.bodyMedium('Ownership & custody')),
              const InfoTooltipIcon(
                message:
                    'Optional custodial metadata used for compliance exports and inventory transfers.',
              ),
            ],
          ),
          UI.spacingVerticalSm,
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Owner organization id (optional)',
              hintText: 'e.g., AZA-Partner-001',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            initialValue: formState.ownerOrganizationId,
            onChanged: context
                .read<GenetCreationBloc>()
                .onOwnerOrganizationChanged,
          ),
          UI.spacingVerticalSm,
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Managing organization id (optional)',
              hintText: 'Custodial org for day-to-day care',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            initialValue: formState.managingOrganizationId,
            onChanged: context
                .read<GenetCreationBloc>()
                .onManagingOrganizationChanged,
          ),
        ],
      ),
    );
  }
}
