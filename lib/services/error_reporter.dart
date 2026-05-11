import 'dart:async';

import 'package:meta/meta.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/crash_reporting_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Centralized helper that standardizes async error handling across services.
///
/// Use this to wrap async operations so that:
/// - Errors are converted to [DomainError] using [ErrorHandler.transformError]
/// - Errors are logged consistently with contextual metadata
/// - Crash reporting receives a handled-exception breadcrumb
class ErrorReporter {
  ErrorReporter({LoggingService? logger, CrashReportingService? crashReporter})
    : _logger = logger ?? LoggingService.instance,
      _crashReporter = crashReporter ?? CrashReportingService.instance;

  final LoggingService _logger;
  final CrashReportingService _crashReporter;

  /// Guard an async operation, returning its result or rethrowing a normalized [DomainError].
  Future<T> guard<T>(
    String context,
    Future<T> Function() operation, {
    AppErrorCategory category = AppErrorCategory.unknown,
    AppErrorSeverity severity = AppErrorSeverity.high,
    Map<String, Object?>? metadata,
    T Function(DomainError error)? onError,
  }) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      final normalized = _normalizeError(
        ErrorHandler.transformError(
          error,
          stackTrace: stackTrace,
          context: context,
        ),
        category: category,
        severity: severity,
        metadata: metadata,
        contextLabel: context,
      );

      _logger.logDomainError(
        normalized,
        context: context,
        stackTrace: stackTrace,
      );
      _crashReporter.recordHandledError(
        normalized,
        context: context,
        stackTrace: stackTrace,
      );

      if (onError != null) {
        return onError(normalized);
      }
      throw normalized;
    }
  }

  /// Guard a sync operation with the same semantics as [guard].
  T guardSync<T>(
    String context,
    T Function() operation, {
    AppErrorCategory category = AppErrorCategory.unknown,
    AppErrorSeverity severity = AppErrorSeverity.high,
    Map<String, Object?>? metadata,
    T Function(DomainError error)? onError,
  }) {
    try {
      return operation();
    } catch (error, stackTrace) {
      if (error is! DomainError) {
        // Wrap non domain errors for consistent handling.
        return _rethrowSync(
          error,
          stackTrace,
          context: context,
          category: category,
          severity: severity,
          metadata: metadata,
          onError: onError,
        );
      }

      final normalized = _normalizeError(
        error,
        category: category,
        severity: severity,
        metadata: metadata,
        contextLabel: context,
      );

      _logger.logDomainError(
        normalized,
        context: context,
        stackTrace: stackTrace,
      );
      _crashReporter.recordHandledError(
        normalized,
        context: context,
        stackTrace: stackTrace,
      );

      if (onError != null) {
        return onError(normalized);
      }
      throw normalized;
    }
  }

  Never _rethrowSync<T>(
    Object error,
    StackTrace stackTrace, {
    required String context,
    required AppErrorCategory category,
    required AppErrorSeverity severity,
    Map<String, Object?>? metadata,
    T Function(DomainError error)? onError,
  }) {
    final normalized = _normalizeError(
      ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: context,
      ),
      category: category,
      severity: severity,
      metadata: metadata,
      contextLabel: context,
    );

    _logger.logDomainError(
      normalized,
      context: context,
      stackTrace: stackTrace,
    );
    _crashReporter.recordHandledError(
      normalized,
      context: context,
      stackTrace: stackTrace,
    );

    if (onError != null) {
      // Invoke callback but still throw to ensure callers notice the error.
      onError(normalized);
    }
    throw normalized;
  }

  DomainError _normalizeError(
    DomainError error, {
    required AppErrorCategory category,
    required AppErrorSeverity severity,
    Map<String, Object?>? metadata,
    required String contextLabel,
  }) {
    final mergedMetadata = <String, Object?>{
      if (error.context != null) ...error.context!,
      if (metadata != null) ...metadata,
      'context': contextLabel,
    };

    final needsAugment =
        error.category != category ||
        error.severity != severity ||
        !_mapEquals(error.context, mergedMetadata);

    if (!needsAugment) {
      return error;
    }

    return _AugmentedDomainError(
      base: error,
      category: category,
      severity: severity,
      metadata: mergedMetadata,
    );
  }

  bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

@immutable
class _AugmentedDomainError extends DomainError {
  _AugmentedDomainError({
    required DomainError base,
    required super.category,
    required super.severity,
    required Map<String, Object?> metadata,
  }) : _base = base,
       super(
         message: base.message,
         technicalDetails: base.technicalDetails,
         originalError: base.originalError,
         stackTrace: base.stackTrace,
         recoverySuggestion: base.recoverySuggestion,
         context: metadata,
       );

  final DomainError _base;

  @override
  String toString() => _base.toString();
}
