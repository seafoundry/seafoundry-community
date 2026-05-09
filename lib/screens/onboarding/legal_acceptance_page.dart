import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/legal/legal_document.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/screens/onboarding/onboarding_page.dart';
import 'package:seafoundry_app/services/legal_documents_service.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Formats date for legal documents in "Mon DD, YYYY" format
String _formatLegalDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Onboarding page for legal acceptance (Terms of Service and Privacy Policy)
class LegalAcceptancePage extends OnboardingPage {
  const LegalAcceptancePage({
    super.key,
    required this.tosAccepted,
    required this.privacyAccepted,
    required this.onTosChanged,
    required this.onPrivacyChanged,
    required super.isPure,
    required super.onNext,
    super.onBack,
  }) : super(
          title: 'Legal Agreement',
          description:
              'Before continuing, please review and accept our Terms of Service and Privacy Policy.',
          nextButtonText: 'Accept & Continue',
        );

  final bool tosAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onTosChanged;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget buildContent(BuildContext context) {
    final tos = LegalDocumentsService.getTermsOfService();
    final privacy = LegalDocumentsService.getPrivacyPolicy();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Terms of Service checkbox
        _buildCheckboxTile(
          context: context,
          document: tos,
          value: tosAccepted,
          onChanged: onTosChanged,
        ),
        UI.dividerMd,
        // Privacy Policy checkbox
        _buildCheckboxTile(
          context: context,
          document: privacy,
          value: privacyAccepted,
          onChanged: onPrivacyChanged,
        ),
        UI.dividerLg,
        // Legal notice
        _buildLegalNotice(context),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required BuildContext context,
    required LegalDocument document,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: UI.paddingMd,
      decoration: BoxDecoration(
        color: UI.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? UI.primaryColor : UI.dividerColor,
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: UI.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: UIText.bodyLargeStyle,
                    children: [
                      const TextSpan(text: 'I have read and accept the '),
                      TextSpan(
                        text: document.type.displayName,
                        style: UIText.bodyLargeStyle.copyWith(
                              color: UI.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showDocument(context, document),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                UIText.bodySmall(
                  document.summary ?? '',
                  color: UI.textSecondaryColor,
                ),
                const SizedBox(height: 4),
                UIText.bodySmall(
                  'Effective: ${_formatLegalDate(document.effectiveDate)} • Version ${document.version}',
                  color: UI.textDisabledColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalNotice(BuildContext context) {
    return Container(
      padding: UI.paddingMd,
      decoration: BoxDecoration(
        color: UI.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: UI.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: UIText.bodySmall(
              'By accepting these agreements, you confirm that you have read, understood, '
              'and agree to be bound by the terms. You can review these documents at any time '
              'from your account settings.',
              color: UI.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showDocument(BuildContext context, LegalDocument document) {
    // If document has external URL, open it in browser
    if (document.isExternal) {
      _launchExternalDocument(document.url!);
    } else {
      // Otherwise show inline content dialog
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (context) => _LegalDocumentDialog(document: document),
      );
    }
  }

  Future<void> _launchExternalDocument(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (kDebugMode) {
          LoggingService.instance.warning('Could not launch URL: $urlString');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        LoggingService.instance.debug('Error launching URL', e);
      }
    }
  }

  @override
  bool validateForm() {
    return tosAccepted && privacyAccepted;
  }
}

/// Dialog for displaying a legal document
class _LegalDocumentDialog extends StatelessWidget {
  const _LegalDocumentDialog({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: UI.surfaceColor,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: UI.paddingLg,
              decoration: BoxDecoration(
                color: UI.backgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UIText.h4(document.type.displayName),
                        const SizedBox(height: 4),
                        UIText.bodySmall(
                          'Version ${document.version} • Effective ${_formatLegalDate(document.effectiveDate)}',
                          color: UI.textSecondaryColor,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: UI.paddingLg,
                child: SelectableText(
                  document.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: UI.paddingLg,
              decoration: BoxDecoration(
                color: UI.backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
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
