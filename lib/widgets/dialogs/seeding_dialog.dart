// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/seeding/seeding_dialog_cubit.dart';
import 'package:seafoundry_app/cubits/seeding/seeding_dialog_state.dart';
import 'package:seafoundry_app/services/seeding_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/maintenance_reset_seed_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_components.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog that surfaces CLI commands for seeding/reset tooling.
class SeedingDialog extends StatelessWidget {
  final SeedingCommand command;
  final bool showAdvancedOptions;
  final String? defaultOrgId;
  final String? defaultUserId;

  const SeedingDialog({
    super.key,
    required this.command,
    this.showAdvancedOptions = false,
    this.defaultOrgId,
    this.defaultUserId,
  });

  static Future<void> show(
    BuildContext context, {
    required SeedingCommand command,
    bool showAdvancedOptions = false,
    String? defaultOrgId,
    String? defaultUserId,
  }) async {
    await showDialog(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      barrierDismissible: false,
      builder: (_) => SeedingDialog(
        command: command,
        showAdvancedOptions: showAdvancedOptions,
        defaultOrgId: defaultOrgId,
        defaultUserId: defaultUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SeedingDialogCubit(
        seedingService: SeedingService(),
        command: command,
        defaultOrgId: defaultOrgId,
        defaultUserId: defaultUserId,
      ),
      child: _SeedingDialogView(
        command: command,
        showAdvancedOptions: showAdvancedOptions,
      ),
    );
  }
}

/// Internal StatefulWidget for SeedingDialog view
///
/// **Migration Status**: Remains StatefulWidget (legitimate use case)
///
/// **Why StatefulWidget**:
/// - Manages FormState (`_formKey`) which requires widget lifecycle
/// - Handles async seeding operations with progress tracking
/// - Manages TextEditingController instances for CLI command inputs
/// - Requires lifecycle hooks for proper form validation and submission
///
/// **Architecture**: Uses Cubit (`SeedingDialogCubit`) for business logic,
/// but StatefulWidget wrapper required for form lifecycle and controller management.
/// FormState pattern is appropriate for multi-field validation and submission.
class _SeedingDialogView extends StatefulWidget {
  const _SeedingDialogView({
    required this.command,
    required this.showAdvancedOptions,
  });

  final SeedingCommand command;
  final bool showAdvancedOptions;

  @override
  State<_SeedingDialogView> createState() => _SeedingDialogViewState();
}

class _SeedingDialogViewState extends State<_SeedingDialogView>
    with SafeDialogMixin<_SeedingDialogView> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  final Map<String, bool> _isUpdatingController = {};
  int _lastShownOutputIndex = -1;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SeedingDialogCubit>();
    _textControllers = {};

    // Initialize controllers from cubit state
    for (final field in cubit.config.fields.where((f) => !f.isBoolean)) {
      final initialValue =
          cubit.state.textFieldValues[field.key] ?? field.initialValue ?? '';
      final controller = TextEditingController(text: initialValue);
      controller.addListener(
        () => _onFieldChanged(cubit, field.key, controller.text),
      );
      _textControllers[field.key] = controller;
      _isUpdatingController[field.key] = false;
    }
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged(SeedingDialogCubit cubit, String key, String value) {
    if (_isUpdatingController[key] == true) return;
    cubit.textFieldChanged(key, value);
  }

  void _copyCommand(SeedingDialogCubit cubit, SeedingDialogState state) {
    if (!state.supportsExecution) {
      showDialogSnackBar(
        'This action is available via the maintenance tools.',
        isError: true,
      );
      return;
    }
    final includeVerbose =
        widget.showAdvancedOptions && state.supportsExecution && state.verbose;
    final command = cubit.buildCommandString(includeVerbose: includeVerbose);
    Clipboard.setData(ClipboardData(text: command));
    showDialogSnackBar('Command copied to clipboard', isSuccess: true);
  }

  Future<void> _runCommand(
    SeedingDialogCubit cubit,
    SeedingDialogState state,
  ) async {
    if (!state.supportsExecution) {
      showDialogSnackBar(
        'Use the dedicated maintenance dialog for this task.',
        isError: true,
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!state.canRun) {
      showDialogSnackBar(
        'Local seeding tooling unavailable. Copy the command to run manually.',
        isError: true,
      );
      return;
    }

    final includeVerbose =
        widget.showAdvancedOptions && state.supportsExecution && state.verbose;
    final invocation = cubit.buildInvocation(includeVerbose: includeVerbose);
    await cubit.runCommand(invocation);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SeedingDialogCubit, SeedingDialogState>(
      listener: (context, state) {
        // Sync controllers with cubit state
        for (final entry in _textControllers.entries) {
          final cubitValue = state.textFieldValues[entry.key] ?? '';
          if (entry.value.text != cubitValue) {
            _isUpdatingController[entry.key] = true;
            entry.value.value = entry.value.value.copyWith(
              text: cubitValue,
              selection: TextSelection.collapsed(offset: cubitValue.length),
            );
            _isUpdatingController[entry.key] = false;
          }
        }

        // Show snackbars for new output events (avoid duplicates)
        final outputs = state.outputs;
        if (outputs.length > _lastShownOutputIndex + 1) {
          for (int i = _lastShownOutputIndex + 1; i < outputs.length; i++) {
            final output = outputs[i];
            if (output.type == SeedingOutputType.success ||
                output.type == SeedingOutputType.error) {
              showDialogSnackBar(
                output.message,
                isError: output.type == SeedingOutputType.error,
                isSuccess: output.type == SeedingOutputType.success,
              );
            }
          }
          _lastShownOutputIndex = outputs.length - 1;
        }
      },
      child: BlocBuilder<SeedingDialogCubit, SeedingDialogState>(
        builder: (context, state) {
          final cubit = context.read<SeedingDialogCubit>();
          final advancedOptionsEnabled =
              widget.showAdvancedOptions && state.supportsExecution;
          final includeVerbose =
              widget.showAdvancedOptions &&
              state.supportsExecution &&
              state.verbose;
          final commandPreview = state.supportsExecution
              ? cubit.buildCommandString(includeVerbose: includeVerbose)
              : 'Command executes through the maintenance tools.';

          final showMaintenanceButton =
              widget.command == SeedingCommand.nurseries ||
              widget.command == SeedingCommand.clear;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  _getCommandIcon(widget.command),
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(widget.command.label),
              ],
            ),
            content: SizedBox(
              width: 700,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: DialogScrollView(
                  padding: const EdgeInsets.only(right: 4),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UIText.bodyMedium(widget.command.description),
                        if (widget.command == SeedingCommand.modular) ...[
                          UI.spacingVerticalSm,
                          UIText.bodySmall(
                            'Genetics data is seeded automatically before nursery, outplant, monitoring, or history tasks.',
                            color: UI.textSecondaryColor,
                          ),
                        ],
                        UI.spacingVerticalMd,
                        if (state.isLoadingSupport)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Checking local seeding tooling...'),
                            ],
                          )
                        else if (state.supportStatus != null)
                          SeedingSupportStatusBanner(
                            status: state.supportStatus!,
                            isRunning: state.isRunning,
                          ),
                        UI.spacingVerticalMd,
                        ..._buildFieldSections(cubit, state),
                        if (advancedOptionsEnabled) ...[
                          UI.spacingVerticalSm,
                          CheckboxListTile(
                            title: const Text('Verbose output'),
                            subtitle: const Text(
                              'Append --verbose to the command',
                            ),
                            value: state.verbose,
                            onChanged: (value) {
                              cubit.verboseChanged(value ?? false);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                        UI.spacingVerticalMd,
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            commandPreview,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        UI.spacingVerticalSm,
                        UIText.bodySmall(
                          state.supportsExecution
                              ? 'Update parameters as needed, then run from here or copy for external use.'
                              : 'Run this flow from the Reset & Seed dialog.',
                          color: UI.textSecondaryColor,
                        ),
                        if (state.outputs.isNotEmpty) ...[
                          UI.spacingVerticalMd,
                          SeedingLogList(outputs: state.outputs),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => popDialog(),
                child: const Text('Close'),
              ),
              if (showMaintenanceButton)
                OutlinedButton.icon(
                  onPressed: () async {
                    // CRITICAL: Show nested dialog BEFORE popping to keep context valid
                    await MaintenanceResetSeedDialog.show(context);
                    if (mounted) popDialog();
                  },
                  icon: const Icon(Icons.account_tree),
                  label: const Text('Open Reset & Seed'),
                ),
              TextButton.icon(
                onPressed: state.supportsExecution
                    ? () => _copyCommand(cubit, state)
                    : null,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Command'),
              ),
              Builder(
                builder: (context) {
                  final runButton = ElevatedButton.icon(
                    onPressed: state.canRun
                        ? () => _runCommand(cubit, state)
                        : null,
                    icon: state.isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(state.isRunning ? 'Running…' : 'Run Now'),
                  );

                  if (state.canRun) {
                    return runButton;
                  }

                  return Tooltip(
                    message: state.isRunning
                        ? 'Command is in progress'
                        : state.supportsExecution
                        ? 'Local tooling unavailable; copy the command to run manually.'
                        : 'Run this via maintenance tools.',
                    child: runButton,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFieldSections(
    SeedingDialogCubit cubit,
    SeedingDialogState state,
  ) {
    final theme = Theme.of(context);
    bool isVisible(SeedingFieldConfig field) {
      if (field.isVisible == null) return true;
      return field.isVisible!(state.boolFieldValues);
    }

    final basicFields = cubit.config.fields
        .where((field) => !field.advanced && isVisible(field))
        .map((field) => _buildField(cubit, state, field));
    final advancedFields = cubit.config.fields
        .where((field) => field.advanced && isVisible(field))
        .map((field) => _buildField(cubit, state, field))
        .toList();

    return [
      ...basicFields,
      if (advancedFields.isNotEmpty) ...[
        UI.spacingVerticalSm,
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: const Text('Advanced overrides'),
              subtitle: const Text('Fine-tune structure counts and ranges'),
              children: advancedFields,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildField(
    SeedingDialogCubit cubit,
    SeedingDialogState state,
    SeedingFieldConfig config,
  ) {
    switch (config.type) {
      case SeedingFieldType.bool:
        return SwitchListTile.adaptive(
          title: Text(config.label),
          subtitle: config.helper == null ? null : Text(config.helper!),
          value: state.boolFieldValues[config.key] ?? config.initialBool,
          onChanged: (value) {
            cubit.boolFieldChanged(config.key, value);
          },
        );
      case SeedingFieldType.textarea:
        final controller = _textControllers[config.key]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: config.label,
              helperText: config.helper,
              hintText: config.placeholder,
            ),
            validator: config.required
                ? (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null
                : null,
          ),
        );
      case SeedingFieldType.text:
        final controller = _textControllers[config.key]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: config.label,
              helperText: config.helper,
              hintText: config.placeholder,
            ),
            validator: config.required
                ? (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null
                : null,
          ),
        );
    }
  }

  IconData _getCommandIcon(SeedingCommand command) {
    switch (command) {
      case SeedingCommand.fresh:
        return Icons.refresh;
      case SeedingCommand.all:
        return Icons.storage;
      case SeedingCommand.types:
        return Icons.category;
      case SeedingCommand.sample:
        return Icons.data_object;
      case SeedingCommand.clear:
        return Icons.delete_forever;
      case SeedingCommand.genetics:
        return Icons.biotech;
      case SeedingCommand.nurseries:
        return Icons.account_tree;
      case SeedingCommand.dataQuality:
        return Icons.build;
      case SeedingCommand.modular:
        return Icons.tune;
    }
  }
}