// ignore_for_file: overridden_fields
import 'package:seafoundry_community/models/provenance_base.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/models/types/provenance_kind.dart';

/// Canonical provenance metadata (genets, broodstock lots, donor meadows, etc.).
class ProvenanceRecord extends Record implements ProvenanceBase {
  ProvenanceRecord({
    required super.id,
    super.createdAt = Missing.dateTimeString,
    super.createdById = Missing.string,
    super.updatedAt = Missing.dateTimeString,
    super.updatedById = Missing.string,
    super.organizationId = Missing.string,
    required this.organismKind,
    required this.provenanceKind,
    required this.displayName,
    String? localGenetId,
    String? provenanceId,
    required this.speciesId,
    this.parentProvenanceId,
    this.siteId,
    List<String> aliasLabels = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
  })  : localGenetId = _readString(localGenetId),
        provenanceId = _readString(provenanceId),
        aliasLabels = List.unmodifiable(aliasLabels),
        metadata = Map.unmodifiable(metadata),
        super(metadata: metadata);

  @override
  final OrganismKind organismKind;
  @override
  final ProvenanceKind provenanceKind;
  @override
  final String displayName;
  @override
  final String? localGenetId;
  @override
  final String? provenanceId;
  @override
  final String speciesId;
  @override
  final String? parentProvenanceId;
  @override
  final String? siteId;
  @override
  final List<String> aliasLabels;
  @override
  final Map<String, dynamic> metadata;

  @override
  ModelType get modelType => ModelType.genet;

  @override
  ProvenanceRecord copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    OrganismKind? organismKind,
    ProvenanceKind? provenanceKind,
    String? displayName,
    String? localGenetId,
    String? provenanceId,
    String? speciesId,
    String? parentProvenanceId,
    String? siteId,
    List<String>? aliasLabels,
    Map<String, dynamic>? metadata,
  }) {
    return ProvenanceRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      organismKind: organismKind ?? this.organismKind,
      provenanceKind: provenanceKind ?? this.provenanceKind,
      displayName: displayName ?? this.displayName,
      localGenetId: localGenetId ?? this.localGenetId,
      provenanceId: provenanceId ?? this.provenanceId,
      speciesId: speciesId ?? this.speciesId,
      parentProvenanceId: parentProvenanceId ?? this.parentProvenanceId,
      siteId: siteId ?? this.siteId,
      aliasLabels: aliasLabels ?? this.aliasLabels,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ProvenanceRecord.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    final recordId = id ?? Record.inferId(json) ?? Missing.string;
    final kindRaw = json['organismKind']?.toString().trim().toLowerCase();
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name.toLowerCase() == kindRaw,
      orElse: () {
        // Fallback or throw? For safety/legacy data, default to coral.
        // But throwing is safer for new code.
        return OrganismKind.coral;
      },
    );

    final provenanceKind =
        ProvenanceKindX.tryParse(json['provenanceKind']?.toString()) ??
        ProvenanceKindX.tryParse(json['lineageKind']?.toString()) ??
        ProvenanceKind.genet;

    final parentValue =
        json['parentProvenanceId']?.toString().trim() ??
        json['parentLineageId']?.toString().trim();
    final siteValue = json['siteId']?.toString().trim();
    final metadataValue =
        json['metadata'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['metadata'])
            : const <String, dynamic>{};
    final localGenetId =
        _readString(json['localGenetId']) ??
        _readString(metadataValue['localGenetId']) ??
        _readString(json['name']) ??
        _readString(metadataValue['displayName']) ??
        _readString(metadataValue['name']);
    final provenanceId = _readString(json['provenanceId']);

    return ProvenanceRecord(
      id: recordId,
      createdAt: Record.stringFromJson(json, 'createdAt') ?? Missing.dateTimeString,
      createdById: Record.stringFromJson(json, 'createdById') ?? Missing.string,
      updatedAt: Record.stringFromJson(json, 'updatedAt') ?? Missing.dateTimeString,
      updatedById: Record.stringFromJson(json, 'updatedById') ?? Missing.string,
      organizationId: Record.inferOrganizationId(json) ?? Missing.string,
      organismKind: organismKind,
      provenanceKind: provenanceKind,
      displayName:
          json['displayName']?.toString().trim() ??
          localGenetId ??
          recordId,
      localGenetId: localGenetId,
      provenanceId: provenanceId,
      speciesId: json['speciesId']?.toString().trim() ?? '',
      parentProvenanceId: parentValue == null || parentValue.isEmpty
          ? null
          : parentValue,
      siteId: siteValue == null || siteValue.isEmpty ? null : siteValue,
      aliasLabels: _parseAliasLabels(json),
      metadata: metadataValue,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final payload = super.toJson(); // Gets generic Record fields (id, timestamps)
    
    // Add specific fields
    payload['organismKind'] = organismKind.name;
    payload['provenanceKind'] = provenanceKind.name;
    payload['displayName'] = displayName;
    if (localGenetId != null) payload['localGenetId'] = localGenetId;
    if (provenanceId != null) payload['provenanceId'] = provenanceId;
    payload['speciesId'] = speciesId;
    if (siteId != null) payload['siteId'] = siteId;
    payload['aliasLabels'] = aliasLabels;
    payload['aliases'] = aliasLabels; // Compat
    
    if (parentProvenanceId != null) {
      payload['parentProvenanceId'] = parentProvenanceId;
      payload['parentLineageId'] = parentProvenanceId;
    }
    
    // Merge metadata
    if (metadata.isNotEmpty) {
      payload['metadata'] = metadata;
    }
    
    return payload;
  }

  @override
  List<Object?> get props => [
    ...super.props,
    organismKind,
    provenanceKind,
    displayName,
    localGenetId,
    provenanceId,
    speciesId,
    parentProvenanceId,
    siteId,
    aliasLabels,
    metadata,
  ];

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _parseAliasLabels(Map<String, dynamic> json) {
    final seen = <String>{};

    void addValue(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          seen.add(trimmed);
        }
      }
    }

    final labelList = json['aliasLabels'];
    if (labelList is Iterable) {
      for (final entry in labelList) {
        addValue(entry);
      }
    }

    final aliases = json['aliases'];
    if (aliases is Iterable) {
      for (final entry in aliases) {
        if (entry is String) {
          addValue(entry);
        } else if (entry is Map<String, dynamic>) {
          addValue(entry['label']);
          addValue(entry['value']);
        }
      }
    }

    return List<String>.unmodifiable(seen);
  }
}
