// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/geometry_form_inputs.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/events/spawn/gamete_collection_entry.dart';
import 'package:seafoundry_app/blocs/events/spawn/spawn_form_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/theme/app_colors.dart';
import 'package:seafoundry_app/utils/permit_metadata_policy.dart';
import 'package:seafoundry_app/widgets/common/inherited_species_display.dart';
import 'package:seafoundry_app/widgets/common/locked_text_field.dart';
import 'package:seafoundry_app/widgets/common/physical_form_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/base_event_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/components/geometry_capture_section.dart';
import 'package:seafoundry_app/widgets/dialogs/components/permit_selector_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/location_selection_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/spawn/components/spawn_parent_organism_chip.dart';
import 'package:seafoundry_app/widgets/forms/base_create_dialog.dart';

import '../../repositories/inventory/organism_record_repository.dart';
import '../spreadsheet/safe_provider_mixin.dart';

/// Dialog for creating spawn events using the established patterns
class SpawnEventDialog
    extends BaseEventDialog<SpawnEvent, SpawnFormBloc, SpawnFormState> {
  const SpawnEventDialog({
    super.key,
    this.allowedParentOrganismIds,
    this.initialParentOrganismIds,
  });

  final Set<String>? allowedParentOrganismIds;
  final List<String>? initialParentOrganismIds;

  @override
  ModelType get modelType => ModelType.event;

  @override
  CreateDialogConfig get config => const CreateDialogConfig(
    title: 'Record Spawning',
    icon: Icons.bubble_chart,
    iconColor: Colors.pink,
    width: 600,
  );

  @override
  bool get showTaskOption => false;

  @override
  List<Widget> buildEventContent(BuildContext context, SpawnFormState state) {
    return [
      // Parent Coral Selection (placeholder)
      _buildParentCoralSelector(context, state),
      const SizedBox(height: 16),
      _buildGameteRoleSelector(context, state),
      const SizedBox(height: 16),

      // Notes
      TextFormField(
        decoration: InputDecoration(
          labelText: state.notes.label,
          hintText: state.notes.hintText,
          errorText: state.notes.displayError?.message,
          alignLabelWithHint: true,
        ),
        maxLines: 3,
        onChanged: (value) {
          context.read<SpawnFormBloc>().add(SpawnNotesChanged(value));
        },
      ),
      const SizedBox(height: 24),
      _buildGameteInventorySection(context, state),
      const SizedBox(height: 24),
      _buildCohortCreationSection(context, state),
      const SizedBox(height: 24),
      _SpawnGeometrySection(state: state),
      const SizedBox(height: 24),
      _PermitMetadataSection(state: state),
    ];
  }

  @override
  List<Widget> buildActions(BuildContext context, SpawnFormState state) {
    final bloc = context.read<SpawnFormBloc>();
    return [
      TextButton(
        onPressed: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? null
            : () => popSafeDialogContext(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? null
            : () {
                // Read current state at click time to avoid stale closure
                final currentState = bloc.state;
                if (!currentState.isValid) {
                  final message =
                      _buildValidationMessage(currentState) ??
                      'Please complete required fields before submitting.';
                  showSafeDialogSnackBar(context, message, isError: true);
                  return;
                }
                bloc.add(const RecordFormSubmit());
              },
        child: state.submissionStatus == FormzSubmissionStatus.inProgress
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(state.isEditing ? 'Update Event' : 'Create Event'),
      ),
    ];
  }

  Widget _buildGameteRoleSelector(BuildContext context, SpawnFormState state) {
    return DropdownButtonFormField<ProvenanceGameteRole>(
      decoration: InputDecoration(
        labelText: state.gameteRole.label,
        hintText: state.gameteRole.hintText,
        errorText: state.gameteRole.displayError?.message,
        prefixIcon: const Icon(Icons.science_outlined),
      ),
      initialValue: state.gameteRole.value,
      items: const [
        DropdownMenuItem(value: ProvenanceGameteRole.egg, child: Text('Eggs')),
        DropdownMenuItem(
          value: ProvenanceGameteRole.sperm,
          child: Text('Sperm'),
        ),
      ],
      onChanged: (value) {
        context.read<SpawnFormBloc>().add(GameteRoleChanged(value));
      },
    );
  }

  Widget _buildParentCoralSelector(BuildContext context, SpawnFormState state) {
    final selectedCount = state.parentOrganisms.value?.length ?? 0;

    // Get organism kind from target node for organism-aware labeling
    final bloc = context.read<SpawnFormBloc>();
    final organismKind = bloc.organismKind;
    final organismLabel = organismKind?.metadata.displayName ?? 'organism';
    final pluralLabel = '${organismLabel}s';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: state.parentOrganisms.label,
            hintText: state.parentOrganisms.hintText,
            errorText: state.parentOrganisms.displayError?.message,
            contentPadding: EdgeInsets.zero,
          ),
          child: InkWell(
            onTap: () => _showOrganismSelectionDialog(context, state),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.disabled.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedCount > 0
                        ? Icons.check_circle
                        : Icons.add_circle_outline,
                    color: selectedCount > 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Tap to select parent $pluralLabel'
                          : '$selectedCount $organismLabel${selectedCount > 1 ? 's' : ''} selected',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (state.parentOrganisms.value ?? []).map((organismId) {
              return SpawnParentOrganismChip(
                organismId: organismId,
                onDeleted: () {
                  final newList = [
                    ...(state.parentOrganisms.value ?? []),
                  ].cast<String>();
                  newList.remove(organismId);
                  context.read<SpawnFormBloc>().add(
                    ParentOrganismsChanged(newList),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGameteInventorySection(
    BuildContext context,
    SpawnFormState state,
  ) {
    final theme = Theme.of(context);
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    // Check if user is using the new multi-gamete workflow
    final hasMultiGameteCollections =
        state.damGameteCollection != null || state.sireGameteCollection != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gamete Inventory', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Create gamete inventory records from the spawning organisms. '
          'Enable dam (eggs) and/or sire (sperm) collections below.',
          style: helperStyle,
        ),
        const SizedBox(height: 16),
        _InheritedSpeciesField(state: state),
        const SizedBox(height: 16),
        // Dam gamete collection (eggs)
        _GameteCollectionSection(
          title: 'Dam Collection (Eggs)',
          icon: Icons.circle_outlined,
          iconColor: Colors.pink,
          gameteRole: ProvenanceGameteRole.egg,
          collection: state.damGameteCollection,
          parentOrganismKind: state.parentOrganismKind,
          onCollectionChanged: (entry) {
            context.read<SpawnFormBloc>().add(
              DamGameteCollectionChanged(entry),
            );
          },
          onShowDestinationDialog: () => _showGameteCollectionDestinationDialog(
            context,
            state,
            ProvenanceGameteRole.egg,
          ),
        ),
        const SizedBox(height: 16),
        // Sire gamete collection (sperm)
        _GameteCollectionSection(
          title: 'Sire Collection (Sperm)',
          icon: Icons.lens_blur,
          iconColor: Colors.blue,
          gameteRole: ProvenanceGameteRole.sperm,
          collection: state.sireGameteCollection,
          parentOrganismKind: state.parentOrganismKind,
          onCollectionChanged: (entry) {
            context.read<SpawnFormBloc>().add(
              SireGameteCollectionChanged(entry),
            );
          },
          onShowDestinationDialog: () => _showGameteCollectionDestinationDialog(
            context,
            state,
            ProvenanceGameteRole.sperm,
          ),
        ),
        // Legacy single-gamete section (only shown if multi-gamete not enabled)
        if (!hasMultiGameteCollections) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Or use legacy single-gamete collection:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildGameteLocalIdField(state),
          const SizedBox(height: 16),
          _buildGameteRecordNameField(state),
          const SizedBox(height: 16),
          _buildGametePhysicalFormSection(context, state),
          const SizedBox(height: 16),
          _buildGameteCountField(context, state),
          const SizedBox(height: 16),
          _buildGameteDestinationSelector(context, state),
        ],
      ],
    );
  }

  Future<void> _showGameteCollectionDestinationDialog(
    BuildContext context,
    SpawnFormState state,
    ProvenanceGameteRole role,
  ) async {
    final bloc = context.read<SpawnFormBloc>();
    final targetNode = bloc.targetNode;
    if (targetNode == null) return;

    SiteNode? siteNode;
    if (targetNode is SiteNode) {
      siteNode = targetNode;
    } else {
      final candidate = targetNode.siteNode;
      if (candidate is SiteNode) {
        siteNode = candidate;
      }
    }

    if (siteNode == null && targetNode is OrganizationNode) {
      siteNode = await _selectSiteFromOrganization(context, targetNode);
    }

    if (siteNode == null) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Please select a site before choosing a destination.',
        isError: true,
      );
      return;
    }

    try {
      await siteNode.awaitLoaded().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Loading structures timed out. Please try again.',
        isError: true,
      );
      return;
    } catch (error) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Unable to load structures. Please try again.',
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;
    final roleLabel = role == ProvenanceGameteRole.egg ? 'eggs' : 'sperm';
    final selectedGroup = await LocationSelectionDialog.show(
      context,
      siteNode: siteNode,
      initialSelection: null,
      organismLabel: roleLabel,
    );

    if (!context.mounted) return;
    if (selectedGroup != null) {
      final entry = role == ProvenanceGameteRole.egg
          ? (state.damGameteCollection ?? createDamGameteEntry())
          : (state.sireGameteCollection ?? createSireGameteEntry());
      final updatedEntry = entry.copyWith(destinationGroup: selectedGroup);
      if (role == ProvenanceGameteRole.egg) {
        bloc.add(DamGameteCollectionChanged(updatedEntry));
      } else {
        bloc.add(SireGameteCollectionChanged(updatedEntry));
      }
    }
  }

  Widget _buildGameteLocalIdField(SpawnFormState state) {
    final localId = state.gameteLocalId.value?.trim();

    return LockedTextField(
      value: localId,
      labelText: state.gameteLocalId.label,
      tooltipMessage: 'Inherited from parent',
      prefixIcon: Icons.fingerprint,
      helperText: localId == null || localId.isEmpty
          ? 'Local ID will be inherited from the selected parent'
          : null,
    );
  }

  Widget _buildGameteRecordNameField(SpawnFormState state) {
    return _GameteRecordNameField(state: state);
  }

  Widget _buildGameteCountField(BuildContext context, SpawnFormState state) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: state.gameteCount.label,
        hintText: state.gameteCount.hintText,
        errorText: state.gameteCount.displayError?.message,
        suffixText: 'containers',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final count = value.isEmpty ? null : int.tryParse(value);
        context.read<SpawnFormBloc>().add(GameteCountChanged(count));
      },
    );
  }

  Widget _buildGametePhysicalFormSection(
    BuildContext context,
    SpawnFormState state,
  ) {
    final bloc = context.read<SpawnFormBloc>();
    final theme = Theme.of(context);
    final organismKind = state.parentOrganismKind ?? bloc.organismKind;

    if (organismKind == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Select a parent organism to load physical forms.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final errors = <String>[];
    final physicalFormError = state.gametePhysicalForm.displayError?.message;
    if (physicalFormError != null) {
      errors.add(physicalFormError);
    }
    final sizeSpecError = state.gameteSizeSpec.displayError?.message;
    if (sizeSpecError != null) {
      errors.add(sizeSpecError);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Physical Form & Size', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        PhysicalFormSelectorWidget(
          organismKind: organismKind,
          lifeStage: LifeStage.gamete,
          initialPhysicalFormId: state.gametePhysicalForm.value,
          initialSizeSpec: state.gameteSizeSpec.value ?? const SizeSpec(),
          onChanged: (selection) {
            bloc.add(GametePhysicalFormChanged(selection.physicalFormId));
            bloc.add(GameteSizeSpecChanged(selection.sizeSpec));
          },
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errors.join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  String? _buildValidationMessage(SpawnFormState state) {
    final errors = <String>[];
    for (final input in state.inputs) {
      final error = input.validator(input.value);
      if (error == null) continue;
      final message = error.message;
      errors.add('${input.label}: $message');
    }
    if (errors.isEmpty) return null;
    return errors.join('\n');
  }

  Widget _buildCohortCreationSection(
    BuildContext context,
    SpawnFormState state,
  ) {
    final theme = Theme.of(context);
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final bloc = context.read<SpawnFormBloc>();
    final organismKind = state.parentOrganismKind ?? bloc.organismKind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cohort Creation', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Create a larval cohort from the fertilized gametes. '
          'Species is inherited from the contributing gametes.',
          style: helperStyle,
        ),
        const SizedBox(height: 16),
        _CohortLocalIdField(state: state),
        const SizedBox(height: 16),
        _CohortRecordNameField(state: state),
        const SizedBox(height: 16),
        _buildCohortPhysicalFormSection(context, state, organismKind),
        const SizedBox(height: 16),
        _buildCohortDestinationSelector(context, state),
      ],
    );
  }

  Widget _buildCohortPhysicalFormSection(
    BuildContext context,
    SpawnFormState state,
    OrganismKind? organismKind,
  ) {
    final bloc = context.read<SpawnFormBloc>();
    final theme = Theme.of(context);

    if (organismKind == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Select parent organisms to load physical forms.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final errors = <String>[];
    final physicalFormError = state.cohortPhysicalForm.displayError?.message;
    if (physicalFormError != null) {
      errors.add(physicalFormError);
    }
    final sizeSpecError = state.cohortSizeSpec.displayError?.message;
    if (sizeSpecError != null) {
      errors.add(sizeSpecError);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Physical Form & Size', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        PhysicalFormSelectorWidget(
          organismKind: organismKind,
          lifeStage: LifeStage.larva,
          initialPhysicalFormId: state.cohortPhysicalForm.value,
          initialSizeSpec: state.cohortSizeSpec.value ?? const SizeSpec(),
          onChanged: (selection) {
            bloc.add(CohortPhysicalFormChanged(selection.physicalFormId));
            bloc.add(CohortSizeSpecChanged(selection.sizeSpec));
          },
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            errors.join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCohortDestinationSelector(
    BuildContext context,
    SpawnFormState state,
  ) {
    final selectedGroup = state.cohortDestination.value;
    final displayText =
        selectedGroup?.name ?? 'Tap to select cohort destination';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: state.cohortDestination.label,
        hintText: state.cohortDestination.hintText,
        errorText: state.cohortDestination.displayError?.message,
        contentPadding: EdgeInsets.zero,
      ),
      child: InkWell(
        onTap: () => _showCohortDestinationDialog(context, state),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.disabled.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.child_care,
                color: selectedGroup == null
                    ? AppColors.textSecondary
                    : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCohortDestinationDialog(
    BuildContext context,
    SpawnFormState state,
  ) async {
    final bloc = context.read<SpawnFormBloc>();
    final targetNode = bloc.targetNode;
    if (targetNode == null) return;

    SiteNode? siteNode;
    if (targetNode is SiteNode) {
      siteNode = targetNode;
    } else {
      final candidate = targetNode.siteNode;
      if (candidate is SiteNode) {
        siteNode = candidate;
      }
    }

    if (siteNode == null && targetNode is OrganizationNode) {
      siteNode = await _selectSiteFromOrganization(context, targetNode);
    }

    if (siteNode == null) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Please select a site before choosing a destination.',
        isError: true,
      );
      return;
    }

    try {
      await siteNode.awaitLoaded().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Loading structures timed out. Please try again.',
        isError: true,
      );
      return;
    } catch (error) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Unable to load structures. Please try again.',
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;
    GroupNode? initialSelection = state.cohortDestination.value;
    // Default to gamete destination if cohort destination not set
    initialSelection ??= state.gameteDestination.value;
    if (initialSelection == null) {
      if (targetNode is GroupNode) {
        initialSelection = targetNode;
      } else if (targetNode is OrganismNode) {
        final parent = targetNode.parent;
        if (parent is GroupNode) {
          initialSelection = parent;
        }
      }
    }
    final selectedGroup = await LocationSelectionDialog.show(
      context,
      siteNode: siteNode,
      initialSelection: initialSelection,
      organismLabel: 'cohort',
    );

    if (!context.mounted) return;
    if (selectedGroup != null) {
      context.read<SpawnFormBloc>().add(
        CohortDestinationChanged(selectedGroup),
      );
    }
  }

  Widget _buildGameteDestinationSelector(
    BuildContext context,
    SpawnFormState state,
  ) {
    final selectedGroup = state.gameteDestination.value;
    final displayText = selectedGroup?.name ?? 'Tap to select destination';

    return InputDecorator(
      decoration: InputDecoration(
        labelText: state.gameteDestination.label,
        hintText: state.gameteDestination.hintText,
        errorText: state.gameteDestination.displayError?.message,
        contentPadding: EdgeInsets.zero,
      ),
      child: InkWell(
        onTap: () => _showGameteDestinationDialog(context, state),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.disabled.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: selectedGroup == null
                    ? AppColors.textSecondary
                    : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrganismSelectionDialog(
    BuildContext context,
    SpawnFormState state,
  ) async {
    final bloc = context.read<SpawnFormBloc>();
    final targetNode = bloc.targetNode;
    if (targetNode == null) return;

    // Get available organisms from the parent node
    try {
      await targetNode.awaitLoaded().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      LoggingService.instance.warning(
        'SpawnEventDialog: Loading target node timed out',
        {'nodeId': targetNode.id},
      );
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Loading organisms timed out. Please try again.',
        isError: true,
      );
      return;
    } catch (error) {
      LoggingService.instance.warning(
        'SpawnEventDialog: Failed to load target node',
        {'error': error.toString()},
      );
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Unable to load organisms. Please try again.',
        isError: true,
      );
      return;
    }
    if (!context.mounted) return;
    final nodeState = targetNode.state;
    if (nodeState is! GraphLoadedState) return;

    // Get organisms based on node type.
    final availableOrganisms = <OrganismRecord>[];
    if (targetNode is OrganismNode) {
      final organism = await _loadOrganismSafely(targetNode);
      if (!context.mounted) return;
      if (organism != null) {
        availableOrganisms.add(organism);
      }
    } else if (targetNode is GroupNode) {
      // Get all organisms in this group - load in parallel
      final children = nodeState.children;
      final organismNodes = children.whereType<OrganismNode>().toList();
      final results = await Future.wait(
        organismNodes.map((node) => _loadOrganismSafely(node)),
        eagerError: false,
      );
      if (!context.mounted) return;
      availableOrganisms.addAll(results.whereType<OrganismRecord>());
    } else if (targetNode is SiteNode) {
      // Get all organisms in all groups in this site
      // Phase 1: Load all groups in parallel
      final children = nodeState.children;
      final groupNodes = children.whereType<GroupNode>().toList();
      await Future.wait(
        groupNodes.map((node) => _loadGroupSafely(node)),
        eagerError: false,
      );
      if (!context.mounted) return;

      // Phase 2: Collect all organism nodes from loaded groups and load in parallel
      final organismNodes = <OrganismNode>[];
      for (final groupNode in groupNodes) {
        final groupState = groupNode.state;
        if (groupState is GraphLoadedState<Group>) {
          organismNodes.addAll(groupState.children.whereType<OrganismNode>());
        }
      }

      final results = await Future.wait(
        organismNodes.map((node) => _loadOrganismSafely(node)),
        eagerError: false,
      );
      if (!context.mounted) return;
      availableOrganisms.addAll(results.whereType<OrganismRecord>());
    }

    var filteredOrganisms = availableOrganisms;
    if (allowedParentOrganismIds != null) {
      filteredOrganisms = availableOrganisms
          .where((organism) => allowedParentOrganismIds!.contains(organism.id))
          .toList();
    }

    if (filteredOrganisms.isEmpty) {
      if (!context.mounted) return;
      final organismKind = bloc.organismKind;
      final pluralLabel = organismKind != null
          ? '${organismKind.metadata.displayName}s'
          : 'organisms';
      showSafeDialogSnackBar(
        context,
        'No $pluralLabel available for selection',
        isError: true,
      );
      return;
    }

    // Show selection dialog
    if (!context.mounted) return;
    final selectedOrganisms = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (dialogContext) => _OrganismSelectionDialog(
        availableOrganisms: filteredOrganisms,
        selectedOrganismIds: state.parentOrganisms.value ?? [],
      ),
    );

    if (!context.mounted) return;
    if (selectedOrganisms != null) {
      context.read<SpawnFormBloc>().add(
        ParentOrganismsChanged(selectedOrganisms),
      );
    }
  }

  Future<void> _showGameteDestinationDialog(
    BuildContext context,
    SpawnFormState state,
  ) async {
    final bloc = context.read<SpawnFormBloc>();
    final targetNode = bloc.targetNode;
    if (targetNode == null) return;

    SiteNode? siteNode;
    if (targetNode is SiteNode) {
      siteNode = targetNode;
    } else {
      final candidate = targetNode.siteNode;
      if (candidate is SiteNode) {
        siteNode = candidate;
      }
    }

    if (siteNode == null && targetNode is OrganizationNode) {
      siteNode = await _selectSiteFromOrganization(context, targetNode);
    }

    if (siteNode == null) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Please select a site before choosing a destination.',
        isError: true,
      );
      return;
    }

    try {
      await siteNode.awaitLoaded().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Loading structures timed out. Please try again.',
        isError: true,
      );
      return;
    } catch (error) {
      if (!context.mounted) return;
      showSafeDialogSnackBar(
        context,
        'Unable to load structures. Please try again.',
        isError: true,
      );
      return;
    }

    if (!context.mounted) return;
    GroupNode? initialSelection = state.gameteDestination.value;
    if (initialSelection == null) {
      if (targetNode is GroupNode) {
        initialSelection = targetNode;
      } else if (targetNode is OrganismNode) {
        final parent = targetNode.parent;
        if (parent is GroupNode) {
          initialSelection = parent;
        }
      }
    }
    final selectedGroup = await LocationSelectionDialog.show(
      context,
      siteNode: siteNode,
      initialSelection: initialSelection,
      organismLabel: 'gametes',
    );

    if (!context.mounted) return;
    if (selectedGroup != null) {
      context.read<SpawnFormBloc>().add(
        GameteDestinationChanged(selectedGroup),
      );
    }
  }

  /// Show the spawn dialog
  static Future<SpawnEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    Set<String>? allowedParentOrganismIds,
    List<String>? initialParentOrganismIds,
  }) {
    if (!context.mounted) return Future.value(null);
    // Read dependencies BEFORE showDialog to ensure provider scope
    final eventRepository = context.safeRead<EventRepository>();
    if (eventRepository == null) {
      showSafeDialogSnackBar(
        context,
        'Spawning tools are still loading. Please try again.',
        isError: true,
      );
      return Future.value(null);
    }
    final propagationService = context.maybeRead<EventPropagationService>();
    final organismRepository = context.maybeRead<OrganismRecordRepository>();
    if (organismRepository == null) {
      showSafeDialogSnackBar(
        context,
        'Organism tools are still loading. Please try again.',
        isError: true,
      );
      return Future.value(null);
    }
    // Get or create UniqueNameValidationService for record name suggestions
    final validationService =
        context.maybeRead<UniqueNameValidationService>() ??
        UniqueNameValidationService(firestore: organismRepository.db);

    final resolvedInitialParentOrganismIds =
        initialParentOrganismIds ??
        (targetNode is OrganismNode ? [targetNode.id] : null);

    return showDialog<SpawnEvent>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false, // Stay in provider scope
      builder: (dialogContext) {
        Widget content = BlocProvider(
          create: (_) {
            final bloc = SpawnFormBloc(
              eventRepository: eventRepository,
              propagationService: propagationService,
              organismRepository: organismRepository,
              validationService: validationService,
            )..add(EventFormTargetChanged(targetNode));
            final filteredInitial = resolvedInitialParentOrganismIds
                ?.where((id) => allowedParentOrganismIds?.contains(id) ?? true)
                .toList(growable: false);
            if (filteredInitial != null && filteredInitial.isNotEmpty) {
              bloc.add(ParentOrganismsChanged(filteredInitial));
            }
            return bloc;
          },
          child: SpawnEventDialog(
            allowedParentOrganismIds: allowedParentOrganismIds,
            initialParentOrganismIds: resolvedInitialParentOrganismIds,
          ),
        );

        content = RepositoryProvider<OrganismRecordRepository>.value(
          value: organismRepository,
          child: content,
        );

        return content;
      },
    );
  }
}

class _GameteRecordNameField extends StatefulWidget {
  const _GameteRecordNameField({required this.state});

  final SpawnFormState state;

  @override
  State<_GameteRecordNameField> createState() => _GameteRecordNameFieldState();
}

class _GameteRecordNameFieldState extends State<_GameteRecordNameField> {
  late final TextEditingController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.gameteRecordName.value ?? '',
    )..addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _GameteRecordNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.state.gameteRecordName.value ?? '';
    if (desired != _controller.text) {
      _syncController(desired);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (_isSyncing) return;
    context.read<SpawnFormBloc>().add(
      GameteRecordNameChanged(_controller.text),
    );
  }

  void _syncController(String next) {
    _isSyncing = true;
    _controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _isSyncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: state.gameteRecordName.label,
        hintText: state.gameteRecordName.hintText,
        errorText: state.gameteRecordName.displayError?.message,
        prefixIcon: const Icon(Icons.label),
      ),
    );
  }
}

class _CohortLocalIdField extends StatefulWidget {
  const _CohortLocalIdField({required this.state});

  final SpawnFormState state;

  @override
  State<_CohortLocalIdField> createState() => _CohortLocalIdFieldState();
}

class _CohortLocalIdFieldState extends State<_CohortLocalIdField> {
  late final TextEditingController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.cohortLocalId.value ?? '',
    )..addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _CohortLocalIdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.state.cohortLocalId.value ?? '';
    if (desired != _controller.text) {
      _syncController(desired);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (_isSyncing) return;
    context.read<SpawnFormBloc>().add(CohortLocalIdChanged(_controller.text));
  }

  void _syncController(String next) {
    _isSyncing = true;
    _controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _isSyncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: state.cohortLocalId.label,
        hintText: state.cohortLocalId.hintText,
        errorText: state.cohortLocalId.displayError?.message,
        prefixIcon: const Icon(Icons.fingerprint),
        helperText: 'Unique identifier for the new cohort',
      ),
    );
  }
}

class _CohortRecordNameField extends StatefulWidget {
  const _CohortRecordNameField({required this.state});

  final SpawnFormState state;

  @override
  State<_CohortRecordNameField> createState() => _CohortRecordNameFieldState();
}

class _CohortRecordNameFieldState extends State<_CohortRecordNameField> {
  late final TextEditingController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.cohortRecordName.value ?? '',
    )..addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _CohortRecordNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.state.cohortRecordName.value ?? '';
    if (desired != _controller.text) {
      _syncController(desired);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (_isSyncing) return;
    context.read<SpawnFormBloc>().add(
      CohortRecordNameChanged(_controller.text),
    );
  }

  void _syncController(String next) {
    _isSyncing = true;
    _controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _isSyncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: state.cohortRecordName.label,
        hintText: state.cohortRecordName.hintText,
        errorText: state.cohortRecordName.displayError?.message,
        prefixIcon: const Icon(Icons.label),
        helperText: 'Display name for the cohort',
      ),
    );
  }
}

class _SpawnGeometrySection extends StatefulWidget {
  const _SpawnGeometrySection({required this.state});

  final SpawnFormState state;

  @override
  State<_SpawnGeometrySection> createState() => _SpawnGeometrySectionState();
}

class _SpawnGeometrySectionState extends State<_SpawnGeometrySection> {
  late final TextEditingController _controller;
  bool _isSyncingController = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.state.geometryText.value ?? '',
    )..addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _SpawnGeometrySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final desired = widget.state.geometryText.value ?? '';
    if (desired != _controller.text) {
      _syncController(desired);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (_isSyncingController) return;
    context.read<SpawnFormBloc>().add(GeometryTextChanged(_controller.text));
  }

  void _syncController(String next) {
    _isSyncingController = true;
    _controller
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    _isSyncingController = false;
  }

  void _clearGeometry() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return GeometryCaptureSection(
      controller: _controller,
      enabled: state.submissionStatus != FormzSubmissionStatus.inProgress,
      errorText: state.geometryValidationMessage,
      helperText:
          'Optional decimal degree coordinates (lat,lng per line) to '
          'describe where spawning occurred.',
      site: state.site,
      geometryInput: state.geometryInput,
      onClear: _clearGeometry,
      title: 'Spawning geometry (optional)',
    );
  }
}

class _PermitMetadataSection extends StatelessWidget {
  const _PermitMetadataSection({required this.state});

  final SpawnFormState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SpawnFormBloc>();
    final supportsPermits = PermitMetadataPolicy.siteSupportsPermits(
      state.site,
    );
    final siteName = state.site?.name ?? 'this site';
    final isSubmitting =
        state.submissionStatus == FormzSubmissionStatus.inProgress;
    final permitId = state.permitId.value ?? '';
    final permitType = state.permitType.value ?? '';
    final issuingAuthority = state.issuingAuthority.value ?? '';

    // Capture user context for permit creation
    final currentUserState = context.maybeRead<CurrentUser>()?.state;
    final userId = currentUserState is CurrentUserLoaded
        ? currentUserState.user.id
        : null;
    final isPro =
        currentUserState is CurrentUserLoaded &&
        (currentUserState.organization.tier == Tier.pro ||
            currentUserState.organization.tier == Tier.scale);

    final organization =
        context.maybeRead<Organization>() ??
        (currentUserState is CurrentUserLoaded
            ? currentUserState.organization
            : null);
    final organizationId = organization?.id;

    if (!supportsPermits) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permit metadata is disabled for $siteName. '
                  'Enable permit uploads under Site Capabilities to capture compliance data.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (organizationId == null || organizationId.isEmpty) {
      LoggingService.instance.warning(
        'SpawnEventDialog: Organization not available for permit selection',
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permit metadata is temporarily unavailable for $siteName. '
                  'Please refresh the page and try again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permit (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        PermitSelectorWidget(
          organizationId: organizationId,
          userId: userId,
          isPro: isPro,
          selectedPermitId: permitId.isNotEmpty ? permitId : null,
          enabled: !isSubmitting,
          displayOptions: PermitSelectorDisplayOptions.compact,
          onPermitSelected: (permit) {
            if (permit == null) {
              bloc.add(const PermitIdChanged(null));
              bloc.add(const PermitTypeChanged(null));
              bloc.add(const IssuingAuthorityChanged(null));
              bloc.add(const PermitAttachmentUrlsChanged(null));
              bloc.add(const PermitValidFromChanged(null));
              bloc.add(const PermitValidToChanged(null));
            } else {
              bloc.add(PermitIdChanged(permit.permitNumber));
              bloc.add(PermitTypeChanged(permit.type.displayName));
              bloc.add(IssuingAuthorityChanged(permit.issuingAuthority));
              bloc.add(
                PermitAttachmentUrlsChanged(permit.attachmentUrls.join(', ')),
              );
              bloc.add(PermitValidFromChanged(permit.validFrom));
              bloc.add(PermitValidToChanged(permit.validTo));
            }
          },
        ),
        if (permitId.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedPermitDetails(
            permitId: permitId,
            permitType: permitType,
            issuingAuthority: issuingAuthority,
            validFrom: state.permitValidFrom.value,
            validTo: state.permitValidTo.value,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedPermitDetails({
    required String permitId,
    required String permitType,
    required String issuingAuthority,
    required DateTime? validFrom,
    required DateTime? validTo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
        color: Colors.green.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                'Selected Permit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPermitDetailRow('Permit #', permitId),
          if (permitType.isNotEmpty) _buildPermitDetailRow('Type', permitType),
          if (issuingAuthority.isNotEmpty)
            _buildPermitDetailRow('Authority', issuingAuthority),
          if (validFrom != null && validTo != null)
            _buildPermitDetailRow(
              'Valid',
              '${_formatPermitDate(validFrom)} - ${_formatPermitDate(validTo)}',
            ),
        ],
      ),
    );
  }

  Widget _buildPermitDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatPermitDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Extension to make old API compatible
extension SpawnDialogCompat on SpawnEventDialog {
  /// Compatibility method for existing code
  static Future<SpawnEvent?> showCompat(
    BuildContext context, {
    required GraphNode node,
  }) {
    return SpawnEventDialog.show(context, targetNode: node);
  }
}

/// Displays inherited species from the first parent organism
class _InheritedSpeciesField extends StatelessWidget {
  const _InheritedSpeciesField({required this.state});

  final SpawnFormState state;

  @override
  Widget build(BuildContext context) {
    final parentIds = state.parentOrganisms.value ?? const <String>[];
    if (parentIds.isEmpty) {
      return InheritedSpeciesDisplay(species: null, inheritedFrom: 'parent');
    }

    // Load species from OrganismRecordRepository asynchronously
    return FutureBuilder<Species?>(
      future: _resolveSpecies(context, parentIds.first),
      builder: (context, snapshot) {
        return InheritedSpeciesDisplay(
          species: snapshot.data,
          inheritedFrom: 'parent',
        );
      },
    );
  }

  Future<Species?> _resolveSpecies(
    BuildContext context,
    String organismId,
  ) async {
    final repository = context.read<OrganismRecordRepository>();
    try {
      final organism = await repository.getRecordForId(organismId);
      if (organism?.speciesId == null) return null;
      return SpeciesRegistry.globalById(organism!.speciesId);
    } catch (_) {
      return null;
    }
  }
}

/// Dialog for selecting parent organisms
class _OrganismSelectionDialog extends StatefulWidget {
  final List<OrganismRecord> availableOrganisms;
  final List<String> selectedOrganismIds;

  const _OrganismSelectionDialog({
    required this.availableOrganisms,
    required this.selectedOrganismIds,
  });

  @override
  State<_OrganismSelectionDialog> createState() =>
      _OrganismSelectionDialogState();
}

class _OrganismSelectionDialogState extends State<_OrganismSelectionDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedOrganismIds);
  }

  @override
  Widget build(BuildContext context) {
    // Get organism kind for labeling
    final organismKind = widget.availableOrganisms.isNotEmpty
        ? widget.availableOrganisms.first.organismKind
        : OrganismKind.coral;
    final pluralLabel = '${organismKind.metadata.displayName}s';

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bubble_chart, color: Colors.pink),
          const SizedBox(width: 8),
          Text('Select Parent $pluralLabel'),
          const Spacer(),
          Text(
            '${_selectedIds.length} selected',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: ListView.builder(
          itemCount: widget.availableOrganisms.length,
          itemBuilder: (context, index) {
            final organism = widget.availableOrganisms[index];
            final species = SpeciesRegistry.globalById(organism.speciesId);
            final isSelected = _selectedIds.contains(organism.id);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedIds.add(organism.id);
                  } else {
                    _selectedIds.remove(organism.id);
                  }
                });
              },
              title: Text(organism.name),
              subtitle: Text(
                '${species?.name ?? 'Unknown species'} • Quantity: ${organism.measurement.value}',
              ),
              secondary: CircleAvatar(
                backgroundColor: isSelected ? Colors.pink : Colors.grey[300],
                child: Text(
                  species?.code ?? '?',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popSafeDialogContext(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => popSafeDialogContext(context, _selectedIds.toList()),
          icon: const Icon(Icons.check),
          label: Text(
            _selectedIds.isEmpty
                ? 'Select $pluralLabel'
                : 'Select ${_selectedIds.length} ${organismKind.metadata.displayName}${_selectedIds.length > 1 ? 's' : ''}',
          ),
        ),
      ],
    );
  }
}

/// Helper function to safely load an organism node in parallel.
/// Returns the organism record if available, null otherwise.
Future<OrganismRecord?> _loadOrganismSafely(OrganismNode node) async {
  try {
    await node.awaitLoaded().timeout(const Duration(seconds: 10));
    final state = node.state;
    if (state is GraphLoadedState<OrganismRecord>) {
      final organism = state.record;
      return organism;
    }
  } catch (error) {
    LoggingService.instance.warning(
      'Failed to load organism node for selection',
      {'nodeId': node.id, 'error': error.toString()},
    );
  }
  return null;
}

/// Helper function to safely load a group node in parallel.
Future<void> _loadGroupSafely(GroupNode node) async {
  try {
    await node.awaitLoaded().timeout(const Duration(seconds: 10));
  } catch (error) {
    LoggingService.instance.warning('Failed to load group node for selection', {
      'nodeId': node.id,
      'error': error.toString(),
    });
  }
}

Future<SiteNode?> _selectSiteFromOrganization(
  BuildContext context,
  OrganizationNode organizationNode,
) async {
  try {
    await organizationNode.awaitLoaded().timeout(const Duration(seconds: 10));
  } on TimeoutException {
    if (!context.mounted) return null;
    showSafeDialogSnackBar(
      context,
      'Loading sites timed out. Please try again.',
      isError: true,
    );
    return null;
  } catch (_) {
    if (!context.mounted) return null;
    showSafeDialogSnackBar(
      context,
      'Unable to load sites for selection',
      isError: true,
    );
    return null;
  }
  if (!context.mounted) return null;

  final nodeState = organizationNode.state;
  if (nodeState is! OrganizationLoadedState) return null;
  final sites = nodeState.siteNodes.toList()
    ..sort((a, b) => a.site.name.compareTo(b.site.name));
  if (sites.isEmpty) {
    showSafeDialogSnackBar(
      context,
      'No sites available for selection',
      isError: true,
    );
    return null;
  }

  return showDialog<SiteNode>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: false,
    builder: (dialogContext) {
      SiteNode? selectedSite;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Site'),
            content: DropdownButtonFormField<SiteNode>(
              initialValue: selectedSite,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Choose a site',
              ),
              items: sites
                  .map(
                    (site) => DropdownMenuItem(
                      value: site,
                      child: Text(site.site.name),
                    ),
                  )
                  .toList(),
              onChanged: (site) => setState(() => selectedSite = site),
            ),
            actions: [
              TextButton(
                onPressed: () => popSafeDialogContext(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedSite == null
                    ? null
                    : () => popSafeDialogContext(dialogContext, selectedSite),
                child: const Text('Select'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Collapsible section for collecting gametes (dam eggs or sire sperm).
class _GameteCollectionSection extends StatelessWidget {
  const _GameteCollectionSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.gameteRole,
    required this.collection,
    required this.parentOrganismKind,
    required this.onCollectionChanged,
    required this.onShowDestinationDialog,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final ProvenanceGameteRole gameteRole;
  final GameteCollectionEntry? collection;
  final OrganismKind? parentOrganismKind;
  final void Function(GameteCollectionEntry) onCollectionChanged;
  final VoidCallback onShowDestinationDialog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = collection?.enabled ?? false;
    final entry =
        collection ??
        (gameteRole == ProvenanceGameteRole.egg
            ? createDamGameteEntry()
            : createSireGameteEntry());

    return Card(
      elevation: isEnabled ? 2 : 0,
      color: isEnabled
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          InkWell(
            onTap: () {
              onCollectionChanged(entry.copyWith(enabled: !isEnabled));
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: isEnabled ? iconColor : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      onCollectionChanged(entry.copyWith(enabled: value));
                    },
                    activeTrackColor: iconColor.withValues(alpha: 0.5),
                    activeThumbColor: iconColor,
                  ),
                ],
              ),
            ),
          ),
          // Content (only shown when enabled)
          if (isEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Container count
                  TextFormField(
                    initialValue: entry.count?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Number of containers',
                      hintText: 'Enter container count',
                      suffixText: 'containers',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      final count = value.isEmpty ? null : int.tryParse(value);
                      onCollectionChanged(
                        count == null
                            ? entry.copyWith(clearCount: true)
                            : entry.copyWith(count: count),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Physical form selector
                  if (parentOrganismKind != null)
                    PhysicalFormSelectorWidget(
                      organismKind: parentOrganismKind!,
                      lifeStage: LifeStage.gamete,
                      initialPhysicalFormId: entry.physicalFormId,
                      initialSizeSpec: entry.sizeSpec ?? const SizeSpec(),
                      onChanged: (selection) {
                        onCollectionChanged(
                          entry.copyWith(
                            physicalFormId: selection.physicalFormId,
                            sizeSpec: selection.sizeSpec,
                          ),
                        );
                      },
                    )
                  else
                    Text(
                      'Select parent organisms to load physical forms.',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 16),
                  // Destination selector
                  _buildDestinationSelector(context, entry),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationSelector(
    BuildContext context,
    GameteCollectionEntry entry,
  ) {
    final selectedGroup = entry.destinationGroup;
    final displayText = selectedGroup?.name ?? 'Tap to select destination';

    return InkWell(
      onTap: onShowDestinationDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.disabled.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on,
              size: 20,
              color: selectedGroup == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}
