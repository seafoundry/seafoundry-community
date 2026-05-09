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
import 'package:seafoundry_app/models/legal/legal_document.dart';

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
    defaultValue: 'https://www.seafoundry.com/terms',
  );
  static String get _privacyUrl => const String.fromEnvironment(
    'LEGAL_PRIVACY_URL',
    defaultValue: 'https://www.seafoundry.com/privacy',
  );
  static String get _slaUrl => const String.fromEnvironment(
    'LEGAL_SLA_URL',
    defaultValue: 'https://www.seafoundry.com/sla',
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

For questions about these Terms of Service, please contact us at [support@seafoundry.com](mailto:support@seafoundry.com).

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

To exercise these rights, contact us at [privacy@seafoundry.com](mailto:privacy@seafoundry.com).

## 7. Children's Privacy

The Service is not intended for children under 13. We do not knowingly collect information from children.

## 8. International Data Transfers

Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place.

## 9. Changes to This Policy

We may update this Privacy Policy. Material changes will be communicated, and continued use constitutes acceptance of the updated policy.

## 10. Contact Us

For privacy questions or concerns, contact us at:
- Email: [privacy@seafoundry.com](mailto:privacy@seafoundry.com)
- Data Protection Officer: [dpo@seafoundry.com](mailto:dpo@seafoundry.com)

---

**PLACEHOLDER NOTICE:** This is a placeholder document. Please consult with legal counsel to create a proper Privacy Policy compliant with applicable regulations (GDPR, CCPA, etc.).
''';

  static const String _slaContent = '''
# Service Level Agreement (SLA)

**Effective Date:** January 1, 2025
**Version:** 1.0
**Applicable To:** SeaFoundry customers

## 1. Service Availability

### Uptime Commitment
- **Target:** 99.5% monthly uptime

### Scheduled Maintenance
- Scheduled maintenance windows: Sundays 02:00-06:00 UTC
- Advance notice: At least 72 hours for planned downtime
- Emergency maintenance: As needed with best-effort notification

### Uptime Calculation
Uptime percentage = ((Total Minutes in Month - Downtime Minutes) / Total Minutes in Month) × 100

Excluded from downtime calculations:
- Scheduled maintenance windows
- Issues caused by factors outside our control
- Client application or network issues

## 2. Support Response Times

- **Email Support:** Business hours (Mon-Fri, 9 AM - 5 PM local time)
- **Response Time:** Within 24 business hours
- **Channels:** Email, support portal

### Issue Priority Levels
- **P0 (Critical):** Service completely unavailable
- **P1 (High):** Major feature unavailable or data integrity issue
- **P2 (Medium):** Feature degradation with workaround available
- **P3 (Low):** Minor issues, feature requests

## 3. Data Backup and Recovery

### Backup Frequency
- **Automated backups:** Every 24 hours
- **Backup retention:** 30 days

### Recovery Time Objective (RTO)
- **Target:** 24 hours

### Recovery Point Objective (RPO)
- **Target:** 24 hours (data loss up to last backup)

## 4. Performance Standards

### Response Times
- **Page Load:** < 3 seconds (95th percentile)
- **API Response:** < 500ms (95th percentile)
- **Search Operations:** < 2 seconds (95th percentile)

### Scalability
- Auto-scaling to handle traffic spikes
- Database optimization for growing datasets

## 5. Service Credits

If we fail to meet the uptime commitment, you may be eligible for service credits:

- 99.0% - 99.49% uptime: 10% monthly fee credit
- 98.0% - 98.99% uptime: 25% monthly fee credit
- < 98.0% uptime: 50% monthly fee credit

### Credit Request Process
1. Submit claim within 30 days of incident
2. Provide details of downtime experienced
3. Credits applied to next billing cycle
4. Credits are your sole remedy for SLA breaches

## 6. Exclusions

This SLA does not apply to:
- Beta or experimental features
- Issues caused by user error or misuse
- Third-party service failures beyond our control
- Force majeure events

## 7. Monitoring and Reporting

- Public status page: [status.seafoundry.com](https://status.seafoundry.com)
- Real-time incident notifications
- Monthly uptime reports available on request

## 8. SLA Review and Updates

This SLA may be updated with 60 days notice. Continued use after changes constitutes acceptance.

## 9. Contact

For SLA-related questions or credit claims:
- Email: [sla@seafoundry.com](mailto:sla@seafoundry.com)
- Support Portal: [support.seafoundry.com](https://support.seafoundry.com)

---

**PLACEHOLDER NOTICE:** This is a placeholder document. Please consult with legal and technical teams to create an SLA that accurately reflects your service capabilities and commitments.
''';
}
