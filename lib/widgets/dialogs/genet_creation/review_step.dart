// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'genet_creation_utils.dart';
import '../components/dialog_scroll_view.dart';

class GenetReviewStep extends StatelessWidget {
  const GenetReviewStep({super.key, required this.state});

  final GenetCreationInProgress state;

  @override
  Widget build(BuildContext context) {
    final formState = state.formState;
    final buffer = <Widget>[];

    if (formState.species.value != null) {
      buffer.add(_buildReviewField('Species', formState.species.value!.name));
    }
    buffer.add(_buildReviewField('Local Genet ID', formState.name.value));
    if (formState.provenanceType.value != null) {
      buffer.add(_buildReviewField('Provenance Type', formState.provenanceType.value!.displayName));
    }
    if (formState.lifeStage.value != null) {
      buffer.add(_buildReviewField('Life Stage', formState.lifeStage.value!.displayName));
    }
    if (formState.clonalId.value?.isNotEmpty == true) {
      buffer.add(_buildReviewField('Clonal ID', formState.clonalId.value!));
    }
    if (formState.accessionNumber.value?.isNotEmpty == true) {
      buffer.add(
        _buildReviewField('Accession #', formState.accessionNumber.value!),
      );
    }

    // Handle type-specific fields based on provenance type and life stage
    final provenanceType = formState.provenanceType.value;
    final lifeStage = formState.lifeStage.value;

    // Gamete-specific fields
    if (lifeStage == LifeStage.gamete) {
      if (formState.donorGenotypeId.value.trim().isNotEmpty) {
        buffer.add(
          _buildReviewField(
            'Donor Genotype',
            formState.donorGenotypeId.value.trim(),
          ),
        );
      }
      if (formState.gameteSpawnDate.value != null) {
        buffer.add(
          _buildReviewField(
            'Spawn Date',
            formatGenetDate(formState.gameteSpawnDate.value!),
          ),
        );
      }
    } else if (provenanceType == ProvenanceType.sexualCohort) {
      // Cohort-specific fields
      final dams = formState.normalizedDamIds;
      final sires = formState.normalizedSireIds;
      final date = formState.crossDate.value;
      if (date != null) {
        buffer.add(_buildReviewField('Cross Date', formatGenetDate(date)));
      }
      if (dams.isNotEmpty) {
        buffer.add(_buildReviewField('Dam Gametes', dams.join(', ')));
      }
      if (sires.isNotEmpty) {
        buffer.add(_buildReviewField('Sire Gametes', sires.join(', ')));
      }
    } else if (provenanceType == ProvenanceType.graduatedIndividual) {
      // Sexual recruit-specific fields
      if (formState.parentCohortId.value.trim().isNotEmpty) {
        buffer.add(
          _buildReviewField(
            'Parent Cohort',
            formState.parentCohortId.value.trim(),
          ),
        );
      }
    }

    if (formState.notes.value.trim().isNotEmpty) {
      buffer.add(_buildReviewField('Notes', formState.notes.value.trim()));
    }

    buffer
      ..add(UI.spacingVerticalMd)
      ..add(const Divider())
      ..add(UI.spacingVerticalMd)
      ..add(
        const Center(
          child: Column(
            children: [
              Icon(Icons.fingerprint, size: 64, color: Colors.purple),
              SizedBox(height: 8),
              Text('Creating New Genet'),
            ],
          ),
        ),
      );

    return DialogScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buffer,
      ),
    );
  }
}

Widget _buildReviewField(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: UIText.bodySmall('$label:', color: UI.textSecondaryColor),
        ),
        Expanded(child: UIText.bodyMedium(value)),
      ],
    ),
  );
}