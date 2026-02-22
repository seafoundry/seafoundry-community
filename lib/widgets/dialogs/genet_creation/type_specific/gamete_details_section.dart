// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/ui.dart';

import 'components/date_fields.dart';
import 'components/parent_selectors.dart';

class GameteDetailsSection extends StatelessWidget {
  const GameteDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }
    final formState = state.formState;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DonorGenotypeSelector(),
        UI.spacingVerticalSm,
        DropdownButtonFormField<GameteSex>(
          decoration: const InputDecoration(
            labelText: 'Gamete Sex (eggs/sperm)',
            border: OutlineInputBorder(),
            suffixIcon: InfoTooltipIcon(
              message: 'Specify whether collected gametes were eggs or sperm.',
            ),
          ),
          initialValue: formState.gameteSex.value,
          items: const [
            DropdownMenuItem(value: GameteSex.eggs, child: Text('Eggs')),
            DropdownMenuItem(value: GameteSex.sperm, child: Text('Sperm')),
          ],
          onChanged: (sex) {
            if (sex != null) {
              context.read<GenetCreationBloc>().onGameteSexChanged(sex);
            }
          },
        ),
        UI.spacingVerticalSm,
        GenetDatePickerField(
          label: 'Spawning Event Date',
          placeholder: 'Select a spawning event date',
          selectedDate: formState.gameteSpawnDate.value,
          onDateSelected: context
              .read<GenetCreationBloc>()
              .onGameteSpawnDateChanged,
          tooltip: 'Date when the donor colony spawned.',
        ),
      ],
    );
  }
}
