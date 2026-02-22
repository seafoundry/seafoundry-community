// @tier: community
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/logging_service.dart';

import 'crash_reporting_interface.dart';

/// Firebase Crashlytics-backed crash reporting delegate for production monitoring.
class FirebaseCrashlyticsDelegate implements CrashReportingDelegate {
  FirebaseCrashlyticsDelegate._();

  static final FirebaseCrashlyticsDelegate instance = FirebaseCrashlyticsDelegate._();

  final LoggingService _logger = LoggingService.instance;
  FirebaseCrashlytics? _crashlytics;

  @override
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {
    if (kIsWeb) {
      _logger.info('Crashlytics not supported on web platform');
      return;
    }

    try {
      _crashlytics = FirebaseCrashlytics.instance;
      _crashlytics?.setCrashlyticsCollectionEnabled(enableCrashReporting);
      _logger.info('Firebase Crashlytics initialized successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to initialize Firebase Crashlytics', error, stackTrace);
    }
  }

  @override
  void setUser({
    required String userId,
    String? email,
    String? name,
    String? organization,
    Map<String, String>? customData,
  }) {
    if (_crashlytics == null) return;

    try {
      _crashlytics!.setUserIdentifier(userId);
      if (email != null) _crashlytics!.setCustomKey('user_email', email);
      if (name != null) _crashlytics!.setCustomKey('user_name', name);
      if (organization != null) _crashlytics!.setCustomKey('organization', organization);
      customData?.forEach((key, value) => _crashlytics!.setCustomKey(key, value));
    } catch (error, stackTrace) {
      _logger.error('Failed to set user for Crashlytics', error, stackTrace);
    }
  }

  @override
  void addMetadata(String key, String value) {
    if (_crashlytics == null) return;
    try {
      _crashlytics!.setCustomKey(key, value);
    } catch (error, stackTrace) {
      _logger.error('Failed to add Crashlytics metadata', error, stackTrace);
    }
  }

  @override
  void clearAllMetadata() {
    // Crashlytics doesn't have a clearAll method - no-op
  }

  @override
  void showBugReportScreen() {
    // No UI in Crashlytics - Shake handles this
  }

  @override
  void logEvent(String event, {Map<String, String>? data}) {
    if (_crashlytics == null) return;
    try {
      _crashlytics!.log('Event: $event');
      data?.forEach((key, value) => _crashlytics!.setCustomKey('event_$key', value));
    } catch (error, stackTrace) {
      _logger.error('Failed to log event to Crashlytics', error, stackTrace);
    }
  }

  @override
  void setCurrentScreen(String screenName) {
    if (_crashlytics == null) return;
    try {
      _crashlytics!.setCustomKey('current_screen', screenName);
      _crashlytics!.log('Screen: $screenName');
    } catch (error, stackTrace) {
      _logger.error('Failed to set current screen for Crashlytics', error, stackTrace);
    }
  }

  @override
  void addLogMessage(String message, {String level = 'info'}) {
    if (_crashlytics == null) return;
    try {
      _crashlytics!.log('[$level] $message');
    } catch (error, stackTrace) {
      _logger.error('Failed to add log message to Crashlytics', error, stackTrace);
    }
  }

  @override
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    if (_crashlytics == null) return;

    try {
      _crashlytics!.setCustomKey('error_category', error.category.name);
      _crashlytics!.setCustomKey('error_severity', error.severity.name);
      if (context != null) _crashlytics!.setCustomKey('error_context', context);

      metadata?.forEach((key, value) {
        _crashlytics!.setCustomKey('meta_$key', value?.toString() ?? 'null');
      });

      _crashlytics!.recordError(error, stackTrace, reason: context ?? error.message, fatal: false);
    } catch (err, stack) {
      _logger.error('Failed to record handled error to Crashlytics', err, stack);
    }
  }

  /// Record a fatal crash to Crashlytics (called from global error handlers)
  void recordFatalError(dynamic exception, StackTrace? stackTrace, {String? reason}) {
    if (_crashlytics == null) return;
    try {
      _crashlytics!.recordError(exception, stackTrace, reason: reason, fatal: true);
    } catch (error, stack) {
      _logger.error('Failed to record fatal error to Crashlytics', error, stack);
    }
  }
}
