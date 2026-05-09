import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/mixins/life_stage_progression_mixin.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Neutral batch cohort record referencing a provenance record, life stage, and
/// population measurement. Cohorts help bridge coral-specific cohorts to the
/// organism-agnostic inventory model.
///
/// `organismKind`, `lifeStage`, and `population` live on the embedded
/// [organismRecord]; top-level getters delegate to it. Cohort-specific state
/// (placement, scheduling) remains as plain fields.
class Cohort extends Equatable with LifeStageProgressionMixin, MeasurableMixin {
  Cohort({
    required this.id,
    required this.name,
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required PopulationMeasurement population,
    this.provenanceId,
    this.siteId,
    this.groupId,
    this.structureId,
    this.startedAt,
    this.completedAt,
    Map<String, dynamic> metadata = const <String, dynamic>{},
    HoldingAttributes? attributes,
    OrganismRecord? organismRecord,
  }) : metadata = UnmodifiableMapView(_normalizeMetadata(metadata)),
       attributes = _normalizeAttributes(attributes),
       organismRecord = _buildOrganismRecord(
         base: organismRecord,
         organismKind: organismKind,
         lifeStage: lifeStage,
         population: population,
         attributes: _normalizeAttributes(attributes),
         metadata: _normalizeMetadata(metadata),
       );

  final String id;
  final String name;
  final String? provenanceId;
  final String? siteId;
  final String? groupId;
  final String? structureId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;
  final HoldingAttributes attributes;
  final OrganismRecord organismRecord;

  // Delegating getters: these axes used to live on Cohort as duplicated
  // `final` state, kept in sync with the embedded organism record by the
  // now-removed `_syncOrganismRecord` reconciler. They now read through
  // to the single source of truth on [organismRecord].
  OrganismKind get organismKind => organismRecord.organismKind;
  LifeStage get lifeStage => organismRecord.lifeStage.stage;
  PopulationMeasurement get population => organismRecord.measurement;

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
  PopulationMeasurement get canonicalMeasurement => population;

  @override
  SizeSpec get measurementSizeSpec => organismRecord.sizeSpec;

  @override
  List<MeasurementSnapshot> get measurementHistory =>
      organismRecord.measurementHistory;

  @override
  Duration? get customMinimumStageInterval {
    final days = metadata['lifeStageIntervalDays'];
    if (days is num && days > 0) {
      return Duration(days: days.round());
    }
    return null;
  }

  Cohort copyWith({
    String? id,
    String? name,
    OrganismKind? organismKind,
    LifeStage? lifeStage,
    PopulationMeasurement? population,
    String? provenanceId,
    String? siteId,
    String? groupId,
    String? structureId,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
    HoldingAttributes? attributes,
    OrganismRecord? organismRecord,
  }) {
    return Cohort(
      id: id ?? this.id,
      name: name ?? this.name,
      organismKind: organismKind ?? this.organismKind,
      lifeStage: lifeStage ?? this.lifeStage,
      population: population ?? this.population,
      provenanceId: provenanceId ?? this.provenanceId,
      siteId: siteId ?? this.siteId,
      groupId: groupId ?? this.groupId,
      structureId: structureId ?? this.structureId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
      attributes: attributes ?? this.attributes,
      organismRecord: organismRecord ?? this.organismRecord,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'organismKind': organismKind.name,
      'lifeStageId': lifeStage.id,
      'lifeStage': lifeStage.id,
      'population': population.toJson(),
      if (provenanceId != null) 'provenanceId': provenanceId,
      if (siteId != null) 'siteId': siteId,
      if (groupId != null) 'groupId': groupId,
      if (structureId != null) 'structureId': structureId,
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'metadata': metadata,
      if (!attributes.isEmpty) 'attributes': attributes.toJson(),
      'organismRecord': organismRecord.toJson(),
    };
  }

  factory Cohort.fromJson(Map<String, dynamic> json) {
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name == json['organismKind'],
      orElse: () => OrganismKind.coral,
    );

    final lifeStage =
        LifeStageX.tryParse(json['lifeStageId']?.toString()) ??
        LifeStageX.tryParse(json['lifeStage']?.toString()) ??
        LifeStage.juvenile;

    return Cohort(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      organismKind: organismKind,
      lifeStage: lifeStage,
      population: _parsePopulation(json),
      provenanceId: json['provenanceId']?.toString(),
      siteId: json['siteId']?.toString(),
      groupId: json['groupId']?.toString(),
      structureId: json['structureId']?.toString(),
      startedAt: _parseDate(json['startedAt']),
      completedAt: _parseDate(json['completedAt']),
      metadata: UnmodifiableMapView(
        _normalizeMetadata(json['metadata']),
      ),
      attributes: _parseAttributes(json),
      organismRecord: json['organismRecord'] is Map
          ? OrganismRecord.fromJson(
              deepNormalizeMap(json['organismRecord']),
            )
          : null,
    );
  }

  factory Cohort.fromHolding(
    HoldingRecord holding, {
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return Cohort(
      id: holding.id,
      name: holding.tagId,
      organismKind: holding.organismKind,
      lifeStage: holding.lifeStage,
      population: holding.measurement,
      provenanceId: holding.provenanceId,
      siteId: holding.siteId,
      groupId: holding.groupId,
      structureId: holding.structureId,
      startedAt: startedAt,
      completedAt: completedAt,
      metadata: holding.metadata ?? const <String, dynamic>{},
      attributes: holding.attributes,
      organismRecord: holding.organismRecord,
    );
  }

  static HoldingAttributes _parseAttributes(Map<String, dynamic> json) {
    final metadata = Map<String, dynamic>.from(json['metadata'] ?? const {});
    final metadataAttributes = HoldingAttributes.fromMetadata(metadata);
    final rawAttributes = json['attributes'];
    final recordAttributes = rawAttributes is Map<String, dynamic>
        ? HoldingAttributes.fromJson(Map<String, dynamic>.from(rawAttributes))
        : const HoldingAttributes();
    return recordAttributes.merge(metadataAttributes);
  }

  static PopulationMeasurement _parsePopulation(Map<String, dynamic> json) {
    PopulationMeasurement? fromField(dynamic value) {
      if (value is Map<String, dynamic> && value.isNotEmpty) {
        try {
          return PopulationMeasurement.fromJson(
            Map<String, dynamic>.from(value),
          );
        } on ArgumentError {
          return null;
        } on FormatException {
          return null;
        }
      }
      if (value is Map && value.isNotEmpty) {
        try {
          return PopulationMeasurement.fromJson(
            Map<String, dynamic>.from(value.cast<String, dynamic>()),
          );
        } on ArgumentError {
          return null;
        } on FormatException {
          return null;
        }
      }
      return null;
    }

    final population = fromField(json['population']);
    if (population != null) {
      return population;
    }

    final measurement = fromField(json['measurement']);
    if (measurement != null) {
      return measurement;
    }

    final unitToken =
        json['measurementUnit']?.toString() ??
        json['populationUnit']?.toString() ??
        json['unit']?.toString() ??
        MeasurementUnit.count.id;
    final unit =
        MeasurementUnitX.tryParse(unitToken) ?? MeasurementUnit.count;
    final value = safeDouble(json['quantity']) ?? 0;
    return PopulationMeasurement(value: value, unit: unit);
  }

  static HoldingAttributes _normalizeAttributes(HoldingAttributes? value) =>
      value ?? const HoldingAttributes();

  Cohort alignWithOrganismRecord(
    OrganismRecord record, {
    Map<String, dynamic>? metadataOverrides,
  }) {
    if (record.organismKind != organismKind) {
      throw ArgumentError(
        'organismKind mismatch. Cohort $organismKind cannot adopt '
        '${record.organismKind}.',
      );
    }
    final mergedMetadata = <String, dynamic>{...metadata};
    final recordMetadata = record.metadata;
    if (recordMetadata?.isNotEmpty ?? false) {
      mergedMetadata.addAll(recordMetadata!);
    }
    if (metadataOverrides != null && metadataOverrides.isNotEmpty) {
      mergedMetadata.addAll(metadataOverrides);
    }

    return copyWith(
      organismKind: record.organismKind,
      lifeStage: record.lifeStage.stage,
      population: record.measurement,
      metadata: mergedMetadata,
      organismRecord: record,
    );
  }

  static Map<String, dynamic> _normalizeMetadata(dynamic metadata) {
    if (metadata == null) {
      return <String, dynamic>{};
    }
    if (metadata is Map<String, dynamic>) {
      return Map<String, dynamic>.from(metadata);
    }
    if (metadata is Map) {
      return metadata.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  /// Build the embedded [OrganismRecord] from constructor inputs. Named axes
  /// override matching fields on a supplied [base] record, preserving the
  /// semantics of the former `_syncOrganismRecord` reconciler.
  static OrganismRecord _buildOrganismRecord({
    required OrganismRecord? base,
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required PopulationMeasurement population,
    required HoldingAttributes attributes,
    required Map<String, dynamic> metadata,
  }) {
    final source = base ??
        OrganismRecord.inferFromMetadata(
          organismKind: organismKind,
          lifeStage: lifeStage,
          measurement: population,
          metadata: metadata,
          speciesId: attributes.speciesId,
        );
    final lifeStageSpec = source.lifeStage.stage == lifeStage
        ? source.lifeStage
        : source.lifeStage.copyWith(stage: lifeStage);
    return source.copyWith(
      organismKind: organismKind,
      lifeStage: lifeStageSpec,
      measurement: population,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    provenanceId,
    siteId,
    groupId,
    structureId,
    startedAt,
    completedAt,
    metadata,
    attributes,
    organismRecord,
  ];
}
