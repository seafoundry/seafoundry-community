// @tier: community
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Thrown when a Supabase operation is requested but the dependency is not
/// available in the current build (package not installed or client factory not
/// registered).
class SupabaseUnavailableException implements Exception {
  const SupabaseUnavailableException(this.reason);

  final String reason;

  @override
  String toString() => 'SupabaseUnavailableException: $reason';
}

typedef SupabaseClientFactory = dynamic Function(String url, String apiKey);

/// Centralized Supabase client management with lazy initialization and retry support.
///
/// The service reads credentials from Flutter `--dart-define` values:
/// - `SUPABASE_URL`
/// - `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_ANON_KEY` as a fallback)
/// - `SUPABASE_MAX_RETRIES` (optional, defaults to 3)
///
/// Call [runWithRetry] for Supabase operations that should automatically retry on
/// transient failures. The underlying [SupabaseClient] is memoized to avoid
/// creating multiple HTTP pools.
class SupabaseService {
  SupabaseService._();

  static SupabaseService? _instance;

  /// Singleton accessor.
  static SupabaseService get instance => _instance ??= SupabaseService._();

  final LoggingService _logger = LoggingService.instance;

  dynamic _client;
  Completer<dynamic>? _initializing;
  SupabaseClientFactory? _clientFactory;

  String? _overrideUrl;
  String? _overrideKey;
  int? _overrideMaxRetries;

  /// True when both URL and key are available (either via overrides or env).
  bool get isConfigured {
    if (_client != null) {
      return true;
    }

    final hasUrl =
        (_overrideUrl != null && _overrideUrl!.isNotEmpty) ||
        _envValue('SUPABASE_URL') != null;
    final hasKey =
        (_overrideKey != null && _overrideKey!.isNotEmpty) ||
        _envValue('SUPABASE_SERVICE_ROLE_KEY') != null ||
        _envValue('SUPABASE_ANON_KEY') != null;
    return hasUrl && hasKey;
  }

  /// True when a Supabase client can be produced (either memoized or via factory).
  bool get isAvailable =>
      _client != null || (_clientFactory != null && isConfigured);

  /// Lazily initializes and returns the shared SupabaseClient.
  Future<dynamic> get client async {
    final cached = _client;
    if (cached != null) return cached;

    final pending = _initializing;
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<dynamic>();
    _initializing = completer;

    try {
      final factory = _clientFactory;
      if (factory == null) {
        throw const SupabaseUnavailableException(
          'Supabase client factory not registered',
        );
      }

      final url = _resolveUrl();
      final key = _resolveKey();
      final initializedClient = factory(url, key);
      _client = initializedClient;
      completer.complete(initializedClient);
      return initializedClient;
    } on SupabaseUnavailableException catch (error, stackTrace) {
      _logger.warning('Supabase unavailable; skipping client initialization', {
        'reason': error.reason,
      });
      completer.completeError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize Supabase client', error, stackTrace);
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initializing = null;
    }
  }

  /// Runs a Supabase operation with bounded exponential backoff.
  Future<T> runWithRetry<T>(
    Future<T> Function(dynamic client) operation, {
    int? maxAttempts,
    Duration initialDelay = const Duration(milliseconds: 300),
    Duration maxDelay = const Duration(seconds: 3),
  }) async {
    if (!isConfigured) {
      throw const SupabaseUnavailableException(
        'Supabase credentials are not configured',
      );
    }

    if (!isAvailable) {
      throw const SupabaseUnavailableException(
        'Supabase dependency not available',
      );
    }

    final attemptsAllowed = maxAttempts ?? _resolveMaxRetries();
    if (attemptsAllowed <= 0) {
      throw ArgumentError.value(
        attemptsAllowed,
        'maxAttempts',
        'Must be at least 1',
      );
    }

    var attempt = 0;
    var delay = initialDelay;

    while (true) {
      attempt += 1;

      try {
        final supabaseClient = await client;
        return await operation(supabaseClient);
      } on SupabaseUnavailableException {
        rethrow;
      } catch (error, stackTrace) {
        if (attempt >= attemptsAllowed) {
          _logger.error(
            'Supabase operation failed after $attemptsAllowed attempts',
            error,
            stackTrace,
          );
          rethrow;
        }

        _logger.warning(
          'Supabase operation failed (attempt $attempt/$attemptsAllowed). Retrying in ${delay.inMilliseconds}ms',
          {'error': error},
        );

        await Future.delayed(delay);
        final nextDelayMs = (delay.inMilliseconds * 2).clamp(
          initialDelay.inMilliseconds,
          maxDelay.inMilliseconds,
        );
        delay = Duration(milliseconds: nextDelayMs);
      }
    }
  }

  /// Clears the cached client. Mainly useful for tests or hot reload scenarios.
  Future<void> dispose() async {
    _client = null;
  }

  /// Overrides configuration during tests.
  @visibleForTesting
  void override({
    String? url,
    String? apiKey,
    int? maxRetries,
    dynamic client, // TODO(backlog): Re-enable SupabaseClient when package is added
  }) {
    _overrideUrl = url;
    _overrideKey = apiKey;
    _overrideMaxRetries = maxRetries;
    _client = client;
    _clientFactory = null;
  }

  @visibleForTesting
  void reset() {
    _client = null;
    _initializing = null;
    _clientFactory = null;
    _overrideUrl = null;
    _overrideKey = null;
    _overrideMaxRetries = null;
  }

  /// Registers a factory used to construct the Supabase client lazily.
  void registerClientFactory(SupabaseClientFactory factory) {
    _clientFactory = factory;
  }

  String _resolveUrl() {
    final override = _overrideUrl;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final env = _envValue('SUPABASE_URL');
    if (env != null && env.isNotEmpty) {
      return env;
    }
    throw const SupabaseUnavailableException(
      'Supabase URL not configured. Set SUPABASE_URL via .env and dart_defines.',
    );
  }

  String _resolveKey() {
    final override = _overrideKey;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final serviceKey = _envValue('SUPABASE_SERVICE_ROLE_KEY');
    if (serviceKey != null && serviceKey.isNotEmpty) {
      return serviceKey;
    }
    final anonKey = _envValue('SUPABASE_ANON_KEY');
    if (anonKey != null && anonKey.isNotEmpty) {
      return anonKey;
    }
    throw const SupabaseUnavailableException(
      'Supabase key not configured. Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY.',
    );
  }

  int _resolveMaxRetries() {
    final override = _overrideMaxRetries;
    if (override != null && override > 0) {
      return override;
    }
    final env = _envValue('SUPABASE_MAX_RETRIES');
    final parsed = env != null ? int.tryParse(env) : null;
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 3;
  }

  String? _envValue(String key) {
    switch (key) {
      case 'SUPABASE_URL':
        const value = String.fromEnvironment('SUPABASE_URL');
        return value.isEmpty ? null : value;
      case 'SUPABASE_SERVICE_ROLE_KEY':
        const value = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
        return value.isEmpty ? null : value;
      case 'SUPABASE_ANON_KEY':
        const value = String.fromEnvironment('SUPABASE_ANON_KEY');
        return value.isEmpty ? null : value;
      case 'SUPABASE_MAX_RETRIES':
        const value = String.fromEnvironment('SUPABASE_MAX_RETRIES');
        return value.isEmpty ? null : value;
    }
    return null;
  }
}
