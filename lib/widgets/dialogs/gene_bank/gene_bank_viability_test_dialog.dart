// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/cubits/gene_bank/gene_bank_viability_test_cubit.dart';
import 'package:seafoundry_app/models/events/gene_bank_viability_test_event.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../components/dialog_scroll_view.dart';
import '../../notifications/toast_overlay.dart';

class GeneBankViabilityTestDialog extends StatelessWidget {
  const GeneBankViabilityTestDialog({
    super.key,
    required this.targetNode,
    this.existingEvent,
  });

  final GraphNode targetNode;
  final GeneBankViabilityTestEvent? existingEvent;

  static Future<GeneBankViabilityTestEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    GeneBankViabilityTestEvent? existingEvent,
  }) {
    final eventRepository = context.read<EventRepository>();

    return showDialog<GeneBankViabilityTestEvent>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) => GeneBankViabilityTestCubit(
          eventRepository: eventRepository,
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
        child: GeneBankViabilityTestDialog(
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GeneBankViabilityTestCubit, GeneBankViabilityTestState>(
      listener: (context, state) {
        if (state.createdEvent != null && context.mounted) {
          popSafeDialogContext(context, state.createdEvent);
        }
        if (state.errorMessage != null && state.isLoading == false) {
          showSafeDialogSnackBar(
            context,
            state.errorMessage!,
            isError: true,
          );
        }
      },
      builder: (context, state) {
        return _GeneBankViabilityTestDialogContent(state: state);
      },
    );
  }
}

class _GeneBankViabilityTestDialogContent extends StatefulWidget {
  const _GeneBankViabilityTestDialogContent({required this.state});

  final GeneBankViabilityTestState state;

  @override
  State<_GeneBankViabilityTestDialogContent> createState() =>
      _GeneBankViabilityTestDialogContentState();
}

class _GeneBankViabilityTestDialogContentState
    extends State<_GeneBankViabilityTestDialogContent>
    with SafeDialogMixin<_GeneBankViabilityTestDialogContent> {
  late final TextEditingController _testTypeController;
  late final TextEditingController _viabilityController;
  late final TextEditingController _samplesController;
  late final TextEditingController _resultController;
  late final TextEditingController _notesController;
  late final TextEditingController _commentController;

  GeneBankViabilityTestCubit get _cubit =>
      context.read<GeneBankViabilityTestCubit>();

  @override
  void initState() {
    super.initState();
    _testTypeController = TextEditingController(text: widget.state.testType);
    _viabilityController = TextEditingController(
      text: widget.state.viabilityPercentage?.toString() ?? '',
    );
    _samplesController = TextEditingController(
      text: widget.state.samplesTested?.toString() ?? '',
    );
    _resultController = TextEditingController(text: widget.state.result ?? '');
    _notesController = TextEditingController(
      text: widget.state.testNotes ?? '',
    );
    _commentController = TextEditingController(text: widget.state.comment);
  }

  @override
  void dispose() {
    _testTypeController.dispose();
    _viabilityController.dispose();
    _samplesController.dispose();
    _resultController.dispose();
    _notesController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        state.isEditing ? 'Edit Viability Test' : 'Record Viability Test',
      ),
      content: SizedBox(
        width: 420,
        child: DialogScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errorMessage != null && state.isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    state.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              TextField(
                controller: _testTypeController,
                decoration: const InputDecoration(
                  labelText: 'Test type',
                  hintText: 'e.g. visual, culture, staining',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) => _cubit.testTypeChanged(value.trim()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _viabilityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Viability (%)',
                  hintText: '0 - 100 (optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.viabilityChanged(double.tryParse(value)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _samplesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Samples tested',
                  hintText: 'Number of samples (optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.samplesTestedChanged(int.tryParse(value)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: 'Result',
                  hintText: 'Overall outcome (optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.resultChanged(value.isEmpty ? null : value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Method notes',
                  hintText: 'Methodology or conditions (optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.notesChanged(value.isEmpty ? null : value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional notes',
                  hintText: 'Optional notes for this test',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: _cubit.commentChanged,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : popDialog,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              state.isLoading ? null : () => _submit(context),
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(state.isEditing ? 'Update' : 'Record'),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    try {
      await context.read<GeneBankViabilityTestCubit>().submit();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to save gene bank viability test',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      ToastOverlay.showSnackBar(context,
        SnackBar(content: Text('Failed to save test: $error')),
      );
    }
  }
}
