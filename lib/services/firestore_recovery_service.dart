// @tier: community
import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/services/disposable_singleton.dart';
import 'package:seafoundry_app/services/firestore_recovery_stub.dart'
    if (dart.library.html) 'package:seafoundry_app/services/firestore_recovery_web.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Represents a Firestore stream recovery event
class FirestoreRecoveryEvent {
  const FirestoreRecoveryEvent({
    required this.state,
    required this.timestamp,
    this.repositoryType,
    this.errorMessage,
    this.attemptNumber,
  });

  final FirestoreRecoveryState state;
  final DateTime timestamp;
  final String? repositoryType;
  final String? errorMessage;
  final int? attemptNumber;

  @override
  String toString() {
    final parts = <String>['FirestoreRecoveryEvent(state: $state'];
    if (repositoryType != null) parts.add('repo: $repositoryType');
    if (attemptNumber != null) parts.add('attempt: $attemptNumber');
    if (errorMessage != null) {
      final truncated = errorMessage!.length > 50
          ? '${errorMessage!.substring(0, 50)}...'
          : errorMessage;
      parts.add('error: $truncated');
    }
    return '${parts.join(', ')})';
  }
}

/// State of the Firestore recovery process
enum FirestoreRecoveryState {
  /// No recovery in progress, streams are healthy
  healthy,

  /// Internal assertion error detected, preparing recovery
  errorDetected,

  /// Attempting to reconnect streams
  reconnecting,

  /// Recovery succeeded, streams restored
  recovered,

  /// Recovery failed after max retries, requires manual intervention
  failed,

  /// Cache is being cleared (web only)
  clearingCache,
}

/// Service responsible for detecting and recovering from Firestore stream errors.
///
/// This singleton monitors Firestore snapshot streams for internal assertion
/// failures and coordinates recovery attempts across all repositories.
///
/// Usage:
/// ```dart
/// // Register error from repository
/// FirestoreRecoveryService.instance.reportError(
///   error: e,
///   repositoryType: 'SiteRepository',
///   onReconnect: () => _resubscribeToStream(),
/// );
///
/// // Listen to recovery events in UI
/// FirestoreRecoveryService.instance.recoveryStream.listen((event) {
///   if (event.state == FirestoreRecoveryState.failed) {
///     // Show manual recovery UI
///   }
/// });
/// ```
class FirestoreRecoveryService implements DisposableSingleton {
  FirestoreRecoveryService._();
  static FirestoreRecoveryService? _instance;
  static FirestoreRecoveryService get instance =>
      _instance ??= FirestoreRecoveryService._();

  /// For testing: allows injecting a mock instance
  static void setInstance(FirestoreRecoveryService instance) {
    _instance = instance;
  }

  /// For testing: resets the singleton
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  @override
  String get singletonId => 'FirestoreRecoveryService';

  final _logger = LoggingService.instance;

  /// Stream of recovery events for UI to react to
  final _recoverySubject = BehaviorSubject<FirestoreRecoveryEvent>.seeded(
    FirestoreRecoveryEvent(
      state: FirestoreRecoveryState.healthy,
      timestamp: DateTime.now(),
    ),
  );

  Stream<FirestoreRecoveryEvent> get recoveryStream => _recoverySubject.stream;
  FirestoreRecoveryEvent get currentEvent => _recoverySubject.value;
  FirestoreRecoveryState get currentState => _recoverySubject.value.state;
  bool get isHealthy => currentState == FirestoreRecoveryState.healthy;
  bool get isRecovering =>
      currentState == FirestoreRecoveryState.reconnecting ||
      currentState == FirestoreRecoveryState.clearingCache;

  /// Tracks reconnection callbacks by repository type
  final Map<String, VoidCallback> _reconnectCallbacks = {};

  /// Tracks retry attempts per repository
  final Map<String, int> _retryAttempts = {};

  /// Maximum number of retry attempts before giving up
  static const int maxRetryAttempts = 3;

  /// Base delay between retry attempts (doubles with each attempt)
  static const Duration baseRetryDelay = Duration(seconds: 2);

  /// Cooldown period before allowing another recovery for the same repository
  static const Duration recoveryCooldown = Duration(minutes: 1);

  /// Tracks last recovery time per repository
  final Map<String, DateTime> _lastRecoveryTime = {};

  /// Detects if an error is a Firestore internal assertion failure
  bool isFirestoreInternalError(Object error) {
    final errorString = error.toString();
    return errorString.contains('INTERNAL ASSERTION FAILED');
  }

  /// Reports a Firestore stream error and initiates recovery if needed.
  ///
  /// [error] - The error that occurred
  /// [repositoryType] - Identifier for the repository (e.g., 'SiteRepository')
  /// [onReconnect] - Callback to resubscribe to the Firestore stream
  ///
  /// Returns true if recovery was initiated, false if skipped (cooldown/not applicable)
  Future<bool> reportError({
    required Object error,
    required String repositoryType,
    required VoidCallback onReconnect,
  }) async {
    if (!isFirestoreInternalError(error)) {
      _logger.debug(
        'FirestoreRecoveryService: Non-internal error for $repositoryType, skipping recovery',
      );
      return false;
    }

    // Check cooldown
    final lastRecovery = _lastRecoveryTime[repositoryType];
    if (lastRecovery != null) {
      final timeSinceRecovery = DateTime.now().difference(lastRecovery);
      if (timeSinceRecovery < recoveryCooldown) {
        _logger.warning(
          'FirestoreRecoveryService: Skipping recovery for $repositoryType - '
          'cooldown active (${timeSinceRecovery.inSeconds}s < ${recoveryCooldown.inSeconds}s)',
        );
        return false;
      }
    }

    _logger.warning(
      'FirestoreRecoveryService: Internal assertion error detected for $repositoryType',
      {'error': error.toString().substring(0, 200)},
    );

    // Store the reconnect callback
    _reconnectCallbacks[repositoryType] = onReconnect;

    // Emit error detected event
    _emitEvent(
      FirestoreRecoveryState.errorDetected,
      repositoryType: repositoryType,
      errorMessage: error.toString(),
    );

    // Initiate recovery
    await _attemptRecovery(repositoryType);
    return true;
  }

  /// Attempts to recover a repository's stream with exponential backoff
  Future<void> _attemptRecovery(String repositoryType) async {
    final attempts = _retryAttempts[repositoryType] ?? 0;

    if (attempts >= maxRetryAttempts) {
      _logger.error(
        'FirestoreRecoveryService: Max retries exceeded for $repositoryType',
      );
      _emitEvent(
        FirestoreRecoveryState.failed,
        repositoryType: repositoryType,
        attemptNumber: attempts,
      );
      _retryAttempts.remove(repositoryType);
      return;
    }

    _retryAttempts[repositoryType] = attempts + 1;
    final currentAttempt = attempts + 1;

    // Calculate delay with exponential backoff
    final delay = baseRetryDelay * (1 << attempts); // 2s, 4s, 8s

    _logger.info(
      'FirestoreRecoveryService: Attempting recovery for $repositoryType '
      '(attempt $currentAttempt/$maxRetryAttempts, delay: ${delay.inSeconds}s)',
    );

    _emitEvent(
      FirestoreRecoveryState.reconnecting,
      repositoryType: repositoryType,
      attemptNumber: currentAttempt,
    );

    // Wait before reconnecting
    await Future.delayed(delay);

    // Attempt reconnection
    final callback = _reconnectCallbacks[repositoryType];
    if (callback != null) {
      try {
        callback();
        _logger.info(
          'FirestoreRecoveryService: Recovery callback executed for $repositoryType',
        );

        // Mark successful recovery
        _lastRecoveryTime[repositoryType] = DateTime.now();
        _retryAttempts.remove(repositoryType);
        _reconnectCallbacks.remove(repositoryType);

        _emitEvent(
          FirestoreRecoveryState.recovered,
          repositoryType: repositoryType,
          attemptNumber: currentAttempt,
        );

        // Reset to healthy after a brief delay
        await Future.delayed(const Duration(seconds: 1));
        if (_recoverySubject.value.state == FirestoreRecoveryState.recovered) {
          _emitEvent(FirestoreRecoveryState.healthy);
        }
      } catch (e, stackTrace) {
        _logger.error(
          'FirestoreRecoveryService: Recovery callback failed for $repositoryType',
          e,
          stackTrace,
        );

        // Retry if we haven't exceeded max attempts
        if ((_retryAttempts[repositoryType] ?? 0) < maxRetryAttempts) {
          await _attemptRecovery(repositoryType);
        } else {
          _emitEvent(
            FirestoreRecoveryState.failed,
            repositoryType: repositoryType,
            errorMessage: e.toString(),
          );
        }
      }
    }
  }

  /// Clears the Firestore persistence cache.
  ///
  /// On web, this deletes the IndexedDB database used by Firestore.
  /// On other platforms, this is a no-op.
  ///
  /// Returns true if cache was cleared (web), false otherwise (other platforms).
  Future<bool> clearFirestoreCache() async {
    _logger.info('FirestoreRecoveryService: Clearing Firestore cache');

    _emitEvent(FirestoreRecoveryState.clearingCache);

    try {
      final result = await clearFirestorePersistenceCache();

      if (result) {
        _logger.info('FirestoreRecoveryService: Cache cleared successfully');
      } else {
        _logger.debug(
          'FirestoreRecoveryService: Cache clearing not supported on this platform',
        );
      }

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'FirestoreRecoveryService: Failed to clear cache',
        e,
        stackTrace,
      );
      _emitEvent(
        FirestoreRecoveryState.failed,
        errorMessage: 'Failed to clear cache: $e',
      );
      return false;
    }
  }

  /// Manually triggers recovery for all registered repositories.
  ///
  /// Useful when user wants to force a reconnection attempt.
  Future<void> forceRecoveryAll() async {
    _logger.info(
      'FirestoreRecoveryService: Force recovery for ${_reconnectCallbacks.length} repositories',
    );

    // Reset retry counts
    _retryAttempts.clear();
    _lastRecoveryTime.clear();

    // Trigger recovery for each registered repository
    for (final entry in _reconnectCallbacks.entries) {
      await _attemptRecovery(entry.key);
    }
  }

  /// Resets the service to healthy state.
  ///
  /// Call this after manual intervention or successful recovery.
  void resetToHealthy() {
    _retryAttempts.clear();
    _reconnectCallbacks.clear();
    _emitEvent(FirestoreRecoveryState.healthy);
    _logger.debug('FirestoreRecoveryService: Reset to healthy state');
  }

  void _emitEvent(
    FirestoreRecoveryState state, {
    String? repositoryType,
    String? errorMessage,
    int? attemptNumber,
  }) {
    final event = FirestoreRecoveryEvent(
      state: state,
      timestamp: DateTime.now(),
      repositoryType: repositoryType,
      errorMessage: errorMessage,
      attemptNumber: attemptNumber,
    );
    _logger.debug('FirestoreRecoveryService: Emitting event $event');
    _recoverySubject.add(event);
  }

  @override
  void dispose() {
    _recoverySubject.close();
    _reconnectCallbacks.clear();
    _retryAttempts.clear();
    _lastRecoveryTime.clear();
  }
}
