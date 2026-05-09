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
/// Identity, life-stage, measurement, and ownership data live on the embedded
/// [organismRecord]. Top-level getters delegate to it so existing call sites
/// keep working. Holding-level state (placement, foreign keys, attributes,
/// metadata) remains as plain fields.
class HoldingRecord extends InventoryRecord
    with LifeStageProgressionMixin, MeasurableMixin {
  HoldingRecord({
    required super.id,
    required String tagId,
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required PopulationMeasurement measurement,
    this.provenanceId,
    this.cohortId,
    this.siteId,
    this.groupId,
    this.structureId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    Map<String, ForeignKeyReference>? foreignKeys,
    HoldingAttributes? attributes,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    OrganismRecord? organismRecord,
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
  final OrganismRecord organismRecord;

  // Delegating getters: these fields previously lived on HoldingRecord as
  // duplicated `final` state, kept in sync with the embedded organism record
  // by the now-removed `_syncOrganismRecord` reconciler. They now read
  // through to the single source of truth on [organismRecord].
  String get tagId => organismRecord.tagId;
  OrganismKind get organismKind => organismRecord.organismKind;
  LifeStage get lifeStage => organismRecord.lifeStage.stage;
  PopulationMeasurement get measurement => organismRecord.measurement;
  String? get ownerOrganizationId => organismRecord.ownerOrganizationId;
  String? get managingOrganizationId => organismRecord.managingOrganizationId;

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
      'organismRecord': organismRecord.toJson(),
      if (!attributes.isEmpty) 'attributes': attributes.toJson(),
    });
    return payload;
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
    foreignKeys,
  ];

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
