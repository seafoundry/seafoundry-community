import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:shake_flutter/enums/log_level.dart' as shake;
import 'package:shake_flutter/shake_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/utils/js_error_utils.dart';

/// Service responsible for application logging using Talker
///
/// This service provides a centralized logging interface following
/// clean architecture principles. All logging should go through this service
/// rather than directly using Talker to maintain abstraction.
///
/// Note: Colors and formatting are disabled on iOS to prevent ANSI escape codes
/// from appearing in Shake bug reports. Colors are also disabled in release mode
/// for cleaner production logs.
class LoggingService {
  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();
  static const bool _graphNodeDebugEnabled =
      bool.fromEnvironment('GRAPH_NODE_DEBUG', defaultValue: false);

  LoggingService._();

  Talker? _talker;
  bool _isInitialized = false;

  LogLevel? _logLevel;
  LogLevel get logLevel => _logLevel ??= getLogLevel();

  bool get _allowDebugLogging =>
      kDebugMode ||
      logLevel == LogLevel.debug ||
      logLevel == LogLevel.verbose;

  bool get _allowTraceLogging =>
      kDebugMode || logLevel == LogLevel.verbose;

  bool get _shouldSendDebugToShake =>
      !kReleaseMode &&
      (logLevel == LogLevel.debug || logLevel == LogLevel.verbose);

  /// Initialize the logging service
  /// Should be called once during app startup
  void initialize() {
    // Skip if already initialized
    if (_isInitialized && _talker != null) {
      return;
    }
    // Disable in release mode for cleaner logs
    final shouldEnableColors = !kReleaseMode;

    _talker = TalkerFlutter.init(
      settings: TalkerSettings(
        enabled: true,
        useHistory: true,
        maxHistoryItems: 100,
        useConsoleLogs: true,
      ),
      logger: TalkerLogger(
        // Custom output handler for platform-specific logging via developer.log
        output: (message) {
          final logName = 'Talker';
          if (kIsWeb) {
            debugPrint(message);
            return;
          }
          developer.log(message, name: logName);
        },
        settings: TalkerLoggerSettings(
          level: logLevel,
          enableColors: shouldEnableColors,
          // Simplify formatting to avoid box-drawing characters in logs
          lineSymbol: shouldEnableColors ? '─' : '',
          maxLineWidth: shouldEnableColors ? 110 : 0,
        ),
      ),
    );

    _isInitialized = true;
  }

  LogLevel getLogLevel() {
    // Check for LOG_LEVEL environment variable first
    const logLevelEnv = String.fromEnvironment('LOG_LEVEL');

    if (logLevelEnv.isNotEmpty) {
      // Parse the LOG_LEVEL from environment
      switch (logLevelEnv.toLowerCase()) {
        case 'verbose':
          return LogLevel.verbose;
        case 'debug':
          return LogLevel.debug;
        case 'info':
          return LogLevel.info;
        case 'warning':
        case 'warn':
          return LogLevel.warning;
        case 'error':
          return LogLevel.error;
        case 'critical':
          return LogLevel.critical;
        default:
          if (kDebugMode) {
            // ignore: avoid_print
            print('Warning: Invalid LOG_LEVEL "$logLevelEnv". Using default.');
          }
          // Fall back to default if invalid value
          return kDebugMode ? LogLevel.debug : LogLevel.info;
      }
    } else {
      // Fall back to existing logic if LOG_LEVEL not set
      return kDebugMode ? LogLevel.debug : LogLevel.info;
    }
  }

  /// Get the Talker instance for advanced usage
  /// (e.g., BLoC integration, HTTP interceptors)
  Talker get talker {
    if (_talker == null) {
      initialize();
    }
    return _talker!;
  }

  // Logging methods

  /// Log debug information
  void debug(String message, [Object? extra]) {
    if (!_allowDebugLogging) return;
    talker.debug(_formatLogMessage(message, extra));
    if (_shouldSendDebugToShake) {
      final fullMessage = extra != null ? '$message | $extra' : message;
      _logToShake(shake.LogLevel.debug, fullMessage);
    }
  }

  void graphNodeDebug(String message, [Object? extra]) {
    if (!_graphNodeDebugEnabled) return;
    debug(message, extra);
  }

  /// Log extremely verbose diagnostics (never forwarded to Shake).
  void trace(String message, [Object? extra]) {
    if (!_allowTraceLogging) return;
    talker.debug(_formatLogMessage('[trace] $message', extra));
  }

  /// Log informational messages
  void info(String message, [Object? extra]) {
    talker.info(_formatLogMessage(message, extra));
    final fullMessage = extra != null ? '$message | $extra' : message;
    _logToShake(shake.LogLevel.info, fullMessage);
  }

  /// Log warnings
  void warning(String message, [Object? extra]) {
    talker.warning(_formatLogMessage(message, extra));
    final fullMessage = extra != null ? '$message | $extra' : message;
    _logToShake(shake.LogLevel.warn, fullMessage);
  }

  /// Log errors with special handling for domain errors
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final resolvedError = _resolveWebError(error);
    // Check if this is a domain error and format it specially
    if (resolvedError is DomainError) {
      // Use error level logging with formatted message to ensure it appears
      talker.error(DomainErrorLog._formatDomainError(message, resolvedError));
    } else if (resolvedError is RecordFactoryError) {
      // Use error level logging with formatted message to ensure it appears
      talker.error(
        RecordFactoryErrorLog._formatRecordFactoryError(message, resolvedError),
      );
    } else if (resolvedError.toString().contains('RecordDataError')) {
      talker.error('Record data error: $message', resolvedError, stackTrace);
    } else {
      talker.error(message, resolvedError, stackTrace);
    }
    final fullMessage = resolvedError != null
        ? '$message - Error: $resolvedError'
        : message;
    _logToShake(shake.LogLevel.error, fullMessage);
  }

  /// Log critical errors
  void critical(String message, [Object? error, StackTrace? stackTrace]) {
    final resolvedError = _resolveWebError(error);
    talker.critical(_formatLogMessage(message, resolvedError), stackTrace);
    final fullMessage = resolvedError != null
        ? '$message - Error: $resolvedError'
        : message;
    _logToShake(shake.LogLevel.error, fullMessage);
  }

  Object? _resolveWebError(Object? error) {
    if (!kIsWeb || error == null) return error;
    final boxedError = getJsProperty(error, 'error');
    return boxedError ?? error;
  }

  // Application-specific logging methods

  /// Log authentication events
  void logAuth(String event, {Map<String, dynamic>? details}) {
    talker.logCustom(AuthLog(event, details));
    final fullMessage = details != null
        ? 'Auth: $event - $details'
        : 'Auth: $event';
    _logToShake(shake.LogLevel.info, fullMessage);
  }

  /// Log user actions
  void logUserAction(String action, {Map<String, dynamic>? details}) {
    talker.logCustom(UserActionLog(action, details));
    final fullMessage = details != null
        ? 'User Action: $action - $details'
        : 'User Action: $action';
    _logToShake(shake.LogLevel.info, fullMessage);
  }

  /// Log domain errors with enhanced formatting
  void logDomainError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
  }) {
    talker.logCustom(DomainErrorLog(context ?? 'Domain error occurred', error));
  }

  void _logToShake(shake.LogLevel level, String message) {
    if (kIsWeb) return;

    // Skip Shake logging in test environment
    if (Platform.environment.containsKey('FLUTTER_TEST') ||
        const bool.fromEnvironment('FLUTTER_TEST', defaultValue: false)) {
      return;
    }

    Shake.log(level, message).catchError((Object error) {
      if (error is MissingPluginException && kDebugMode) {
        developer.log(
          'Shake plugin not available; skipping log: $message',
          level: 800,
          name: 'LoggingService',
        );
      }
    });
  }
}

// Custom log types for clean single-line logging

// Helper function to format log messages consistently
String _formatLogMessage(String message, [Object? extra]) {
  final timestamp = DateTime.now().toLocal();
  final timeStr =
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  final extraStr = extra != null ? ' | $extra' : '';
  return '$timeStr - $message$extraStr';
}

// Custom log types for domain-specific logging

class AuthLog extends TalkerLog {
  AuthLog(String event, Map<String, dynamic>? details)
    : super('🔐 Auth: $event ${details != null ? '- $details' : ''}');

  @override
  String get key => 'auth';

  @override
  String get title => 'Authentication';
}

class UserActionLog extends TalkerLog {
  UserActionLog(String action, Map<String, dynamic>? details)
    : super('👤 User Action: $action ${details != null ? '- $details' : ''}');

  @override
  String get key => 'user_action';

  @override
  String get title => 'User Action';
}

// Error-specific log formatters

class DomainErrorLog extends TalkerLog {
  final DomainError domainError;

  DomainErrorLog(String context, this.domainError)
    : super(_formatDomainError(context, domainError));

  static String _formatDomainError(String context, DomainError error) {
    final buffer = StringBuffer();
    buffer.writeln('❌ Domain Error: $context');
    buffer.writeln('├─ Message: ${error.message}');
    buffer.writeln(
      '├─ Category: ${error.category.name} • Severity: ${error.severity.name}',
    );

    if (error.recoverySuggestion != null) {
      buffer.writeln('├─ Recovery: ${error.recoverySuggestion}');
    }

    if (error.technicalDetails != null) {
      buffer.writeln('├─ Details: ${error.technicalDetails}');
    }

    if (error.context != null && error.context!.isNotEmpty) {
      buffer.writeln('├─ Context: ${error.context}');
    }

    if (error is RecordParsingError) {
      if (error.modelType != null) {
        buffer.writeln('├─ Model Type: ${error.modelType!.name}');
      }
      if (error.json != null && error.json!.isNotEmpty) {
        buffer.writeln('├─ JSON Data:');
        _prettyPrintJson(buffer, error.json!, '│  ');
      }
    }

    final isRecoverable = error.isRecoverable;
    buffer.write('└─ Recoverable: ${isRecoverable ? '✅ Yes' : '❌ No'}');

    return buffer.toString();
  }

  @override
  String get key => 'domain_error';

  @override
  String get title => 'Domain Error';

  @override
  AnsiPen get pen => AnsiPen()..red();
}

class RecordFactoryErrorLog extends TalkerLog {
  final RecordFactoryError factoryError;

  RecordFactoryErrorLog(String context, this.factoryError)
    : super(_formatRecordFactoryError(context, factoryError));

  static String _formatRecordFactoryError(
    String context,
    RecordFactoryError error,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('🏭❌ Record Factory Error: $context');
    buffer.writeln('├─ Message: ${error.message}');

    // Pretty print the full JSON that failed to parse
    if (error.json.isNotEmpty) {
      buffer.writeln('├─ JSON Data (failed to parse):');
      _prettyPrintJson(buffer, error.json, '│  ');
    }

    // Try to identify the issue
    if (error.message.contains('missing key')) {
      buffer.writeln('├─ Issue: Required field missing from JSON');

      // Try to identify which keys might be missing by comparing with expected structure
      if (error.message.contains('for type')) {
        final typeMatch = RegExp(r'for type (\w+)').firstMatch(error.message);
        if (typeMatch != null) {
          final typeName = typeMatch.group(1);
          buffer.writeln('│  └─ Expected type: $typeName');
        }
      }
    } else if (error.message.contains('Invalid event type')) {
      buffer.writeln('├─ Issue: Unknown event type');
      if (error.json.containsKey('eventTypeId')) {
        buffer.writeln(
          '│  └─ Received event type: ${error.json['eventTypeId']}',
        );
      }
    } else if (error.message.contains('Invalid record type')) {
      buffer.writeln('├─ Issue: Unknown record type');
      if (error.json.containsKey('modelType')) {
        buffer.writeln('│  └─ Received model type: ${error.json['modelType']}');
      }
    } else if (error.message.contains('Empty model type')) {
      buffer.writeln('├─ Issue: Model type is empty or null');
    } else if (error.message.contains("type 'Null' is not a subtype")) {
      buffer.writeln('├─ Issue: Null value found where non-null expected');
      // Try to extract field name from error message
      final fieldMatch = RegExp(r"of type '(\w+)'").firstMatch(error.message);
      if (fieldMatch != null) {
        buffer.writeln('│  └─ Expected type: ${fieldMatch.group(1)}');
      }
    }

    buffer.write('└─ Action: Check data source and model definitions');

    return buffer.toString();
  }

  @override
  String get key => 'record_factory_error';

  @override
  String get title => 'Record Factory Error';

  @override
  AnsiPen get pen => AnsiPen()..red();
}

/// Helper method to pretty print JSON with proper indentation
void _prettyPrintJson(
  StringBuffer buffer,
  Map<String, dynamic> json,
  String prefix,
) {
  final entries = json.entries.toList();
  for (int i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final isLast = i == entries.length - 1;
    final linePrefix = isLast ? '└─' : '├─';

    final value = entry.value;
    if (value is Map<String, dynamic>) {
      buffer.writeln('$prefix$linePrefix ${entry.key}: {');
      _prettyPrintJson(buffer, value, '$prefix${isLast ? '   ' : '│  '}');
      buffer.writeln('$prefix${isLast ? '   ' : '│  '}}');
    } else if (value is List) {
      buffer.writeln('$prefix$linePrefix ${entry.key}: [');
      for (int j = 0; j < value.length && j < 5; j++) {
        // Limit to first 5 items
        final item = value[j];
        final itemIsLast = j == value.length - 1 || j == 4;
        buffer.writeln(
          '$prefix${isLast ? '   ' : '│  '}${itemIsLast ? '└─' : '├─'} $item',
        );
      }
      if (value.length > 5) {
        buffer.writeln(
          '$prefix${isLast ? '   ' : '│  '}└─ ... and ${value.length - 5} more items',
        );
      }
      buffer.writeln('$prefix${isLast ? '   ' : '│  '}]');
    } else {
      String valueStr = value?.toString() ?? 'null';
      // Truncate very long values
      if (valueStr.length > 200) {
        valueStr = '${valueStr.substring(0, 197)}...';
      }
      buffer.writeln('$prefix$linePrefix ${entry.key}: $valueStr');
    }
  }
}
