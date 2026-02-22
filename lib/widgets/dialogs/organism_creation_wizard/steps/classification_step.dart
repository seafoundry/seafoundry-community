// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart' as types;
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/common/visual_selector.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/forms/species_selector.dart';
import 'organism_creation_step_scroll_view.dart';

/// Step 1: Classification - Organism Kind + Species selection
class ClassificationStep extends StatefulWidget {
  const ClassificationStep({
    super.key,
    required this.state,
  });

  final OrganismCreationState state;

  @override
  State<ClassificationStep> createState() => _ClassificationStepState();
}

class _ClassificationStepState extends State<ClassificationStep> {
  String? _pendingSpeciesId;

  Future<void> _onSpeciesChanged(BuildContext context, Species? species) async {
    final cubit = context.read<OrganismCreationCubit>();
    cubit.speciesChanged(species);

    if (species == null) {
      _pendingSpeciesId = null;
      cubit.suggestedLocalIdChanged(null);
      return;
    }

    final firestore = context.maybeRead<FirebaseService>()?.firestore;
    if (firestore == null) return;

    _pendingSpeciesId = species.id;

    final currentUserState = context.read<CurrentUser>().state;
    if (currentUserState is! CurrentUserLoaded) return;

    try {
      final validationService = UniqueNameValidationService(firestore: firestore);
      final suggestedName = await validationService.suggestNextOrganismLocalId(
        speciesId: species.id,
        organizationId: currentUserState.organization.id,
      );
      if (mounted && _pendingSpeciesId == species.id) {
        cubit.suggestedLocalIdChanged(suggestedName);
      }
    } catch (e) {
      LoggingService.instance.debug('Failed to suggest local ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserState = context.read<CurrentUser>().state;
    List<types.OrganismKind> supportedKinds = types.OrganismKind.values;
    if (currentUserState is CurrentUserLoaded) {
      supportedKinds = currentUserState.organization.supportedOrganismKinds;
    }

    // Identify if the organism selection is essentially locked/single-choice
    final isLockedKind = supportedKinds.length <= 1;

    return OrganismCreationStepScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Only show the organism selector if there is a choice to be made
          if (!isLockedKind) ...[
            Text(
              'Organism Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OrganismKindSelector(
              selected: widget.state.organismKind,
              onChanged: context.read<OrganismCreationCubit>().organismKindChanged,
              availableKinds: supportedKinds,
            ),
            const SizedBox(height: 24),
          ],
          
          Text(
            'Species',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SpeciesSelector(
            value: widget.state.species,
            onChanged: (species) => _onSpeciesChanged(context, species),
            labelText: 'Species',
            hintText: 'Select a species',
            organismKind: widget.state.organismKind,
            // Pass filter to ensure only species for the active kind are shown
            // (Standard behavior, but explicit context helps)
          ),
        ],
      ),
    );
  }
}
