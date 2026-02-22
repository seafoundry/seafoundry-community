// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

enum InvitationStatus { pending, accepted, expired }

class Invitation extends Record {
  const Invitation({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.email,
    required this.invitedById,
    this.status = InvitationStatus.pending,
    this.role,
    this.expiresAt,
    this.emailSent,
    this.emailSentAt,
    this.emailError,
    this.token,
    this.originDomain,
  });

  Invitation.fromJson(super.json)
    : email = json['email'],
      invitedById = json['invitedById'],
      status = _parseInvitationStatus(json['status']),
      role = json['role'],
      expiresAt = _parseTimestampToString(json['expiresAt']),
      emailSent = json['emailSent'],
      emailSentAt = _parseTimestampToString(json['emailSentAt']),
      emailError = json['emailError'],
      token = json['token'] as String?,
      originDomain = json['originDomain'] as String?,
      super.fromJson();

  Invitation.partial({
    super.json,
    super.id,
    String? email,
    String? organizationId,
    String? invitedById,
    InvitationStatus? status,
    String? role,
    String? expiresAt,
    bool? emailSent,
    String? emailSentAt,
    String? emailError,
    String? token,
    String? originDomain,
  }) : email = email ?? json?['email'] ?? Missing.string,
       invitedById = invitedById ?? json?['invitedById'] ?? Missing.string,
       status = status ?? _parseInvitationStatus(json?['status']),
       role = role ?? json?['role'],
       expiresAt = expiresAt ?? _parseTimestampToString(json?['expiresAt']),
       emailSent = json?['emailSent'],
       emailSentAt = emailSentAt ?? _parseTimestampToString(json?['emailSentAt']),
       emailError = emailError ?? json?['emailError'],
       token = token ?? json?['token'],
       originDomain = originDomain ?? json?['originDomain'],
       super.partial();

  static InvitationStatus _parseInvitationStatus(dynamic value) {
    if (value == null) return InvitationStatus.pending;
    final statusMap = {
      for (var status in InvitationStatus.values) status.name: status,
    };
    return statusMap[value] ?? InvitationStatus.pending;
  }

  /// Converts Firestore Timestamp, DateTime, or String to ISO8601 String
  static String? _parseTimestampToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return null;
  }

  @override
  ModelType get modelType => ModelType.invitation;

  final String email;
  final String invitedById;
  final InvitationStatus status;
  final String? role;
  final String? expiresAt;
  final bool? emailSent;
  final String? emailSentAt;
  final String? emailError;
  final String? token;
  final String? originDomain;

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      "email": email,
      "invitedById": invitedById,
      "status": status.name,
      "role": role,
      "expiresAt": expiresAt,
      "emailSent": emailSent,
      "emailSentAt": emailSentAt,
      "emailError": emailError,
      if (token != null) "token": token,
      if (originDomain != null) "originDomain": originDomain,
    };
  }

  @override
  Invitation copyWith({
    String? id,
    String? email,
    String? invitedById,
    InvitationStatus? status,
    String? role,
    String? expiresAt,
    bool? emailSent,
    String? emailSentAt,
    String? emailError,
    String? token,
    String? originDomain,
    String? organizationId,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
  }) => Invitation(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    createdById: createdById ?? this.createdById,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    email: email ?? this.email,
    invitedById: invitedById ?? this.invitedById,
    status: status ?? this.status,
    role: role ?? this.role,
    expiresAt: expiresAt ?? this.expiresAt,
    emailSent: emailSent ?? this.emailSent,
    emailSentAt: emailSentAt ?? this.emailSentAt,
    emailError: emailError ?? this.emailError,
    token: token ?? this.token,
    originDomain: originDomain ?? this.originDomain,
  );

  @override
  bool validate() {
    return super.validate() && email.isNotEmpty && invitedById.isNotEmpty;
  }

  @override
  List<Object?> get props =>
      super.props + [email, invitedById, status, role, expiresAt, emailSent, emailSentAt, emailError, token, originDomain];

  bool get isExpired {
    if (expiresAt == null) return false;
    final expiry = DateTime.tryParse(expiresAt!);
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }
  bool get isPending => status == InvitationStatus.pending && !isExpired;
}
