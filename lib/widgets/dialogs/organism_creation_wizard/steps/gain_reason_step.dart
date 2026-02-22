// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/widgets/common/population_gain_reason_selector.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 3b: Gain Reason - For EXISTING inventory mode only
class GainReasonStep extends StatelessWidget {
  const GainReasonStep({
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
            'Population Gain Reason',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'How did this organism enter your inventory?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          PopulationGainReasonSelector(
            selected: state.gainReason,
            onChanged: cubit.gainReasonChanged,
          ),
        ],
      ),
    );
  }
}
