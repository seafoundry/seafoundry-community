// @tier: community
import 'dart:async';

import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/life_stage_progression/life_stage_progression_cubit.dart';
import 'package:seafoundry_app/cubits/life_stage_progression/life_stage_progression_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/physical_form_version_service.dart';
import 'package:seafoundry_app/widgets/common/field_tooltip.dart';
import 'package:seafoundry_app/widgets/common/gesture_navigation.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/mixins/event_propagation_mixin.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for progressing organism life stages with physical form configuration
class LifeStageProgressionDialog extends StatelessWidget {
  const LifeStageProgressionDialog({
    super.key,
    required this.organism,
    required this.node,
  });

  final OrganismRecord organism;
  final GraphNode node;

  static Future<bool?> show(
    BuildContext context,
    OrganismRecord organism,
    GraphNode node,
  ) {
    // Read required dependencies from parent context
    final organismRepository = context.read<OrganismRecordRepository>();
    final eventRepository = context.read<EventRepository>();
    final currentUser = context.read<CurrentUser>();
    final firestore = context.read<FirebaseService>().firestore;

    // Extract user ID from CurrentUser
    final currentUserState = currentUser.state;
    String userId;
    if (currentUserState is CurrentUserLoaded) {
      userId = currentUserState.user.id;
    } else {
      throw Exception('User not authenticated');
    }

    // Instantiate version service for config version tracking
    final versionService = PhysicalFormVersionService(firestore: firestore);

    return showDialog<bool>(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      barrierDismissible: false,
      builder: (dialogContext) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: organismRepository),
          RepositoryProvider.value(value: eventRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: currentUser),
            BlocProvider(
              create: (_) => LifeStageProgressionCubit(
                organism: organism,
                organismKind: organism.organismKind,
                organismRepository: organismRepository,
                eventRepository: eventRepository,
                userId: userId,
                versionService: versionService,
              ),
            ),
          ],
          child: LifeStageProgressionDialog(organism: organism, node: node),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _LifeStageProgressionDialogContent(organism: organism, node: node);
  }
}

/// Internal StatefulWidget for LifeStageProgressionDialog content
///
/// **Migration Status**: Remains StatefulWidget (legitimate use case)
///
/// **Why StatefulWidget**:
/// - Uses `EventPropagationMixin` which requires StatefulWidget lifecycle hooks
/// - Manages TextEditingController for notes (lifecycle management)
/// - Mixin requires mounted state checks for event propagation
/// - Form submission with async operations needs widget lifecycle
///
/// **Architecture**: Uses Cubit (`LifeStageProgressionCubit`) for form state,
/// but StatefulWidget wrapper required for mixin and controller lifecycle.
class _LifeStageProgressionDialogContent extends StatefulWidget {
  const _LifeStageProgressionDialogContent({
    required this.organism,
    required this.node,
  });

  final OrganismRecord organism;
  final GraphNode node;

  @override
  State<_LifeStageProgressionDialogContent> createState() =>
      _LifeStageProgressionDialogContentState();
}

class _LifeStageProgressionDialogContentState
    extends State<_LifeStageProgressionDialogContent>
    with
        EventPropagationMixin,
        SafeDialogMixin<_LifeStageProgressionDialogContent> {
  late final TextEditingController _notesController;
  bool _isUpdatingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    super.dispose();
  }

  void _onNotesChanged() {
    if (_isUpdatingNotes) return;
    context.read<LifeStageProgressionCubit>().notesChanged(
      _notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeStageProgressionCubit, LifeStageProgressionState>(
      builder: (context, cubitState) {
        // Sync controller with cubit state if it changed externally
        if (_notesController.text != cubitState.notes) {
          _isUpdatingNotes = true;
          _notesController.value = _notesController.value.copyWith(
            text: cubitState.notes,
            selection: TextSelection.collapsed(offset: cubitState.notes.length),
          );
          _isUpdatingNotes = false;
        }

        return SwipeToDismissWrapper(
          onDismiss: () => popDialog(false),
          direction: DismissDirection.down,
          child: AlertDialog(
            title: const Text('Life Stage Progression'),
            content: SizedBox(
              width: 400,
              child: DialogScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress organism to new life stage',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildCurrentLifeStage(context),
                    const SizedBox(height: 16),
                    _buildTargetLifeStageField(context, cubitState),
                    const SizedBox(height: 16),
                    _buildPhysicalFormField(context, cubitState),
                    const SizedBox(height: 16),
                    _buildSizeBandField(context, cubitState),
                    const SizedBox(height: 16),
                    _buildSizeBandField(context, cubitState),
                    const SizedBox(height: 16),
                    _buildReasonField(context, cubitState),
                    const SizedBox(height: 16),
                    _buildNotesField(context, cubitState),
                    if (cubitState.error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorMessage(context, cubitState.error!),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: cubitState.loading
                    ? null
                    : () => popDialog(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: cubitState.isValid && !cubitState.loading
                    ? () => _submitProgression(context)
                    : null,
                child: cubitState.loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentLifeStage(BuildContext context) {
    final currentStage = widget.organism.lifeStage.stage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Life Stage:',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(currentStage.displayName),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
      ],
    );
  }

  Widget _buildTargetLifeStageField(
    BuildContext context,
    LifeStageProgressionState state,
  ) {
    final currentStage = widget.organism.lifeStage.stage;
    final availableStages = LifeStage.values
        .where((stage) => stage != currentStage)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldTooltip(
          title: 'Target Life Stage',
          message:
              'Select the life stage to progress this organism to. '
              'Available physical forms will be loaded based on your selection.',
          child: Text(
            'Target Life Stage:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LifeStage>(
          initialValue: state.selectedLifeStage,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Select target life stage',
          ),
          items: availableStages.map((stage) {
            return DropdownMenuItem(
              value: stage,
              child: Text(stage.displayName),
            );
          }).toList(),
          onChanged: state.loading
              ? null
              : (value) {
                  context.read<LifeStageProgressionCubit>().lifeStageChanged(
                    value,
                  );
                },
        ),
      ],
    );
  }

  Widget _buildPhysicalFormField(
    BuildContext context,
    LifeStageProgressionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldTooltip(
          title: 'Physical Form',
          message:
              'Select the physical form configuration for this life stage. '
              'Each form defines size bands and measurement requirements.',
          child: Text(
            'Physical Form:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        if (state.loadingForms)
          const Center(child: CircularProgressIndicator())
        else if (state.selectedLifeStage == null)
          const Text('Select a target life stage first')
        else if (state.availableForms.isEmpty)
          const Text('No physical forms available for selected life stage')
        else
          _PhysicalFormVisualSelector(
            forms: state.availableForms,
            selectedForm: state.selectedForm,
            enabled: !state.loading,
            onChanged: (value) {
              context.read<LifeStageProgressionCubit>().physicalFormChanged(
                value,
              );
            },
          ),
      ],
    );
  }

  Widget _buildReasonField(
    BuildContext context,
    LifeStageProgressionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldTooltip(
          title: 'Reason',
          message: 'The reason for this life stage progression.',
          child: Text(
            'Reason:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LifeStageTransitionReason>(
          initialValue: state.reason,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Select reason',
          ),
          items: LifeStageTransitionReason.builtins.values.map((reason) {
            return DropdownMenuItem(
              value: reason,
              child: Text(reason.name),
            );
          }).toList(),
          onChanged: state.loading
              ? null
              : (value) {
                  context.read<LifeStageProgressionCubit>().reasonChanged(value);
                },
        ),
      ],
    );
  }

  Widget _buildSizeBandField(
    BuildContext context,
    LifeStageProgressionState state,
  ) {
    final sizeBands = state.selectedForm?.sizeBands ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldTooltip(
          title: 'Size Band',
          message:
              'Select the size band that best describes this organism. '
              'Size bands help categorize organisms within the same physical form.',
          child: Text(
            'Size Band:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        if (state.selectedForm == null)
          const Text('Select a physical form first')
        else if (sizeBands.isEmpty)
          const Text('No size bands available for selected form')
        else
          _SizeBandVisualSelector(
            sizeBands: sizeBands,
            selectedBand: state.selectedSizeBand,
            enabled: !state.loading,
            onChanged: (value) {
              context.read<LifeStageProgressionCubit>().sizeBandChanged(value);
            },
          ),
      ],
    );
  }

  Widget _buildNotesField(
    BuildContext context,
    LifeStageProgressionState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldTooltip(
          title: 'Notes',
          message:
              'Optional notes about this life stage progression. '
              'These notes are recorded as part of the progression event.',
          child: Text(
            'Notes (optional):',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          enabled: !state.loading,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Add notes about the progression...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitProgression(BuildContext context) async {
    final cubit = context.read<LifeStageProgressionCubit>();

    await safeAsyncOperation(
      () async {
        try {
          final success = await cubit.submit();

          if (!mounted) return;

          if (success) {
            // Collect nodes that need to be reloaded to show updated data
            // Include the node itself and all parent nodes (site, group, etc.)
            // that display summary cards and event feeds
            final nodesToReload = <GraphNode>{widget.node};

            // Add all parent nodes from lineage (excluding the node itself)
            // Lineage typically goes: [organization, site, group, organism]
            // We want to reload site and group nodes which show summary cards
            for (final ancestor in widget.node.lineage) {
              if (ancestor != widget.node) {
                nodesToReload.add(ancestor);
              }
            }

            // Propagate the life stage progression event
            // Note: The event is already created in cubit.submit()
            // Here we just need to notify the UI
            if (!mounted) return;

            LoggingService.instance.info(
              'Life stage progression completed for organism ${widget.organism.id}',
            );

            // Wait a brief moment for Firestore to propagate changes before reloading
            // This ensures the reload picks up the updated record and new event
            await Future.delayed(const Duration(milliseconds: 500));

            // Request reload of all affected nodes to refresh event feeds and summary cards
            for (final node in nodesToReload) {
              if (!node.isClosed) {
                node.add(const GraphNodeReloadRequested());
              }
            }

            // Success - show feedback and close dialog
            if (mounted) {
              final targetStage = cubit.state.selectedLifeStage!;
              showDialogSnackBar(
                'Progressed organism to ${targetStage.displayName}',
                isSuccess: true,
              );
              popDialog(true);
            }
          }
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to progress life stage',
            e,
            stackTrace,
          );
          rethrow;
        }
      },
      operationName: 'Progress life stage',
      onError: (error, stackTrace) {
        cubit.setLoading(false);
        if (mounted) {
          showDialogSnackBar(
            'Failed to progress life stage: $error',
            isError: true,
          );
        }
      },
    );
  }
}

/// Visual grid selector for physical forms
class _PhysicalFormVisualSelector extends StatelessWidget {
  const _PhysicalFormVisualSelector({
    required this.forms,
    required this.selectedForm,
    required this.enabled,
    required this.onChanged,
  });

  final List<PhysicalFormConfig> forms;
  final PhysicalFormConfig? selectedForm;
  final bool enabled;
  final ValueChanged<PhysicalFormConfig?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: forms.map((form) {
        final isSelected = selectedForm?.id == form.id;
        return Material(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? () => onChanged(form) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  form.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? primaryColor
                        : (enabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Visual grid selector for size bands
class _SizeBandVisualSelector extends StatelessWidget {
  const _SizeBandVisualSelector({
    required this.sizeBands,
    required this.selectedBand,
    required this.enabled,
    required this.onChanged,
  });

  final List<SizeBandConfig> sizeBands;
  final SizeBandConfig? selectedBand;
  final bool enabled;
  final ValueChanged<SizeBandConfig?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return DialogScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sizeBands.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final band = sizeBands[i];
                final isSelected = selectedBand?.id == band.id;
                final metrics = _resolveMetrics(band);
                final showVolume = band.enableVolume;
                final showTissue = band.enableTissueArea;
                return Material(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: enabled ? () => onChanged(band) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 56, minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : theme.colorScheme.outline
                                  .withValues(alpha: 0.4),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              band.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? primaryColor
                                    : (enabled
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (showVolume || showTissue) ...[
                              const SizedBox(height: 4),
                              if (showVolume)
                                Text(
                                  'Physical Volume ${_formatMetric(metrics.volumeCm3)} cm³',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              if (showTissue)
                                Text(
                                  'Tissue Area ${_formatMetric(metrics.tissueAreaCm2)} cm²',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  SizeMetrics _resolveMetrics(SizeBandConfig band) {
    final volume = band.defaultVolumeCm3 ?? (band.volumeMm3 / 1000.0);
    final tissue = band.defaultTissueAreaCm2;
    return SizeMetrics(volumeCm3: volume, tissueAreaCm2: tissue);
  }

  String _formatMetric(double? value) {
    if (value == null) return '--';
    return value.round().toString();
  }
}