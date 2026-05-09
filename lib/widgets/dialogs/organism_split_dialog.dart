// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/organism_split/organism_split_bloc.dart';
import 'package:seafoundry_app/blocs/organism_split/organism_split_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/common/inherited_species_display.dart';
import 'package:seafoundry_app/widgets/common/locked_text_field.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog_shell.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class OrganismSplitDialog extends StatelessWidget {
  const OrganismSplitDialog({super.key, required this.sourceOrganism});

  final OrganismRecord sourceOrganism;

  static Future<OrganismRecord?> show(
    BuildContext context, {
    required OrganismNode organismNode,
  }) async {
    try {
      await organismNode.awaitLoaded();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'OrganismSplitDialog: Failed to load organism node',
        error,
        stackTrace,
      );
      if (context.mounted) {
        showSafeDialogSnackBar(
          context,
          'Unable to load organism for split. Please try again.',
          isError: true,
        );
      }
      return null;
    }
    if (!context.mounted) return null;

    final nodeState = organismNode.state;
    if (nodeState is! GraphLoadedState<OrganismRecord>) {
      showSafeDialogSnackBar(
        context,
        'Unable to load organism for split. Please try again.',
        isError: true,
      );
      return null;
    }

    final organism = nodeState.record;

    // Validate split is possible
    if (organism.measurement.value <= 1) {
      showSafeDialogSnackBar(
        context,
        'Cannot split: organism quantity must be greater than 1',
        isError: true,
      );
      return null;
    }

    final organismRepository = context.read<OrganismRecordRepository>();
    final graphRepository = context.read<GraphRepository>();

    return showDialog<OrganismRecord?>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) => OrganismSplitBloc(
          sourceOrganism: organism,
          organismRepository: organismRepository,
          graphRepository: graphRepository,
        ),
        child: OrganismSplitDialog(sourceOrganism: organism),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StructureDialogShell<
      OrganismRecord,
      OrganismSplitState,
      OrganismSplitBloc
    >(
      config: StructureDialogConfig<OrganismRecord, OrganismSplitState>(
        icon: Icons.call_split,
        progressTitle: 'Loading split options...',
        submitButtonLabel: 'Split Record',
        autoInitialize: true,
        titleBuilder: (state) => _titleForIndex(state.currentStepIndex),
        stepBuilders: {
          BaseRecordFormStep: (context, state) => _buildStep(context, state),
        },
        successHandler: (context, state) async {
          final newRecord = state.createdRecord;
          if (newRecord != null) {
            showSafeDialogSnackBar(
              context,
              'Created ${newRecord.tagId} with ${newRecord.measurement.value.toStringAsFixed(0)} ${newRecord.measurement.unit.symbol}',
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
        return 'Select Quantity';
      case 1:
        return 'Record Details';
      case 2:
        return 'Review & Confirm';
      default:
        return 'Split Organism';
    }
  }

  Widget _buildStep(BuildContext context, OrganismSplitState state) {
    if (state.loadStatus != RecordFormLoadStatus.success) {
      return const SizedBox.shrink();
    }

    switch (state.currentStepIndex) {
      case 0:
        return _QuantitySelectionStep(state: state);
      case 1:
        return _RecordDetailsStep(state: state);
      case 2:
        return _ReviewStep(state: state, sourceOrganism: sourceOrganism);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _QuantitySelectionStep extends StatelessWidget {
  const _QuantitySelectionStep({required this.state});

  final OrganismSplitState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<OrganismSplitBloc>();
    final sourceOrganism = state.sourceOrganism;
    if (sourceOrganism == null) return const SizedBox.shrink();

    final sourceQuantity = sourceOrganism.measurement.value;
    final splitQuantity = state.splitQuantity;
    final unit = sourceOrganism.measurement.unit.symbol;

    // For qty=2, show informational message
    final isMinimalSplit = sourceQuantity == 2;

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Split from: ${sourceOrganism.tagId}'),
          UIText.caption(
            'Current quantity: ${sourceQuantity.toStringAsFixed(0)} $unit',
          ),
          UI.spacingVerticalMd,
          UIText.bodyMedium('Quantity for new record'),
          UI.spacingVerticalSm,
          if (isMinimalSplit) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: UIText.caption(
                        'Splitting will create two records with 1 $unit each.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            UI.spacingVerticalSm,
          ] else ...[
            Slider(
              value: splitQuantity.clamp(1.0, sourceQuantity - 1),
              min: 1.0,
              max: sourceQuantity - 1,
              divisions: (sourceQuantity - 2).toInt().clamp(1, 100),
              label: splitQuantity.toStringAsFixed(0),
              onChanged: (value) {
                bloc.add(SplitQuantityChanged(value.roundToDouble()));
              },
            ),
          ],
          UI.spacingVerticalMd,
          _QuantityPreviewCard(
            sourceQuantity: sourceQuantity,
            splitQuantity: splitQuantity,
            unit: unit,
          ),
          if (state.splitQuantityInput.displayError != null) ...[
            UI.spacingVerticalSm,
            Text(
              state.splitQuantityInput.displayError!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuantityPreviewCard extends StatelessWidget {
  const _QuantityPreviewCard({
    required this.sourceQuantity,
    required this.splitQuantity,
    required this.unit,
  });

  final double sourceQuantity;
  final double splitQuantity;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final remaining = sourceQuantity - splitQuantity;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  UI.spacingVerticalXs,
                  UIText.caption('Original'),
                  UIText.bodyLarge('${remaining.toStringAsFixed(0)} $unit'),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: theme.colorScheme.outline),
            Expanded(
              child: Column(
                children: [
                  Icon(
                    Icons.add_box_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  UI.spacingVerticalXs,
                  UIText.caption('New Record'),
                  UIText.bodyLarge('${splitQuantity.toStringAsFixed(0)} $unit'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordDetailsStep extends StatefulWidget {
  const _RecordDetailsStep({required this.state});

  final OrganismSplitState state;

  @override
  State<_RecordDetailsStep> createState() => _RecordDetailsStepState();
}

class _RecordDetailsStepState extends State<_RecordDetailsStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.state.splitRecordName ?? widget.state.suggestedRecordName,
    );
    _notesController = TextEditingController(
      text: widget.state.splitNotes,
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
    final bloc = context.read<OrganismSplitBloc>();
    final suggestedName = widget.state.suggestedRecordName;
    final sourceOrganism = widget.state.sourceOrganism;

    // Resolve species from source organism
    final species = sourceOrganism?.speciesId != null
        ? SpeciesRegistry.globalById(sourceOrganism!.speciesId)
        : null;

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Record Details'),
          UI.spacingVerticalSm,
          // Locked Species field - same organism, split into multiple records
          InheritedSpeciesDisplay(
            species: species,
            lockTooltip: 'Same organism, split into multiple records',
            emptyPlaceholder: 'Species not available',
          ),
          UI.spacingVerticalMd,
          // Locked LocalID field - same organism, split into multiple records
          LockedTextField(
            value: sourceOrganism?.localGenetId,
            labelText: 'Local ID',
            tooltipMessage: 'Same organism, split into multiple records',
            prefixIcon: Icons.fingerprint,
          ),
          UI.spacingVerticalMd,
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Name *',
              hintText: 'Enter record name',
              helperText: suggestedName != null
                  ? 'Suggested: $suggestedName'
                  : null,
              prefixIcon: const Icon(Icons.auto_awesome),
              suffixIcon:
                  suggestedName != null && _nameController.text != suggestedName
                  ? IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Use suggested name',
                      onPressed: () {
                        _nameController.text = suggestedName;
                        bloc.add(SplitRecordNameChanged(suggestedName));
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              bloc.add(SplitRecordNameChanged(value));
            },
          ),
          if (widget.state.splitRecordNameInput.displayError != null) ...[
            UI.spacingVerticalSm,
            Text(
              widget.state.splitRecordNameInput.displayError!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          UI.spacingVerticalMd,
          DropdownButtonFormField<PhysicalFormChangeReason>(
            initialValue: widget.state.splitReason,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Reason *',
              hintText: 'Select reason for split',
            ),
            items: PhysicalFormChangeReason.builtins.values.map((reason) {
              return DropdownMenuItem(
                value: reason,
                child: Text(reason.name),
              );
            }).toList(),
            onChanged: (value) {
              bloc.add(SplitReasonChanged(value));
            },
          ),
          if (widget.state.splitReasonInput.displayError != null) ...[
            UI.spacingVerticalSm,
            Text(
              widget.state.splitReasonInput.displayError!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          UI.spacingVerticalMd,
           TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Notes',
              hintText: 'Optional notes about this split',
            ),
            maxLines: 2,
            onChanged: (value) {
              bloc.add(SplitNotesChanged(value));
            },
          ),
          UI.spacingVerticalMd,
          UIText.caption(
            'The new record will inherit the local ID, provenance, genetics, '
            'and full history from the source record.',
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state, required this.sourceOrganism});

  final OrganismSplitState state;
  final OrganismRecord sourceOrganism;

  @override
  Widget build(BuildContext context) {
    final splitQuantity = state.splitQuantity;
    final remainingQuantity = state.remainingQuantity;
    final newRecordName = state.splitRecordName ?? 'New Record';
    final unit = sourceOrganism.measurement.unit.symbol;
    final theme = Theme.of(context);

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UIText.bodyMedium('Summary'),
          UI.spacingVerticalMd,
          _ReviewCard(
            icon: Icons.inventory_2_outlined,
            iconColor: theme.colorScheme.primary,
            title: 'Source Record',
            subtitle: sourceOrganism.tagId,
            trailing:
                '${sourceOrganism.measurement.value.toStringAsFixed(0)} $unit → ${remainingQuantity.toStringAsFixed(0)} $unit',
          ),
          UI.spacingVerticalSm,
          _ReviewCard(
            icon: Icons.add_box_outlined,
            iconColor: theme.colorScheme.secondary,
            title: 'New Record',
            subtitle: newRecordName,
            trailing: '${splitQuantity.toStringAsFixed(0)} $unit',
          ),
          UI.spacingVerticalMd,
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: UIText.caption(
                      'The new record will inherit: local ID (${sourceOrganism.localGenetId}), '
                      'provenance, genetics, life stage history, and measurement history.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          trailing,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
