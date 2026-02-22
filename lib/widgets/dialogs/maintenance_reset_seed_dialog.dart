// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/seeding/seeding_dialog_cubit.dart';
import 'package:seafoundry_app/services/seeding_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_components.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_field_builders.dart';
import 'components/dialog_scroll_view.dart';

/// Developer maintenance dialog for resetting and reseeding demo data.
///
/// This dialog orchestrates the maintenance scripts found in `scripts/` so
/// engineers can wipe and reseed a Firestore dataset without leaving the UI.
class MaintenanceResetSeedDialog extends StatefulWidget {
  const MaintenanceResetSeedDialog({
    super.key,
    this.supportStatusLoader,
    this.sequenceRunner,
    this.seedingService,
  });

  /// Optional override for loading environment support status (used in tests).
  final Future<SeedingSupportStatus?> Function()? supportStatusLoader;

  /// Optional override for executing the seeding sequence (used in tests).
  final Stream<SeedingOutput> Function(List<SeedingInvocation> invocations)?
  sequenceRunner;

  /// Optional override for the seeding service instance (used in tests).
  final SeedingService? seedingService;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => const MaintenanceResetSeedDialog(),
    );
  }

  @override
  State<MaintenanceResetSeedDialog> createState() =>
      _MaintenanceResetSeedDialogState();
}

class _MaintenanceResetSeedDialogState extends State<MaintenanceResetSeedDialog>
    with SafeDialogMixin<MaintenanceResetSeedDialog> {
  static const _modularDefaults = <String, bool>{
    'delete': true,
    'seed_land': true,
    'seed_field': true,
    'seed_gene': true,
    'seed_outplant': true,
    'seed_monitoring': true,
    'seed_history': true,
  };

  static const _modularLabels = <String, String>{
    'delete': 'Delete existing data before seeding',
    'seed_land': 'Seed land nurseries',
    'seed_field': 'Seed field nurseries',
    'seed_gene': 'Seed gene banks',
    'seed_outplant': 'Seed outplant events',
    'seed_monitoring': 'Seed monitoring events',
    'seed_history': 'Seed historical activity',
  };

  final _formKey = GlobalKey<FormState>();
  final _orgController = TextEditingController();
  final _userController = TextEditingController();
  final _user2Controller = TextEditingController();
  final _extraArgsController = TextEditingController();

  late final List<SeedingFieldConfig> _overrideFields;
  late final Map<String, TextEditingController> _overrideControllers;
  late final SeedingService _seedingService =
      widget.seedingService ?? SeedingService();
  Future<SeedingSupportStatus?> Function()? get _supportStatusLoader =>
      widget.supportStatusLoader;
  Stream<SeedingOutput> Function(List<SeedingInvocation>)?
  get _sequenceRunner => widget.sequenceRunner;

  StreamSubscription<SeedingOutput>? _subscription;

  bool _includeGenetics = true;
  bool _includeDataQuality = false;
  bool _includeTypes = false;
  bool _includeSample = false;
  bool _includeModular = false;
  bool _verbose = false;

  final Map<String, bool> _modularToggles = Map<String, bool>.from(
    _modularDefaults,
  );
  List<SeedingInvocation> _lastInvocations = const [];

  bool _isRunning = false;
  bool _isLoadingStatus = true;
  SeedingSupportStatus? _supportStatus;
  List<SeedingOutput> _outputs = const [];

  @override
  void initState() {
    super.initState();
    _overrideFields = SeedingFieldBuilders.resetOverrides();
    _overrideControllers = {
      for (final field in _overrideFields)
        field.key: TextEditingController(text: field.initialValue ?? ''),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillDefaults();
    });
    _loadSupportStatus();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _orgController.dispose();
    _userController.dispose();
    _user2Controller.dispose();
    _extraArgsController.dispose();
    for (final controller in _overrideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _prefillDefaults() async {
    try {
      final currentUser = context.read<CurrentUser>();
      final state = currentUser.state;
      if (state is CurrentUserLoaded) {
        if (_orgController.text.isEmpty) {
          _orgController.text = state.organization.id;
        }
        if (_userController.text.isEmpty) {
          _userController.text = state.user.id;
        }
      }
    } catch (_) {
      // CurrentUser cubit not in scope; user must enter values manually.
    }
  }

  Future<void> _loadSupportStatus() async {
    try {
      SeedingSupportStatus? status;
      if (_supportStatusLoader != null) {
        status = await _supportStatusLoader!.call();
      } else {
        final dartExecutable = await _seedingService.resolveDartExecutable();
        final hasScripts = await _seedingService.areSeedingScriptsAvailable();
        status = SeedingSupportStatus(
          hasDart: dartExecutable != null,
          hasScripts: hasScripts,
          dartExecutable: dartExecutable,
        );
      }
      if (!mounted) return;
      setState(() {
        _supportStatus = status;
        _isLoadingStatus = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _supportStatus = null;
        _isLoadingStatus = false;
      });
    }
  }

  bool get _environmentReady =>
      !_isLoadingStatus && (_supportStatus?.isReady ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_tree, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Maintenance: Reset & Seed'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: DialogScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoadingStatus)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Checking execution environment…'),
                      ],
                    ),
                  )
                else if (_supportStatus != null)
                  SeedingSupportStatusBanner(
                    status: _supportStatus!,
                    isRunning: _isRunning,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unable to verify local seeding environment. Commands may still run, '
                            'but ensure Dart and scripts/seed_*.dart are accessible.',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _buildCredentialSection(theme),
                const SizedBox(height: 16),
                _buildOperationsSection(theme),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _verbose,
                  onChanged: _isRunning
                      ? null
                      : (value) => setState(() => _verbose = value),
                  title: const Text('Enable verbose logging (--verbose)'),
                  subtitle: const Text(
                    'Appends --verbose to each command for additional output.',
                  ),
                ),
                const SizedBox(height: 12),
                _buildAdvancedOverrides(theme),
                const SizedBox(height: 16),
                Text(
                  '⚠️ Developer tool: executes maintenance scripts against the connected Firestore environment. '
                  'Use only with test data.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                if (_outputs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Execution log', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SeedingLogList(outputs: _outputs),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isRunning ? null : popDialog,
          child: const Text('Close'),
        ),
        TextButton.icon(
          onPressed: _isRunning ? null : _copyCommandsToClipboard,
          icon: const Icon(Icons.copy),
          label: const Text('Copy CLI Commands'),
        ),
        Tooltip(
          message: _environmentReady
              ? ''
              : 'Install Flutter/Dart and ensure scripts/seed_*.dart are available.',
          child: ElevatedButton.icon(
            onPressed: (!_environmentReady || _isRunning) ? null : _runSequence,
            icon: _isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? 'Running…' : 'Run Reset & Seed'),
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Credentials', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: _orgController,
          enabled: !_isRunning,
          decoration: const InputDecoration(
            labelText: 'Organization ID',
            hintText: '<ORG_ID>',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Organization ID is required.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _userController,
          enabled: !_isRunning,
          decoration: const InputDecoration(
            labelText: 'Admin User ID',
            hintText: '<ADMIN_USER_ID>',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Admin User ID is required.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _user2Controller,
          enabled: !_isRunning,
          decoration: const InputDecoration(
            labelText: 'Secondary User ID (optional)',
            helperText:
                'Used when seeding additional datasets (transfers, collaborations).',
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Operations', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.refresh, color: Colors.green.shade700),
          title: const Text('Reset & reseed core inventory'),
          subtitle: const Text(
            'Clears existing sites, groups, corals, and genets, then seeds nurseries, '
            'gene banks, and outplant events.',
          ),
          trailing: Icon(Icons.check_circle, color: theme.colorScheme.primary),
        ),
        CheckboxListTile(
          value: _includeGenetics,
          onChanged: _isRunning
              ? null
              : (value) => setState(() => _includeGenetics = value ?? false),
          title: const Text('Include genetics dataset'),
          subtitle: const Text(
            'Runs seed_inventory.dart for genetics-focused demo records.',
          ),
          secondary: const Icon(Icons.science, color: Colors.deepPurple),
        ),
        CheckboxListTile(
          value: _includeDataQuality,
          onChanged: _isRunning
              ? null
              : (value) => setState(() => _includeDataQuality = value ?? false),
          title: const Text('Include data quality scenario'),
          subtitle: const Text(
            'Adds data quality workflows and historical records.',
          ),
          secondary: Icon(
            Icons.stacked_bar_chart,
            color: Colors.amber.shade700,
          ),
        ),
        CheckboxListTile(
          value: _includeTypes,
          onChanged: _isRunning
              ? null
              : (value) => setState(() => _includeTypes = value ?? false),
          title: const Text('Seed reference types & lookup data'),
          subtitle: const Text(
            'Ensures species, coral types, and lookup tables are populated.',
          ),
          secondary: const Icon(Icons.category, color: Colors.blueGrey),
        ),
        CheckboxListTile(
          value: _includeSample,
          onChanged: _isRunning
              ? null
              : (value) => setState(() => _includeSample = value ?? false),
          title: const Text('Seed lightweight sample dataset'),
          subtitle: const Text(
            'Adds a minimal dataset useful for quick demos or workshops.',
          ),
          secondary: Icon(Icons.bolt, color: Colors.orangeAccent.shade200),
        ),
        CheckboxListTile(
          value: _includeModular,
          onChanged: _isRunning
              ? null
              : (value) => setState(() => _includeModular = value ?? false),
          title: const Text('Seed modular dataset'),
          subtitle: const Text(
            'Runs seed_modular.dart to generate comprehensive nurseries, genetics, '
            'outplant, and monitoring data.',
          ),
          secondary: const Icon(Icons.grid_view, color: Colors.teal),
        ),
        if (_includeModular)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              child: Column(
                children: _modularToggles.entries.map((entry) {
                  final description = _modularLabels[entry.key] ?? entry.key;
                  return CheckboxListTile(
                    value: entry.value,
                    onChanged: _isRunning
                        ? null
                        : (value) => setState(
                            () => _modularToggles[entry.key] = value ?? false,
                          ),
                    title: Text(description),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvancedOverrides(ThemeData theme) {
    return ExpansionTile(
      title: const Text('Advanced inventory overrides'),
      subtitle: const Text('Optional parameter overrides for reset scripts.'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text(
            'Provide ranges using min-max format (e.g. 10-15). Leave blank to use script defaults.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        for (final field in _overrideFields)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextFormField(
              controller: _overrideControllers[field.key],
              enabled: !_isRunning,
              decoration: InputDecoration(
                labelText: field.label,
                helperText: field.helper,
                hintText: field.placeholder,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: TextFormField(
            controller: _extraArgsController,
            enabled: !_isRunning,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Additional CLI flags',
              helperText: 'Optional extra flags appended to each command.',
              hintText: '--flag=value --another=10',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runSequence() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final invocations = await _buildInvocationsList();

    if (!mounted) return;
    setState(() {
      _isRunning = true;
      _outputs = const [];
      _lastInvocations = invocations;
    });

    try {
      _subscription?.cancel();
      final stream =
          _sequenceRunner?.call(invocations) ??
          _seedingService.executeSeedingSequence(invocations);
      _subscription = stream.listen(
        _handleSeedingOutput,
        onError: _handleSeedingError,
        onDone: _handleSeedingDone,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
      });
      showDialogSnackBar(
        'Failed to start maintenance reset: $error',
        isError: true,
      );
    }
  }

  void _handleSeedingOutput(SeedingOutput output) {
    if (!mounted) return;
    setState(() {
      _outputs = List<SeedingOutput>.from(_outputs)..add(output);
    });
  }

  void _handleSeedingError(Object error) {
    if (!mounted) return;
    setState(() {
      _isRunning = false;
    });
    showDialogSnackBar('Seeding failed: $error', isError: true);
  }

  void _handleSeedingDone() {
    if (!mounted) return;
    final hasError = _outputs.any(
      (output) => output.type == SeedingOutputType.error,
    );
    setState(() {
      _isRunning = false;
    });
    showDialogSnackBar(
      hasError
          ? 'Maintenance reset completed with warnings/errors.'
          : 'Maintenance reset completed successfully.',
      isError: hasError,
      isSuccess: !hasError,
    );
  }

  Future<void> _copyCommandsToClipboard() async {
    final invocations = _lastInvocations.isNotEmpty
        ? _lastInvocations
        : await _buildInvocationsList();
    if (!mounted) return;
    if (invocations.isEmpty) {
      showDialogSnackBar('No commands to copy.');
      return;
    }

    if (_lastInvocations.isEmpty) {
      setState(() {
        _lastInvocations = invocations;
      });
    }

    final buffer = StringBuffer();
    for (final invocation in invocations) {
      buffer.writeln(invocation.displayCommand);
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    showDialogSnackBar('CLI commands copied to clipboard.', isSuccess: true);
  }

  Future<SeedingInvocation> _buildInvocation(SeedingCommand command) async {
    final cubit = SeedingDialogCubit(
      seedingService: _seedingService,
      command: command,
      defaultOrgId: _orgController.text.trim(),
      defaultUserId: _userController.text.trim(),
    );

    for (final field in cubit.config.fields) {
      switch (field.key) {
        case 'org':
          cubit.textFieldChanged(field.key, _orgController.text.trim());
          break;
        case 'user':
          cubit.textFieldChanged(field.key, _userController.text.trim());
          break;
        case 'user2':
          final user2 = _user2Controller.text.trim();
          if (user2.isNotEmpty) {
            cubit.textFieldChanged(field.key, user2);
          }
          break;
        case 'additional_args':
          final extra = _extraArgsController.text.trim();
          if (extra.isNotEmpty) {
            cubit.textFieldChanged(field.key, extra);
          }
          break;
        default:
          final override = _overrideControllers[field.key];
          if (override != null) {
            final value = override.text.trim();
            if (value.isNotEmpty) {
              cubit.textFieldChanged(field.key, value);
            }
          }
      }
    }

    if (command == SeedingCommand.modular && _includeModular) {
      for (final entry in _modularToggles.entries) {
        cubit.boolFieldChanged(entry.key, entry.value);
      }
    }

    if (_verbose) {
      cubit.verboseChanged(true);
    }

    final invocation = cubit.buildInvocation(includeVerbose: _verbose);
    await cubit.close();
    return invocation;
  }

  Future<List<SeedingInvocation>> _buildInvocationsList() async {
    final commands = <SeedingCommand>[
      SeedingCommand.fresh,
      if (_includeGenetics) SeedingCommand.genetics,
      if (_includeDataQuality) SeedingCommand.dataQuality,
      if (_includeTypes) SeedingCommand.types,
      if (_includeSample) SeedingCommand.sample,
      if (_includeModular) SeedingCommand.modular,
    ];

    final invocations = <SeedingInvocation>[];
    for (final command in commands) {
      invocations.add(await _buildInvocation(command));
    }
    return invocations;
  }
}