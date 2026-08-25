// ignore_for_file: overridden_fields
import 'package:seafoundry_community/models/legal/legal_document.dart';
import 'package:seafoundry_community/models/model_interfaces.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

class User extends Record implements Named {
  const User({
    required super.id,
    required this.name,
    required this.email,
    this.tagline,
    this.imageUrl,
    this.role,
    this.legalAcceptances = const [],
    this.metadata,
    this.onboardingCompletedAt,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
  });

  User.partial({
    super.json,
    String? id,
    String? name,
    String? email,
    String? tagline,
    String? organizationId,
    String? imageUrl,
    String? role,
    List<LegalAcceptance>? legalAcceptances,
    Map<String, dynamic>? metadata,
    DateTime? onboardingCompletedAt,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
  }) : name = name ?? json?['name'] ?? Missing.string,
       email = email ?? json?['email'] ?? Missing.string,
       tagline = tagline ?? (json?['tagline'] is String ? json!['tagline'] as String : null),
       imageUrl = imageUrl ?? json?['imageUrl'] ?? Missing.string,
       role = role ?? json?['role'],
       legalAcceptances = legalAcceptances ??
         _parseLegalAcceptances(json?['legalAcceptances']),
       metadata = metadata ?? safeMapCast(json?['metadata']),
       onboardingCompletedAt = onboardingCompletedAt ??
         (json?['onboardingCompletedAt'] != null
             ? DateTime.parse(json!['onboardingCompletedAt'] as String)
             : null),
       super.partial();

  User.fromJson(super.json)
    : name = json['name'],
      email = json['email'],
      tagline = json['tagline'] is String ? json['tagline'] as String : null,
      imageUrl = json['imageUrl'],
      role = json['role'],
      legalAcceptances = _parseLegalAcceptances(json['legalAcceptances']),
      metadata = safeMapCast(json['metadata']),
      onboardingCompletedAt = json['onboardingCompletedAt'] != null
          ? DateTime.parse(json['onboardingCompletedAt'] as String)
          : null,
      super.fromJson();

  @override
  ModelType get modelType => ModelType.user;

  @override
  final String name;
  final String email;

  /// Returns the first name (first word of the name)
  String get firstName => name.split(' ').first;

  /// Returns the initials (first letter of first and last name)
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
  
  /// Optional user tagline/bio (e.g., "Marine Biologist | Coral Restoration Specialist")
  final String? tagline;
  final String? imageUrl;
  final String? role;

  /// Computed property that returns true if the user has admin role.
  bool get isAdmin => role == 'admin';

  final List<LegalAcceptance> legalAcceptances;

  /// Timestamp when the user completed onboarding.
  /// null if onboarding has not been completed yet.
  final DateTime? onboardingCompletedAt;

  @override
  final Map<String, dynamic>? metadata;

  @override
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "email": email,
      if (tagline != null && tagline!.isNotEmpty) "tagline": tagline,
      "organizationId": organizationId,
      "imageUrl": imageUrl,
      "role": role,
      "legalAcceptances": legalAcceptances.map((e) => e.toJson()).toList(),
      if (metadata != null) "metadata": metadata,
      if (onboardingCompletedAt != null)
        "onboardingCompletedAt": onboardingCompletedAt!.toIso8601String(),
      ...super.toJson(),
    };
  }

  @override
  bool validate() {
    return super.validate() && name.isNotEmpty && email.isNotEmpty;
  }

  @override
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? tagline,
    String? organizationId,
    String? imageUrl,
    String? role,
    List<LegalAcceptance>? legalAcceptances,
    Map<String, dynamic>? metadata,
    DateTime? onboardingCompletedAt,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    tagline: tagline ?? this.tagline,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    imageUrl: imageUrl ?? this.imageUrl,
    role: role ?? this.role,
    legalAcceptances: legalAcceptances ?? this.legalAcceptances,
    metadata: metadata ?? this.metadata,
    onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
  );

  @override
  List<Object?> get props => super.props + [name, email, tagline, imageUrl, role, legalAcceptances, metadata, onboardingCompletedAt];

  static List<LegalAcceptance> _parseLegalAcceptances(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) {
      final map = safeMapCast(e);
      return map != null ? LegalAcceptance.fromJson(map) : null;
    }).whereType<LegalAcceptance>().toList();
  }
}
