import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Firestore-backed inventory record that stores the canonical five-axis
/// [OrganismRecord] payload. Events and cross-organism services can resolve a
/// single record ID (shared with the source holding/cohort) instead of
/// inspecting legacy snapshots.
class OrganismRecordEntry extends InventoryRecord {
  const OrganismRecordEntry({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required this.displayName,
    required this.source,
    this.sourceKind,
    required this.organismRecord,
    super.metadata,
  });

  OrganismRecordEntry.fromJson(super.json)
    : displayName = json['displayName'] ?? '',
      source = OrganismRecordSourceX.parse(json['source']),
      sourceKind = json['sourceKind'] as String?,
      organismRecord = OrganismRecord.fromJson(
        _extractOrganismRecordPayload(json, null),
      ),
      super.fromJson();

  OrganismRecordEntry.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
    String? displayName,
    String? source,
    String? sourceKind,
    Map<String, dynamic>? organismRecord,
    super.metadata,
  }) : displayName = displayName ?? json?['displayName'] ?? '',
       source = OrganismRecordSourceX.parse(source ?? json?['source']),
       sourceKind = sourceKind ?? json?['sourceKind'],
       organismRecord = OrganismRecord.fromJson(
         _extractOrganismRecordPayload(json, organismRecord),
       ),
       super.partial();

  final String displayName;
  final OrganismRecordSource source;
  final String? sourceKind;
  final OrganismRecord organismRecord;

  @override
  ModelType get modelType => ModelType.organismRecord;

  @override
  OrganismRecordEntry copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
    String? displayName,
    OrganismRecordSource? source,
    String? sourceKind,
    OrganismRecord? organismRecord,
  }) {
    return OrganismRecordEntry(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      metadata: metadata ?? this.metadata,
      displayName: displayName ?? this.displayName,
      source: source ?? this.source,
      sourceKind: sourceKind ?? this.sourceKind,
      organismRecord: organismRecord ?? this.organismRecord,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'displayName': displayName,
      'source': source.name,
      if (sourceKind != null) 'sourceKind': sourceKind,
      'organismKind': organismRecord.organismKind.name,
      'organismRecord': organismRecord.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    ...super.props,
    displayName,
    source,
    sourceKind,
    organismRecord,
  ];
}

enum OrganismRecordSource {
  holding,
  cohort,
  coral,
}

extension OrganismRecordSourceX on OrganismRecordSource {
  static OrganismRecordSource parse(dynamic value) {
    final text = value?.toString().toLowerCase();
    return OrganismRecordSource.values.firstWhere(
      (candidate) => candidate.name == text,
      orElse: () => OrganismRecordSource.holding,
    );
  }
}

Map<String, dynamic> _extractOrganismRecordPayload(
  Map<String, dynamic>? json,
  Map<String, dynamic>? override,
) {
  final source = override ??
      safeMapCast(json?['organismRecord']);
  if (source == null) {
    throw ArgumentError('organismRecord payload is required');
  }
  // Use deepNormalizeMap to handle nested Map<dynamic, dynamic> from web Firestore
  return deepNormalizeMap(source);
}
