// @tier: community
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:seafoundry_app/services/logging_service.dart';

enum FeedbackType {
  bugReport,
  featureRequest,
  generalFeedback,
  question,
}

extension FeedbackTypeX on FeedbackType {
  String get apiValue => switch (this) {
        FeedbackType.bugReport => 'bug_report',
        FeedbackType.featureRequest => 'feature_request',
        FeedbackType.generalFeedback => 'general_feedback',
        FeedbackType.question => 'question',
      };

  String get label => switch (this) {
        FeedbackType.bugReport => 'Bug report',
        FeedbackType.featureRequest => 'Feature request',
        FeedbackType.generalFeedback => 'General feedback',
        FeedbackType.question => 'Question',
      };
}

enum FeedbackSeverity {
  low,
  medium,
  high,
  critical,
}

extension FeedbackSeverityX on FeedbackSeverity {
  String get apiValue => name;

  String get label => switch (this) {
        FeedbackSeverity.low => 'Low',
        FeedbackSeverity.medium => 'Medium',
        FeedbackSeverity.high => 'High',
        FeedbackSeverity.critical => 'Critical',
      };
}

class FeedbackSubmissionResult {
  const FeedbackSubmissionResult({
    required this.ticketId,
    required this.message,
    this.emailSent = false,
  });

  final String ticketId;
  final String message;
  final bool emailSent;

  factory FeedbackSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmissionResult(
      ticketId: json['ticketId'] as String? ?? 'unknown',
      message: json['message'] as String? ?? 'Feedback submitted',
      emailSent: json['emailSent'] as bool? ?? false,
    );
  }
}

class FeedbackService {
  FeedbackService({
    FirebaseFunctions? functions,
    LoggingService? logger,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _logger = logger ?? LoggingService.instance;

  final FirebaseFunctions _functions;
  final LoggingService _logger;

  Future<FeedbackSubmissionResult> submitFeedback({
    required FeedbackType type,
    required String description,
    required String userId,
    required String userName,
    required String userEmail,
    required String organizationId,
    required String organizationName,
    required String organizationTier,
    FeedbackSeverity? severity,
    String? stepsToReproduce,
    String? currentScreen,
    String? currentNodeType,
  }) async {
    final callable = _functions.httpsCallable('submitFeedbackReport');
    final payload = <String, dynamic>{
      'feedbackType': type.apiValue,
      'description': description,
      if (severity != null) 'severity': severity.apiValue,
      if (stepsToReproduce != null && stepsToReproduce.isNotEmpty)
        'stepsToReproduce': stepsToReproduce,
      'user': {
        'id': userId,
        'name': userName,
        'email': userEmail,
      },
      'organization': {
        'id': organizationId,
        'name': organizationName,
        'tier': organizationTier,
      },
      'context': {
        if (currentScreen != null) 'currentScreen': currentScreen,
        if (currentNodeType != null) 'currentNodeType': currentNodeType,
        'platform': _platformLabel(),
      },
      'source': 'feedback_dialog',
    };

    try {
      final result = await callable.call<Map<String, dynamic>>(payload);
      return FeedbackSubmissionResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e, stackTrace) {
      _logger.error('Feedback submission failed: ${e.code}', e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      _logger.error('Feedback submission failed', e, stackTrace);
      rethrow;
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
