// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// A funding source (grant provider, donor, foundation) that sponsors restoration activities.
class Funder extends Record {
  static const Object _unset = Object();

  final String name;
  final String? contactName;
  final String? contactEmail;
  final String? notes;
  final String? logoUrl;
  final bool isActive;

  const Funder({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.name,
    this.contactName,
    this.contactEmail,
    this.notes,
    this.logoUrl,
    this.isActive = true,
    super.metadata,
  });

  Funder.fromJson(super.json)
      : name = json['name'] ?? 'Untitled Funder',
        contactName = json['contactName'],
        contactEmail = json['contactEmail'],
        notes = json['notes'],
        logoUrl = json['logoUrl'],
        isActive = json['isActive'] ?? true,
        super.fromJson();

  Funder.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? name,
    String? contactName,
    String? contactEmail,
    String? notes,
    String? logoUrl,
    bool? isActive,
  })  : name = name ?? json?['name'] ?? 'Untitled Funder',
        contactName = contactName ?? json?['contactName'],
        contactEmail = contactEmail ?? json?['contactEmail'],
        notes = notes ?? json?['notes'],
        logoUrl = logoUrl ?? json?['logoUrl'],
        isActive = isActive ?? json?['isActive'] ?? true,
        super.partial();

  @override
  ModelType get modelType => ModelType.funder;

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (contactName != null) 'contactName': contactName,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (notes != null) 'notes': notes,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'isActive': isActive,
      ...super.toJson(),
    };
  }

  @override
  Funder copyWith({
    Object? id = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? name = _unset,
    Object? contactName = _unset,
    Object? contactEmail = _unset,
    Object? notes = _unset,
    Object? logoUrl = _unset,
    Object? isActive = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Funder(
      id: identical(id, _unset) ? this.id : id as String,
      createdById: identical(createdById, _unset)
          ? this.createdById
          : createdById as String,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as String,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as String,
      updatedById: identical(updatedById, _unset)
          ? this.updatedById
          : updatedById as String,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as String,
      name: identical(name, _unset) ? this.name : name as String,
      contactName: identical(contactName, _unset)
          ? this.contactName
          : contactName as String?,
      contactEmail: identical(contactEmail, _unset)
          ? this.contactEmail
          : contactEmail as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      logoUrl: identical(logoUrl, _unset) ? this.logoUrl : logoUrl as String?,
      isActive: identical(isActive, _unset) ? this.isActive : isActive as bool,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    return super.validate() && name.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        ...super.props,
        name,
        contactName,
        contactEmail,
        notes,
        logoUrl,
        isActive,
      ];
}
