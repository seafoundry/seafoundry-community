// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/info_tooltip_icon.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'type_specific/cohort_details_section.dart';
import 'type_specific/founder_details_section.dart';
import 'type_specific/gamete_details_section.dart';
import 'type_specific/sexual_recruit_section.dart';
import 'type_specific/transfer_details_section.dart';
import '../components/dialog_scroll_view.dart';

class TypeSpecificStep extends StatelessWidget {
  const TypeSpecificStep({super.key, required this.state});

  final GenetCreationInProgress state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GenetCreationBloc>();
    final formState = state.formState;
    final provenanceType = formState.provenanceType.value;
    final lifeStage = formState.lifeStage.value;
    final transferPartnerName = formState.provInstitution.value.trim();

    final Widget body = switch (_resolveTypeFromProvenance(provenanceType, lifeStage)) {
      _GenetCategory.founder => FounderDetailsSection(state: state),
      _GenetCategory.cohort => const CohortDetailsSection(),
      _GenetCategory.sexualRecruit => const SexualRecruitSection(),
      _GenetCategory.gamete => const GameteDetailsSection(),
      _GenetCategory.unknown => const Text(
        'Select a provenance type to enter specific details.',
      ),
    };

    return DialogScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          UI.spacingVerticalMd,
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Additional information about this genet...',
              prefixIcon: const Icon(Icons.note),
              border: const OutlineInputBorder(),
              suffixIcon: const InfoTooltipIcon(
                message: 'Optional free-form notes about this genet.',
              ),
              errorText: formState.notes.displayError?.message,
            ),
            initialValue: formState.notes.value,
            maxLines: 3,
            onChanged: bloc.onNotesChanged,
          ),
          UI.spacingVerticalMd,
          const Divider(),
          UI.spacingVerticalSm,
          UIText.h6('Testing'),
          UI.spacingVerticalSm,
          CheckboxListTile(
            value: formState.heatTested,
            onChanged: (v) => bloc.onHeatTestedToggled(v ?? false),
            title: const Text('Heat Tested'),
            subtitle: const Text('This genet has been tested for heat tolerance'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (formState.heatTested) ...[
            UI.spacingVerticalSm,
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Heat Testing Comment (optional)',
                hintText: 'Specify how the genet was tested...',
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
              initialValue: formState.heatTestingComment,
              maxLines: 2,
              onChanged: bloc.onHeatTestingCommentChanged,
            ),
          ],
          CheckboxListTile(
            value: formState.diseaseTested,
            onChanged: (v) => bloc.onDiseaseTestedToggled(v ?? false),
            title: const Text('Disease Tested'),
            subtitle: const Text('This genet has been tested for disease resistance'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (formState.diseaseTested) ...[
            UI.spacingVerticalSm,
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Disease Testing Comment (optional)',
                hintText: 'Specify how the genet was tested...',
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
              initialValue: formState.diseaseTestingComment,
              maxLines: 2,
              onChanged: bloc.onDiseaseTestingCommentChanged,
            ),
          ],
          UI.spacingVerticalMd,
          const Divider(),
          UI.spacingVerticalSm,
          CheckboxListTile(
            value: formState.sendTransfer,
            onChanged: (v) => bloc.onSendTransferToggled(v ?? false),
            title: Text(
              formState.transferOrgId.isNotEmpty
                  ? formState.transferOrgId == 'unknown'
                        ? 'Record as received from unknown organization'
                        : transferPartnerName.isNotEmpty
                            ? 'Record as received from $transferPartnerName'
                            : 'Record as received from another organization'
                  : 'Record as received from another organization',
            ),
            subtitle: const Text(
              'Check this if genet was received from another organization',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (formState.sendTransfer) ...[
            UI.spacingVerticalSm,
            const TransferDetailsSection(),
          ],
        ],
      ),
    );
  }

  _GenetCategory _resolveTypeFromProvenance(ProvenanceType? provenanceType, LifeStage? lifeStage) {
    if (provenanceType == null) {
      return _GenetCategory.unknown;
    }

    // Check for gamete life stage first
    if (lifeStage == LifeStage.gamete) {
      return _GenetCategory.gamete;
    }

    switch (provenanceType) {
      case ProvenanceType.wild:
        return _GenetCategory.founder;
      case ProvenanceType.sexualCohort:
        return _GenetCategory.cohort;
      case ProvenanceType.graduatedIndividual:
        return _GenetCategory.sexualRecruit;
      case ProvenanceType.transfer:
        return _GenetCategory.founder; // Transfers display as founders
      case ProvenanceType.unknown:
        return _GenetCategory.unknown;
    }
  }
}

enum _GenetCategory { founder, cohort, sexualRecruit, gamete, unknown }