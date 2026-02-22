// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/widgets/inputs/lineage_id_selector.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class ParentCohortSelector extends StatelessWidget {
  const ParentCohortSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final species = state.formState.species.value;
    final parentCohortId = state.formState.parentCohortId.value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LineageIdSelector(
          label: 'Parent Cohort *',
          value: parentCohortId.isEmpty ? null : parentCohortId,
          species: species,
          allowedProvenanceTypeIds: const ['provenance_type_sexual_cohort'],
          allowCreate: true,
          onChanged: (value) => bloc.onParentCohortIdChanged(value ?? ''),
        ),
        UI.spacingVerticalXs,
        UIText.caption(
          'Select the cohort this recruit came from (same species)',
        ),
      ],
    );
  }
}

class DonorGenotypeSelector extends StatelessWidget {
  const DonorGenotypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final state = context.watch<GenetCreationBloc>().state;
    if (state is! GenetCreationInProgress) {
      return const SizedBox.shrink();
    }

    final species = state.formState.species.value;
    final donorId = state.formState.donorGenotypeId.value.trim();

    return LineageIdSelector(
      label: 'Donor Genotype *',
      value: donorId.isEmpty ? null : donorId,
      species: species,
      allowedProvenanceTypeIds: const ['provenance_type_wild'],
      helperText:
          'Select the founder genotype that provided gametes for this record.',
      allowCreate: true,
      onChanged: (value) => bloc.onDonorGenotypeIdChanged(value ?? ''),
    );
  }
}
