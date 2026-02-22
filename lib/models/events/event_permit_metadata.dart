// @tier: community
import 'package:equatable/equatable.dart';

class EventPermitMetadata extends Equatable {
  const EventPermitMetadata._internal({
    this.permitId,
    this.permitType,
    this.issuingAuthority,
    this.validFrom,
    this.validTo,
    this.attachmentUrls = const [],
  });

  const EventPermitMetadata.empty() : this._internal();

  factory EventPermitMetadata({
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    DateTime? validFrom,
    DateTime? validTo,
    List<String>? attachmentUrls,
  }) {
    return EventPermitMetadata._internal(
      permitId: permitId,
      permitType: permitType,
      issuingAuthority: issuingAuthority,
      validFrom: validFrom,
      validTo: validTo,
      attachmentUrls: attachmentUrls == null
          ? const []
          : List.unmodifiable(List<String>.from(attachmentUrls)),
    );
  }

  final String? permitId;
  final String? permitType;
  final String? issuingAuthority;
  final DateTime? validFrom;
  final DateTime? validTo;
  final List<String> attachmentUrls;

  bool get isEmpty =>
      (permitId == null || permitId!.isEmpty) &&
      (permitType == null || permitType!.isEmpty) &&
      (issuingAuthority == null || issuingAuthority!.isEmpty) &&
      validFrom == null &&
      validTo == null &&
      attachmentUrls.isEmpty;

  EventPermitMetadata copyWith({
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    DateTime? validFrom,
    DateTime? validTo,
    List<String>? attachmentUrls,
  }) {
    return EventPermitMetadata(
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (permitId != null) 'permitId': permitId,
      if (permitType != null) 'permitType': permitType,
      if (issuingAuthority != null) 'issuingAuthority': issuingAuthority,
      if (validFrom != null) 'validFrom': validFrom!.toIso8601String(),
      if (validTo != null) 'validTo': validTo!.toIso8601String(),
      if (attachmentUrls.isNotEmpty) 'attachmentUrls': attachmentUrls,
    };
  }

  factory EventPermitMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const EventPermitMetadata.empty();
    }
    return EventPermitMetadata._internal(
      permitId: _asString(json['permitId']),
      permitType: _asString(json['permitType']),
      issuingAuthority: _asString(json['issuingAuthority']),
      validFrom: _parseDate(json['validFrom']),
      validTo: _parseDate(json['validTo']),
      attachmentUrls: json['attachmentUrls'] is List
          ? List<String>.from(
              (json['attachmentUrls'] as List).whereType<String>(),
            )
          : const [],
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    permitId,
    permitType,
    issuingAuthority,
    validFrom,
    validTo,
    attachmentUrls,
  ];
}

EventPermitMetadata? buildPermitMetadataFromTextInputs({
  required String permitIdText,
  required String permitTypeText,
  required String issuingAuthorityText,
  required String attachmentsText,
  required DateTime? validFrom,
  required DateTime? validTo,
  bool hadInitialPermit = false,
  bool isEditMode = false,
}) {
  String trim(String value) => value.trim();
  final permitId = trim(permitIdText);
  final permitType = trim(permitTypeText);
  final issuingAuthority = trim(issuingAuthorityText);
  final attachments = attachmentsText
      .split(RegExp(r'[\n,]'))
      .map(trim)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  final hasValues =
      permitId.isNotEmpty ||
      permitType.isNotEmpty ||
      issuingAuthority.isNotEmpty ||
      attachments.isNotEmpty ||
      validFrom != null ||
      validTo != null;

  if (hasValues) {
    return EventPermitMetadata(
      permitId: permitId.isEmpty ? null : permitId,
      permitType: permitType.isEmpty ? null : permitType,
      issuingAuthority: issuingAuthority.isEmpty ? null : issuingAuthority,
      validFrom: validFrom,
      validTo: validTo,
      attachmentUrls: attachments,
    );
  }

  if (isEditMode && hadInitialPermit) {
    return const EventPermitMetadata.empty();
  }

  return null;
}
