// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_bloc.dart';
import 'package:seafoundry_app/blocs/genet_creation/genet_creation_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_creation/genet_creation_wizard.dart';

class CreateGenetDialog extends StatelessWidget {
  const CreateGenetDialog({super.key});

  static Future<Genet?> show(
    BuildContext context, {
    ProvenanceType? initialProvenanceType,
    List<ProvenanceType>? allowedProvenanceTypes,
    Species? initialSpecies,
    Genet? existingGenet,
  }) {
    final genetRepository = context.read<GenetRepository>();
    final organizationRepository = context.read<OrganizationRepository>();
    final invitationRepository = context.read<InvitationRepository>();
    final provenanceLookupService = context.maybeRead<ProvenanceLookupService>();

    return showDialog<Genet>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Provide all repositories needed by child widgets (e.g., TransferTargetPicker,
        // _GameteSelector) that use context.read<Repository>()
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<GenetRepository>.value(value: genetRepository),
            RepositoryProvider<OrganizationRepository>.value(value: organizationRepository),
          ],
          child: BlocProvider(
            create: (_) {
              final bloc = GenetCreationBloc(
                genetRepository: genetRepository,
                organizationRepository: organizationRepository,
                invitationRepository: invitationRepository,
                provenanceLookupService: provenanceLookupService,
              );

              // Initialize with existing genet data if editing
              if (existingGenet != null) {
                final existingProvenanceType = ProvenanceTypeX.tryParse(
                  existingGenet.provenanceTypeId,
                );
                final existingSpecies = Species.lookupById(existingGenet.speciesId);
                bloc.initialize(
                  initialProvenanceType: initialProvenanceType ?? existingProvenanceType,
                  allowedProvenanceTypes: allowedProvenanceTypes,
                  initialSpecies: initialSpecies ?? existingSpecies,
                );
                bloc.initializeForEdit(existingGenet);
              } else {
                bloc.initialize(
                  initialProvenanceType: initialProvenanceType,
                  allowedProvenanceTypes: allowedProvenanceTypes,
                  initialSpecies: initialSpecies,
                );
              }

              return bloc;
            },
            child: const CreateGenetDialog(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GenetCreationBloc, GenetCreationState>(
      listener: (context, state) {
        if (state is GenetCreationSuccess) {
          if (context.mounted) popSafeDialogContext(context, state.genet);
        } else if (state is GenetUpdateSuccess) {
          if (context.mounted) popSafeDialogContext(context, state.genet);
        }
      },
      builder: (context, state) {
        return GenetCreationWizard(state: state);
      },
    );
  }
}
