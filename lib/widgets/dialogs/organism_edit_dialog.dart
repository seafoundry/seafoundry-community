import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/organism_record_edit/organism_record_edit_cubit.dart';
import 'package:seafoundry_app/blocs/organism_record_edit/organism_record_edit_state.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/life_stage_transition_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_record_change_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/validation/organism_constraints_service.dart';
import 'package:seafoundry_app/widgets/common/alias_editor.dart';
import 'package:seafoundry_app/widgets/common/life_stage_transition_editor.dart';
import 'package:seafoundry_app/widgets/common/physical_form_change_editor.dart';
import 'package:seafoundry_app/widgets/common/quantity_change_editor.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

/// Full-screen dialog for editing all 5 axes of an organism record:
/// identity, quantity, life stage, physical form, and provenance/aliases.
///
/// Backed by [OrganismRecordEditCubit] for change detection, validation,
/// event emission, and genet-wide updates. Health status is merged into the
/// save callback via a [ValueNotifier] so all changes are written in a single
/// Firestore operation.
class OrganismEditDialog extends StatefulWidget {
  const OrganismEditDialog({
    super.key,
    required this.organism,
    required this.organismNode,
    required this.healthStatusNotifier,
  });

  final OrganismRecord organism;
  final OrganismNode organismNode;
  final ValueNotifier<HealthStatus> healthStatusNotifier;

  static Future<bool?> show(
    BuildContext context, {
    required OrganismNode organismNode,
  }) {
    final state = organismNode.state;
    if (state is! GraphLoadedState<OrganismRecord>) {
      return Future.value(null);
    }
    final organism = state.record;

    // Capture providers BEFORE showDialog (dialog creates new context).
    final repository = context.read<OrganismRecordRepository>();
    final genetRepository = context.read<GenetRepository>();
    final eventRepository = context.read<EventRepository>();
    final provenanceLookupService = context.read<ProvenanceLookupService>();
    final currentUser = context.read<CurrentUser>();
    final userState = currentUser.state;
    if (userState is! CurrentUserLoaded) return Future.value(null);
    final organization = userState.organization;

    // Shared health status notifier: the dialog updates it, and the
    // onSubmit callback reads it to merge metadata in a single write.
    final healthStatusNotifier = ValueNotifier(organism.healthStatus);

    final cubit = OrganismRecordEditCubit(
      originalRecord: organism,
      changeService: const OrganismRecordChangeService(),
      transitionService: LifeStageTransitionService(),
      constraintsService: const OrganismConstraintsService(),
      onSubmit: (updated, {eventMetadata}) async {
        // Merge health status into the record if changed.
        var record = updated;
        final currentHealth = healthStatusNotifier.value;
        if (currentHealth != organism.healthStatus) {
          final meta = Map<String, dynamic>.from(
            record.metadata ?? <String, dynamic>{},
          );
          meta['healthStatus'] = currentHealth.id;
          record = record.copyWith(metadata: meta);
        }
        await repository.updateRecordWithEvents(
          organism,
          record,
          eventMetadata: eventMetadata,
        );
      },
      genetRepository: genetRepository,
      organismRecordRepository: repository,
      provenanceLookupService: provenanceLookupService,
      provenanceIdService: null,
      eventRepository: eventRepository,
      organization: organization,
    );

    final dialog = OrganismEditDialog(
      organism: organism,
      organismNode: organismNode,
      healthStatusNotifier: healthStatusNotifier,
    );

    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<OrganismRecordRepository>.value(value: repository),
          RepositoryProvider<GenetRepository>.value(value: genetRepository),
          RepositoryProvider<EventRepository>.value(value: eventRepository),
          RepositoryProvider<ProvenanceLookupService>.value(
            value: provenanceLookupService,
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<CurrentUser>.value(value: currentUser),
            BlocProvider<OrganismRecordEditCubit>.value(value: cubit),
          ],
          child: Provider<Organization>.value(
            value: organization,
            child: dialog,
          ),
        ),
      ),
    ).whenComplete(() {
      cubit.close();
      healthStatusNotifier.dispose();
    });
  }

  @override
  State<OrganismEditDialog> createState() => _OrganismEditDialogState();
}

class _OrganismEditDialogState extends State<OrganismEditDialog>
    with SafeDialogMixin<OrganismEditDialog> {
  late TextEditingController _recordNameController;
  late TextEditingController _localIdController;
  late TextEditingController _clonalIdController;
  late TextEditingController _accessionController;

  late HealthStatus _healthStatus;
  bool _healthStatusChanged = false;

  @override
  void initState() {
    super.initState();
    _recordNameController = TextEditingController(
      text: widget.organism.tagId,
    );
    _localIdController = TextEditingController(
      text: widget.organism.localGenetId ?? '',
    );
    _clonalIdController = TextEditingController();
    _accessionController = TextEditingController();
    _healthStatus = widget.organism.healthStatus;
  }

  @override
  void dispose() {
    _recordNameController.dispose();
    _localIdController.dispose();
    _clonalIdController.dispose();
    _accessionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<OrganismRecordEditCubit>();
    final cubitState = cubit.state;

    if (cubitState.canSubmit) {
      // Health status is merged into the record via the onSubmit callback.
      cubit.submit();
    } else if (_healthStatusChanged && !cubitState.changeSet.hasChanges) {
      // Health-only change with no cubit changes: save metadata directly.
      // Guard: don't allow health-only save when cubit has invalid changes,
      // since the user should fix validation errors first.
      await _saveHealthStatusOnly();
    }
  }

  Future<void> _saveHealthStatusOnly() async {
    final repository = context.read<OrganismRecordRepository>();

    final updatedMetadata = Map<String, dynamic>.from(
      widget.organism.metadata ?? <String, dynamic>{},
    );
    updatedMetadata['healthStatus'] = _healthStatus.id;

    final updated = widget.organism.copyWith(metadata: updatedMetadata);

    try {
      await repository.updateRecordWithEvents(widget.organism, updated);
      widget.organismNode.add(const GraphNodeReloadRequested());
      if (!mounted) return;
      showDialogSnackBar('Record updated', isSuccess: true);
      popDialog(true);
    } catch (e, stack) {
      LoggingService.instance.error('Failed to update health status', e, stack);
      if (mounted) {
        showDialogSnackBar('Error: $e', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<OrganismRecordEditCubit, OrganismRecordEditState>(
      listener: (context, state) {
        // Populate clonal ID / accession once genet loads
        if (state.underlyingGenet != null) {
          if (_clonalIdController.text.isEmpty) {
            _clonalIdController.text = state.clonalIdOverride ?? '';
          }
          if (_accessionController.text.isEmpty) {
            _accessionController.text = state.accessionNumberOverride ?? '';
          }
        }

        // Handle successful submission
        if (state.submissionSucceeded) {
          _onSaveSuccess(state);
        }
      },
      child: BlocBuilder<OrganismRecordEditCubit, OrganismRecordEditState>(
        builder: (context, state) {
          final identityDisabled =
              state.isCustodian || state.isIdentityLocked;
          final canSave =
              (state.canSubmit || (_healthStatusChanged && !state.changeSet.hasChanges)) &&
              !state.isSubmitting;

          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => popDialog(false),
                ),
                title: const Text('Edit Record'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton(
                      onPressed: canSave ? _save : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error banner
                    if (state.submissionError != null)
                      _buildErrorBanner(theme, state.submissionError!),

                    // Identity section
                    _buildIdentitySection(theme, state, identityDisabled),

                    const SizedBox(height: 16),

                    // Health Status
                    _buildHealthStatusSection(theme, state),

                    const SizedBox(height: 8),

                    // Quantity
                    _buildQuantityTile(state),

                    // Life Stage
                    _buildLifeStageTile(state),

                    // Physical Form
                    _buildPhysicalFormTile(state),

                    // Provenance & Aliases
                    _buildProvenanceTile(theme, state, identityDisabled),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onSaveSuccess(OrganismRecordEditState state) {
    widget.organismNode.add(const GraphNodeReloadRequested());

    final warning = state.genetWideUpdateWarning;
    final count = state.genetWideUpdateCount;
    String message = 'Record updated';
    if (count != null && count > 0) {
      message = 'Record updated ($count related records also updated)';
    }

    showDialogSnackBar(
      warning ?? message,
      isSuccess: warning == null,
    );
    popDialog(true);
  }

  Widget _buildErrorBanner(ThemeData theme, String error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection(
    ThemeData theme,
    OrganismRecordEditState state,
    bool disabled,
  ) {
    final cubit = context.read<OrganismRecordEditCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Identity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _recordNameController,
          decoration: const InputDecoration(
            labelText: 'Record Name',
            helperText: 'A friendly name for this record (e.g., "Fluffy").',
          ),
          enabled: !disabled && !state.isSubmitting,
          onChanged: cubit.setRecordName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _localIdController,
          decoration: InputDecoration(
            labelText: 'Local ID',
            helperText: 'Genet identifier (e.g., ACER-001).',
            errorText: state.localIdConflictError,
          ),
          enabled: !disabled && !state.isSubmitting,
          onChanged: cubit.setLocalId,
        ),
        if (disabled)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              state.isCustodian
                  ? 'Identity fields are managed by the owner organization.'
                  : 'Identity fields are locked due to transfer.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHealthStatusSection(
    ThemeData theme,
    OrganismRecordEditState state,
  ) {
    // Ensure current status is in the items list even if it's a terminal
    // status (deceased, lost, etc.) that is not in selectableValues.
    final items = HealthStatus.selectableValues.toList();
    if (!items.contains(_healthStatus)) {
      items.insert(0, _healthStatus);
    }

    return DropdownButtonFormField<HealthStatus>(
      key: ValueKey(_healthStatus),
      initialValue: _healthStatus,
      decoration: const InputDecoration(labelText: 'Health Status'),
      items: items
          .map(
            (status) => DropdownMenuItem(
              value: status,
              child: Text(status.displayName),
            ),
          )
          .toList(),
      onChanged: state.isSubmitting
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _healthStatus = value;
                  _healthStatusChanged =
                      value != widget.organism.healthStatus;
                  // Update the shared notifier so the onSubmit callback
                  // merges health status into the single Firestore write.
                  widget.healthStatusNotifier.value = value;
                });
              }
            },
    );
  }

  Widget _buildQuantityTile(OrganismRecordEditState state) {
    final cubit = context.read<OrganismRecordEditCubit>();

    return _ChangeIndicatorTile(
      title: 'Quantity',
      hasChange: state.hasQuantityChange,
      initiallyExpanded: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: QuantityChangeEditor(
          currentMeasurement: widget.organism.measurement,
          kind: state.quantityKind,
          onKindChanged: cubit.setQuantityKind,
          selectedReason: state.quantityReason,
          onReasonChanged: cubit.setQuantityReason,
          pendingValue: state.quantityOverride,
          onValueChanged: cubit.setQuantityValue,
          mortalityReason: state.mortalityReason,
          onMortalityReasonChanged: cubit.setMortalityReason,
          comment: state.quantityComment,
          onCommentChanged: cubit.setQuantityComment,
          validationMessage: state.quantityValidationMessage,
          isBusy: state.isSubmitting,
        ),
      ),
    );
  }

  Widget _buildLifeStageTile(OrganismRecordEditState state) {
    final cubit = context.read<OrganismRecordEditCubit>();

    return _ChangeIndicatorTile(
      title: 'Life Stage',
      hasChange: state.hasLifeStageChange,
      initiallyExpanded: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LifeStageTransitionEditor(
          currentStage: widget.organism.lifeStage,
          allowedStages: LifeStage.values,
          selectedStage: state.lifeStageOverride,
          onStageChanged: cubit.setLifeStage,
          selectedReason: state.lifeStageReason,
          onReasonChanged: cubit.setLifeStageReason,
          minimumInterval: state.minimumStageInterval,
          lastTransitionAt: state.lastTransitionAt,
          validationMessage: state.lifeStageValidationMessage,
          isBusy: state.isSubmitting,
        ),
      ),
    );
  }

  Widget _buildPhysicalFormTile(OrganismRecordEditState state) {
    final cubit = context.read<OrganismRecordEditCubit>();
    final effectiveLifeStage =
        state.lifeStageOverride ?? widget.organism.lifeStage.stage;

    return _ChangeIndicatorTile(
      title: 'Physical Form',
      hasChange: state.hasPhysicalFormChange,
      initiallyExpanded: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: PhysicalFormChangeEditor(
          organismKind: widget.organism.organismKind,
          lifeStage: effectiveLifeStage,
          currentFormId: widget.organism.physicalForm?.formId,
          allowedFormIds: state.allowedFormIds,
          selectedFormId: state.formIdOverride,
          onFormIdChanged: cubit.setPhysicalForm,
          selectedReason: state.physicalFormChangeReason,
          onReasonChanged: cubit.setPhysicalFormChangeReason,
          validationMessage: state.physicalFormValidationMessage,
          isBusy: state.isSubmitting,
        ),
      ),
    );
  }

  Widget _buildProvenanceTile(
    ThemeData theme,
    OrganismRecordEditState state,
    bool identityDisabled,
  ) {
    final cubit = context.read<OrganismRecordEditCubit>();
    final provenanceType = widget.organism.provenanceType;

    return _ChangeIndicatorTile(
      title: 'Provenance & Aliases',
      hasChange: state.hasProvenanceChange,
      initiallyExpanded: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read-only provenance type chip
            if (provenanceType != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Chip(
                  avatar: const Icon(Icons.fingerprint, size: 18),
                  label: Text(provenanceType.displayName),
                ),
              ),

            // Clonal ID
            TextFormField(
              controller: _clonalIdController,
              decoration: const InputDecoration(
                labelText: 'Clonal ID',
                helperText: 'Unique genetic identifier.',
              ),
              enabled: !identityDisabled && !state.isSubmitting,
              onChanged: cubit.setClonalId,
            ),
            const SizedBox(height: 12),

            // Accession Number
            TextFormField(
              controller: _accessionController,
              decoration: const InputDecoration(
                labelText: 'Accession Number',
                helperText: 'External accession or catalog number.',
              ),
              enabled: !identityDisabled && !state.isSubmitting,
              onChanged: cubit.setAccessionNumber,
            ),
            const SizedBox(height: 16),

            // Aliases
            Text('Aliases', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            AliasEditorList(
              aliases: state.aliasEntries,
              onAddAlias: identityDisabled ? null : cubit.addAliasEntry,
              onRemoveAlias:
                  identityDisabled ? null : cubit.removeAliasEntry,
              onValueChanged: identityDisabled
                  ? null
                  : (index, value) =>
                      cubit.updateAliasValue(index, value),
              onSourceChanged: identityDisabled
                  ? null
                  : (index, source) =>
                      cubit.updateAliasSource(index, source),
              onLabelChanged: identityDisabled
                  ? null
                  : (index, label) =>
                      cubit.updateAliasLabel(index, label),
              excludedSystems: kReservedAliasSystems,
              enabled: !identityDisabled && !state.isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}

/// ExpansionTile wrapper that shows a change-indicator dot when [hasChange] is true.
class _ChangeIndicatorTile extends StatelessWidget {
  const _ChangeIndicatorTile({
    required this.title,
    required this.hasChange,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final bool hasChange;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Row(
        children: [
          Text(title),
          if (hasChange) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      children: [child],
    );
  }
}
