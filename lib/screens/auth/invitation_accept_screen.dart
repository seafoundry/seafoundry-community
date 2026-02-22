// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/invitation_accept/invitation_accept_cubit.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Screen shown when an authenticated user clicks an invitation link.
/// Handles accepting the invitation and shows appropriate feedback.
class InvitationAcceptScreen extends StatelessWidget {
  final String invitationId;
  final String userEmail;
  final String userId;
  final VoidCallback onComplete;
  final VoidCallback onError;

  const InvitationAcceptScreen({
    super.key,
    required this.invitationId,
    required this.userEmail,
    required this.userId,
    required this.onComplete,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InvitationAcceptCubit(
        firestore: context.read<FirebaseService>().firestore,
        recordRepository: context.read<RecordRepository>(),
        currentUserCubit: context.read<CurrentUser>(),
        invitationId: invitationId,
        userEmail: userEmail,
        userId: userId,
      )..processInvitation(),
      child: _InvitationAcceptContent(
        onComplete: onComplete,
        onError: onError,
      ),
    );
  }
}

class _InvitationAcceptContent extends StatelessWidget {
  const _InvitationAcceptContent({
    required this.onComplete,
    required this.onError,
  });

  final VoidCallback onComplete;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: BlocConsumer<InvitationAcceptCubit, InvitationAcceptState>(
                listener: (context, state) {
                  if (state is InvitationAcceptSuccess) {
                    // Auto-navigate after a short delay
                    Future.delayed(const Duration(seconds: 2), () {
                      if (context.mounted) {
                        onComplete();
                      }
                    });
                  }
                },
                builder: (context, state) {
                  return switch (state) {
                    InvitationAcceptInitial() ||
                    InvitationAcceptLoading() =>
                      _buildLoading(context),
                    InvitationAcceptSuccess(:final organizationName) =>
                      _buildSuccess(context, organizationName),
                    InvitationAcceptError(:final message) =>
                      _buildError(context, message),
                  };
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            UI.spacingVerticalLg,
            UIText.h4('Accepting Invitation'),
            UI.spacingVerticalMd,
            UIText.bodyMedium(
              'Please wait while we add you to the organization...',
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, String? organizationName) {
    final orgName = organizationName ?? 'the organization';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.withOpacity(AppColors.success, 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.success,
              ),
            ),
            UI.spacingVerticalLg,
            UIText.h4('Welcome!'),
            UI.spacingVerticalMd,
            UIText.bodyMedium(
              'You have successfully joined $orgName.',
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            UI.spacingVerticalLg,
            UIText.bodySmall(
              'Redirecting you to the dashboard...',
              color: AppColors.textHint,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            UI.spacingVerticalLg,
            UIText.h4('Could Not Accept Invitation'),
            UI.spacingVerticalMd,
            UIText.bodyMedium(
              message,
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            UI.spacingVerticalXl,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onError,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                ),
                child: const Text('Continue to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
