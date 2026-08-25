import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/organism_movement/organism_movement_bloc.dart';
import 'package:seafoundry_community/cubits/organism_movement/organism_movement_state.dart';
import 'package:seafoundry_community/models/graph/graph_node_state.dart';
import 'package:seafoundry_community/models/graph/group_node.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_async.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_community/widgets/dialogs/structure_dialog_shell.dart';
import 'package:seafoundry_community/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_community/widgets/ui.dart';
import 'package:seafoundry_community/widgets/ui_text.dart';

class OrganismMovementDialog extends StatelessWidget {
  const OrganismMovementDialog({super.key, required this.sourceGroup});

  final Group sourceGroup;

  static Future<bool?> show(
    BuildContext context, {
    required GroupNode sourceGroupNode,
    Set<String>? allowedOrganismIds,
    Set<String>? initialSelectedOrganismIds,
  }) async {
    await sourceGroupNode.awaitLoaded();
    if (!context.mounted) return null;

    final nodeState = sourceGroupNode.state;
    if (nodeState is! GraphLoadedState<Group>) {
      throw Exception('Failed to load source group');
    }

    final repositories = context.safeReadAll(() => (
          context.read<GroupRepository>(),
          context.read<OrganismRecordRepository>(),
          context.read<GraphRepository>(),
        ));
    if (repositories == null) {
      showSafeDialogSnackBar(
        context,
        'Move tools are still loading. Please try again.',
        isError: true,
      );
      return null;
    }
    final (groupRepository, organismRepository, graphRepository) = repositories;

    final result = await showDialog<OrganismRecord?>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: groupRepository),
          RepositoryProvider.value(value: organismRepository),
          RepositoryProvider.value(value: graphRepository),
        ],
        child: BlocProvider(
          create: (_) => OrganismMovementBloc(
            sourceGroup: nodeState.record,
            organismRepository: organismRepository,
            groupRepository: groupRepository,
            graphRepository: graphRepository,
            allowedOrganismIds: allowedOrganismIds,
            initialSelectedOrganismIds: initialSelectedOrganismIds,
          ),
          child: OrganismMovementDialog(sourceGroup: nodeState.record),
        ),
      ),
    );

    if (result == null) return null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StructureDialogShell<OrganismRecord, OrganismMovementState,
        OrganismMovementBloc>(
      config:
          StructureDialogConfig<OrganismRecord, OrganismMovementState>(
        icon: Icons.compare_arrows_outlined,
        progressTitle: 'Loading organism movement…',
        submitButtonLabel: 'Move Organisms',
        autoInitialize: true,
        titleBuilder: (state) => _titleForIndex(state.currentStepIndex),
        stepBuilders: {
          BaseRecordFormStep: (context, state) => _buildStep(context, state),
        },
        successHandler: (context, state) async {
          showSafeDialogSnackBar(
            context,
            'Moved ${state.selectedOrganismIds.value?.length ?? 0} organism(s).',
            isSuccess: true,
          );
        },
        resultBuilder: (state) => state.createdRecord,
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Select Organisms';
      case 1:
        return 'Select Target Structure';
      case 2:
        return 'Review & Confirm';
      default:
        return 'Move Organisms';
    }
  }

  Widget _buildStep(BuildContext context, OrganismMovementState state) {
    if (state.loadStatus != RecordFormLoadStatus.success) {
      return const SizedBox.shrink();
    }

    switch (state.currentStepIndex) {
      case 0:
        return _OrganismSelectionStep(state: state);
      case 1:
        return _TargetSelectionStep(state: state);
      case 2:
        return _ReviewStep(state: state, sourceGroup: sourceGroup);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OrganismSelectionStep extends StatelessWidget {
  const _OrganismSelectionStep({required this.state});

  final OrganismMovementState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OrganismMovementBloc>();
    final selectedIds = state.selectedOrganismIds.value ?? <String>{};
    final quantities = state.selectedQuantities.value ?? const <String, int>{};

    if (state.availableOrganisms.isEmpty) {
      return SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.info_outline, color: Colors.orange, size: 32),
            SizedBox(height: 12),
            Text('There are no organisms available to move in this group.'),
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
          UIText.bodyMedium('Select Organisms to Move'),
          UIText.caption(
            '${selectedIds.length} of ${state.availableOrganisms.length} selected',
          ),
          UI.spacingVerticalSm,
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  final allIds =
                      state.availableOrganisms.map((o) => o.id).toSet();
                  final allQuantities = {
                    for (final organism in state.availableOrganisms)
                      organism.id: organism.measurement.value.toInt(),
                  };
                  bloc.add(RecordIdSetChanged(allIds));
                  bloc.add(QuantityMapChanged(allQuantities));
                },
                icon: const Icon(Icons.check_box, size: 16),
                label: const Text('Select All'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  bloc.add(const RecordIdSetChanged(<String>{}));
                  bloc.add(const QuantityMapChanged(<String, int>{}));
                },
                icon: const Icon(Icons.check_box_outline_blank, size: 16),
                label: const Text('Clear All'),
              ),
            ],
          ),
          UI.spacingVerticalSm,
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.availableOrganisms.length,
              itemBuilder: (context, index) {
                final organism = state.availableOrganisms[index];
                final isSelected = selectedIds.contains(organism.id);
                final currentQuantity = organism.measurement.value.toInt();
                final selectedQuantity =
                    quantities[organism.id] ?? currentQuantity;

                return CheckboxListTile(
                  value: isSelected,
                  title: Text(organism.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currentQuantity available • ${organism.organismKind.metadata.displayName}',
                      ),
                      if (isSelected && currentQuantity > 1)
                        _QuantitySelector(
                          current: selectedQuantity,
                          max: currentQuantity,
                          onChanged: (value) {
                            final updated = Map<String, int>.from(quantities)
                              ..[organism.id] = value;
                            bloc.add(QuantityMapChanged(updated));
                          },
                        ),
                    ],
                  ),
                  onChanged: (selected) {
                    final updatedIds = Set<String>.from(selectedIds);
                    final updatedQuantities = Map<String, int>.from(quantities);
                    if (selected == true) {
                      updatedIds.add(organism.id);
                      updatedQuantities[organism.id] = currentQuantity;
                    } else {
                      updatedIds.remove(organism.id);
                      updatedQuantities.remove(organism.id);
                    }
                    bloc.add(RecordIdSetChanged(updatedIds));
                    bloc.add(QuantityMapChanged(updatedQuantities));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetSelectionStep extends StatelessWidget {
  const _TargetSelectionStep({required this.state});

  final OrganismMovementState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OrganismMovementBloc>();
    final targetGroupId = state.targetGroupId;

    if (state.availableGroups.isEmpty) {
      return SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning, color: Colors.orange, size: 32),
            SizedBox(height: 12),
            Text('No other groups available. Create a target group first.'),
          ],
        ),
      );
    }

    return SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIText.bodyMedium('Select Target Structure'),
          UI.spacingVerticalSm,
          DropdownButtonFormField<String>(
            initialValue: targetGroupId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Select target structure',
            ),
            items: state.availableGroups
                .map(
                  (group) => DropdownMenuItem(
                    value: group.id,
                    child: Text(group.name),
                  ),
                )
                .toList(),
            onChanged: (value) => bloc.add(TargetGroupChanged(value)),
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state, required this.sourceGroup});

  final OrganismMovementState state;
  final Group sourceGroup;

  @override
  Widget build(BuildContext context) {
    final selectedIds = state.selectedOrganismIds.value ?? <String>{};
    final selectedOrganisms = state.availableOrganisms
        .where((organism) => selectedIds.contains(organism.id))
        .toList();
    final targetGroup = state.availableGroups.firstWhere(
      (group) => group.id == state.targetGroupId,
      orElse: () => state.availableGroups.first,
    );
    final quantities = state.selectedQuantities.value ?? const <String, int>{};

    return SizedBox(
      width: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Summary'),
          UI.spacingVerticalSm,
          _ReviewTile(
            icon: Icons.folder_open,
            title: 'Source Structure',
            body: sourceGroup.name,
          ),
          UI.spacingVerticalSm,
          _ReviewTile(
            icon: Icons.outbox,
            title: 'Target Structure',
            body: targetGroup.name,
          ),
          UI.spacingVerticalSm,
          UIText.bodyMedium('Organisms (${selectedOrganisms.length})'),
          UI.spacingVerticalXs,
          ...selectedOrganisms.map(
            (organism) {
              final currentQuantity = organism.measurement.value.toInt();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.water_drop_outlined, size: 18),
                title: Text(organism.name),
                subtitle: Text(
                  'Moving ${quantities[organism.id] ?? currentQuantity} of $currentQuantity',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.current,
    required this.max,
    required this.onChanged,
  });

  final int current;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: current > 1 ? () => onChanged(current - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('$current of $max'),
        ),
        IconButton(
          onPressed: current < max ? () => onChanged(current + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(body),
      ),
    );
  }
}
