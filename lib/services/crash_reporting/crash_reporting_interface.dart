import 'package:seafoundry_app/errors/domain_errors.dart';

/// Contract for crash and bug reporting services.
///
/// Concrete implementations may forward to third-party SDKs (e.g. Shake) or
/// operate as in-memory stubs for tests and unsupported platforms.
abstract class CrashReportingDelegate {
  /// Initialize the crash reporting SDK.
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  });

  /// Associate the active user with crash reports.
  void setUser({
    required String userId,
    String? email,
    String? name,
    String? organization,
    Map<String, String>? customData,
  });

  /// Attach metadata that will be sent with future crash reports.
  void addMetadata(String key, String value);

  /// Remove all metadata previously recorded with [addMetadata].
  void clearAllMetadata();

  /// Present the bug report UI to the user.
  void showBugReportScreen();

  /// Record a custom event for diagnostics.
  void logEvent(String event, {Map<String, String>? data});

  /// Track the current screen/route for context in crash reports.
  void setCurrentScreen(String screenName);

  /// Add a log message with the supplied severity level.
  void addLogMessage(String message, {String level = 'info'});

  /// Record a handled (non-fatal) domain error with optional context.
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  });
}

