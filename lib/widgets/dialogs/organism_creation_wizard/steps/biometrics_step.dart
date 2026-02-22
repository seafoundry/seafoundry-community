// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 4: Biometrics - Life Stage + Physical Form selection
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
            onChanged: (stage) async {
              if (stage == LifeStage.gamete) {
                // First commit the selection so the UI updates to show 'Gamete'
                await cubit.lifeStageChanged(stage);
                if (context.mounted) {
                  await _showGameteRoleDialog(context, cubit);
                }
              } else {
                cubit.lifeStageChanged(stage);
              }
            },
          ),
          if (state.lifeStage == LifeStage.gamete && state.gameteRole != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Text(
                    'Gamete Type:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 12),
                  InputChip(
                    label: Text(
                      state.gameteRole == ProvenanceGameteRole.sperm
                          ? 'Sperm'
                          : 'Eggs',
                    ),
                    avatar: Icon(
                      state.gameteRole == ProvenanceGameteRole.sperm
                          ? Icons.water // Using water/waves for sperm
                          : Icons.circle_outlined, // Circle for egg
                      size: 18,
                    ),
                    onPressed: () => _showGameteRoleDialog(context, cubit),
                    // No delete icon, just tap to change
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showGameteRoleDialog(
    BuildContext context,
    OrganismCreationCubit cubit,
  ) async {
    final role = await showDialog<ProvenanceGameteRole>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Gamete Type'),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, ProvenanceGameteRole.sperm),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.water, size: 24),
                  SizedBox(width: 12),
                  Text('Sperm', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ProvenanceGameteRole.egg),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.circle_outlined, size: 24),
                  SizedBox(width: 12),
                  Text('Eggs', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (role != null) {
      cubit.gameteRoleChanged(role);
      // Removed redundant lifeStageChanged call to avoid state reset
    }
  }
}
