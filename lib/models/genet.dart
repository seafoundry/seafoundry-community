// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/models/provenance_base.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

class Genet extends InventoryRecord
    with GraphNodeRecord
    implements Named, ProvenanceBase {
  Genet({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.name,
    String? localId,
    required this.speciesId,
    required this.provenanceTypeId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    this.organismKind = OrganismKind.coral,
    required this.provenanceId,
    required this.clonalId,
    required this.accessionNumber,
    this.notes,
    this.provenance,
    List<Map<String, dynamic>>? aliases,
    ProvenanceKind? overrideProvenanceKind,
    this.parentGameteIds,
    this.parentCohortId,
    this.donorGenotypeId,
    this.damGameteIds,
    this.sireGameteIds,
    this.crossDate,
    this.readyForOutplant = false,
    this.archived = false,
    this.archivedAt,
    this.heatTested = false,
    this.diseaseTested = false,
    this.heatTestingComment,
    this.diseaseTestingComment,
  }) : localId = localId ?? name,
       aliases = _canonicalizeAliases(aliases),
       provenanceKind =
           overrideProvenanceKind ?? _mapProvenanceKindFromProvenanceType(provenanceTypeId);

  factory Genet.fromJson(Map<String, dynamic> json) {
    final normalized = _ensureInventoryPaths(json);
    return Genet._fromJson(normalized);
  }

  Genet._fromJson(super.json)
    : name =
          json['name'] ??
          (json['createdEvent']?['name'] as String? ?? Missing.string),
      localId =
          json['localId'] ??
          json['createdEvent']?['localId'] ??
          json['metadata']?['localId'] ??
          json['createdEvent']?['metadata']?['localId'] ??
          json['name'] ??
          (json['createdEvent']?['name'] as String? ?? Missing.string),
      speciesId =
          json['speciesId'] ??
          json['createdEvent']?['speciesId'] ??
          Missing.string,
      provenanceTypeId =
          json['provenanceTypeId'] ??
          json['createdEvent']?['provenanceTypeId'] ??
          Missing.string,
      organismKind = _parseOrganismKind(
        json['organismKind'] ?? json['createdEvent']?['organismKind'],
      ),
      provenanceId =
          json['provenanceId'] ??
          json['createdEvent']?['provenanceId'] ??
          Missing.string,
      clonalId = json['clonalId'] ?? json['createdEvent']?['clonalId'],
      accessionNumber =
          json['accessionNumber'] ?? json['createdEvent']?['accessionNumber'],
      notes = json['notes'],
      provenance = safeMapCast(json['provenance']) ??
          safeMapCast(json['createdEvent']?['provenance']),
      aliases = _canonicalizeAliases(json['aliases']),
      provenanceKind = _resolveProvenanceKind(
        rawKind: json['provenanceKind'] ?? json['lineageKind'],
        createdEventKind:
            json['createdEvent']?['provenanceKind'] ??
            json['createdEvent']?['lineageKind'],
        provenanceTypeId:
            (json['provenanceTypeId'] ?? json['createdEvent']?['provenanceTypeId'])
                ?.toString() ??
            Missing.string,
      ),
      parentGameteIds =
          (json['parentGameteIds'] as List?)?.whereType<String>().toList() ??
          (json['createdEvent']?['parentGameteIds'] as List?)
              ?.whereType<String>()
              .toList(),
      parentCohortId =
          json['parentCohortId'] as String? ??
          json['createdEvent']?['parentCohortId'] as String?,
      donorGenotypeId =
          json['donorGenotypeId'] as String? ??
          json['createdEvent']?['donorGenotypeId'] as String?,
      damGameteIds =
          (json['damGameteIds'] as List?)?.whereType<String>().toList() ??
          (json['createdEvent']?['damGameteIds'] as List?)
              ?.whereType<String>()
              .toList(),
      sireGameteIds =
          (json['sireGameteIds'] as List?)?.whereType<String>().toList() ??
          (json['createdEvent']?['sireGameteIds'] as List?)
              ?.whereType<String>()
              .toList(),
      crossDate =
          _parseDateTime(json['crossDate']) ??
          _parseDateTime(json['createdEvent']?['crossDate']),
      readyForOutplant =
          (json['readyForOutplant'] ??
              json['createdEvent']?['readyForOutplant']) ==
          true,
      archived = json['archived'] == true,
      archivedAt = _parseDateTime(json['archivedAt']),
      heatTested =
          (json['heatTested'] ?? json['createdEvent']?['heatTested']) == true,
      diseaseTested =
          (json['diseaseTested'] ?? json['createdEvent']?['diseaseTested']) ==
          true,
      heatTestingComment =
          json['heatTestingComment'] as String? ??
          json['createdEvent']?['heatTestingComment'] as String?,
      diseaseTestingComment =
          json['diseaseTestingComment'] as String? ??
          json['createdEvent']?['diseaseTestingComment'] as String?,
      super.fromJson();

  factory Genet.partial({
    Map<String, dynamic>? json,
    String? id,
    String? internalPath,
    String? slug,
    String? urlPath,
    String? name,
    String? localId,
    String? speciesId,
    String? provenanceTypeId,
    OrganismKind? organismKind,
    String? organizationId,
    String? createdById,
    ProvenanceKind? overrideProvenanceKind,
    String? provenanceId,
    String? clonalId,
    String? accessionNumber,
    String? notes,
    Map<String, dynamic>? provenance,
    List<Map<String, dynamic>>? aliases,
    List<String>? parentGameteIds,
    String? parentCohortId,
    String? donorGenotypeId,
    List<String>? damGameteIds,
    List<String>? sireGameteIds,
    DateTime? crossDate,
    bool? readyForOutplant,
    bool? archived,
    DateTime? archivedAt,
    bool? heatTested,
    bool? diseaseTested,
    String? heatTestingComment,
    String? diseaseTestingComment,
    Map<String, dynamic>? metadata,
  }) {
    final normalized = json != null ? _ensureInventoryPaths(json) : null;
    return Genet._partial(
      json: normalized,
      id: id,
      internalPath: internalPath,
      slug: slug,
      urlPath: urlPath,
      name: name,
      localId: localId,
      speciesId: speciesId,
      provenanceTypeId: provenanceTypeId,
      organismKindParam: organismKind,
      provenanceId: provenanceId,
      clonalId: clonalId,
      accessionNumber: accessionNumber,
      notes: notes,
      provenance: provenance,
      aliases: aliases,
      overrideProvenanceKind: overrideProvenanceKind,
      parentGameteIds: parentGameteIds,
      parentCohortId: parentCohortId,
      donorGenotypeId: donorGenotypeId,
      damGameteIds: damGameteIds,
      sireGameteIds: sireGameteIds,
      crossDate: crossDate,
      readyForOutplant: readyForOutplant,
      organizationId: organizationId,
      createdById: createdById,
      archived: archived,
      archivedAt: archivedAt,
      heatTested: heatTested,
      diseaseTested: diseaseTested,
      heatTestingComment: heatTestingComment,
      diseaseTestingComment: diseaseTestingComment,
      metadata: metadata,
    );
  }

  Genet._partial({
    super.json,
    super.id,
    super.internalPath,
    super.slug,
    super.urlPath,
    String? name,
    String? localId,
    String? speciesId,
    String? provenanceTypeId,
    OrganismKind? organismKindParam,
    super.organizationId,
    super.createdById,
    String? provenanceId,
    String? clonalId,
    String? accessionNumber,
    String? notes,
    Map<String, dynamic>? provenance,
    List<Map<String, dynamic>>? aliases,
    ProvenanceKind? overrideProvenanceKind,
    List<String>? parentGameteIds,
    String? parentCohortId,
    String? donorGenotypeId,
    List<String>? damGameteIds,
    List<String>? sireGameteIds,
    DateTime? crossDate,
    bool? readyForOutplant,
    bool? archived,
    DateTime? archivedAt,
    bool? heatTested,
    bool? diseaseTested,
    String? heatTestingComment,
    String? diseaseTestingComment,
    super.metadata,
  }) : name = name ?? json?['name'] ?? Missing.string,
       localId =
           localId ??
           json?['localId'] ??
           json?['metadata']?['localId'] ??
           name ??
           json?['name'] ??
           Missing.string,
       speciesId = speciesId ?? json?['speciesId'] ?? Missing.string,
       provenanceTypeId = provenanceTypeId ?? json?['provenanceTypeId'] ?? Missing.string,
       organismKind =
           organismKindParam ?? _parseOrganismKind(json?['organismKind']),
       provenanceId =
           provenanceId ??
           json?['provenanceId'] ??
           json?['metadata']?['provenanceId'] ??
           Missing.string,
       clonalId = clonalId ?? json?['clonalId'],
       accessionNumber = accessionNumber ?? json?['accessionNumber'],
       notes = notes ?? json?['notes'],
       provenance = provenance ?? json?['provenance'],
       aliases = _canonicalizeAliases(aliases ?? json?['aliases']),
       provenanceKind = _resolveProvenanceKind(
         override: overrideProvenanceKind,
         rawKind: json?['provenanceKind'] ?? json?['lineageKind'],
         createdEventKind:
             json?['createdEvent']?['provenanceKind'] ??
             json?['createdEvent']?['lineageKind'],
         provenanceTypeId:
             (provenanceTypeId ?? json?['provenanceTypeId'])?.toString() ??
             Missing.string,
       ),
       parentGameteIds =
           parentGameteIds ??
           (json?['parentGameteIds'] as List?)?.whereType<String>().toList(),
       parentCohortId = parentCohortId ?? json?['parentCohortId'],
       donorGenotypeId = donorGenotypeId ?? json?['donorGenotypeId'],
       damGameteIds =
           damGameteIds ??
           (json?['damGameteIds'] as List?)?.whereType<String>().toList(),
       sireGameteIds =
           sireGameteIds ??
           (json?['sireGameteIds'] as List?)?.whereType<String>().toList(),
       crossDate = crossDate ?? _parseDateTime(json?['crossDate']),
       readyForOutplant = readyForOutplant ?? json?['readyForOutplant'] == true,
       archived = archived ?? json?['archived'] == true,
       archivedAt = archivedAt ?? _parseDateTime(json?['archivedAt']),
       heatTested = heatTested ?? json?['heatTested'] == true,
       diseaseTested = diseaseTested ?? json?['diseaseTested'] == true,
       heatTestingComment = heatTestingComment ?? json?['heatTestingComment'],
       diseaseTestingComment =
           diseaseTestingComment ?? json?['diseaseTestingComment'],
       super.partial();

  @override
  ModelType get modelType => ModelType.genet;

  @override
  String get displayName => name;

  @override
  String? get parentProvenanceId {
    if (donorGenotypeId != null && donorGenotypeId!.isNotEmpty) {
      return donorGenotypeId;
    }
    if (parentCohortId != null && parentCohortId!.isNotEmpty) {
      return parentCohortId;
    }
    if (parentGameteIds != null && parentGameteIds!.isNotEmpty) {
      return parentGameteIds!.first;
    }
    return null;
  }

  @override
  String? get siteId => null;

  @override
  List<String> get aliasLabels => _aliasLabels;

  @override
  Map<String, dynamic> get metadata {
    final base = super.metadata ?? const <String, dynamic>{};
    return Map.unmodifiable({
      ...base,
      if (localId != null) 'localId': localId,
      'provenanceTypeId': provenanceTypeId,
      'provenanceId': provenanceId,
      'provenanceKind': provenanceKind.name,
      if (clonalId != null) 'clonalId': clonalId,
      if (accessionNumber != null) 'accessionNumber': accessionNumber,
      if (provenance != null) 'provenance': provenance,
      if (parentGameteIds != null && parentGameteIds!.isNotEmpty)
        'parentGameteIds': parentGameteIds,
      if (damGameteIds != null && damGameteIds!.isNotEmpty)
        'damGameteIds': damGameteIds,
      if (sireGameteIds != null && sireGameteIds!.isNotEmpty)
        'sireGameteIds': sireGameteIds,
    });
  }

  /// Organization-scoped genet label (localID).
  @override
  final String name;
  /// Optional alias for the genet local ID stored in metadata for compatibility.
  @override
  final String? localId;
  @override
  final OrganismKind organismKind;
  /// Species identifier for the genet.
  @override
  final String speciesId;
  /// Coarse provenance bucket derived from the provenance type.
  @override
  final ProvenanceKind provenanceKind;
  /// Provenance type identifier (taxonomy ID).
  final String provenanceTypeId;

  /// Canonical provenance identifier (PID) for cross-org comparisons.
  @override
  final String provenanceId;

  final String? clonalId;
  final String? accessionNumber;
  final String? notes;
  final Map<String, dynamic>? provenance;
  final List<Map<String, dynamic>>? aliases;
  final List<String>? parentGameteIds;
  final String? parentCohortId;
  final String? donorGenotypeId;
  final List<String>? damGameteIds;
  final List<String>? sireGameteIds;
  final DateTime? crossDate;
  final bool readyForOutplant;
  final bool archived;
  final DateTime? archivedAt;
  final bool heatTested;
  final bool diseaseTested;
  final String? heatTestingComment;
  final String? diseaseTestingComment;

  static Map<String, dynamic> _ensureInventoryPaths(Map<String, dynamic> source) {
    try {
      // Defensive copy to ensure we have a clean Dart map, preventing DDC interop issues
      final json = Map<String, dynamic>.from(source);
      
      if (json['urlPath'] is String &&
          json['internalPath'] is String &&
          json['slug'] is String) {
        return json;
      }

      final updated = Map<String, dynamic>.from(json);
      final createdEvent = safeMapCast(updated['createdEvent']);


    String? fallbackUrlPath;
    String? fallbackInternalPath;

    if (createdEvent != null) {
      final createdUrlPath = createdEvent['urlPath'] as String?;
      if (createdUrlPath != null) {
        final segments = createdUrlPath.split('/');
        if (segments.length >= 2) {
          fallbackUrlPath = segments.take(segments.length - 1).join('/');
        }
      }

      final createdInternalPath = createdEvent['internalPath'] as String?;
      if (createdInternalPath != null) {
        final segments = createdInternalPath.split('/');
        if (segments.length >= 2) {
          fallbackInternalPath = segments.take(segments.length - 1).join('/');
        }
      }
    }

    final id = updated['id']?.toString();
    final organizationId = updated['organizationId']?.toString();

    updated['urlPath'] ??=
        fallbackUrlPath ??
        (id != null ? '${organizationId ?? ''}/$id' : Missing.string);
    updated['internalPath'] ??=
        fallbackInternalPath ??
        (id != null ? '${organizationId ?? ''}/$id' : Missing.string);

    updated['slug'] ??= updated['urlPath'] is String
        ? (updated['urlPath'] as String).split('/').last
        : id ?? Missing.string;

    return updated;
    } catch (e) {
      // If anything fails during path resolution, rely on partial parsing downstream
      // or return original source to let standard factories handle it.
      return source;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'organismKind': organismKind.name,
    'provenanceKind': provenanceKind.name,
    'lineageKind': provenanceKind.name,
    'name': name,
    if (localId != null) 'localId': localId,
    'nameLowercase': name.toLowerCase(),
    'speciesId': speciesId,
    'provenanceTypeId': provenanceTypeId,
    'provenanceId': provenanceId,
    'clonalId': clonalId,
    'accessionNumber': accessionNumber,
    'notes': notes,
    if (provenance != null) 'provenance': provenance,
    if (aliases != null && aliases!.isNotEmpty) 'aliases': aliases,
    if (parentGameteIds != null && parentGameteIds!.isNotEmpty)
      'parentGameteIds': parentGameteIds,
    if (parentCohortId != null) 'parentCohortId': parentCohortId,
    if (donorGenotypeId != null) 'donorGenotypeId': donorGenotypeId,
    if (damGameteIds != null && damGameteIds!.isNotEmpty)
      'damGameteIds': damGameteIds,
    if (sireGameteIds != null && sireGameteIds!.isNotEmpty)
      'sireGameteIds': sireGameteIds,
    if (crossDate != null) 'crossDate': crossDate!.toIso8601String(),
    'readyForOutplant': readyForOutplant,
    'archived': archived,
    if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
    'heatTested': heatTested,
    'diseaseTested': diseaseTested,
    if (heatTestingComment != null) 'heatTestingComment': heatTestingComment,
    if (diseaseTestingComment != null)
      'diseaseTestingComment': diseaseTestingComment,
  };

  @override
  Genet copyWith({
    String? id,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? name,
    String? localId,
    String? speciesId,
    String? provenanceTypeId,
    OrganismKind? organismKind,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? provenanceId,
    String? clonalId,
    String? accessionNumber,
    String? notes,
    Map<String, dynamic>? provenance,
    List<Map<String, dynamic>>? aliases,
    List<String>? parentGameteIds,
    String? parentCohortId,
    String? donorGenotypeId,
    List<String>? damGameteIds,
    List<String>? sireGameteIds,
    DateTime? crossDate,
    bool? readyForOutplant,
    bool? archived,
    DateTime? archivedAt,
    bool? heatTested,
    bool? diseaseTested,
    String? heatTestingComment,
    String? diseaseTestingComment,
    ProvenanceKind? overrideProvenanceKind,
    Map<String, dynamic>? metadata,
  }) => Genet(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    createdById: createdById ?? this.createdById,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    name: name ?? this.name,
    localId: localId ?? this.localId,
    speciesId: speciesId ?? this.speciesId,
    provenanceTypeId: provenanceTypeId ?? this.provenanceTypeId,
    organismKind: organismKind ?? this.organismKind,
    overrideProvenanceKind:
        overrideProvenanceKind ?? provenanceKind,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    slug: slug ?? this.slug,
    provenanceId: provenanceId ?? this.provenanceId,
    clonalId: clonalId ?? this.clonalId,
    accessionNumber: accessionNumber ?? this.accessionNumber,
    notes: notes ?? this.notes,
    provenance: provenance ?? this.provenance,
    aliases: aliases != null ? _canonicalizeAliases(aliases) : this.aliases,
    parentGameteIds: parentGameteIds ?? this.parentGameteIds,
    parentCohortId: parentCohortId ?? this.parentCohortId,
    donorGenotypeId: donorGenotypeId ?? this.donorGenotypeId,
    damGameteIds: damGameteIds ?? this.damGameteIds,
    sireGameteIds: sireGameteIds ?? this.sireGameteIds,
    crossDate: crossDate ?? this.crossDate,
    readyForOutplant: readyForOutplant ?? this.readyForOutplant,
    archived: archived ?? this.archived,
    archivedAt: archivedAt ?? this.archivedAt,
    heatTested: heatTested ?? this.heatTested,
    diseaseTested: diseaseTested ?? this.diseaseTested,
    heatTestingComment: heatTestingComment ?? this.heatTestingComment,
    diseaseTestingComment: diseaseTestingComment ?? this.diseaseTestingComment,
    metadata: metadata ?? this.metadata,
  );

  @override
  bool validate() {
    return super.validate() &&
        name.isNotEmpty &&
        speciesId.isNotEmpty &&
        provenanceTypeId.isNotEmpty &&
        provenanceId.isNotEmpty;
  }

  @override
  List<Object?> get props => [
    ...super.props,
    name,
    localId,
    organismKind,
    speciesId,
    provenanceTypeId,
    provenanceKind,
    provenanceId,
    clonalId,
    accessionNumber,
    notes,
    provenance,
    aliases,
    parentGameteIds,
    parentCohortId,
    donorGenotypeId,
    damGameteIds,
    sireGameteIds,
    crossDate,
    readyForOutplant,
    archived,
    archivedAt,
    heatTested,
    diseaseTested,
    heatTestingComment,
    diseaseTestingComment,
  ];

  List<OrganismAlias> get aliasEntries =>
      OrganismAlias.listFromJson(aliases ?? const <Map<String, dynamic>>[]);

  List<String> get _aliasLabels {
    final entries = aliasEntries;
    if (entries.isEmpty) return const [];
    final seen = <String>{};
    final labels = <String>[];
    for (final alias in entries) {
      final label = (alias.label ?? alias.value).trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase();
      if (seen.add(key)) {
        labels.add(label);
      }
    }
    return labels;
  }

  static OrganismKind _parseOrganismKind(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return OrganismKind.values.firstWhere(
        (kind) => kind.name.toLowerCase() == value.toLowerCase(),
        orElse: () => OrganismKind.coral,
      );
    }
    return OrganismKind.coral;
  }

  static ProvenanceKind _resolveProvenanceKind({
    ProvenanceKind? override,
    dynamic rawKind,
    dynamic createdEventKind,
    required String provenanceTypeId,
  }) {
    if (override != null) {
      return override;
    }
    final parsed =
        ProvenanceKindX.tryParse(rawKind?.toString()) ??
        ProvenanceKindX.tryParse(createdEventKind?.toString());
    return parsed ?? _mapProvenanceKindFromProvenanceType(provenanceTypeId);
  }

  static ProvenanceKind _mapProvenanceKindFromProvenanceType(String provenanceTypeId) {
    final provenanceType = ProvenanceTypeX.tryParse(provenanceTypeId);
    if (provenanceType != null) {
      return provenanceType.defaultProvenanceKind;
    }
    return ProvenanceKind.genet;
  }

  static List<Map<String, dynamic>>? _canonicalizeAliases(dynamic raw) {
    if (raw == null) return null;
    final parsed = OrganismAlias.listFromJson(raw is Iterable ? raw : [raw]);
    if (parsed.isEmpty) return null;
    final seen = <String>{};
    final canonical = <Map<String, dynamic>>[];
    for (final alias in parsed) {
      final source = alias.sourceSystem.trim().isEmpty
          ? 'custom'
          : alias.sourceSystem.trim().toLowerCase();
      final value = alias.value.trim();
      if (value.isEmpty) continue;
      final key = '$source::${value.toLowerCase()}';
      if (seen.add(key)) {
        canonical.add({
          'sourceSystem': source,
          'value': value,
          if (alias.label != null && alias.label!.trim().isNotEmpty)
            'label': alias.label!.trim(),
          if (alias.isPrimary) 'isPrimary': true,
        });
      }
    }
    return canonical.isEmpty ? null : canonical;
  }

  // ============================================================================
  // PROVENANCE COMPLETENESS
  // ============================================================================

  /// Completeness score from 0.0 to 1.0 for provenance/gamete metadata.
  double get completenessScore => _computeProvenanceCompleteness().score;

  /// Returns list of incomplete provenance/gamete field names for display.
  List<String> get incompleteFields =>
      _computeProvenanceCompleteness().missingFields;

  /// Whether provenance metadata is complete for this genet's provenance type.
  bool get isProvenanceComplete => incompleteFields.isEmpty;

  /// List of missing provenance fields for this genet.
  List<String> get missingProvenanceFields => incompleteFields;

  /// Provenance completeness status.
  ProvenanceCompletenessStatus get provenanceCompletenessStatus {
    final provenanceType = _resolvedProvenanceType;
    if (provenanceType == ProvenanceType.unknown) {
      return ProvenanceCompletenessStatus.unknown;
    }
    return isProvenanceComplete
        ? ProvenanceCompletenessStatus.complete
        : ProvenanceCompletenessStatus.incomplete;
  }

  _ProvenanceCompleteness _computeProvenanceCompleteness() {
    final missing = <String>[];
    var total = 0;

    void requireField(String label, bool isComplete) {
      total += 1;
      if (!isComplete) {
        missing.add(label);
      }
    }

    final provenanceType = _resolvedProvenanceType;
    final lifeStage = _resolvedLifeStage(provenanceType);

    if (lifeStage == LifeStage.gamete) {
      requireField('Donor genotype', _hasMeaningfulValue(donorGenotypeId));
      requireField(
        'Gamete sex',
        _hasProvenanceValue(const ['gamete_sex', 'gameteSex']),
      );
      requireField(
        'Spawn date',
        _hasProvenanceValue(const ['spawn_date', 'spawnDate']),
      );
      return _ProvenanceCompleteness(_score(total, missing.length), missing);
    }

    switch (provenanceType) {
      case ProvenanceType.wild:
        requireField(
          'Collection method',
          _hasProvenanceValue(
            const [
              'collection_method',
              'collectionMethod',
              'wild_method',
              'wildMethod',
            ],
          ),
        );
        requireField(
          'Collection date',
          _hasProvenanceValue(const ['collection_date', 'collectionDate']),
        );
        break;
      case ProvenanceType.sexualCohort:
        final parentCount =
            (parentGameteIds ?? const <String>[])
                .where(_hasMeaningfulValue)
                .length;
        final hasParentPair = parentCount >= 2;
        final hasDam =
            _hasMeaningfulList(damGameteIds) || hasParentPair;
        final hasSire =
            _hasMeaningfulList(sireGameteIds) || hasParentPair;
        requireField('Dam gamete linkage', hasDam);
        requireField('Sire gamete linkage', hasSire);
        requireField('Cross/spawn date', crossDate != null);
        break;
      case ProvenanceType.graduatedIndividual:
        requireField(
          'Parent cohort linkage',
          _hasMeaningfulValue(parentCohortId),
        );
        break;
      case ProvenanceType.transfer:
        // Check for source organization - can be stored in various fields
        // depending on how the transfer was created (manual, inter-org, etc.)
        requireField(
          'Source organization',
          _hasMetadataValue(
                const [
                  'sourceOrganizationId',
                  'sourceOrganization',
                  'fromOrganizationId',
                ],
              ) ||
              _hasProvenanceValue(
                const [
                  'sending_organization',
                  'sendingOrganization',
                  'sourceOrganization',
                  'sourceOrganizationId',
                  'fromOrganizationId',
                ],
              ),
        );
        requireField(
          'Source provenance ID',
          _hasMeaningfulValue(provenanceId) ||
              _hasMetadataValue(const ['sourceProvenanceId']) ||
              _hasProvenanceValue(const ['sourceProvenanceId']) ||
              _hasMeaningfulValue(donorGenotypeId),
        );
        break;
      case ProvenanceType.unknown:
        requireField('Provenance type', false);
        break;
    }

    return _ProvenanceCompleteness(_score(total, missing.length), missing);
  }

  ProvenanceType get _resolvedProvenanceType =>
      ProvenanceTypeX.tryParse(provenanceTypeId) ?? ProvenanceType.unknown;

  LifeStage _resolvedLifeStage(ProvenanceType provenanceType) {
    final meta = super.metadata ?? const <String, dynamic>{};
    final rawStage =
        meta['lifeStageId']?.toString() ?? meta['lifeStage']?.toString();
    final parsed = LifeStageX.tryParse(rawStage);
    return parsed ?? provenanceType.defaultLifeStage;
  }

  bool _hasProvenanceValue(List<String> keys) {
    final prov = provenance;
    if (prov == null || prov.isEmpty) return false;
    for (final key in keys) {
      if (_hasMeaningfulValue(prov[key])) return true;
    }
    return false;
  }

  bool _hasMetadataValue(List<String> keys) {
    final meta = super.metadata;
    if (meta == null || meta.isEmpty) return false;
    for (final key in keys) {
      if (_hasMeaningfulValue(meta[key])) return true;
    }
    return false;
  }

  static bool _hasMeaningfulList(List<String>? values) {
    if (values == null || values.isEmpty) return false;
    return values.any(_hasMeaningfulValue);
  }

  static bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return false;
      final normalized = trimmed.toLowerCase();
      if (normalized == 'unknown' ||
          normalized == 'n/a' ||
          normalized == 'na') {
        return false;
      }
      return true;
    }
    if (value is Iterable) {
      for (final entry in value) {
        if (_hasMeaningfulValue(entry)) return true;
      }
      return false;
    }
    return true;
  }

  static double _score(int total, int missingCount) {
    if (total <= 0) return 0.0;
    final completeCount = total - missingCount;
    return completeCount / total;
  }
}

/// Status of provenance metadata completeness for a genet.
enum ProvenanceCompletenessStatus {
  complete,
  incomplete,
  unknown;

  String get displayName => switch (this) {
        complete => 'Complete',
        incomplete => 'Incomplete',
        unknown => 'Unknown',
      };

  String get description => switch (this) {
        complete => 'All provenance metadata is documented',
        incomplete => 'Some provenance metadata is missing',
        unknown => 'Provenance information is not available',
      };
}

class _ProvenanceCompleteness {
  const _ProvenanceCompleteness(this.score, this.missingFields);

  final double score;
  final List<String> missingFields;
}
