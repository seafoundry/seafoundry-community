// @tier: community
import 'package:equatable/equatable.dart';

/// Point-in-time snapshot of organization data for transfer manifests.
///
/// This is intentionally denormalized to preserve the historical record of
/// what organization data looked like at the time of transfer initiation.
/// The organization name, domain, etc. may change after the transfer,
/// but the manifest preserves the original values.
class OrganizationSnapshot extends Equatable {
  const OrganizationSnapshot({
    this.id,
    this.name,
    this.domain,
    this.urlPath,
    this.email,
  });

  /// Organization ID (may be null for email-only transfers).
  final String? id;

  /// Organization name at time of transfer.
  final String? name;

  /// Organization domain at time of transfer.
  final String? domain;

  /// Organization URL path at time of transfer.
  final String? urlPath;

  /// Email address (for email-only transfers where org ID is not known).
  final String? email;

  factory OrganizationSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OrganizationSnapshot();
    return OrganizationSnapshot(
      id: json['id'] as String?,
      name: json['name'] as String?,
      domain: json['domain'] as String?,
      urlPath: json['urlPath'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (domain != null) 'domain': domain,
      if (urlPath != null) 'urlPath': urlPath,
      if (email != null) 'email': email,
    };
  }

  /// Whether this is an email-only transfer recipient (no org ID).
  bool get isEmailOnly => id == null && email != null;

  /// Display name: organization name if available, otherwise email.
  String get displayName => name ?? email ?? 'Unknown';

  /// Provides backward compatibility with Map<String, dynamic> access patterns.
  /// Allows code to use `snapshot['id']` instead of `snapshot.id`.
  /// @Deprecated('Use typed property accessors instead')
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'domain':
        return domain;
      case 'urlPath':
        return urlPath;
      case 'email':
        return email;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [id, name, domain, urlPath, email];
}

/// Point-in-time snapshot of user data for transfer manifests.
///
/// This preserves who initiated or acted on a transfer at that moment in time.
class UserSnapshot extends Equatable {
  const UserSnapshot({
    required this.id,
    this.name,
    this.email,
  });

  final String id;
  final String? name;
  final String? email;

  factory UserSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const UserSnapshot(id: '');
    }
    return UserSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    };
  }

  /// Display name: user name if available, otherwise email, otherwise ID.
  String get displayName => name ?? email ?? id;

  /// Provides backward compatibility with Map<String, dynamic> access patterns.
  /// @Deprecated('Use typed property accessors instead')
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'email':
        return email;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [id, name, email];
}

/// Point-in-time snapshot of genet data for transfer manifests.
///
/// This preserves the genet's state at the time of transfer initiation.
/// Contains provenance information, ownership details, and lineage data
/// that may change after the transfer is completed.
class GenetSnapshot extends Equatable {
  const GenetSnapshot({
    required this.id,
    this.name,
    this.speciesId,
    this.speciesCode,
    this.localId,
    this.provenanceTypeId,
    this.provenanceId,
    this.clonalId,
    this.accessionNumber,
    this.notes,
    this.provenance,
    this.parentGameteIds,
    this.parentCohortId,
    this.donorGenotypeId,
    this.damGameteIds,
    this.sireGameteIds,
    this.crossDate,
    this.readyForOutplant = false,
    this.createdAt,
    this.updatedAt,
    this.aliases,
    this.ownership,
    this.metadata,
  });

  final String id;
  final String? name;
  final String? speciesId;
  final String? speciesCode;
  final String? localId;
  final String? provenanceTypeId;
  final String? provenanceId;
  final String? clonalId;
  final String? accessionNumber;
  final String? notes;
  final Map<String, dynamic>? provenance;
  final List<String>? parentGameteIds;
  final String? parentCohortId;
  final String? donorGenotypeId;
  final List<String>? damGameteIds;
  final List<String>? sireGameteIds;
  final String? crossDate;
  final bool readyForOutplant;
  final String? createdAt;
  final String? updatedAt;
  final List<Map<String, dynamic>>? aliases;
  final Map<String, dynamic>? ownership;
  final Map<String, dynamic>? metadata;

  factory GenetSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const GenetSnapshot(id: '');
    return GenetSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String?,
      speciesId: json['speciesId'] as String?,
      speciesCode: json['speciesCode'] as String?,
      localId: json['localId'] as String?,
      provenanceTypeId: json['provenanceTypeId'] as String?,
      provenanceId: json['provenanceId'] as String?,
      clonalId: json['clonalId'] as String?,
      accessionNumber: json['accessionNumber'] as String?,
      notes: json['notes'] as String?,
      provenance: _parseProvenance(json['provenance']),
      parentGameteIds: (json['parentGameteIds'] as List?)?.cast<String>(),
      parentCohortId: json['parentCohortId'] as String?,
      donorGenotypeId: json['donorGenotypeId'] as String?,
      damGameteIds: (json['damGameteIds'] as List?)?.cast<String>(),
      sireGameteIds: (json['sireGameteIds'] as List?)?.cast<String>(),
      crossDate: json['crossDate'] as String?,
      readyForOutplant: json['readyForOutplant'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      aliases: (json['aliases'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      ownership: json['ownership'] is Map
          ? Map<String, dynamic>.from(json['ownership'] as Map)
          : null,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (speciesId != null) 'speciesId': speciesId,
      if (speciesCode != null) 'speciesCode': speciesCode,
      if (localId != null) 'localId': localId,
      if (provenanceTypeId != null) 'provenanceTypeId': provenanceTypeId,
      if (provenanceId != null && provenanceId!.isNotEmpty)
        'provenanceId': provenanceId,
      if (clonalId != null) 'clonalId': clonalId,
      if (accessionNumber != null) 'accessionNumber': accessionNumber,
      if (notes != null) 'notes': notes,
      if (provenance != null) 'provenance': provenance,
      if (parentGameteIds != null && parentGameteIds!.isNotEmpty)
        'parentGameteIds': parentGameteIds,
      if (parentCohortId != null) 'parentCohortId': parentCohortId,
      if (donorGenotypeId != null) 'donorGenotypeId': donorGenotypeId,
      if (damGameteIds != null && damGameteIds!.isNotEmpty)
        'damGameteIds': damGameteIds,
      if (sireGameteIds != null && sireGameteIds!.isNotEmpty)
        'sireGameteIds': sireGameteIds,
      if (crossDate != null) 'crossDate': crossDate,
      'readyForOutplant': readyForOutplant,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (aliases != null && aliases!.isNotEmpty) 'aliases': aliases,
      if (ownership != null && ownership!.isNotEmpty) 'ownership': ownership,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Display name for UI.
  String get displayName => name ?? localId ?? id;

  /// Provides backward compatibility with Map<String, dynamic> access patterns.
  /// @Deprecated('Use typed property accessors instead')
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'speciesId':
        return speciesId;
      case 'speciesCode':
        return speciesCode;
      case 'localId':
        return localId;
      case 'provenanceTypeId':
        return provenanceTypeId;
      case 'provenanceId':
        return provenanceId;
      case 'clonalId':
        return clonalId;
      case 'accessionNumber':
        return accessionNumber;
      case 'notes':
        return notes;
      case 'provenance':
        return provenance;
      case 'parentGameteIds':
        return parentGameteIds;
      case 'parentCohortId':
        return parentCohortId;
      case 'donorGenotypeId':
        return donorGenotypeId;
      case 'damGameteIds':
        return damGameteIds;
      case 'sireGameteIds':
        return sireGameteIds;
      case 'crossDate':
        return crossDate;
      case 'readyForOutplant':
        return readyForOutplant;
      case 'createdAt':
        return createdAt;
      case 'updatedAt':
        return updatedAt;
      case 'aliases':
        return aliases;
      case 'ownership':
        return ownership;
      case 'metadata':
        return metadata;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        speciesId,
        speciesCode,
        localId,
        provenanceTypeId,
        provenanceId,
        clonalId,
        accessionNumber,
        notes,
        provenance,
        parentGameteIds,
        parentCohortId,
        donorGenotypeId,
        damGameteIds,
        sireGameteIds,
        crossDate,
        readyForOutplant,
        createdAt,
        updatedAt,
        aliases,
        ownership,
        metadata,
      ];
}

Map<String, dynamic>? _parseProvenance(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return {'legacyValue': raw};
  }
  return null;
}
