// @tier: community
import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Callback type for connection restored events
typedef ConnectionRestoredCallback = void Function();

/// Service to monitor network connectivity status
class ConnectivityService {
  ConnectivityService._();
  static ConnectivityService? _instance;
  static ConnectivityService get instance =>
      _instance ??= ConnectivityService._();

  /// Callbacks to invoke when connection is restored
  final List<ConnectionRestoredCallback> _connectionRestoredCallbacks = [];

  final _logger = LoggingService.instance;

  // Use BehaviorSubject to always have the latest connectivity state
  final _connectivitySubject = BehaviorSubject<ConnectivityStatus>.seeded(
    ConnectivityStatus.checking,
  );

  Stream<ConnectivityStatus> get connectivityStream =>
      _connectivitySubject.stream;
  ConnectivityStatus get currentStatus => _connectivitySubject.value;
  bool get isOnline => currentStatus == ConnectivityStatus.online;
  bool get isOffline => currentStatus == ConnectivityStatus.offline;

  Timer? _periodicCheckTimer;
  static const _checkInterval = Duration(seconds: 30);
  static const _quickCheckInterval = Duration(seconds: 5);

  /// Flag to prevent concurrent connectivity checks
  bool _isCheckingConnectivity = false;

  /// Flag to track if service has been disposed
  bool _isDisposed = false;

  // URLs to check connectivity (use multiple for redundancy)
  static const _connectivityCheckUrls = [
    'https://www.google.com',
    'https://firestore.googleapis.com',
    'https://seafoundry.app',
  ];

  /// Initialize the connectivity monitoring
  Future<void> initialize() async {
    _logger.info('Initializing ConnectivityService');

    // Initial check
    await checkConnectivity();

    // Start periodic checks
    _startPeriodicChecks();
  }

  /// Manually check connectivity status
  Future<ConnectivityStatus> checkConnectivity() async {
    // Guard against concurrent checks to prevent race conditions
    if (_isCheckingConnectivity || _isDisposed) {
      return currentStatus;
    }
    _isCheckingConnectivity = true;

    try {
      // Try to resolve multiple hosts for redundancy
      for (final url in _connectivityCheckUrls) {
        try {
          final uri = Uri.parse(url);
          final result = await InternetAddress.lookup(
            uri.host,
          ).timeout(const Duration(seconds: 5));

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            _updateStatus(ConnectivityStatus.online);
            return ConnectivityStatus.online;
          }
        } catch (e) {
          // Continue to next URL
          continue;
        }
      }

      // If all checks failed
      _updateStatus(ConnectivityStatus.offline);
      return ConnectivityStatus.offline;
    } catch (e) {
      _logger.error('Error checking connectivity', e);
      _updateStatus(ConnectivityStatus.offline);
      return ConnectivityStatus.offline;
    } finally {
      _isCheckingConnectivity = false;
    }
  }

  /// Start periodic connectivity checks
  void _startPeriodicChecks() {
    if (_isDisposed) return;
    _periodicCheckTimer?.cancel();
    _scheduleNextCheck();
  }

  /// Schedule the next connectivity check based on current status.
  /// Uses shorter interval when offline to detect recovery quickly.
  void _scheduleNextCheck() {
    if (_isDisposed) return;

    final interval = isOffline ? _quickCheckInterval : _checkInterval;

    _periodicCheckTimer = Timer(interval, () async {
      if (_isDisposed) return;

      await checkConnectivity();

      // Schedule next check - interval will adjust based on new status
      if (!_isDisposed) {
        _scheduleNextCheck();
      }
    });
  }

  /// Update connectivity status and notify listeners
  void _updateStatus(ConnectivityStatus newStatus) {
    if (_connectivitySubject.value != newStatus) {
      _logger.info(
        'Connectivity status changed: ${_connectivitySubject.value} -> $newStatus',
      );
      _connectivitySubject.add(newStatus);

      // Trigger sync when coming back online
      if (newStatus == ConnectivityStatus.online) {
        _onConnectionRestored();
      }
    }
  }

  /// Register a callback to be invoked when connection is restored
  void addConnectionRestoredListener(ConnectionRestoredCallback callback) {
    _connectionRestoredCallbacks.add(callback);
  }

  /// Remove a previously registered callback
  void removeConnectionRestoredListener(ConnectionRestoredCallback callback) {
    _connectionRestoredCallbacks.remove(callback);
  }

  /// Called when connection is restored
  void _onConnectionRestored() {
    _logger.info('Connection restored - notifying ${_connectionRestoredCallbacks.length} listeners');
    // Create a copy of the list to prevent ConcurrentModificationException
    // if a callback adds or removes a listener during iteration.
    final callbacksCopy = List<ConnectionRestoredCallback>.of(_connectionRestoredCallbacks);
    for (final callback in callbacksCopy) {
      try {
        callback();
      } catch (error, stackTrace) {
        _logger.error('Failed to notify connection restored listener', error, stackTrace);
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _isDisposed = true;
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _connectivitySubject.close();
  }
}

/// Connectivity status enum
enum ConnectivityStatus { online, offline, checking }

/// Extension for user-friendly status messages
extension ConnectivityStatusExtension on ConnectivityStatus {
  String get displayMessage {
    switch (this) {
      case ConnectivityStatus.online:
        return 'Connected';
      case ConnectivityStatus.offline:
        return 'Offline - Changes will sync when connected';
      case ConnectivityStatus.checking:
        return 'Checking connection...';
    }
  }

  bool get canSync => this == ConnectivityStatus.online;
}

