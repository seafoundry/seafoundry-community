// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/cubits/gene_bank/gene_bank_temperature_monitoring_cubit.dart';
import 'package:seafoundry_app/models/events/gene_bank_temperature_monitoring_event.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import '../components/dialog_scroll_view.dart';
import '../../notifications/toast_overlay.dart';

class GeneBankTemperatureMonitoringDialog extends StatelessWidget {
  const GeneBankTemperatureMonitoringDialog({
    super.key,
    required this.targetNode,
    this.existingEvent,
  });

  final GraphNode targetNode;
  final GeneBankTemperatureMonitoringEvent? existingEvent;

  static Future<GeneBankTemperatureMonitoringEvent?> show(
    BuildContext context, {
    required GraphNode targetNode,
    GeneBankTemperatureMonitoringEvent? existingEvent,
  }) {
    final eventRepository = context.read<EventRepository>();

    return showDialog<GeneBankTemperatureMonitoringEvent>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => BlocProvider(
        create: (_) => GeneBankTemperatureMonitoringCubit(
          eventRepository: eventRepository,
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
        child: GeneBankTemperatureMonitoringDialog(
          targetNode: targetNode,
          existingEvent: existingEvent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      GeneBankTemperatureMonitoringCubit,
      GeneBankTemperatureMonitoringState
    >(
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
        return _GeneBankTemperatureMonitoringDialogContent(state: state);
      },
    );
  }
}

class _GeneBankTemperatureMonitoringDialogContent extends StatefulWidget {
  const _GeneBankTemperatureMonitoringDialogContent({required this.state});

  final GeneBankTemperatureMonitoringState state;

  @override
  State<_GeneBankTemperatureMonitoringDialogContent> createState() =>
      _GeneBankTemperatureMonitoringDialogContentState();
}

class _GeneBankTemperatureMonitoringDialogContentState
    extends State<_GeneBankTemperatureMonitoringDialogContent>
    with SafeDialogMixin<_GeneBankTemperatureMonitoringDialogContent> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _locationController;
  late final TextEditingController _commentController;

  GeneBankTemperatureMonitoringCubit get _cubit =>
      context.read<GeneBankTemperatureMonitoringCubit>();

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController(
      text: widget.state.temperatureCelsius?.toString() ?? '',
    );
    _minController = TextEditingController(
      text: widget.state.minTemperature?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.state.maxTemperature?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: widget.state.measurementLocation ?? '',
    );
    _commentController = TextEditingController(text: widget.state.comment);
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _locationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        state.isEditing ? 'Edit Temperature Reading' : 'Record Temperature',
      ),
      content: SizedBox(
        width: 420,
        child: DialogScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                controller: _temperatureController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Temperature (°C)',
                  border: OutlineInputBorder(),
                  hintText: 'Enter temperature reading',
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.temperatureChanged(double.tryParse(value)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min (°C)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !state.isLoading,
                      onChanged: (value) =>
                          _cubit.minTemperatureChanged(double.tryParse(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max (°C)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !state.isLoading,
                      onChanged: (value) =>
                          _cubit.maxTemperatureChanged(double.tryParse(value)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Within acceptable range'),
                value: state.isWithinRange,
                onChanged: state.isLoading ? null : _cubit.withinRangeChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Measurement location',
                  hintText: 'Tank, tray, or sensor location (optional)',
                  border: OutlineInputBorder(),
                ),
                enabled: !state.isLoading,
                onChanged: (value) =>
                    _cubit.locationChanged(value.isEmpty ? null : value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Additional observations (optional)',
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
      await context.read<GeneBankTemperatureMonitoringCubit>().submit();
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to save gene bank temperature reading',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      ToastOverlay.showSnackBar(context,
        SnackBar(content: Text('Failed to save reading: $error')),
      );
    }
  }
}
