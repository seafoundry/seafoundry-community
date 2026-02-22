// @tier: community
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Initialization state for GoogleSignInService
enum GoogleSignInInitState {
  uninitialized,
  initializing,
  initialized,
  failed,
}

/// Service wrapper for GoogleSignIn that ensures proper initialization
/// before any sign-in operations.
///
/// On web, GoogleSignIn.initialize() runs asynchronously without blocking
/// app startup. This service tracks initialization state and provides a
/// [ready] future that callers can await before attempting sign-in.
class GoogleSignInService {
  static GoogleSignInService? _instance;
  static GoogleSignInService get instance => _instance ??= GoogleSignInService._();

  /// Reset instance for testing
  static void resetInstance() {
    _instance = null;
  }

  GoogleSignInService._();

  final _initCompleter = Completer<bool>();
  GoogleSignInInitState _initState = GoogleSignInInitState.uninitialized;
  String? _initError;

  /// Current initialization state
  GoogleSignInInitState get initState => _initState;

  /// Error message if initialization failed
  String? get initError => _initError;

  /// Whether the service has completed initialization (success or failure)
  bool get isInitialized =>
      _initState == GoogleSignInInitState.initialized ||
      _initState == GoogleSignInInitState.failed;

  /// Whether the service initialized successfully
  bool get isReady => _initState == GoogleSignInInitState.initialized;

  /// Future that completes when initialization finishes.
  /// Returns true if initialization succeeded, false if it failed.
  Future<bool> get ready => _initCompleter.future;

  /// Initialize the GoogleSignIn instance.
  ///
  /// On web, this must be called with a [clientId].
  /// On mobile platforms, no clientId is needed.
  ///
  /// This method is safe to call multiple times - subsequent calls
  /// will return immediately if already initialized or initializing.
  Future<bool> initialize({String? clientId}) async {
    final logger = LoggingService.instance;

    // Already initialized or initializing - return existing future
    if (_initState != GoogleSignInInitState.uninitialized) {
      logger.debug('GoogleSignInService already ${_initState.name}');
      return _initCompleter.future;
    }

    _initState = GoogleSignInInitState.initializing;
    logger.info('GoogleSignInService starting initialization...');

    try {
      if (kIsWeb) {
        if (clientId == null || clientId.isEmpty) {
          throw ArgumentError('clientId is required for web initialization');
        }
        await GoogleSignIn.instance
            .initialize(clientId: clientId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'GoogleSignIn initialization timed out after 10 seconds',
                );
              },
            );
      } else {
        // Mobile platforms
        await GoogleSignIn.instance.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException(
              'GoogleSignIn initialization timed out after 10 seconds',
            );
          },
        );
      }

      _initState = GoogleSignInInitState.initialized;
      logger.info('GoogleSignInService initialized successfully');
      _initCompleter.complete(true);
      return true;
    } catch (error, stackTrace) {
      _initState = GoogleSignInInitState.failed;
      _initError = error.toString();
      logger.error(
        'GoogleSignInService initialization failed',
        error,
        stackTrace,
      );
      _initCompleter.complete(false);
      return false;
    }
  }

  /// Authenticate with Google, ensuring initialization is complete first.
  ///
  /// Throws [GoogleSignInNotReadyException] if initialization failed.
  /// Throws [GoogleSignInException] for authentication errors.
  Future<GoogleSignInAccount> authenticate() async {
    final logger = LoggingService.instance;

    // Wait for initialization to complete
    final initSuccess = await ready;

    if (!initSuccess) {
      logger.warning(
        'GoogleSignIn authenticate called but initialization failed: $_initError',
      );
      throw GoogleSignInNotReadyException(
        'Google Sign-In is not available. ${_initError ?? 'Initialization failed.'}',
      );
    }

    return GoogleSignIn.instance.authenticate();
  }

  /// Sign out from Google, ensuring initialization is complete first.
  ///
  /// Safe to call even if not signed in or initialization failed.
  Future<void> signOut() async {
    final logger = LoggingService.instance;

    // Wait for initialization, but don't fail if it failed
    await ready;

    if (!isReady) {
      logger.debug('GoogleSignIn signOut skipped - not initialized');
      return;
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      logger.warning('GoogleSignIn signOut error (non-fatal)', error);
    }
  }

  /// Disconnect from Google (revokes access), ensuring initialization first.
  ///
  /// Safe to call even if not signed in or initialization failed.
  Future<void> disconnect() async {
    final logger = LoggingService.instance;

    await ready;

    if (!isReady) {
      logger.debug('GoogleSignIn disconnect skipped - not initialized');
      return;
    }

    try {
      await GoogleSignIn.instance.disconnect();
    } catch (error) {
      logger.warning('GoogleSignIn disconnect error (non-fatal)', error);
    }
  }

  /// Get the underlying GoogleSignIn instance.
  ///
  /// Prefer using the service methods ([authenticate], [signOut]) instead.
  /// This is provided for advanced use cases and backward compatibility.
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;
}

/// Exception thrown when GoogleSignIn operations are attempted
/// before successful initialization.
class GoogleSignInNotReadyException implements Exception {
  final String message;

  const GoogleSignInNotReadyException(this.message);

  @override
  String toString() => 'GoogleSignInNotReadyException: $message';
}
