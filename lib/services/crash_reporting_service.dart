// @tier: community
import 'package:meta/meta.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/crash_reporting/crash_reporting_interface.dart';

// Conditional import: use stub on web, impl on mobile/desktop
import 'crash_reporting/crash_reporting_stub.dart'
    if (dart.library.io) 'crash_reporting/crash_reporting_impl.dart';

/// Service responsible for crash reporting and bug reporting
///
/// This service provides a centralized interface for crash reporting
/// and user feedback following clean architecture principles. It uses
/// the delegate pattern with conditional exports to select the appropriate
/// implementation (stub for web, Shake-backed impl for mobile/desktop).
///
/// **Platform Support**:
/// - Mobile/Desktop: Uses Shake SDK via `CrashReportingServiceImpl`
/// - Web: Uses no-op stub via `CrashReportingServiceStub`
///
/// Usage:
/// ```dart
/// CrashReportingService.instance.initialize(apiKey: 'your-key');
/// CrashReportingService.instance.setUser(userId: 'user123');
/// ```
class CrashReportingService {
  CrashReportingService._({
    required CrashReportingDelegate delegate,
  }) : _delegate = delegate;

  static CrashReportingService? _instance;
  
  /// Get the singleton instance of CrashReportingService
  ///
  /// Automatically selects the appropriate implementation based on platform:
  /// - Web: Uses stub (no-op)
  /// - Mobile/Desktop: Uses Shake SDK implementation
  static CrashReportingService get instance {
    if (_instance != null) return _instance!;

    // Create delegate using conditional export
    // This will be CrashReportingServiceStub on web, CrashReportingServiceImpl on mobile/desktop
    final delegate = createCrashReportingService();
    
    _instance = CrashReportingService._(delegate: delegate);
    return _instance!;
  }

  final CrashReportingDelegate _delegate;
  final LoggingService _logger = LoggingService.instance;

  /// Initialize crash reporting SDK
  ///
  /// Should be called once during app startup. On web, this is a no-op.
  ///
  /// [apiKey] - API key for the crash reporting service (e.g., Shake)
  /// [enableCrashReporting] - Whether to enable automatic crash reporting
  /// [enableBugReporting] - Whether to enable manual bug reporting UI
  /// [enableScreenRecording] - Whether to enable automatic screen recording
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {
    try {
      _delegate.initialize(
        apiKey: apiKey,
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

  /// Set user information for crash reports
  ///
  /// Associates the active user with future crash reports and bug reports.
  void setUser({
    required String userId,
    String? email,
    String? name,
    String? organization,
    Map<String, String>? customData,
  }) {
    try {
      _delegate.setUser(
        userId: userId,
        email: email,
        name: name,
        organization: organization,
        customData: customData,
      );
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

  /// Add custom metadata to crash reports
  ///
  /// Metadata will be included in the next crash report or bug report.
  void addMetadata(String key, String value) {
    try {
      _delegate.addMetadata(key, value);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to add crash reporting metadata',
        error,
        stackTrace,
      );
    }
  }

  /// Clear all metadata previously added via [addMetadata]
  void clearAllMetadata() {
    try {
      _delegate.clearAllMetadata();
      _logger.debug('Cleared all crash reporting metadata');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to clear crash reporting metadata',
        error,
        stackTrace,
      );
    }
  }

  /// Manually show the bug report screen
  ///
  /// Useful for "Report a Bug" buttons in the app. On web, this is a no-op.
  void showBugReportScreen() {
    try {
      _delegate.showBugReportScreen();
      _logger.logUserAction('Manual bug report triggered');
    } catch (error, stackTrace) {
      _logger.error('Failed to show bug report screen', error, stackTrace);
    }
  }

  /// Log a custom event for debugging
  ///
  /// Events are included in crash reports and bug reports for context.
  void logEvent(String event, {Map<String, String>? data}) {
    try {
      _delegate.logEvent(event, data: data);
      _logger.debug('Logged event to crash reporting: $event');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to log event to crash reporting',
        error,
        stackTrace,
      );
    }
  }

  /// Set the current screen/route for context in crash reports
  ///
  /// Screen information helps identify where crashes occur.
  void setCurrentScreen(String screenName) {
    try {
      _delegate.setCurrentScreen(screenName);
      _logger.debug('Set current screen for crash reporting: $screenName');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to set current screen for crash reporting',
        error,
        stackTrace,
      );
    }
  }

  /// Add a log message that will be included in crash reports
  ///
  /// [level] - Log level: 'verbose', 'debug', 'info', 'warn', 'error'
  void addLogMessage(String message, {String level = 'info'}) {
    try {
      _delegate.addLogMessage(message, level: level);
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to add log message to crash reporting',
        error,
        stackTrace,
      );
    }
  }

  /// Record a handled (non-fatal) domain error with contextual metadata
  ///
  /// This is useful for tracking errors that don't crash the app but should
  /// be monitored, such as API failures, validation errors, etc.
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    try {
      _delegate.recordHandledError(
        error,
        context: context,
        stackTrace: stackTrace,
        metadata: metadata,
      );
    } catch (err, stack) {
      _logger.error('Failed to record handled error', err, stack);
    }
  }

  /// Create a CrashReportingService instance with a specific delegate
  ///
  /// **Test-only**: Use this in tests to inject a mock or stub delegate.
  /// For production code, use [instance] instead.
  @visibleForTesting
  static CrashReportingService createWithDelegate(CrashReportingDelegate delegate) {
    return CrashReportingService._(delegate: delegate);
  }
}