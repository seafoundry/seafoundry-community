// @tier: community
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/reproductive_event_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Neutral representation of a reproductive event (sexual spawn, gamete
/// collection, larval settlement, asexual propagation, etc.). This captures the
/// metadata required for provenance tracking and downstream cohort creation.
class ReproductiveEvent extends Record {
  ReproductiveEvent({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.organismKind,
    required this.eventKind,
    required this.eventDate,
    List<String>? damProvenanceIds,
    List<String>? sireProvenanceIds,
    List<String>? cohortIds,
    this.outputProvenanceId,
    this.siteId,
    this.groupId,
    this.notes,
    this.outputMeasurement,
    this.fertilizationPct,
    this.settlementPct,
    Map<String, dynamic>? metadata,
  }) : damProvenanceIds = List.unmodifiable(damProvenanceIds ?? const []),
       sireProvenanceIds = List.unmodifiable(sireProvenanceIds ?? const []),
       cohortIds = List.unmodifiable(cohortIds ?? const []),
       super(
         metadata: metadata != null
             ? Map.unmodifiable(metadata)
             : const <String, dynamic>{},
       );

  factory ReproductiveEvent.fromJson(Map<String, dynamic> json) {
    return ReproductiveEvent(
      id: json['id']?.toString() ?? Missing.string,
      createdAt: json['createdAt']?.toString() ?? Missing.dateTimeString,
      createdById: json['createdById']?.toString() ?? Missing.string,
      updatedAt:
          json['updatedAt']?.toString() ??
          json['createdAt']?.toString() ??
          Missing.dateTimeString,
      updatedById:
          json['updatedById']?.toString() ??
          json['createdById']?.toString() ??
          Missing.string,
      organizationId: json['organizationId']?.toString() ?? Missing.string,
      organismKind: _parseOrganismKind(json['organismKind']),
      eventKind: ReproductiveEventKindX.fromName(
        json['eventKind']?.toString() ?? '',
      ),
      eventDate: DateTimeConverter.parseWithFallback(
        json['eventDate']?.toString(),
        fallback: DateTime.now().toUtc(),
        fieldName: 'eventDate',
        modelType: 'ReproductiveEvent',
        recordId: json['id'],
      ),
      damProvenanceIds: _parseIdList(
        json,
        'damProvenanceIds',
        legacyKey: 'damLineageIds',
      ),
      sireProvenanceIds: _parseIdList(
        json,
        'sireProvenanceIds',
        legacyKey: 'sireLineageIds',
      ),
      cohortIds: _parseStringList(json['cohortIds']),
      outputProvenanceId: _parseIdValue(
        json,
        'outputProvenanceId',
        legacyKey: 'outputLineageId',
      ),
      siteId: json['siteId']?.toString(),
      groupId: json['groupId']?.toString(),
      notes: json['notes']?.toString(),
      outputMeasurement: json['outputMeasurement'] is Map<String, dynamic>
          ? PopulationMeasurement.fromJson(
              Map<String, dynamic>.from(json['outputMeasurement']),
            )
          : null,
      fertilizationPct: safeDouble(json['fertilizationPct']),
      settlementPct: safeDouble(json['settlementPct']),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : const <String, dynamic>{},
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'organismKind': organismKind.name,
      'eventKind': eventKind.id,
      'eventDate': eventDate.toIso8601String(),
      'damProvenanceIds': damProvenanceIds,
      if (damProvenanceIds.isNotEmpty) 'damLineageIds': damProvenanceIds,
      'sireProvenanceIds': sireProvenanceIds,
      if (sireProvenanceIds.isNotEmpty) 'sireLineageIds': sireProvenanceIds,
      'cohortIds': cohortIds,
      if (outputProvenanceId != null) ...{
        'outputProvenanceId': outputProvenanceId,
        'outputLineageId': outputProvenanceId,
      },
      if (siteId != null) 'siteId': siteId,
      if (groupId != null) 'groupId': groupId,
      if (notes != null) 'notes': notes,
      if (outputMeasurement != null)
        'outputMeasurement': outputMeasurement!.toJson(),
      if (fertilizationPct != null) 'fertilizationPct': fertilizationPct,
      if (settlementPct != null) 'settlementPct': settlementPct,
      if (eventMetadata.isNotEmpty) 'metadata': eventMetadata,
      if (provenanceLookup.isNotEmpty) 'provenanceLookup': provenanceLookup,
    };
  }

  @override
  ReproductiveEvent copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    OrganismKind? organismKind,
    ReproductiveEventKind? eventKind,
    DateTime? eventDate,
    List<String>? damProvenanceIds,
    List<String>? sireProvenanceIds,
    List<String>? cohortIds,
    String? outputProvenanceId,
    String? siteId,
    String? groupId,
    String? notes,
    PopulationMeasurement? outputMeasurement,
    double? fertilizationPct,
    double? settlementPct,
    Map<String, dynamic>? metadata,
  }) {
    return ReproductiveEvent(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      organismKind: organismKind ?? this.organismKind,
      eventKind: eventKind ?? this.eventKind,
      eventDate: eventDate ?? this.eventDate,
      damProvenanceIds: damProvenanceIds ?? this.damProvenanceIds,
      sireProvenanceIds: sireProvenanceIds ?? this.sireProvenanceIds,
      cohortIds: cohortIds ?? this.cohortIds,
      outputProvenanceId: outputProvenanceId ?? this.outputProvenanceId,
      siteId: siteId ?? this.siteId,
      groupId: groupId ?? this.groupId,
      notes: notes ?? this.notes,
      outputMeasurement: outputMeasurement ?? this.outputMeasurement,
      fertilizationPct: fertilizationPct ?? this.fertilizationPct,
      settlementPct: settlementPct ?? this.settlementPct,
      metadata: metadata != null
          ? Map.unmodifiable(Map<String, dynamic>.from(metadata))
          : eventMetadata,
    );
  }

  @override
  ModelType get modelType => ModelType.reproductiveEvent;

  final OrganismKind organismKind;
  final ReproductiveEventKind eventKind;
  final DateTime eventDate;
  final List<String> damProvenanceIds;
  final List<String> sireProvenanceIds;
  final List<String> cohortIds;
  final String? outputProvenanceId;
  final String? siteId;
  final String? groupId;
  final String? notes;
  final PopulationMeasurement? outputMeasurement;
  final double? fertilizationPct;
  final double? settlementPct;
  Map<String, dynamic> get eventMetadata =>
      metadata ?? const <String, dynamic>{};
  List<String> get provenanceLookup {
    final lookup = <String>{
      ...damProvenanceIds,
      ...sireProvenanceIds,
    };
    if (outputProvenanceId != null && outputProvenanceId!.isNotEmpty) {
      lookup.add(outputProvenanceId!);
    }
    return lookup.toList(growable: false);
  }

  @override
  List<Object?> get props => [
    ...super.props,
    organismKind,
    eventKind,
    eventDate,
    damProvenanceIds,
    sireProvenanceIds,
    cohortIds,
    outputProvenanceId,
    siteId,
    groupId,
    notes,
    outputMeasurement,
    fertilizationPct,
    settlementPct,
  ];

  static List<String> _parseIdList(
    Map<String, dynamic> json,
    String primaryKey, {
    String? legacyKey,
  }) {
    final primary = _parseStringList(json[primaryKey]);
    if (legacyKey == null) return primary;
    final legacy = _parseStringList(json[legacyKey]);
    if (legacy.isEmpty) return primary;
    if (primary.isEmpty) return legacy;

    final merged = List<String>.from(primary);
    for (final value in legacy) {
      if (!merged.contains(value)) {
        merged.add(value);
      }
    }
    return merged;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is Iterable) {
      final results = <String>[];
      for (final entry in value) {
        final parsed = _coerceString(entry);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    }
    return const [];
  }

  static String? _parseIdValue(
    Map<String, dynamic> json,
    String primaryKey, {
    String? legacyKey,
  }) {
    final primary = _coerceString(json[primaryKey]);
    if (primary != null) {
      return primary;
    }
    if (legacyKey == null) return null;
    return _coerceString(json[legacyKey]);
  }

  static String? _coerceString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final coerced = value.toString().trim();
    return coerced.isEmpty ? null : coerced;
  }

  static OrganismKind _parseOrganismKind(dynamic value) {
    if (value is OrganismKind) return value;
    if (value is String && value.isNotEmpty) {
      final normalized = value.toLowerCase();
      return OrganismKind.values.firstWhere(
        (kind) => kind.name.toLowerCase() == normalized,
        orElse: () => OrganismKind.coral,
      );
    }
    return OrganismKind.coral;
  }

}
