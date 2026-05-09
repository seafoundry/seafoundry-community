// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 4: Biometrics - Life Stage selection
class BiometricsStep extends StatelessWidget {
  const BiometricsStep({
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
            'Life Stage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LifeStageSelector(
            selected: state.lifeStage,
            availableStages: state.availableLifeStages,
            onChanged: (stage) {
              cubit.lifeStageChanged(stage);
            },
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
