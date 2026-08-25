//
// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  WARNING: PLACEHOLDER LEGAL DOCUMENTS - NOT FOR PRODUCTION USE  ⚠️  ║
// ║                                                                           ║
// ║  The content in this file is placeholder text only.                       ║
// ║  Before deploying to production:                                          ║
// ║  1. Consult with qualified legal counsel                                  ║
// ║  2. Create proper Terms of Service, Privacy Policy, and SLA               ║
// ║  3. Host documents at proper URLs (see _tosUrl, _privacyUrl, _slaUrl)     ║
// ║  4. Remove placeholder content below                                       ║
// ║                                                                           ║
// ║  See: .github/issues/legal-documents-review.md                            ║
// ╚═══════════════════════════════════════════════════════════════════════════╝
//
import 'package:seafoundry_community/models/legal/legal_document.dart';

/// Service for managing legal documents (TOS, Privacy Policy, SLA)
///
/// **Production Setup:**
/// 1. Host your legal documents externally (GitHub Pages, Notion, static site)
/// 2. Update the URL constants below to point to your hosted documents
/// 3. Ensure URLs are publicly accessible and use HTTPS
/// 4. Update version numbers when documents change
///
/// **Why External Hosting:**
/// - Legal documents can be updated without app deployments
/// - Easier review and approval by legal counsel
/// - Version control via Git or CMS
/// - Better accessibility for users
class LegalDocumentsService {
  /// Current version of all legal documents
  static const String currentVersion = '1.0';

  // Whether to use external URLs for legal documents.
  // Set to true only when external URLs are live and accessible.
  // To enable at build time: flutter build --dart-define=LEGAL_USE_EXTERNAL_URLS=true
  static bool get _useExternalUrls => const bool.fromEnvironment(
    'LEGAL_USE_EXTERNAL_URLS',
    defaultValue: false, // Default to inline content
  );

  // Legal document URLs - configurable via environment or defaults to public endpoints
  // To override at build time: flutter build --dart-define=LEGAL_TOS_URL=https://...
  static String get _tosUrl => const String.fromEnvironment(
    'LEGAL_TOS_URL',
    defaultValue: 'https://example.com/terms',
  );
  static String get _privacyUrl => const String.fromEnvironment(
    'LEGAL_PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
  static String get _slaUrl => const String.fromEnvironment(
    'LEGAL_SLA_URL',
    defaultValue: 'https://example.com/sla',
  );

  /// Get the current Terms of Service
  /// 
  /// By default, shows inline content. Set LEGAL_USE_EXTERNAL_URLS=true
  /// at build time to use external URLs instead (requires URLs to be live).
  static LegalDocument getTermsOfService() {
    return LegalDocument(
      id: 'tos-v1.0',
      type: LegalDocumentType.termsOfService,
      version: currentVersion,
      effectiveDate: DateTime(2025, 1, 1),
      summary: 'Terms governing your use of SeaFoundry',
      // Only use external URL if explicitly enabled and URL is configured
      url: _useExternalUrls ? _tosUrl : null,
      content: _tosContent, // Primary content for inline display
    );
  }

  /// Get the current Privacy Policy
  /// 
  /// By default, shows inline content. Set LEGAL_USE_EXTERNAL_URLS=true
  /// at build time to use external URLs instead (requires URLs to be live).
  static LegalDocument getPrivacyPolicy() {
    return LegalDocument(
      id: 'privacy-v1.0',
      type: LegalDocumentType.privacyPolicy,
      version: currentVersion,
      effectiveDate: DateTime(2025, 1, 1),
      summary: 'How we collect, use, and protect your data',
      // Only use external URL if explicitly enabled and URL is configured
      url: _useExternalUrls ? _privacyUrl : null,
      content: _privacyContent, // Primary content for inline display
    );
  }

  /// Get the current Service Level Agreement
  ///
  /// By default, shows inline content. Set LEGAL_USE_EXTERNAL_URLS=true
  /// at build time to use external URLs instead (requires URLs to be live).
  static LegalDocument getServiceLevelAgreement() {
    return LegalDocument(
      id: 'sla-v1.0',
      type: LegalDocumentType.serviceLevelAgreement,
      version: currentVersion,
      effectiveDate: DateTime(2025, 1, 1),
      summary: 'Uptime and support commitments for SeaFoundry customers',
      // Only use external URL if explicitly enabled and URL is configured
      url: _useExternalUrls ? _slaUrl : null,
      content: _slaContent, // Primary content for inline display
    );
  }

  /// Get all current legal documents
  static List<LegalDocument> getAllDocuments() {
    return [
      getTermsOfService(),
      getPrivacyPolicy(),
      getServiceLevelAgreement(),
    ];
  }

  // Placeholder content - REPLACE WITH ACTUAL LEGAL DOCUMENTS

  static const String _tosContent = '''
# Terms of Service

**Effective Date:** January 1, 2025
**Version:** 1.0

## 1. Acceptance of Terms

By accessing and using SeaFoundry ("the Service"), you accept and agree to be bound by the terms and provisions of this agreement.

## 2. Use License

Permission is granted to temporarily access the Service for personal or commercial use related to aquaculture and marine conservation activities.

## 3. User Accounts

- You are responsible for maintaining the confidentiality of your account credentials
- You must provide accurate and complete information during registration
- You are responsible for all activities that occur under your account

## 4. Data and Content

- You retain all rights to data you input into the Service
- We reserve the right to remove content that violates these terms
- You grant us permission to use your data to provide and improve the Service

## 5. Acceptable Use

You agree not to:
- Violate any laws or regulations
- Infringe on intellectual property rights
- Transmit malicious code or attempt unauthorized access
- Use the Service to harm others or disrupt operations

## 6. Service Availability

- The Service is provided "as is" without warranties
- We strive for high availability but do not guarantee uninterrupted access
- We may modify or discontinue features with reasonable notice

## 7. Limitation of Liability

To the maximum extent permitted by law, SeaFoundry shall not be liable for any indirect, incidental, special, or consequential damages.

## 8. Changes to Terms

We reserve the right to modify these terms at any time. Users will be notified of material changes and must re-accept updated terms.

## 9. Termination

We reserve the right to terminate or suspend access to the Service for violations of these terms.

## 10. Contact

For questions about these Terms of Service, please contact us at [your-support-email].

---

**PLACEHOLDER NOTICE:** This is a placeholder document. Please consult with legal counsel to create proper Terms of Service tailored to your organization's needs and jurisdiction.
''';

  static const String _privacyContent = '''
# Privacy Policy

**Effective Date:** January 1, 2025
**Version:** 1.0

## 1. Information We Collect

### Information You Provide
- Account information (name, email, organization details)
- Inventory and operational data you input into the Service
- Communication with our support team

### Automatically Collected Information
- Device and browser information
- IP address and location data
- Usage patterns and feature interactions
- Cookies and similar tracking technologies

## 2. How We Use Your Information

We use collected information to:
- Provide and improve the Service
- Communicate with you about your account and updates
- Ensure security and prevent fraud
- Analyze usage patterns to enhance features
- Comply with legal obligations

## 3. Data Sharing and Disclosure

We do not sell your personal data. We may share data:
- With service providers who assist in operations (cloud hosting, email, analytics)
- When required by law or to protect rights and safety
- With your consent or at your direction
- In connection with a business transfer (merger, acquisition)

## 4. Data Security

We implement industry-standard security measures:
- Encryption in transit (TLS/SSL) and at rest
- Access controls and authentication
- Regular security assessments
- Secure data centers and infrastructure

## 5. Data Retention

We retain your data as long as your account is active or as needed to provide services. You may request deletion of your data, subject to legal retention requirements.

## 6. Your Rights

Depending on your location, you may have rights to:
- Access your personal data
- Correct inaccurate data
- Request deletion of your data
- Object to certain processing
- Data portability

To exercise these rights, contact us at [your-privacy-email].

## 7. Children's Privacy

The Service is not intended for children under 13. We do not knowingly collect information from children.

## 8. International Data Transfers

Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place.

## 9. Changes to This Policy

We may update this Privacy Policy. Material changes will be communicated, and continued use constitutes acceptance of the updated policy.

## 10. Contact Us

For privacy questions or concerns, contact us at:
- Email: [your-privacy-email]
- Data Protection Officer: [your-dpo-email]

---

**PLACEHOLDER NOTICE:** This is a placeholder document. Please consult with legal counsel to create a proper Privacy Policy compliant with applicable regulations (GDPR, CCPA, etc.).
''';

  static const String _slaContent = '''
# Service Level Agreement

SeaFoundry Community Edition is open-source software provided **as-is** under the
terms of the LICENSE file in this repository. No availability commitments,
support response times, backup guarantees, or service credits are offered.

If you self-host SeaFoundry Community for your organization, the SLA that
applies to your users is whatever you publish for your deployment — please
edit this document accordingly or replace it via your deployment configuration.
''';
}
