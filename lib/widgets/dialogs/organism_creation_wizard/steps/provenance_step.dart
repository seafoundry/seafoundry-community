// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 2a: Provenance - Simple provenance type selection for NEW genet mode.
/// Displays 3 options: Wild Collection, Transfer / Import, Unknown.
class ProvenanceStep extends StatelessWidget {
  const ProvenanceStep({
    super.key,
    required this.state,
  });

  final OrganismCreationState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrganismCreationCubit>();

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Provenance Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'How was this organism sourced?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ProvenanceTypeSelector(
            selected: state.provenanceType,
            onChanged: (value) {
              if (value != null) {
                cubit.provenanceTypeChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}
