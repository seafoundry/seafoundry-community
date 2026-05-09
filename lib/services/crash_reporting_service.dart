import 'package:meta/meta.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/services/crash_reporting/crash_reporting_interface.dart';

// Conditional import: use stub on web, impl on mobile/desktop
import 'crash_reporting/crash_reporting_stub.dart'
    if (dart.library.io) 'crash_reporting/crash_reporting_impl.dart';

/// Thin wrapper that selects the platform-appropriate [CrashReportingDelegate]
/// via conditional imports and forwards all calls to it.
///
/// Error handling and logging live in the delegates themselves
/// ([CrashReportingServiceImpl], [FirebaseCrashlyticsDelegate]) and the
/// [CompositeCrashReportingDelegate] that fans out to them.
///
/// **Platform Support**:
/// - Mobile/Desktop: Composite of Shake SDK + Firebase Crashlytics
/// - Web: No-op stub
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
  /// - Mobile/Desktop: Uses Shake SDK + Firebase Crashlytics via composite
  static CrashReportingService get instance {
    if (_instance != null) return _instance!;

    final delegate = createCrashReportingService();
    _instance = CrashReportingService._(delegate: delegate);
    return _instance!;
  }

  final CrashReportingDelegate _delegate;

  /// Initialize crash reporting SDK.
  ///
  /// Should be called once during app startup. On web, this is a no-op.
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {
    _delegate.initialize(
      apiKey: apiKey,
      enableCrashReporting: enableCrashReporting,
      enableBugReporting: enableBugReporting,
      enableScreenRecording: enableScreenRecording,
    );
  }

  /// Set user information for crash reports.
  ///
  /// Associates the active user with future crash reports and bug reports.
  void setUser({
    required String userId,
    String? email,
    String? name,
    String? organization,
    Map<String, String>? customData,
  }) {
    _delegate.setUser(
      userId: userId,
      email: email,
      name: name,
      organization: organization,
      customData: customData,
    );
  }

  /// Record a handled (non-fatal) domain error with contextual metadata.
  ///
  /// Useful for tracking errors that don't crash the app but should be
  /// monitored, such as API failures, validation errors, etc.
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {
    _delegate.recordHandledError(
      error,
      context: context,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  /// Create a CrashReportingService instance with a specific delegate.
  ///
  /// **Test-only**: Use this in tests to inject a mock or stub delegate.
  /// For production code, use [instance] instead.
  @visibleForTesting
  static CrashReportingService createWithDelegate(
    CrashReportingDelegate delegate,
  ) {
    return CrashReportingService._(delegate: delegate);
  }
}