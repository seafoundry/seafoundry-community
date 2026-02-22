// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/services/crash_reporting_service.dart';
import 'package:seafoundry_app/services/feedback_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/feedback_dialog_form.dart';
class FeedbackDialogContent extends StatefulWidget {
  const FeedbackDialogContent({
    super.key,
    required this.user,
    required this.organization,
    required this.supportsSebastian,
    this.onOpenSebastian,
  });

  final User user;
  final Organization organization;
  final bool supportsSebastian;
  final VoidCallback? onOpenSebastian;

  @override
  State<FeedbackDialogContent> createState() => _FeedbackDialogContentState();
}
class _FeedbackDialogContentState extends State<FeedbackDialogContent>
    with SafeDialogMixin<FeedbackDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _feedbackService = FeedbackService();
  final _logger = LoggingService.instance;

  FeedbackType _type = FeedbackType.bugReport;
  FeedbackSeverity _severity = FeedbackSeverity.medium;
  bool _includeShakeDiagnostics = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isScaleOrg => widget.organization.tier == Tier.scale;
  bool get _showSebastianTools =>
      _isScaleOrg &&
      widget.supportsSebastian &&
      widget.onOpenSebastian != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    safeSetState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final description = _descriptionController.text.trim();
    final steps = _stepsController.text.trim();

    try {
      final result = await _feedbackService.submitFeedback(
        type: _type,
        description: description,
        severity: _type == FeedbackType.bugReport ? _severity : null,
        stepsToReproduce: steps.isEmpty ? null : steps,
        userId: widget.user.id,
        userName: widget.user.name,
        userEmail: widget.user.email,
        organizationId: widget.organization.id,
        organizationName: widget.organization.name,
        organizationTier: widget.organization.tier.name,
      );

      _logger.logUserAction(
        'feedback_submitted',
        details: {
          'ticketId': result.ticketId,
          'type': _type.apiValue,
          'orgId': widget.organization.id,
          'summary': _truncate(description),
        },
      );

      CrashReportingService.instance.logEvent(
        'feedback_submitted',
        data: {
          'ticketId': result.ticketId,
          'type': _type.apiValue,
          'orgTier': widget.organization.tier.name,
        },
      );
      CrashReportingService.instance.addLogMessage(
        'User feedback submitted (${_type.apiValue}): ${_truncate(description)}',
      );

      if (_includeShakeDiagnostics) {
        CrashReportingService.instance.addMetadata(
          'feedback_ticket_id',
          result.ticketId,
        );
        CrashReportingService.instance.addMetadata(
          'feedback_type',
          _type.apiValue,
        );
        CrashReportingService.instance.addMetadata(
          'feedback_description',
          _truncate(description, maxLength: 500),
        );
        CrashReportingService.instance.showBugReportScreen();
      }

      if (!mounted) return;
      popDialog();
      showSafeDialogSnackBar(
        context,
        '${result.message} Ticket ID: ${result.ticketId}',
        isSuccess: true,
      );
    } catch (e, stackTrace) {
      _logger.error('Feedback submission failed', e, stackTrace);
      if (!mounted) return;
      safeSetState(() {
        _isSubmitting = false;
        _errorMessage = 'Failed to send feedback. Please try again.';
      });
    }
  }
  void _openSebastian() {
    final launcher = widget.onOpenSebastian;
    if (launcher == null) return;
    popDialog();
    Future.microtask(launcher);
  }
  void _openShakeReport() {
    CrashReportingService.instance.logEvent(
      'feedback_shake_opened',
      data: {'orgTier': widget.organization.tier.name},
    );
    CrashReportingService.instance.showBugReportScreen();
  }

  String? _validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please describe the issue or feedback';
    }
    if (value.trim().length < 10) {
      return 'Please provide at least 10 characters';
    }
    return null;
  }

  String _truncate(String value, {int maxLength = 180}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackDialogForm(
      formKey: _formKey,
      descriptionController: _descriptionController,
      stepsController: _stepsController,
      type: _type,
      severity: _severity,
      includeShakeDiagnostics: _includeShakeDiagnostics,
      showSebastianTools: _showSebastianTools,
      isSubmitting: _isSubmitting,
      errorMessage: _errorMessage,
      onTypeChanged: (value) => safeSetState(() => _type = value ?? _type),
      onSeverityChanged: (value) =>
          safeSetState(() => _severity = value ?? _severity),
      onIncludeShakeChanged: (value) =>
          safeSetState(() => _includeShakeDiagnostics = value),
      onOpenSebastian: _openSebastian,
      onOpenShake: _openShakeReport,
      onCancel: () => popDialog(),
      onSubmit: _submitFeedback,
      descriptionValidator: _validateDescription,
    );
  }
}
