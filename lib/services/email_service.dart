// @tier: community
import 'package:cloud_functions/cloud_functions.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class EmailService {
  static final EmailService instance = EmailService._();
  EmailService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final LoggingService _logger = LoggingService.instance;

  /// Sends an invitation email to the specified email address
  ///
  /// This calls the Firebase Function to send the actual email
  Future<bool> sendInvitationEmail({
    required String email,
    required String organizationName,
    required String invitationId,
    required String invitedByName,
  }) async {
    try {
      // The email is automatically sent by the Firebase Function
      // when a new invitation is created in Firestore
      _logger.info('Invitation created, email will be sent automatically');
      return true;
    } catch (e) {
      _logger.error('Failed to send invitation email: $e');
      return false;
    }
  }

  /// Resends an invitation email using Firebase Functions
  Future<bool> resendInvitationEmail({required String invitationId}) async {
    try {
      // Call the Firebase Function to resend the email
      final callable = _functions.httpsCallable('resendInvitationEmail');
      await callable.call({'invitationId': invitationId});

      _logger.info('Invitation email resent successfully');
      return true;
    } catch (e) {
      _logger.error('Failed to resend invitation email: $e');
      return false;
    }
  }

  /// Sends a reminder email for an existing invitation
  Future<bool> sendReminderEmail({
    required String email,
    required String organizationName,
    required String invitationId,
  }) async {
    try {
      // For now, we'll use the resend function
      return await resendInvitationEmail(invitationId: invitationId);
    } catch (e) {
      _logger.error('Failed to send reminder email: $e');
      return false;
    }
  }
}
