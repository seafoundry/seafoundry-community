// @tier: community
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:seafoundry_app/services/logging_service.dart';

/// Service for executing seeding scripts and providing real-time feedback
class SeedingService {
  static final SeedingService _instance = SeedingService._internal();
  factory SeedingService() => _instance;
  SeedingService._internal();

  final LoggingService _logger = LoggingService.instance;
  String? _dartExecutableCache;
  bool _loggedEnvironmentWarning = false;

  /// Execute a seeding command and return a stream of output
  Stream<SeedingOutput> executeSeedingCommand(SeedingInvocation invocation) {
    final controller = StreamController<SeedingOutput>();
    Process? process;

    void safeAdd(SeedingOutput output) {
      if (!controller.isClosed) {
        controller.add(output);
      }
    }

    controller.onCancel = () {
      process?.kill();
    };

    () async {
      _logger.info('Starting seeding command: ${invocation.command.label}');

      safeAdd(
        SeedingOutput(type: SeedingOutputType.start, command: invocation.command, message: invocation.startMessage),
      );

      try {
        final executable = await _resolveExecutable(invocation.executable);
        if (executable == null) {
          safeAdd(
            SeedingOutput(
              type: SeedingOutputType.error,
              command: invocation.command,
              message: 'Unable to locate Dart executable. Update your PATH or set FLUTTER_ROOT.',
            ),
          );
          await controller.close();
          return;
        }

        process = await Process.start(executable, invocation.args, workingDirectory: Directory.current.path);

        process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.isEmpty) return;
                _logger.info('Seeding output: $line');
                safeAdd(SeedingOutput(type: SeedingOutputType.progress, command: invocation.command, message: line));
              },
              onError: (error) {
                _logger.error('Error reading stdout', error);
                safeAdd(
                  SeedingOutput(
                    type: SeedingOutputType.warning,
                    command: invocation.command,
                    message: 'Stdout error: $error',
                  ),
                );
              },
            );

        process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.isEmpty) return;
                _logger.warning('Seeding stderr: $line');
                safeAdd(SeedingOutput(type: SeedingOutputType.warning, command: invocation.command, message: line));
              },
              onError: (error) {
                _logger.error('Error reading stderr', error);
                safeAdd(
                  SeedingOutput(
                    type: SeedingOutputType.warning,
                    command: invocation.command,
                    message: 'Stderr error: $error',
                  ),
                );
              },
            );

        final exitCode = await process!.exitCode;

        if (exitCode == 0) {
          safeAdd(
            SeedingOutput(
              type: SeedingOutputType.success,
              command: invocation.command,
              message: '${invocation.command.label} completed successfully',
            ),
          );
        } else {
          safeAdd(
            SeedingOutput(
              type: SeedingOutputType.error,
              command: invocation.command,
              message: '${invocation.command.label} failed with exit code $exitCode',
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.error('Failed to execute seeding command', e, stackTrace);
        safeAdd(
          SeedingOutput(
            type: SeedingOutputType.error,
            command: invocation.command,
            message: 'Failed to execute ${invocation.command.label}: $e',
          ),
        );
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Execute multiple seeding commands in sequence
  Stream<SeedingOutput> executeSeedingSequence(List<SeedingInvocation> invocations) async* {
    for (final invocation in invocations) {
      yield* executeSeedingCommand(invocation);

      // Add a small delay between commands
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Check if dart is available
  Future<bool> isDartAvailable() async => (await resolveDartExecutable()) != null;

  Future<String?> resolveDartExecutable() async => _resolveExecutable('dart');

  /// Check if seeding scripts are available
  Future<bool> areSeedingScriptsAvailable() async {
    try {
      const scriptPaths = [
        'scripts/seed_modular.dart',
      ];

      for (final path in scriptPaths) {
        if (!await _fileExists(path)) {
          _logger.warning('Missing seeding script: $path');
          return false;
        }
      }
      return true;
    } catch (e, stackTrace) {
      if (e is UnsupportedError) {
        _logger.info('Skipping seeding script check: file system not supported on this platform.', e);
      } else {
        _logger.error('Failed to check seeding scripts', e, stackTrace);
      }
      return false;
    }
  }

  Future<String?> _resolveExecutable(String executable) async {
    if (executable != 'dart') return executable;
    if (_dartExecutableCache != null) return _dartExecutableCache;

    final environment = _readEnvironment();
    final home = environment['HOME'] ?? environment['USERPROFILE'];

    final candidates = <String>{};
    final commandFallbacks = <String>{};

    final overrideRaw = environment['DART_EXECUTABLE'] ?? environment['SEEDING_DART'];
    if (overrideRaw != null && overrideRaw.trim().isNotEmpty) {
      final override = overrideRaw.trim();
      if (_looksLikePath(override)) {
        candidates.add(_expandHome(override, home));
      } else {
        final resolvedOverride = _findExecutableInPath(environment, override, home);
        if (resolvedOverride != null) {
          candidates.add(resolvedOverride);
        } else {
          commandFallbacks.add(override);
        }
      }
    }

    final pathMatch = _findExecutableInPath(environment, 'dart', home);
    if (pathMatch != null) {
      candidates.add(pathMatch);
    } else {
      commandFallbacks.add('dart');
    }

    final flutterRoots = <String>[];
    for (final raw in [environment['FLUTTER_ROOT'], environment['FLUTTER_HOME'], environment['FLUTTER_SDK_PATH']]) {
      if (raw != null && raw.isNotEmpty) {
        flutterRoots.add(_expandHome(raw, home));
      }
    }

    if (home != null && home.isNotEmpty) {
      flutterRoots.addAll([
        _expandHome('$home/flutter', home),
        _expandHome('$home/development/flutter', home),
        _expandHome('$home/fvm/default', home),
      ]);
    }

    for (final root in flutterRoots) {
      final candidate = _dartExecutableFromFlutterRoot(root);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    for (final candidate in candidates) {
      if (await _fileExists(candidate)) {
        _dartExecutableCache = candidate;
        return _dartExecutableCache;
      }
    }

    for (final command in commandFallbacks) {
      final resolved = await _tryProcessLookup(command);
      if (resolved != null) {
        _dartExecutableCache = resolved;
        return _dartExecutableCache;
      }
    }

    return null;
  }

  String? _dartExecutableFromFlutterRoot(String root) {
    final primary = _joinPathSegments([root, 'bin', Platform.isWindows ? 'dart.exe' : 'dart']);
    if (_fileExistsSync(primary)) return primary;

    final secondary = Platform.isWindows
        ? _joinPathSegments([root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe'])
        : _joinPathSegments([root, 'bin', 'cache', 'dart-sdk', 'bin', 'dart']);
    if (_fileExistsSync(secondary)) return secondary;

    return null;
  }

  Map<String, String> _readEnvironment() {
    try {
      return Platform.environment;
    } catch (error) {
      if (!_loggedEnvironmentWarning) {
        _logger.warning('Environment variables unavailable when resolving Dart executable', error);
        _loggedEnvironmentWarning = true;
      }
      return const <String, String>{};
    }
  }

  String _expandHome(String path, String? homeDir) {
    final trimmed = path.trim();
    if (homeDir == null || homeDir.isEmpty) return trimmed;
    if (trimmed == '~') return homeDir;
    if (trimmed.startsWith('~/') || (Platform.isWindows && trimmed.startsWith('~\\'))) {
      final remainder = trimmed.substring(2);
      final segments = [homeDir, ..._splitPathSegments(remainder)];
      return _joinPathSegments(segments);
    }

    return trimmed;
  }

  bool _looksLikePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final hasForwardSlash = trimmed.contains('/');
    final hasBackSlash = trimmed.contains('\\');
    final startsWithDot = trimmed.startsWith('.');
    final hasDriveLetter = Platform.isWindows && trimmed.contains(':');
    return hasForwardSlash || hasBackSlash || startsWithDot || hasDriveLetter;
  }

  String? _findExecutableInPath(Map<String, String> environment, String command, String? homeDir) {
    final pathVar = environment['PATH'];
    if (pathVar == null || pathVar.isEmpty) return null;

    final separator = Platform.isWindows ? ';' : ':';
    final parts = pathVar.split(separator);

    final commandVariants = Platform.isWindows
        ? <String>['$command.exe', '$command.bat', '$command.cmd', command]
        : <String>[command];

    for (final rawDir in parts) {
      var dir = rawDir.trim();
      if (dir.isEmpty) continue;
      dir = dir.replaceAll('"', '');
      dir = _expandHome(dir, homeDir);
      for (final variant in commandVariants) {
        final candidate = _joinPathSegments([dir, variant]);
        if (_fileExistsSync(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }

  String _joinPathSegments(List<String> segments) {
    final cleaned = <String>[];
    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      cleaned.add(trimmed);
    }
    if (cleaned.isEmpty) return '';
    var result = cleaned.first;
    for (var i = 1; i < cleaned.length; i++) {
      result = _joinTwo(result, cleaned[i]);
    }
    return result;
  }

  String _joinTwo(String parent, String child) {
    final separator = Platform.pathSeparator;
    var parentSegment = parent.trim();
    var childSegment = child.trim();

    if (parentSegment.isEmpty) {
      return childSegment;
    }

    if (parentSegment == separator) {
      parentSegment = '';
    } else {
      parentSegment = _stripTrailingSeparators(parentSegment);
    }

    childSegment = _stripLeadingSeparators(childSegment);

    if (parentSegment.isEmpty) {
      if (childSegment.isEmpty) {
        return separator;
      }
      if (childSegment.startsWith(separator)) {
        return childSegment;
      }
      return '$separator$childSegment';
    }

    if (childSegment.isEmpty) {
      return parentSegment;
    }

    return '$parentSegment$separator$childSegment';
  }

  String _stripTrailingSeparators(String input) {
    if (input.isEmpty) return input;
    final pattern = Platform.isWindows ? RegExp(r'[\\/]+$') : RegExp(r'/+$');
    return input.replaceAll(pattern, '');
  }

  String _stripLeadingSeparators(String input) {
    if (input.isEmpty) return input;
    final pattern = Platform.isWindows ? RegExp(r'^[\\/]+') : RegExp(r'^/+');
    return input.replaceAll(pattern, '');
  }

  List<String> _splitPathSegments(String raw) {
    if (raw.isEmpty) return const [];
    return raw.split(RegExp(r'[\\/]+')).where((segment) => segment.isNotEmpty).toList();
  }

  Future<bool> _fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }

  bool _fileExistsSync(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<String?> _tryProcessLookup(String command) async {
    try {
      final result = await Process.run(command, ['--version']);
      if (result.exitCode == 0) {
        return command;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class SeedingInvocation {
  SeedingInvocation({
    required this.command,
    required this.executable,
    required this.args,
    required this.displayCommand,
  });

  final SeedingCommand command;
  final String executable;
  final List<String> args;
  final String displayCommand;

  String get startMessage => 'Starting ${command.label}...';
}

/// Available seeding commands
enum SeedingCommand {
  fresh,
  all,
  types,
  sample,
  clear,
  genetics,
  nurseries,
  dataQuality,
  modular;

  /// Get the estimated duration for this command
  Duration get estimatedDuration {
    switch (this) {
      case SeedingCommand.fresh:
        return const Duration(minutes: 3);
      case SeedingCommand.all:
        return const Duration(minutes: 2);
      case SeedingCommand.types:
        return const Duration(seconds: 30);
      case SeedingCommand.sample:
        return const Duration(minutes: 1);
      case SeedingCommand.clear:
        return const Duration(seconds: 15);
      case SeedingCommand.genetics:
        return const Duration(seconds: 30);
      case SeedingCommand.nurseries:
        return const Duration(minutes: 1);
      case SeedingCommand.dataQuality:
        return const Duration(minutes: 2);
      case SeedingCommand.modular:
        return const Duration(minutes: 2);
    }
  }

  /// Human-readable label for UI and logs
  String get label {
    switch (this) {
      case SeedingCommand.fresh:
        return 'Reset & Seed Inventory';
      case SeedingCommand.all:
        return 'Seed Inventory (Full)';
      case SeedingCommand.types:
        return 'Seed Demo Types';
      case SeedingCommand.sample:
        return 'Seed Demo Sample';
      case SeedingCommand.clear:
        return 'Clear Inventory';
      case SeedingCommand.genetics:
        return 'Seed Genetics Dataset';
      case SeedingCommand.nurseries:
        return 'Reset & Seed Nurseries';
      case SeedingCommand.dataQuality:
        return 'Seed Data Quality Scenario';
      case SeedingCommand.modular:
        return 'Seed Modular Dataset';
    }
  }

  /// Description used to explain the command to operators
  String get description {
    switch (this) {
      case SeedingCommand.fresh:
        return 'Clears existing inventory data and reseeds with a comprehensive demo environment.';
      case SeedingCommand.all:
        return 'Seeds a full set of nurseries, outplants, and history data '
            'without clearing existing records.';
      case SeedingCommand.types:
        return 'Adds demo reference data across species, genets, and structures '
            'for UI validation.';
      case SeedingCommand.sample:
        return 'Creates a lightweight sample dataset suitable for workshops or quick demos.';
      case SeedingCommand.clear:
        return 'Clears inventory via the reset tooling. Launch the maintenance '
            'flow to run this command.';
      case SeedingCommand.genetics:
        return 'Seeds genetics-focused inventory data and supporting '
            'infrastructure without history.';
      case SeedingCommand.nurseries:
        return 'Resets nurseries and reseeds inventory structures tailored for '
            'nursery operations.';
      case SeedingCommand.dataQuality:
        return 'Seeds inventory data optimized for data quality exercises, '
            'including historical events.';
      case SeedingCommand.modular:
        return 'Runs the modular seeding script with fine-grained controls for '
            'nurseries, genetics, and history.';
    }
  }

  /// Builds a CLI example command for this seeding command
  String buildCliExample({bool verbose = false}) {
    final verboseFlag = verbose ? ' --verbose' : '';
    final baseCommand = 'dart run scripts/reset_and_seed_inventory.dart --org=<ORG_ID> --user=<ADMIN_USER_ID>$verboseFlag';
    
    switch (this) {
      case SeedingCommand.fresh:
      case SeedingCommand.nurseries:
      case SeedingCommand.all:
      case SeedingCommand.genetics:
      case SeedingCommand.dataQuality:
      case SeedingCommand.types:
      case SeedingCommand.sample:
      case SeedingCommand.modular:
        return baseCommand;
      case SeedingCommand.clear:
        return 'Use "Clear Inventory" in the Reset & Seed dialog (no CLI shortcut available yet).';
    }
  }
}

/// Output from seeding commands
class SeedingOutput {
  const SeedingOutput({required this.type, required this.command, required this.message, this.timestamp});

  final SeedingOutputType type;
  final SeedingCommand command;
  final String message;
  final DateTime? timestamp;

  DateTime get effectiveTimestamp => timestamp ?? DateTime.now();
}

/// Types of seeding output
enum SeedingOutputType { start, progress, success, error, warning }
