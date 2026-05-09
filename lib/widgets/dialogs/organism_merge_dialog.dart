import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/graph_node_state.dart';
import 'package:seafoundry_app/models/graph/group_node.dart';
import 'package:seafoundry_app/cubits/organism_merge/organism_merge_bloc.dart';
import 'package:seafoundry_app/cubits/organism_merge/organism_merge_state.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_async.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/url_path_resolver.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog_shell.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

class OrganismMergeDialog extends StatelessWidget {
  const OrganismMergeDialog({super.key});

  static Future<OrganismRecord?> show(
    BuildContext context, {
    required GroupNode groupNode,
    Set<String>? initialSelectedIds,
    String? filterLocalId,
  }) async {
    try {
      await groupNode.awaitLoaded();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'OrganismMergeDialog: Failed to load group node',
        error,
        stackTrace,
      );
      if (context.mounted) {
        showSafeDialogSnackBar(
          context,
          'Unable to load the source structure for merge. Please try again.',
          isError: true,
        );
      }
      return null;
    }
    if (!context.mounted) return null;

    final nodeState = groupNode.state;
    if (nodeState is! GraphLoadedState<Group>) {
      showSafeDialogSnackBar(
        context,
        'Unable to load the source structure for merge. Please try again.',
        isError: true,
      );
      return null;
    }

    final organismRepository = context.read<OrganismRecordRepository>();
    final graphRepository = context.read<GraphRepository>();

    // Get organisms in this group
    List<OrganismRecord> allOrganisms;
    try {
      allOrganisms = await organismRepository.getAll().timeout(
        const Duration(seconds: 8),
      );
    } on TimeoutException catch (error) {
      LoggingService.instance.error(
        'OrganismMergeDialog: Loading organisms timed out',
        error,
      );
      if (context.mounted) {
        showSafeDialogSnackBar(
          context,
          'Loading organisms timed out. Please try again.',
          isError: true,
        );
      }
      return null;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'OrganismMergeDialog: Failed to load organisms',
        error,
        stackTrace,
      );
      if (context.mounted) {
        showSafeDialogSnackBar(
          context,
          'Unable to load organisms for merge. Please try again.',
          isError: true,
        );
      }
      return null;
    }
    if (!context.mounted) return null;

    final resolvedLocalId = filterLocalId?.trim();
    final groupUrlPath = UrlPathResolver.normalizePath(
      nodeState.record.urlPath,
    );
    final groupOrganisms = allOrganisms.where((organism) {
      if (organism.metadata?['isDeleted'] == true) return false;

      if (resolvedLocalId != null && resolvedLocalId.isNotEmpty) {
        final localGenetId = organism.localGenetId?.trim();
        if (localGenetId == null || localGenetId != resolvedLocalId) {
          return false;
        }
      }

      if (groupUrlPath.isEmpty) {
        return organism.groupId == nodeState.record.id;
      }

      final recordPath = UrlPathResolver.normalizePath(
        organism.urlPath,
      );
      if (recordPath.isEmpty) return false;
      if (recordPath == groupUrlPath) return true;
      return UrlPathResolver.isDescendantOf(recordPath, groupUrlPath);
    }).toList();

    if (groupOrganisms.isEmpty) {
      showSafeDialogSnackBar(
        context,
        'No organisms available for merging.',
        isError: true,
      );
      return null;
    }

    if (!context.mounted) return null;
    return showDialog<OrganismRecord?>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) => OrganismMergeBloc(
          availableOrganisms: groupOrganisms,
          organismRepository: organismRepository,
          graphRepository: graphRepository,
          initialSelectedIds: initialSelectedIds,
        ),
        child: const OrganismMergeDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StructureDialogShell<
      OrganismRecord,
      OrganismMergeState,
      OrganismMergeBloc
    >(
      config: StructureDialogConfig<OrganismRecord, OrganismMergeState>(
        icon: Icons.call_merge,
        progressTitle: 'Loading merge options...',
        submitButtonLabel: 'Merge Records',
        autoInitialize: true,
        width: 560,
        titleBuilder: (state) => _titleForIndex(state.currentStepIndex),
        stepBuilders: {
          BaseRecordFormStep: (context, state) => _buildStep(context, state),
        },
        successHandler: (context, state) async {
          final merged = state.createdRecord;
          if (merged != null) {
            showSafeDialogSnackBar(
              context,
              'Merged ${state.absorbedOrganisms.length + 1} records into ${merged.tagId}',
              isSuccess: true,
            );
          }
        },
        resultBuilder: (state) => state.createdRecord,
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Select Records & Target';
      case 1:
        return 'Record Details';
      case 2:
        return 'Review & Confirm';
      default:
        return 'Merge Records';
    }
  }

  Widget _buildStep(BuildContext context, OrganismMergeState state) {
    if (state.loadStatus != RecordFormLoadStatus.success) {
      return const SizedBox.shrink();
    }

    switch (state.currentStepIndex) {
      case 0:
        return _SelectionStep(state: state);
      case 1:
        return _DetailsStep(state: state);
      case 2:
        return _ReviewStep(state: state);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SelectionStep extends StatelessWidget {
  const _SelectionStep({required this.state});

  final OrganismMergeState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OrganismMergeBloc>();
    final selectedIds = state.selectedOrganismIds;
    final targetId = state.targetOrganismId;
    final theme = Theme.of(context);

    // Group organisms by localGenetId for display
    final organismsByLocalId = <String, List<OrganismRecord>>{};
    for (final organism in state.availableOrganisms) {
      final eligible = state.isOrganismEligible(organism);
      final localGenetId = organism.localGenetId;
      if (eligible && localGenetId != null && localGenetId.isNotEmpty) {
        organismsByLocalId.putIfAbsent(localGenetId, () => []).add(organism);
      }
    }

    // Only show localIds with multiple organisms (mergeable)
    final mergeableLocalIds = organismsByLocalId.entries
        .where((e) => e.value.length >= 2)
        .toList();

    final selectedLocalId = state.targetOrganism?.localGenetId?.trim();
    final filteredLocalId =
        (selectedLocalId != null && selectedLocalId.isNotEmpty)
            ? selectedLocalId
            : null;
    final visibleLocalIds = filteredLocalId == null
        ? mergeableLocalIds
        : mergeableLocalIds.where((e) => e.key == filteredLocalId).toList();

    if (visibleLocalIds.isEmpty) {
      return SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.outline,
              size: 48,
            ),
            UI.spacingVerticalMd,
            UIText.bodyMedium('No records available for merging'),
            UI.spacingVerticalSm,
            UIText.caption(
              'Records must share the same Local ID, life stage, '
              'physical form, species, and measurement unit to be merged.',
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Select records to merge'),
          UIText.caption(
            '${selectedIds.length} selected • '
            'Select a target that will absorb the others',
          ),
          UI.spacingVerticalSm,
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: visibleLocalIds.length,
              itemBuilder: (context, index) {
                final entry = visibleLocalIds[index];
                final localGenetId = entry.key;
                final organisms = entry.value;

                return ExpansionTile(
                  initiallyExpanded: index == 0,
                  title: Text('Local ID: $localGenetId'),
                  subtitle: Text('${organisms.length} records'),
                  children: organisms.map((organism) {
                    final isSelected = selectedIds.contains(organism.id);
                    final isTarget = organism.id == targetId;
                    final unit = organism.measurement.unit.symbol;

                    return ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (selected) {
                          final updatedIds = Set<String>.from(selectedIds);
                          if (selected == true) {
                            updatedIds.add(organism.id);
                          } else {
                            updatedIds.remove(organism.id);
                          }
                          bloc.add(MergeRecordSelectionChanged(updatedIds));
                        },
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(organism.tagId)),
                          if (isTarget)
                            Chip(
                              label: const Text('Target'),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${organism.measurement.value.toStringAsFixed(0)} $unit • '
                        '${organism.lifeStage.displayName}',
                      ),
                      trailing: isSelected && !isTarget
                          ? IconButton(
                              icon: const Icon(Icons.star_outline),
                              tooltip: 'Set as target',
                              onPressed: () {
                                bloc.add(MergeTargetChanged(organism.id));
                              },
                            )
                          : isTarget
                          ? Icon(Icons.star, color: theme.colorScheme.primary)
                          : null,
                      onTap: isSelected
                          ? () => bloc.add(MergeTargetChanged(organism.id))
                          : () {
                              final updatedIds = Set<String>.from(selectedIds)
                                ..add(organism.id);
                              bloc.add(MergeRecordSelectionChanged(updatedIds));
                            },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          if (state.selectionInput.displayError != null) ...[
            UI.spacingVerticalSm,
            Text(
              state.selectionInput.displayError!.message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsStep extends StatefulWidget {
  const _DetailsStep({required this.state});

  final OrganismMergeState state;

  @override
  State<_DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<_DetailsStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.state.mergedRecordName ?? widget.state.targetOrganism?.tagId,
    );
    _notesController = TextEditingController(
      text: widget.state.mergeNotes,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OrganismMergeBloc>();

    return DialogScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIText.bodyMedium('Record Details'),
          UI.spacingVerticalSm,
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Name *',
              hintText: 'Enter record name',
            ),
            onChanged: (value) {
              bloc.add(MergeRecordNameChanged(value));
            },
          ),
          if (widget.state.recordNameInput.displayError != null) ...[
            UI.spacingVerticalSm,
            Text(
              widget.state.recordNameInput.displayError!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          UI.spacingVerticalMd,
          _MergePreviewCard(state: widget.state),
        ],
      ),
    );
  }
}

class _MergePreviewCard extends StatelessWidget {
  const _MergePreviewCard({required this.state});

  final OrganismMergeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetOrganism = state.targetOrganism;
    final absorbedOrganisms = state.absorbedOrganisms;

    if (targetOrganism == null) return const SizedBox.shrink();

    final unit = targetOrganism.measurement.unit.symbol;
    final totalQuantity = state.totalQuantityAfterMerge;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.call_merge, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                UIText.bodyMedium('Merge Preview'),
              ],
            ),
            UI.spacingVerticalSm,
            ...absorbedOrganisms.map(
              (o) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o.tagId)),
                    Text('${o.measurement.value.toStringAsFixed(0)} $unit'),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.mergedRecordName ?? targetOrganism.tagId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${totalQuantity.toStringAsFixed(0)} $unit',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final OrganismMergeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetOrganism = state.targetOrganism;
    final absorbedOrganisms = state.absorbedOrganisms;

    if (targetOrganism == null) return const SizedBox.shrink();

    final unit = targetOrganism.measurement.unit.symbol;
    final totalQuantity = state.totalQuantityAfterMerge;

    return SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Summary'),
          UI.spacingVerticalMd,
          Card(
            child: ListTile(
              leading: Icon(Icons.star, color: theme.colorScheme.primary),
              title: const Text('Target Record'),
              subtitle: Text(
                state.mergedRecordName ?? targetOrganism.tagId,
              ),
              trailing: Text(
                '${targetOrganism.measurement.value.toStringAsFixed(0)} $unit',
              ),
            ),
          ),
          UI.spacingVerticalSm,
          UIText.bodyMedium(
            'Records to be merged (${absorbedOrganisms.length})',
          ),
          UI.spacingVerticalXs,
          ...absorbedOrganisms.map(
            (organism) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.remove_circle_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(organism.tagId),
                subtitle: Text(
                  '${organism.measurement.value.toStringAsFixed(0)} $unit • '
                  'Will be archived',
                ),
              ),
            ),
          ),
          UI.spacingVerticalMd,
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.check_circle,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              title: Text(
                'Result: ${totalQuantity.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Histories will be merged, absorbed records will be archived',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}