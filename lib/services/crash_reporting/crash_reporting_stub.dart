import 'package:seafoundry_community/errors/domain_errors.dart';

import 'crash_reporting_interface.dart';

/// No-op crash reporting delegate used on unsupported platforms (e.g. web) and
/// available for tests.
class CrashReportingServiceStub implements CrashReportingDelegate {
  CrashReportingServiceStub._();

  static final CrashReportingServiceStub instance =
      CrashReportingServiceStub._();

  @override
  void initialize({
    required String apiKey,
    bool enableCrashReporting = true,
    bool enableBugReporting = true,
    bool enableScreenRecording = true,
  }) {}

  @override
  void setUser({
    required String userId,
    String? email,
    String? name,
    String? organization,
    Map<String, String>? customData,
  }) {}

  @override
  void addMetadata(String key, String value) {}

  @override
  void clearAllMetadata() {}

  @override
  void showBugReportScreen() {}

  @override
  void logEvent(String event, {Map<String, String>? data}) {}

  @override
  void setCurrentScreen(String screenName) {}

  @override
  void addLogMessage(String message, {String level = 'info'}) {}

  @override
  void recordHandledError(
    DomainError error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) {}
}

CrashReportingDelegate createCrashReportingService() =>
    CrashReportingServiceStub.instance;

