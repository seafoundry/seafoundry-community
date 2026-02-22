// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/inputs/lineage_id_selector.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'components/date_fields.dart';

class CohortDetailsSection extends StatelessWidget {
  const CohortDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;

    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final formState = state.formState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GenetDatePickerField(
          label: 'Cross Date',
          placeholder: 'Select a cross date',
          selectedDate: formState.crossDate.value,
          onDateSelected: bloc.onCrossDateChanged,
          tooltip:
              'Date when parent gametes were crossed to establish this cohort.',
        ),
        UI.spacingVerticalMd,
        UIText.bodyMedium('Parent Gametes (optional)'),
        UI.spacingVerticalXs,
        UIText.bodySmall(
          'Optionally link parent gametes. Missing linkage will affect profile completion.',
          color: Colors.grey[600],
        ),
        UI.spacingVerticalSm,
        _CrossGameteList(
          entries: formState.crossGametes.value,
          errorText: formState.crossGametes.displayError,
          species: formState.species.value,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => bloc.onCrossGameteAdded(),
            icon: const Icon(Icons.add),
            label: const Text('Add Gamete'),
          ),
        ),
      ],
    );
  }
}

class _CrossGameteList extends StatelessWidget {
  const _CrossGameteList({
    required this.entries,
    this.errorText,
    this.species,
  });

  final List<CrossGameteEntry> entries;
  final String? errorText;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Gametes',
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'No parent gametes linked. You can add linkage later to improve profile completion.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...entries.asMap().entries.map((entry) {
          final index = entry.key;
          final gamete = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LineageIdSelector(
                        label: 'Gamete ID',
                        value: gamete.id,
                        species: species,
                        localFilter: _isGameteGenet,
                        itemLabelBuilder: _gameteLabel,
                        onChanged: (value) => context
                            .read<GenetCreationBloc>()
                            .onCrossGameteUpdated(index, value ?? ''),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<CrossGameteRole>(
                              decoration: const InputDecoration(
                                labelText: 'Role',
                                border: OutlineInputBorder(),
                                suffixIcon: InfoTooltipIcon(
                                  message:
                                      'Specify whether this gamete acted as a dam or sire.',
                                ),
                              ),
                              initialValue: gamete.role,
                              items: CrossGameteRole.values
                                  .where((role) =>
                                      role != CrossGameteRole.unknown)
                                  .map(
                                    (role) =>
                                        DropdownMenuItem<CrossGameteRole>(
                                      value: role,
                                      child: Text(
                                        role == CrossGameteRole.dam
                                            ? 'Dam'
                                            : 'Sire',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (role) {
                                if (role != null) {
                                  context
                                      .read<GenetCreationBloc>()
                                      .onCrossGameteRoleChanged(index, role);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => context
                                .read<GenetCreationBloc>()
                                .onCrossGameteRemoved(index),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove gamete',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(errorText!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

bool _isGameteGenet(Genet genet) {
  final meta = genet.metadata;
  final lifeStageId = meta['lifeStageId']?.toString() ?? '';
  final gameteSex = meta['gameteSex']?.toString() ?? '';
  return lifeStageId == 'life_stage_gamete' || gameteSex.isNotEmpty;
}

String _gameteLabel(Genet genet) {
  final meta = genet.metadata;
  final gameteSex = meta['gameteSex']?.toString().toLowerCase() ?? '';
  if (gameteSex == 'eggs') return '${genet.name} (Eggs)';
  if (gameteSex == 'sperm') return '${genet.name} (Sperm)';
  return genet.name;
}
