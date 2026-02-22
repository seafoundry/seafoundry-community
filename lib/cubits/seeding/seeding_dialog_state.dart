// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/services/seeding_service.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';

class SeedingDialogState extends Equatable {
  const SeedingDialogState({
    this.supportStatus,
    this.isLoadingSupport = true,
    this.isRunning = false,
    this.verbose = false,
    this.outputs = const [],
    this.textFieldValues = const {},
    this.boolFieldValues = const {},
    this.configSupportsExecution = true,
  });

  final SeedingSupportStatus? supportStatus;
  final bool isLoadingSupport;
  final bool isRunning;
  final bool verbose;
  final List<SeedingOutput> outputs;
  final Map<String, String> textFieldValues;
  final Map<String, bool> boolFieldValues;
  final bool configSupportsExecution;

  SeedingDialogState copyWith({
    SeedingSupportStatus? supportStatus,
    bool? isLoadingSupport,
    bool? isRunning,
    bool? verbose,
    List<SeedingOutput>? outputs,
    Map<String, String>? textFieldValues,
    Map<String, bool>? boolFieldValues,
    bool? configSupportsExecution,
    bool clearOutputs = false,
    bool clearSupportStatus = false,
  }) {
    return SeedingDialogState(
      supportStatus: clearSupportStatus ? null : (supportStatus ?? this.supportStatus),
      isLoadingSupport: isLoadingSupport ?? this.isLoadingSupport,
      isRunning: isRunning ?? this.isRunning,
      verbose: verbose ?? this.verbose,
      outputs: clearOutputs ? [] : (outputs ?? this.outputs),
      textFieldValues: textFieldValues ?? this.textFieldValues,
      boolFieldValues: boolFieldValues ?? this.boolFieldValues,
      configSupportsExecution: configSupportsExecution ?? this.configSupportsExecution,
    );
  }

  bool get supportsExecution => configSupportsExecution;

  bool get allowInlineExecution =>
      supportsExecution && (supportStatus?.hasDart ?? false);

  bool get canRun =>
      allowInlineExecution &&
      !isRunning &&
      (supportStatus?.hasScripts ?? false);

  bool get includeVerboseFlag =>
      supportsExecution && verbose;

  @override
  List<Object?> get props => [
        supportStatus,
        isLoadingSupport,
        isRunning,
        verbose,
        outputs,
        textFieldValues,
        boolFieldValues,
        configSupportsExecution,
      ];
}
