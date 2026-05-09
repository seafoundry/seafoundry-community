import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/logging_service.dart';

import 'crash_reporting_interface.dart';

/// Composite delegate that forwards crash reporting calls to multiple delegates.
class CompositeCrashReportingDelegate implements CrashReportingDelegate {
  CompositeCrashReportingDelegate(this._delegates);

  final List<CrashReportingDelegate> _delegates;

  void _logError(String method, Object error, CrashReportingDelegate delegate) {
    if (kDebugMode) {
      LoggingService.instance.warning(
        'CompositeCrashReportingDelegate.$method failed for ${delegate.runtimeType}: $error',
      );
    }
  }

  @override
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {
    for (final delegate in _delegates) {
      try {
        delegate.initialize(
          apiKey: apiKey,
          enableCrashReporting: enableCrashReporting,
          enableBugReporting: enableBugReporting,
          enableScreenRecording: enableScreenRecording,
        );
      } catch (e) {
        _logError('initialize', e, delegate);
      }
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
    for (final delegate in _delegates) {
      try {
        delegate.setUser(userId: userId, email: email, name: name, organization: organization, customData: customData);
      } catch (e) {
        _logError('setUser', e, delegate);
      }
    }
  }

  @override
  void addMetadata(String key, String value) {
    for (final delegate in _delegates) {
      try {
        delegate.addMetadata(key, value);
      } catch (e) {
        _logError('addMetadata', e, delegate);
      }
    }
  }

  @override
  void clearAllMetadata() {
    for (final delegate in _delegates) {
      try {
        delegate.clearAllMetadata();
      } catch (e) {
        _logError('clearAllMetadata', e, delegate);
      }
    }
  }

  @override
  void showBugReportScreen() {
    for (final delegate in _delegates) {
      try {
        delegate.showBugReportScreen();
        break;
      } catch (e) {
        _logError('showBugReportScreen', e, delegate);
      }
    }
  }

  @override
  void logEvent(String event, {Map<String, String>? data}) {
    for (final delegate in _delegates) {
      try {
        delegate.logEvent(event, data: data);
      } catch (e) {
        _logError('logEvent', e, delegate);
      }
    }
  }

  @override
  void setCurrentScreen(String screenName) {
    for (final delegate in _delegates) {
      try {
        delegate.setCurrentScreen(screenName);
      } catch (e) {
        _logError('setCurrentScreen', e, delegate);
      }
    }
  }

  @override
  void addLogMessage(String message, {String level = 'info'}) {
    for (final delegate in _delegates) {
      try {
        delegate.addLogMessage(message, level: level);
      } catch (e) {
        _logError('addLogMessage', e, delegate);
      }
    }
  }

  @override
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    for (final delegate in _delegates) {
      try {
        delegate.recordHandledError(error, context: context, stackTrace: stackTrace, metadata: metadata);
      } catch (e) {
        _logError('recordHandledError', e, delegate);
      }
    }
  }
}
