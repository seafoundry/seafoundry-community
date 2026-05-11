import 'package:shake_flutter/enums/log_level.dart';
import 'package:shake_flutter/enums/shake_screen.dart';
import 'package:shake_flutter/shake_flutter.dart';

import 'package:seafoundry_app/errors/domain_errors.dart';

import '../logging_service.dart';
import 'composite_crash_reporting_delegate.dart';
import 'crash_reporting_interface.dart';
import 'firebase_crashlytics_delegate.dart';

/// Shake-backed crash reporting delegate for mobile/desktop platforms.
class CrashReportingServiceImpl implements CrashReportingDelegate {
  CrashReportingServiceImpl._();

  static final CrashReportingServiceImpl instance =
      CrashReportingServiceImpl._();

  final LoggingService _logger = LoggingService.instance;

  @override
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {
    try {
      Shake.start(apiKey);
      _configureShake(
        enableCrashReporting: enableCrashReporting,
        enableBugReporting: enableBugReporting,
        enableScreenRecording: enableScreenRecording,
      );
      _logger.info('Crash reporting service initialized successfully');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to initialize crash reporting service',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  void _configureShake({
    required bool enableCrashReporting,
    required bool enableBugReporting,
    required bool enableScreenRecording,
  }) {
    try {
      Shake.setConsoleLogsEnabled(false);
      Shake.setAutoVideoRecording(enableScreenRecording);

      if (enableBugReporting) {
        Shake.setInvokeShakeOnShakeDeviceEvent(true);
        Shake.setShakingThreshold(500);
        Shake.setInvokeShakeOnScreenshot(false);
        Shake.setShowFloatingReportButton(false);
      } else {
        Shake.setInvokeShakeOnShakeDeviceEvent(false);
        Shake.setInvokeShakeOnScreenshot(false);
        Shake.setShowFloatingReportButton(false);
      }

      Shake.setDefaultScreen(ShakeScreen.newTicket);
      _logger.info('Shake configured successfully');
    } catch (error, stackTrace) {
      _logger.error('Failed to configure Shake', error, stackTrace);
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
    try {
      Shake.registerUser(userId);

      final metadata = <String, String>{};

      if (email != null) metadata['email'] = email;
      if (name != null) {
        final nameParts = name.split(' ');
        if (nameParts.length >= 2) {
          metadata['first_name'] = nameParts.first;
          metadata['last_name'] = nameParts.sublist(1).join(' ');
        } else {
          metadata['first_name'] = name;
        }
      }
      if (organization != null) metadata['organization'] = organization;
      if (customData != null) metadata.addAll(customData);

      if (metadata.isNotEmpty) {
        Shake.updateUserMetadata(metadata);
      }

      _logger.logAuth(
        'User set for crash reporting',
        details: {
          'userId': userId,
          'email': email ?? 'not provided',
          'organization': organization ?? 'not provided',
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set user for crash reporting',
        error,
        stackTrace,
      );
    }
  }

  @override
  void addMetadata(String key, String value) {
    try {
      Shake.setMetadata(key, value);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to add crash reporting metadata',
        error,
        stackTrace,
      );
    }
  }

  @override
  void clearAllMetadata() {
    try {
      Shake.clearMetadata();
      _logger.debug('Cleared all crash reporting metadata');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to clear crash reporting metadata',
        error,
        stackTrace,
      );
    }
  }

  @override
  void showBugReportScreen() {
    try {
      Shake.show();
      _logger.logUserAction('Manual bug report triggered');
    } catch (error, stackTrace) {
      _logger.error('Failed to show bug report screen', error, stackTrace);
    }
  }

  @override
  void logEvent(String event, {Map<String, String>? data}) {
    try {
      Shake.setMetadata('event', event);
      data?.forEach((key, value) {
        Shake.setMetadata('event_$key', value);
      });
      Shake.log(LogLevel.info, 'Event: $event');
      _logger.debug('Logged event to crash reporting: $event');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to log event to crash reporting',
        error,
        stackTrace,
      );
    }
  }

  @override
  void setCurrentScreen(String screenName) {
    try {
      Shake.setMetadata('current_screen', screenName);
      Shake.log(LogLevel.verbose, 'Screen: $screenName');
      _logger.debug('Set current screen for crash reporting: $screenName');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set current screen for crash reporting',
        error,
        stackTrace,
      );
    }
  }

  @override
  void addLogMessage(String message, {String level = 'info'}) {
    try {
      final logLevel = switch (level.toLowerCase()) {
        'verbose' => LogLevel.verbose,
        'debug' => LogLevel.debug,
        'warn' || 'warning' => LogLevel.warn,
        'error' => LogLevel.error,
        _ => LogLevel.info,
      };
      Shake.log(logLevel, message);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to add log message to crash reporting',
        error,
        stackTrace,
      );
    }
  }

  @override
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    try {
      final details = <String, String>{
        'category': error.category.name,
        'severity': error.severity.name,
      };

      if (context != null) {
        details['context'] = context;
      }
      if (error.recoverySuggestion != null) {
        details['recovery'] = error.recoverySuggestion!;
      }
      metadata?.forEach((key, value) {
        details['meta_$key'] = value?.toString() ?? 'null';
      });
      error.context?.forEach((key, value) {
        details['ctx_$key'] = value?.toString() ?? 'null';
      });

      Shake.log(LogLevel.error, 'Handled error: ${error.message}');
      details.forEach((key, value) {
        Shake.setMetadata('error_$key', value);
      });
      if (stackTrace != null) {
        Shake.setMetadata('error_stacktrace', stackTrace.toString());
      }
    } catch (err, stack) {
      _logger.error('Failed to record handled error', err, stack);
    }
  }
}

CrashReportingDelegate createCrashReportingService() =>
    CompositeCrashReportingDelegate([
      CrashReportingServiceImpl.instance,
      FirebaseCrashlyticsDelegate.instance,
    ]);

