import 'package:equatable/equatable.dart';

/// Enum for legal document types
enum LegalDocumentType {
  termsOfService,
  privacyPolicy,
  serviceLevelAgreement;

  String get displayName {
    switch (this) {
      case LegalDocumentType.termsOfService:
        return 'Terms of Service';
      case LegalDocumentType.privacyPolicy:
        return 'Privacy Policy';
      case LegalDocumentType.serviceLevelAgreement:
        return 'Service Level Agreement';
    }
  }

  String get shortName {
    switch (this) {
      case LegalDocumentType.termsOfService:
        return 'TOS';
      case LegalDocumentType.privacyPolicy:
        return 'Privacy';
      case LegalDocumentType.serviceLevelAgreement:
        return 'SLA';
    }
  }
}

/// Represents a legal document (TOS, Privacy Policy, SLA) with versioning
///
/// Supports two modes:
/// 1. Inline content: Provide `content` field with markdown text
/// 2. External URL: Provide `url` field pointing to hosted document (recommended)
class LegalDocument extends Equatable {
  const LegalDocument({
    required this.id,
    required this.type,
    required this.version,
    required this.effectiveDate,
    this.content = '',
    this.url,
    this.summary,
    this.changeDescription,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      type: LegalDocumentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LegalDocumentType.termsOfService,
      ),
      version: json['version'] as String,
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      content: json['content'] as String? ?? '',
      url: json['url'] as String?,
      summary: json['summary'] as String?,
      changeDescription: json['changeDescription'] as String?,
    );
  }

  final String id;
  final LegalDocumentType type;
  final String version; // e.g., "1.0", "1.1", "2.0"
  final String content; // Markdown content (for inline display)
  final String? url; // External URL (recommended for production)
  final DateTime effectiveDate;
  final String? summary; // Brief summary for notifications
  final String? changeDescription; // What changed in this version

  /// Returns true if this document is hosted externally
  bool get isExternal => url != null && url!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'version': version,
    'effectiveDate': effectiveDate.toIso8601String(),
    if (content.isNotEmpty) 'content': content,
    if (url != null) 'url': url,
    if (summary != null) 'summary': summary,
    if (changeDescription != null) 'changeDescription': changeDescription,
  };

  @override
  List<Object?> get props => [id, type, version, content, url, effectiveDate, summary, changeDescription];
}

/// Tracks a user's acceptance of a legal document
class LegalAcceptance extends Equatable {
  const LegalAcceptance({
    required this.documentId,
    required this.documentType,
    required this.documentVersion,
    required this.acceptedAt,
    required this.userIp,
  });

  factory LegalAcceptance.fromJson(Map<String, dynamic> json) {
    return LegalAcceptance(
      documentId: json['documentId'] as String,
      documentType: LegalDocumentType.values.firstWhere(
        (e) => e.name == json['documentType'],
        orElse: () => LegalDocumentType.termsOfService,
      ),
      documentVersion: json['documentVersion'] as String,
      acceptedAt: DateTime.parse(json['acceptedAt'] as String),
      userIp: json['userIp'] as String?,
    );
  }

  final String documentId;
  final LegalDocumentType documentType;
  final String documentVersion;
  final DateTime acceptedAt;
  final String? userIp; // For compliance tracking

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'documentType': documentType.name,
    'documentVersion': documentVersion,
    'acceptedAt': acceptedAt.toIso8601String(),
    if (userIp != null) 'userIp': userIp,
  };

  @override
  List<Object?> get props => [documentId, documentType, documentVersion, acceptedAt, userIp];
}
