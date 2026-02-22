// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Broad categories describing domain-level errors for consistent handling.
enum AppErrorCategory {
  network,
  validation,
  permission,
  data,
  conflict,
  timeout,
  authentication,
  unknown,
}

/// Severity levels for surfaced domain errors.
enum AppErrorSeverity { low, medium, high, critical }

/// Base class for domain-specific errors with user-friendly messages
abstract class DomainError implements Exception {
  const DomainError({
    required this.message,
    this.technicalDetails,
    this.originalError,
    this.stackTrace,
    this.recoverySuggestion,
    this.category = AppErrorCategory.unknown,
    this.severity = AppErrorSeverity.high,
    this.context,
  });

  final String message;
  final String? technicalDetails;
  final Object? originalError;
  final StackTrace? stackTrace;
  final String? recoverySuggestion;
  final AppErrorCategory category;
  final AppErrorSeverity severity;
  final Map<String, Object?>? context;

  bool get isRecoverable => recoverySuggestion != null;

  @override
  String toString() => 'DomainError: $message';
}

/// Error that occurs when parsing JSON data into domain models
class RecordParsingError extends DomainError {
  RecordParsingError({
    required super.message,
    super.technicalDetails,
    super.originalError,
    super.stackTrace,
    super.recoverySuggestion,
    this.modelType,
    this.json,
    super.context,
    super.severity = AppErrorSeverity.high,
    super.category = AppErrorCategory.data,
  });

  factory RecordParsingError.fromRecordFactoryError(
    RecordFactoryError error, {
    StackTrace? stackTrace,
  }) {
    // Extract model type from error message if possible
    ModelType? modelType;
    try {
      if (error.json.containsKey('modelType')) {
        modelType = ModelType.values.byName(error.json['modelType']);
      }
    } catch (e) {
      LoggingService.instance.debug(
        'Failed to extract modelType from RecordFactoryError',
        {'json': error.json, 'error': e.toString()},
      );
    }

    return RecordParsingError(
      message: _getUserFriendlyMessage(error.message, modelType),
      technicalDetails: error.message,
      originalError: error,
      stackTrace: stackTrace,
      recoverySuggestion: _getRecoverySuggestion(error.message),
      modelType: modelType,
      json: error.json,
      context: {'modelType': modelType?.name},
    );
  }

  final ModelType? modelType;
  final Map<String, dynamic>? json;

  static String _getUserFriendlyMessage(
    String technicalMessage,
    ModelType? modelType,
  ) {
    if (technicalMessage.contains('Empty model type')) {
      return 'The data received is incomplete or corrupted';
    }
    if (technicalMessage.contains('Invalid event type')) {
      return 'Unknown event type encountered';
    }
    if (technicalMessage.contains('Invalid record type')) {
      return 'Unknown data type encountered';
    }
    if (technicalMessage.contains('missing key')) {
      return 'Required data is missing from the server response';
    }
    if (modelType != null) {
      return 'Failed to load ${modelType.name} data';
    }
    return 'Failed to process data from server';
  }

  static String? _getRecoverySuggestion(String technicalMessage) {
    if (technicalMessage.contains('missing key') ||
        technicalMessage.contains('Invalid')) {
      return 'Try refreshing the page. If the problem persists, please contact support.';
    }
    return 'Please try again. If the problem continues, contact support.';
  }
}

/// Error that occurs during repository operations
class RepositoryError extends DomainError {
  RepositoryError({
    required super.message,
    super.technicalDetails,
    super.originalError,
    super.stackTrace,
    super.recoverySuggestion,
    this.operationType,
    super.category = AppErrorCategory.data,
    super.severity = AppErrorSeverity.medium,
    super.context,
  });

  final RepositoryOperationType? operationType;

  factory RepositoryError.fromException(
    Exception error, {
    RepositoryOperationType? operationType,
    StackTrace? stackTrace,
  }) {
    String message = 'An error occurred while accessing data';
    String? recoverySuggestion = 'Please try again';

    AppErrorCategory category = AppErrorCategory.data;

    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      message = 'You do not have permission to access this data';
      recoverySuggestion = 'Please sign out and sign back in. '
          'If the issue persists, contact support.';
      category = AppErrorCategory.permission;
    } else if (errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('connection')) {
      message = 'Network connection error';
      recoverySuggestion =
          'Please check your internet connection and try again';
      category = AppErrorCategory.network;
    } else if (errorStr.contains('timeout')) {
      message = 'The request timed out';
      recoverySuggestion = 'Please check your connection and try again.';
      category = AppErrorCategory.timeout;
    }

    return RepositoryError(
      message: message,
      technicalDetails: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
      recoverySuggestion: recoverySuggestion,
      operationType: operationType,
      category: category,
      context: {'operationType': operationType?.name},
      severity: AppErrorSeverity.high,
    );
  }
}

/// Error thrown when a requested action violates capability guardrails.
class CapabilityConstraintError extends DomainError {
  const CapabilityConstraintError({
    required super.message,
    this.capability,
    super.recoverySuggestion,
    super.technicalDetails,
    super.category = AppErrorCategory.permission,
    super.severity = AppErrorSeverity.medium,
    super.context,
  });

  final String? capability;
}

/// Error thrown when a feature is not available for the current tier/license.
class FeatureDisabledError extends DomainError {
  const FeatureDisabledError({
    required this.featureKey,
    super.message = 'This feature is not available for your plan.',
    super.recoverySuggestion = 'Upgrade your plan to unlock this feature.',
    super.category = AppErrorCategory.permission,
    super.severity = AppErrorSeverity.medium,
    super.context,
  });

  final String featureKey;
}

/// Error thrown when a cycle is detected in graph parent traversal.
///
/// This typically indicates a data corruption issue where a node's parent
/// chain forms a cycle (e.g., A -> B -> C -> A).
class GraphCycleDetectedError extends DomainError {
  GraphCycleDetectedError({
    required this.nodeId,
    required this.cycleNodeId,
    required this.visitedPath,
  }) : super(
          message: 'Cycle detected in parent graph: node $cycleNodeId was '
              'already visited while traversing from $nodeId',
          technicalDetails: 'Visited path: ${visitedPath.join(' -> ')} -> $cycleNodeId',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
          recoverySuggestion:
              'This may indicate data corruption. Please contact support.',
          context: {
            'nodeId': nodeId,
            'cycleNodeId': cycleNodeId,
            'visitedPath': visitedPath,
          },
        );

  /// The ID of the node that started the traversal.
  final String nodeId;

  /// The ID of the node where the cycle was detected.
  final String cycleNodeId;

  /// The list of node IDs visited before the cycle was detected.
  final List<String> visitedPath;
}

enum RepositoryOperationType { read, write, delete, subscribe, unsubscribe }

/// Error thrown when a unique constraint is violated (e.g., duplicate ID).
///
/// Use this for typed collision detection instead of string matching on error
/// messages. This enables reliable retry logic for auto-generated IDs.
class UniqueConstraintViolationError extends DomainError {
  const UniqueConstraintViolationError({
    required super.message,
    required this.fieldName,
    required this.value,
    this.existingRecordId,
    super.recoverySuggestion,
    super.context,
  }) : super(
          category: AppErrorCategory.conflict,
          severity: AppErrorSeverity.medium,
        );

  /// The field that has the uniqueness constraint (e.g., 'provenanceId').
  final String fieldName;

  /// The value that violated the constraint.
  final String value;

  /// The ID of the existing record that has this value, if known.
  final String? existingRecordId;
}

/// Error thrown when an optimistic concurrency check fails due to concurrent
/// modifications to the same record.
///
/// This occurs when two users attempt to update the same record simultaneously
/// and the second update detects that the record was modified since it was last
/// read. The user should refresh their view and try again.
class ConcurrentModificationException extends DomainError {
  ConcurrentModificationException({
    required super.message,
    this.recordId,
    this.expectedUpdatedAt,
    this.actualUpdatedAt,
    super.context,
  }) : super(
          category: AppErrorCategory.conflict,
          severity: AppErrorSeverity.medium,
          recoverySuggestion:
              'The record was modified by another user. Please refresh and try again.',
        );

  /// The ID of the record that was concurrently modified.
  final String? recordId;

  /// The timestamp the client expected the record to have.
  final DateTime? expectedUpdatedAt;

  /// The actual timestamp found on the record.
  final DateTime? actualUpdatedAt;
}

/// Utility class for handling and transforming errors
class ErrorHandler {
  static DomainError transformError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    if (error is DomainError) {
      return error;
    }

    if (error is RecordFactoryError) {
      return RecordParsingError.fromRecordFactoryError(
        error,
        stackTrace: stackTrace,
      );
    }

    // Note: RecordDataError handling removed since RecordDataError no longer exists

    if (error is Exception) {
      return RepositoryError.fromException(error, stackTrace: stackTrace);
    }

    // Fallback for unexpected errors
    return RepositoryError(
      message: 'An unexpected error occurred',
      technicalDetails: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
      recoverySuggestion:
          'Please try again or contact support if the problem persists',
      category: AppErrorCategory.unknown,
      severity: AppErrorSeverity.high,
      context: context != null ? {'context': context} : null,
    );
  }

  /// Check if an error is recoverable through retry
  static bool isRetryable(DomainError error) {
    if (error is RepositoryError) {
      return error.originalError.toString().contains('network') ||
          error.originalError.toString().contains('timeout');
    }
    return false;
  }

  /// Get a user-friendly error message with optional details
  static String getDisplayMessage(
    DomainError error, {
    bool includeDetails = false,
  }) {
    final buffer = StringBuffer(error.message);

    if (error.recoverySuggestion != null) {
      buffer.write('\n\n${error.recoverySuggestion}');
    }

    if (includeDetails && error.technicalDetails != null) {
      buffer.write('\n\nDetails: ${error.technicalDetails}');
    }

    return buffer.toString();
  }
}
