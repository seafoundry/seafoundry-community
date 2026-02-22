// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Landing screen shown when an unauthenticated user clicks an invitation link.
/// Shows a generic invitation message and prompts the user to sign in or create an account.
///
/// Note: We don't fetch invitation details here because unauthenticated users
/// don't have Firestore permissions to read invitations. The invitation will
/// be validated after authentication during the onboarding flow.
class InvitationLandingScreen extends StatelessWidget {
  final String invitationId;
  final VoidCallback onContinue;

  const InvitationLandingScreen({
    super.key,
    required this.invitationId,
    required this.onContinue,
  });

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
              child: _buildInvitationCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Image.asset(
              'assets/provenance_logo.png',
              height: 80,
              color: AppColors.background,
              colorBlendMode: BlendMode.multiply,
            ),
            UI.spacingVerticalLg,

            // Title
            UIText.h3("You're Invited!"),
            UI.spacingVerticalMd,

            // Invitation message
            UIText.bodyMedium(
              "You've been invited to join an organization on SeaFoundry Provenance.",
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            UI.spacingVerticalLg,

            // Description
            UIText.bodySmall(
              'Sign in or create an account to accept this invitation and join the team.',
              color: AppColors.textSecondary,
              textAlign: TextAlign.center,
            ),
            UI.spacingVerticalXl,

            // CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            UI.spacingVerticalMd,

            // Info text
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppColors.withOpacity(AppColors.info, 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: UIText.bodySmall(
                      'Use the same email address the invitation was sent to.',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
