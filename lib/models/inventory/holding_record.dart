import 'dart:collection';

import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/mixins/life_stage_progression_mixin.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Neutral representation of a holding (discrete individual or batch) that
/// captures population, life stage, provenance references, and graph-node
/// placement without depending on coral-only models.
///
/// Identity / life-stage / measurement / ownership are persisted as
/// **denormalized display fields** on the holding (kept in sync with the
/// canonical [OrganismRecord] doc identified by [organismRecordId]). Callers
/// needing deep axes (aliases, physicalForm, lifeStageHistory, sizeSpec) must
/// resolve the canonical record via
/// [resolveOrganismRecord], which performs an async repository lookup. The
/// embedded [organismRecord] field is currently retained for the in-flight
/// migration; new code should treat it as private to this file.
class HoldingRecord extends InventoryRecord
    with LifeStageProgressionMixin, MeasurableMixin {
  HoldingRecord({
    required super.id,
    required this.tagId,
    required this.organismKind,
    required this.lifeStage,
    required this.measurement,
    this.provenanceId,
    this.cohortId,
    this.siteId,
    this.groupId,
    this.structureId,
    this.ownerOrganizationId,
    this.managingOrganizationId,
    Map<String, ForeignKeyReference>? foreignKeys,
    HoldingAttributes? attributes,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    OrganismRecord? organismRecord,
    String? organismRecordId,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
  })  : foreignKeys = _normalizeForeignKeys(foreignKeys),
        attributes = _normalizeAttributes(attributes),
        organismRecordId = _resolveOrganismRecordId(
          explicit: organismRecordId,
          base: organismRecord,
          fallbackId: id,
        ),
        organismRecord = _buildOrganismRecord(
          base: organismRecord,
          tagId: tagId,
          organismKind: organismKind,
          lifeStage: lifeStage,
          measurement: measurement,
          attributes: _normalizeAttributes(attributes),
          metadata: _normalizeMetadata(metadata),
          ownerOrganizationId: ownerOrganizationId,
          managingOrganizationId: managingOrganizationId,
          foreignKeys: _normalizeForeignKeys(foreignKeys),
        ),
        super(
          createdAt: createdAt ?? organismRecord?.createdAt ?? Missing.dateTimeString,
          createdById: createdById ?? organismRecord?.createdById ?? Missing.string,
          updatedAt: updatedAt ?? organismRecord?.updatedAt ?? Missing.dateTimeString,
          updatedById: updatedById ?? organismRecord?.updatedById ?? Missing.string,
          organizationId: organizationId ?? organismRecord?.organizationId ?? Missing.string,
          urlPath: urlPath ?? organismRecord?.urlPath ?? Missing.string,
          internalPath: internalPath ?? organismRecord?.internalPath ?? Missing.string,
          slug: slug ?? organismRecord?.slug ?? Missing.string,
          metadata: UnmodifiableMapView(_normalizeMetadata(metadata)),
        );

  final String? provenanceId;
  final String? cohortId;
  final String? siteId;
  final String? groupId;
  final String? structureId;
  final Map<String, ForeignKeyReference> foreignKeys;
  final HoldingAttributes attributes;

  /// Foreign key to the canonical [OrganismRecord] document (the
  /// `organism_records/{id}` Firestore doc). The current persistence flow
  /// shares `holding.id == organismRecord.id`, so this defaults to [id] when
  /// not explicitly provided. Always set by [fromJson] when present.
  final String organismRecordId;

  /// **Migration-only**. Embedded snapshot of the canonical
  /// [OrganismRecord]. Will be removed in the final step of the deembedding
  /// refactor; new readers should call [resolveOrganismRecord] for deep axes
  /// or rely on the denormalized display fields ([tagId], [organismKind],
  /// [lifeStage], [measurement], [ownerOrganizationId], [managingOrganizationId]).
  final OrganismRecord organismRecord;

  // Denormalized display fields. Authoritative for synchronous reads on the
  // holding; deep axes (aliases, physicalForm, sizeSpec, lifeStageHistory,
  // measurementHistory, etc.) live on the canonical OrganismRecord and must
  // be fetched via [resolveOrganismRecord].
  final String tagId;
  final OrganismKind organismKind;
  final LifeStage lifeStage;
  final PopulationMeasurement measurement;
  final String? ownerOrganizationId;
  final String? managingOrganizationId;

  @override
  ModelType get modelType => ModelType.holding;

  String get lifeStageId => lifeStage.id;

  @override
  LifeStageSpec get lifecycleStageSpec => organismRecord.lifeStage;

  @override
  OrganismKind get lifecycleOrganismKind => organismKind;

  /// The current physical form ID for lifecycle tracking.
  String? get lifecycleFormId => organismRecord.physicalForm?.formId;

  @override
  List<LifeStageTransition> get lifeStageHistory =>
      organismRecord.lifeStageHistory;

  @override
  PopulationMeasurement get canonicalMeasurement => measurement;

  @override
  SizeSpec get measurementSizeSpec => organismRecord.sizeSpec;

  @override
  List<MeasurementSnapshot> get measurementHistory =>
      organismRecord.measurementHistory;

  @override
  Duration? get customMinimumStageInterval {
    final raw = metadata?['lifeStageIntervalDays'];
    if (raw is num && raw > 0) {
      return Duration(days: raw.round());
    }
    return null;
  }

  @override
  HoldingRecord copyWith({
    String? id,
    String? tagId,
    OrganismKind? organismKind,
    LifeStage? lifeStage,
    PopulationMeasurement? measurement,
    String? provenanceId,
    String? cohortId,
    String? siteId,
    String? groupId,
    String? structureId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    Map<String, ForeignKeyReference>? foreignKeys,
    Map<String, dynamic>? metadata,
    HoldingAttributes? attributes,
    OrganismRecord? organismRecord,
    String? organismRecordId,
    String? createdById,
    String? createdAt,
    String? updatedById,
    String? updatedAt,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
  }) {
    return HoldingRecord(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      organismKind: organismKind ?? this.organismKind,
      lifeStage: lifeStage ?? this.lifeStage,
      measurement: measurement ?? this.measurement,
      provenanceId: provenanceId ?? this.provenanceId,
      cohortId: cohortId ?? this.cohortId,
      siteId: siteId ?? this.siteId,
      groupId: groupId ?? this.groupId,
      structureId: structureId ?? this.structureId,
      ownerOrganizationId: ownerOrganizationId ?? this.ownerOrganizationId,
      managingOrganizationId:
          managingOrganizationId ?? this.managingOrganizationId,
      foreignKeys: foreignKeys ?? this.foreignKeys,
      attributes: attributes ?? this.attributes,
      metadata: metadata ?? this.metadata ?? const <String, dynamic>{},
      organismRecord: organismRecord ?? this.organismRecord,
      organismRecordId: organismRecordId ?? this.organismRecordId,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    // InventoryRecord.toJson includes super fields, urlPath, etc.
    // We merge our specific fields.
    final payload = super.toJson();
    payload.addAll({
      'tagId': tagId,
      'organismKind': organismKind.name,
      'lifeStageId': lifeStage.id,
      'lifeStage': lifeStage.id, // legacy alias
      'measurement': measurement.toJson(),
      if (provenanceId != null) 'provenanceId': provenanceId,
      if (cohortId != null) 'cohortId': cohortId,
      if (siteId != null) 'siteId': siteId,
      if (groupId != null) 'groupId': groupId,
      if (structureId != null) 'structureId': structureId,
      if (ownerOrganizationId != null)
        'ownerOrganizationId': ownerOrganizationId,
      if (managingOrganizationId != null)
        'managingOrganizationId': managingOrganizationId,
      if (foreignKeys.isNotEmpty)
        'foreignKeys': foreignKeys.map((key, ref) => MapEntry(
              key,
              ref.toJson(),
            )),
      'organismRecordId': organismRecordId,
      'organismRecord': organismRecord.toJson(),
      if (!attributes.isEmpty) 'attributes': attributes.toJson(),
    });
    return payload;
  }

  /// Builds a HoldingRecord whose denormalized display fields are derived
  /// from [organism]. Use when constructing a holding from a freshly-built
  /// OrganismRecord; this avoids redundant per-field plumbing at call sites.
  /// Holding-specific fields (provenanceId, cohortId, siteId, groupId,
  /// structureId, foreignKeys, attributes, metadata) and infrastructure
  /// fields are provided separately.
  factory HoldingRecord.fromOrganismRecord(
    OrganismRecord organism, {
    required String id,
    String? provenanceId,
    String? cohortId,
    String? siteId,
    String? groupId,
    String? structureId,
    Map<String, ForeignKeyReference>? foreignKeys,
    HoldingAttributes? attributes,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String? organismRecordId,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
  }) {
    return HoldingRecord(
      id: id,
      tagId: organism.tagId,
      organismKind: organism.organismKind,
      lifeStage: organism.lifeStage.stage,
      measurement: organism.measurement,
      provenanceId: provenanceId,
      cohortId: cohortId,
      siteId: siteId,
      groupId: groupId,
      structureId: structureId,
      ownerOrganizationId: organism.ownerOrganizationId,
      managingOrganizationId: organism.managingOrganizationId,
      foreignKeys: foreignKeys,
      attributes: attributes,
      metadata: metadata,
      organismRecord: organism,
      organismRecordId: organismRecordId ?? organism.id,
      createdAt: createdAt ?? organism.createdAt,
      createdById: createdById ?? organism.createdById,
      updatedAt: updatedAt ?? organism.updatedAt,
      updatedById: updatedById ?? organism.updatedById,
      organizationId: organizationId ?? organism.organizationId,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: slug,
    );
  }

  factory HoldingRecord.fromJson(Map<String, dynamic> json) {
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name == json['organismKind'],
      orElse: () => OrganismKind.coral,
    );

    String? readText(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final lifeStage =
        LifeStageX.tryParse(json['lifeStageId']?.toString()) ??
        LifeStageX.tryParse(json['lifeStage']?.toString()) ??
        LifeStage.juvenile;

    final measurementJson = json['measurement'];
    final measurement = measurementJson is Map<String, dynamic>
        ? PopulationMeasurement.fromJson(measurementJson)
        : PopulationMeasurement(
            value: safeDouble(json['quantity']) ?? 0.0,
            unit: MeasurementUnit.count,
          );

    final metadata = deepNormalizeMap(json['metadata']);
    final attributesJson = json['attributes'];
    final parsedAttributes = attributesJson is Map
        ? HoldingAttributes.fromJson(deepNormalizeMap(attributesJson))
        : const HoldingAttributes();
    final metadataAttributes = HoldingAttributes.fromMetadata(metadata);
    final mergedAttributes = parsedAttributes.merge(metadataAttributes);
    final organismRecordJson = json['organismRecord'];
    final parsedOrganismRecord =
        organismRecordJson is Map
            ? OrganismRecord.fromJson(
                deepNormalizeMap(organismRecordJson),
              )
            : null;
    // Top-level localGenetId is canonical; no metadata fallbacks
    final localGenetId =
        readText(json['localGenetId']) ??
        parsedOrganismRecord?.localGenetId ??
        readText(json['id']);  // Last resort: use document ID as localGenetId
    final resolvedRecordName =
        readText(json['tagId']) ??
        parsedOrganismRecord?.tagId ??
        localGenetId ??
        json['id']?.toString();

    return HoldingRecord(
      id: json['id']?.toString() ?? Record.inferId(json) ?? Missing.string,
      tagId: resolvedRecordName ?? Missing.string,  // Use Missing.string instead of empty string
      organismKind: organismKind,
      lifeStage: lifeStage,
      measurement: measurement,
      provenanceId: json['provenanceId']?.toString(),
      cohortId: json['cohortId']?.toString(),
      siteId: json['siteId']?.toString(),
      groupId: json['groupId']?.toString(),
      structureId: json['structureId']?.toString(),
      ownerOrganizationId: json['ownerOrganizationId']?.toString(),
      managingOrganizationId: json['managingOrganizationId']?.toString(),
      foreignKeys: _parseForeignKeys(json['foreignKeys']),
      attributes: mergedAttributes,
      metadata: metadata,
      organismRecord: parsedOrganismRecord,
      organismRecordId: readText(json['organismRecordId']),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    provenanceId,
    cohortId,
    siteId,
    groupId,
    structureId,
    attributes,
    organismRecord,
    organismRecordId,
    foreignKeys,
  ];

  /// Resolves the canonical [OrganismRecord] for this holding by looking up
  /// [organismRecordId] via [lookup]. Use when callers need axes that the
  /// holding does not denormalize (aliases, physicalForm, lifeStageHistory,
  /// sizeSpec, etc.). Returns null when [organismRecordId] is empty or no
  /// matching record exists.
  Future<OrganismRecord?> resolveOrganismRecord(
    Future<OrganismRecord?> Function(String id) lookup,
  ) async {
    if (organismRecordId.isEmpty) return null;
    return lookup(organismRecordId);
  }

  static String _resolveOrganismRecordId({
    required String? explicit,
    required OrganismRecord? base,
    required String fallbackId,
  }) {
    final candidate = explicit?.trim().isNotEmpty == true
        ? explicit!.trim()
        : (base?.id.trim().isNotEmpty == true
            ? base!.id.trim()
            : fallbackId);
    return candidate;
  }

  static HoldingAttributes _normalizeAttributes(HoldingAttributes? value) =>
      value ?? const HoldingAttributes();

  /// Validates that required fields are present for a NEW holding record.
  /// Call this during creation flows, NOT during deserialization.
  /// Returns null if valid, or an error message if invalid.
  static String? validateForCreation(HoldingRecord record) {
    final localGenetId = record.organismRecord.localGenetId?.trim();
    if (localGenetId == null || localGenetId.isEmpty || localGenetId == Missing.string) {
      return 'localGenetId is required for new holdings';
    }
    final tagId = record.tagId.trim();
    if (tagId.isEmpty || tagId == Missing.string) {
      return 'tagId is required for new holdings';
    }
    return null;
  }

  /// Returns a new [HoldingRecord] whose canonical axes mirror [record]. Useful
  /// for dialog-driven edits that work directly with [OrganismRecord] payloads.
  HoldingRecord alignWithOrganismRecord(
    OrganismRecord record, {
    Map<String, dynamic>? metadataOverrides,
  }) {
    if (record.organismKind != organismKind) {
      throw ArgumentError(
        'organismKind mismatch. Holding $organismKind cannot adopt '
        '${record.organismKind}.',
      );
    }
    final mergedMetadata = <String, dynamic>{...?metadata};
    final recordMetadata = record.metadata;
    if (recordMetadata?.isNotEmpty ?? false) {
      mergedMetadata.addAll(recordMetadata!);
    }
    if (metadataOverrides != null && metadataOverrides.isNotEmpty) {
      mergedMetadata.addAll(metadataOverrides);
    }

    final mergedForeignKeys = <String, ForeignKeyReference>{...foreignKeys};
    if (record.foreignKeys.isNotEmpty) {
      mergedForeignKeys.addAll(record.foreignKeys);
    }

    return copyWith(
      organismKind: record.organismKind,
      lifeStage: record.lifeStage.stage,
      measurement: record.measurement,
      ownerOrganizationId:
          record.ownerOrganizationId ?? ownerOrganizationId,
      managingOrganizationId:
          record.managingOrganizationId ?? managingOrganizationId,
      foreignKeys: mergedForeignKeys,
      metadata: mergedMetadata,
      organismRecord: record,
    );
  }

  static Map<String, dynamic> _normalizeMetadata(
    Map<String, dynamic> metadata,
  ) {
    if (metadata.isEmpty) return <String, dynamic>{};
    return Map<String, dynamic>.from(metadata);
  }

  /// Build the embedded [OrganismRecord] from constructor inputs. Named params
  /// (`tagId`, `organismKind`, etc.) override matching fields on a supplied
  /// [base] record — this preserves the semantics of the former
  /// `_syncOrganismRecord` reconciler that funneled holding-level overrides
  /// into the embedded record at construction time.
  static OrganismRecord _buildOrganismRecord({
    required OrganismRecord? base,
    required String tagId,
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required PopulationMeasurement measurement,
    required HoldingAttributes attributes,
    required Map<String, dynamic> metadata,
    required String? ownerOrganizationId,
    required String? managingOrganizationId,
    required Map<String, ForeignKeyReference> foreignKeys,
  }) {
    final source = base ??
        OrganismRecord.inferFromMetadata(
          organismKind: organismKind,
          lifeStage: lifeStage,
          measurement: measurement,
          metadata: metadata,
          speciesId: attributes.speciesId,
          ownerOrganizationId: ownerOrganizationId,
          managingOrganizationId: managingOrganizationId,
          foreignKeys: foreignKeys,
        );
    final lifeStageSpec = source.lifeStage.stage == lifeStage
        ? source.lifeStage
        : source.lifeStage.copyWith(stage: lifeStage);
    return source.copyWith(
      organismKind: organismKind,
      lifeStage: lifeStageSpec,
      measurement: measurement,
      tagId: tagId,
      ownerOrganizationId: ownerOrganizationId ?? source.ownerOrganizationId,
      managingOrganizationId:
          managingOrganizationId ?? source.managingOrganizationId,
      foreignKeys: foreignKeys,
    );
  }

  static Map<String, ForeignKeyReference> _normalizeForeignKeys(
    Map<String, ForeignKeyReference>? value,
  ) {
    if (value == null || value.isEmpty) {
      return const <String, ForeignKeyReference>{};
    }
    return Map.unmodifiable(Map<String, ForeignKeyReference>.from(value));
  }

  static Map<String, ForeignKeyReference> _parseForeignKeys(dynamic raw) {
    if (raw is! Map) return const <String, ForeignKeyReference>{};
    final result = <String, ForeignKeyReference>{};
    raw.forEach((dynamic key, dynamic value) {
      if (value is Map<String, dynamic>) {
        result[key.toString()] = ForeignKeyReference.fromJson(value);
      } else if (value is Map) {
        result[key.toString()] = ForeignKeyReference.fromJson(
          Map<String, dynamic>.from(value),
        );
      } else if (value != null) {
        result[key.toString()] = ForeignKeyReference(id: value.toString());
      }
    });
    return result.isEmpty
        ? const <String, ForeignKeyReference>{}
        : Map.unmodifiable(result);
  }

}
