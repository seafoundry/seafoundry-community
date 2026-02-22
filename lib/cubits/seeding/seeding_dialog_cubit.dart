// @tier: community
import 'dart:async';

import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/seeding/seeding_dialog_state.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/seeding_service.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_field_builders.dart';

class SeedingDialogCubit extends SafeCubit<SeedingDialogState>
    with CubitStreamSubscriptionMixin {
  SeedingDialogCubit({
    required SeedingService seedingService,
    required SeedingCommand command,
    String? defaultOrgId,
    String? defaultUserId,
  })  : _seedingService = seedingService,
        _command = command,
        _config = _buildCommandConfig(command, defaultOrgId, defaultUserId),
        super(SeedingDialogState(
          configSupportsExecution: _buildCommandConfig(command, defaultOrgId, defaultUserId).supportsExecution,
        )) {
    _initializeFields();
    _checkSupport();
  }

  final SeedingService _seedingService;
  final SeedingCommand _command;
  final SeedingCommandConfig _config;

  SeedingCommand get command => _command;
  SeedingCommandConfig get config => _config;

  static SeedingCommandConfig _buildCommandConfig(
    SeedingCommand command,
    String? defaultOrgId,
    String? defaultUserId,
  ) {
    switch (command) {
      case SeedingCommand.fresh:
      case SeedingCommand.nurseries:
      case SeedingCommand.all:
      case SeedingCommand.genetics:
      case SeedingCommand.dataQuality:
      case SeedingCommand.types:
      case SeedingCommand.sample:
      case SeedingCommand.modular:
        // Unified to the single active seeding script
        return SeedingCommandConfig(
          executable: 'dart',
          scriptPath: 'scripts/reset_and_seed_inventory.dart',
          fields: [
            SeedingFieldBuilders.org(defaultOrgId),
            SeedingFieldBuilders.user(defaultUserId),
            ...SeedingFieldBuilders.resetOverrides(),
            SeedingFieldBuilders.extraArgs(),
          ],
        );
      case SeedingCommand.clear:
        return SeedingCommandConfig.unsupported();
    }
  }

  void _initializeFields() {
    final textValues = <String, String>{};
    final boolValues = <String, bool>{};

    for (final field in _config.fields.where((f) => !f.isBoolean)) {
      textValues[field.key] = field.initialValue ?? '';
    }
    for (final field in _config.fields.where((f) => f.isBoolean)) {
      boolValues[field.key] = field.initialBool;
    }

    emit(state.copyWith(
      textFieldValues: textValues,
      boolFieldValues: boolValues,
    ));
  }

  Future<void> _checkSupport() async {
    emit(state.copyWith(isLoadingSupport: true));

    try {
      final dartExecutable = await _seedingService.resolveDartExecutable();
      final hasDart = dartExecutable != null;
      final hasScripts = await _seedingService.areSeedingScriptsAvailable();
      final status = SeedingSupportStatus(
        hasDart: hasDart,
        hasScripts: hasScripts,
        dartExecutable: dartExecutable,
      );

      emit(state.copyWith(
        supportStatus: status,
        isLoadingSupport: false,
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to check seeding support: $e',
        {'stackTrace': stackTrace.toString()},
      );
      emit(state.copyWith(
        isLoadingSupport: false,
        clearSupportStatus: true,
      ));
    }
  }

  void textFieldChanged(String key, String value) {
    final updated = Map<String, String>.from(state.textFieldValues);
    updated[key] = value;
    emit(state.copyWith(textFieldValues: updated));
  }

  void boolFieldChanged(String key, bool value) {
    final updated = Map<String, bool>.from(state.boolFieldValues);
    updated[key] = value;
    emit(state.copyWith(boolFieldValues: updated));
  }

  void verboseChanged(bool verbose) {
    emit(state.copyWith(verbose: verbose));
  }

  void addOutput(SeedingOutput output) {
    final updated = List<SeedingOutput>.from(state.outputs)..add(output);
    emit(state.copyWith(outputs: updated));
  }

  SeedingInvocation buildInvocation({required bool includeVerbose}) {
    final args = _buildArgumentsList(includeVerbose: includeVerbose);
    return SeedingInvocation(
      command: _command,
      executable: _config.executable,
      args: args,
      displayCommand: buildCommandString(args: args, includeVerbose: includeVerbose),
    );
  }

  String buildCommandString({List<String>? args, required bool includeVerbose}) {
    if (!state.supportsExecution) {
      return 'Command executes through the maintenance tools.';
    }
    final effectiveArgs = args ?? _buildArgumentsList(includeVerbose: includeVerbose);
    final executable = state.supportStatus?.dartExecutable ?? _config.executable;
    return '$executable ${_joinArgs(effectiveArgs)}';
  }

  List<String> _buildArgumentsList({required bool includeVerbose}) {
    final args = <String>['run', _config.scriptPath];

    for (final field in _config.fields) {
      if (field.isVisible != null &&
          !field.isVisible!(state.boolFieldValues) &&
          field.type != SeedingFieldType.bool) {
        continue;
      }
      if (field.type == SeedingFieldType.bool) {
        final value = state.boolFieldValues[field.key] ?? field.initialBool;
        if (field.flagName == null) continue;
        if (!value && field.omitWhenFalse) {
          continue;
        }
        if (field.flagOnly) {
          args.add('--${field.flagName}');
        } else {
          args.add('--${field.flagName}=${value.toString()}');
        }
      } else {
        final text = state.textFieldValues[field.key] ?? '';
        if (text.trim().isEmpty) continue;
        if (field.flagName == null) {
          args.addAll(_tokenizeArgs(text));
        } else {
          args.add('--${field.flagName}=${text.trim()}');
        }
      }
    }

    if (includeVerbose) {
      args.add('--verbose');
    }

    return args;
  }

  String _joinArgs(List<String> args) {
    return args
        .map(
          (arg) => arg.contains(' ') ? '"${arg.replaceAll('"', '\\"')}"' : arg,
        )
        .join(' ');
  }

  List<String> _tokenizeArgs(String input) {
    final regex = RegExp(r'("[^"]+"|\S+)');
    return regex.allMatches(input).map((match) => match.group(0)!).map((token) {
      if (token.startsWith('"') && token.endsWith('"')) {
        return token.substring(1, token.length - 1);
      }
      return token;
    }).toList();
  }

  Future<void> runCommand(SeedingInvocation invocation) async {
    if (!state.canRun || !state.supportsExecution) return;

    emit(state.copyWith(isRunning: true, clearOutputs: true));

    listenWithKey<SeedingOutput>(
      'seeding',
      _seedingService.executeSeedingCommand(invocation),
      onData: (event) {
        if (isClosed) return;
        addOutput(event);
        if (event.type == SeedingOutputType.success ||
            event.type == SeedingOutputType.error) {
          // The widget will handle showing snackbars
        }
      },
      onError: (error, _) {
        if (isClosed) return;
        emit(state.copyWith(isRunning: false));
        addOutput(
          SeedingOutput(
            type: SeedingOutputType.error,
            command: invocation.command,
            message: '$error',
          ),
        );
      },
      onDone: () {
        if (isClosed) return;
        emit(state.copyWith(isRunning: false));
      },
    );
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
}
