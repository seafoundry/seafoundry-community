// @tier: community
import 'dart:collection';

import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/mixins/life_stage_progression_mixin.dart';
import 'package:seafoundry_app/models/mixins/measurable_mixin.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/services/life_stage_constraint_service.dart';
import 'package:seafoundry_app/services/physical_form_constraint_service.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Neutral five-axis payload stored next to holdings, cohorts, and future
/// organism-aware repositories. Repositories and CSV adapters should treat this
/// as the source of truth when constructing Firestore or export rows instead of
/// relying on coral-specific enums.
class OrganismRecord extends InventoryRecord
    with GraphNodeRecord, LifeStageProgressionMixin, MeasurableMixin {
  /// Maximum reasonable count for organism records to prevent data entry errors
  static const int maxReasonableCount = 1000000;
  OrganismRecord({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
    required this.recordName,
    required this.organismKind,
    required this.lifeStage,
    required this.measurement,
    this.speciesId,
    this.localId,
    this.siteId,
    this.groupId,
    this.zoneId,
    this.subplotId,
    this.outplantTagId,
    this.provenanceType,
    ProvenanceAttributes? provenanceAttributes,
    this.physicalForm,
    this.physicalFormConfigVersion,
    SizeSpec? sizeSpec,
    List<OrganismAlias>? aliases,
    this.ownerOrganizationId,
    this.managingOrganizationId,
    this.genetId,
    Map<String, ForeignKeyReference>? foreignKeys,
    List<LifeStageTransition>? lifeStageHistory,
    List<MeasurementSnapshot>? measurementHistory,
  }) : provenanceAttributes =
           provenanceAttributes ?? const ProvenanceAttributes(),
       sizeSpec = sizeSpec ?? const SizeSpec(),
       inventoryMetrics = _resolveInventoryMetrics(
         sizeSpec ?? const SizeSpec(),
         measurement,
       ),
       aliases = List<OrganismAlias>.unmodifiable(aliases ?? const []),
       foreignKeys = UnmodifiableMapView(
         Map<String, ForeignKeyReference>.from(foreignKeys ?? const {}),
       ),
       lifeStageHistory = List<LifeStageTransition>.unmodifiable(
         lifeStageHistory ?? const <LifeStageTransition>[],
       ),
       measurementHistory = List<MeasurementSnapshot>.unmodifiable(
         measurementHistory ?? const <MeasurementSnapshot>[],
       );

  OrganismRecord.partial({
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
    super.metadata,
    String? recordName,
    OrganismKind? organismKind,
    LifeStageSpec? lifeStage,
    PopulationMeasurement? measurement,
    String? speciesId,
    String? localId,
    String? siteId,
    String? groupId,
    String? zoneId,
    String? subplotId,
    String? outplantTagId,
    ProvenanceType? provenanceType,
    ProvenanceAttributes? provenanceAttributes,
    PhysicalFormInstance? physicalForm,
    String? physicalFormConfigVersion,
    SizeSpec? sizeSpec,
    List<OrganismAlias>? aliases,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    String? genetId,
    Map<String, ForeignKeyReference>? foreignKeys,
    List<LifeStageTransition>? lifeStageHistory,
    List<MeasurementSnapshot>? measurementHistory,
  }) : organismKind =
           organismKind ??
           OrganismKindX.tryParse(json?['organismKind']?.toString()) ??
           OrganismKind.coral,
       recordName = recordName ?? _readRecordName(json) ?? Missing.string,
       lifeStage = lifeStage ?? _parseLifeStage(json ?? {}),
       measurement = measurement ?? _parseMeasurement(json?['measurement']),
       speciesId = speciesId ?? json?['speciesId'],
       localId = localId ?? _readLocalId(json),
       siteId = siteId ?? json?['siteId'],
       groupId = groupId ?? json?['groupId'],
       zoneId = zoneId ?? json?['zoneId'],
       subplotId = subplotId ?? json?['subplotId'],
       outplantTagId = outplantTagId ?? json?['outplantTagId'],
       provenanceType =
           provenanceType ??
           ProvenanceTypeX.tryParse(json?['provenanceType']?.toString()),
       provenanceAttributes =
           provenanceAttributes ??
           ProvenanceAttributes.fromJson(
             safeMapCast(json?['provenanceAttributes']),
           ),
       physicalForm =
           physicalForm ??
           (json?['physicalForm'] != null
               ? PhysicalFormInstance.fromJson(
                   safeMapCast(json!['physicalForm']) ?? const {},
                 )
               : null),
       physicalFormConfigVersion =
           physicalFormConfigVersion ?? json?['physicalFormConfigVersion'],
       sizeSpec = sizeSpec ?? _parseSize(json ?? {}),
       inventoryMetrics = _resolveInventoryMetrics(
         sizeSpec ?? _parseSize(json ?? {}),
         measurement ?? _parseMeasurement(json?['measurement']),
         json: json,
       ),
       aliases = aliases ?? _parseAliases(json?['aliases']),
       ownerOrganizationId =
           ownerOrganizationId ?? json?['ownerOrganizationId'],
       managingOrganizationId =
           managingOrganizationId ?? json?['managingOrganizationId'],
       genetId = genetId ?? json?['genetId'],
       foreignKeys = foreignKeys ?? _parseForeignKeys(json?['foreignKeys']),
       lifeStageHistory =
           lifeStageHistory ??
           _parseLifeStageHistory(json?['lifeStageHistory']),
       measurementHistory =
           measurementHistory ??
           _parseMeasurementHistory(json?['measurementHistory']),
       super.partial();

  factory OrganismRecord.fromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeArchivedMetadata(json);
    return OrganismRecord._fromJson(normalizedJson);
  }

  OrganismRecord._fromJson(super.json)
    : organismKind =
          OrganismKindX.tryParse(json['organismKind']?.toString()) ??
          OrganismKind.coral,
      recordName = _readRecordName(json) ?? Missing.string,
      lifeStage = _parseLifeStage(json),
      measurement = _parseMeasurement(json['measurement']),
      speciesId = _asString(json['speciesId']),
      localId = _readLocalId(json),
      siteId = _asString(json['siteId']) ?? Missing.string,
      groupId = _asString(json['groupId']) ?? Missing.string,
      zoneId = _asString(json['zoneId']),
      subplotId = _asString(json['subplotId']),
      outplantTagId = _asString(json['outplantTagId']),
      provenanceType = ProvenanceTypeX.tryParse(
        json['provenanceType']?.toString(),
      ),
      provenanceAttributes = ProvenanceAttributes.fromJson(
        safeMapCast(json['provenanceAttributes']),
      ),
      physicalForm = _parsePhysicalForm(json),
      physicalFormConfigVersion = _asString(json['physicalFormConfigVersion']),
      sizeSpec = _parseSize(json),
      inventoryMetrics = _resolveInventoryMetrics(
        _parseSize(json),
        _parseMeasurement(json['measurement']),
        json: json,
      ),
      aliases = _parseAliases(json['aliases']),
      ownerOrganizationId = _asString(json['ownerOrganizationId']),
      managingOrganizationId = _asString(json['managingOrganizationId']),
      genetId = _asString(json['genetId']),
      foreignKeys = _parseForeignKeys(json['foreignKeys']),
      lifeStageHistory = _parseLifeStageHistory(json['lifeStageHistory']),
      measurementHistory = _parseMeasurementHistory(json['measurementHistory']),
      super.fromJson();

  /// Factory method for creating new organism records with proper timestamp initialization
  factory OrganismRecord.create({
    required OrganismKind organismKind,
    required String organizationId,
    required String createdById,
    required LifeStageSpec lifeStage,
    required PopulationMeasurement measurement,
    required String recordName,
    String? id,
    String? speciesId,
    String? localId,
    String? siteId,
    String? groupId,
    String? zoneId,
    String? subplotId,
    String? outplantTagId,
    ProvenanceType? provenanceType,
    ProvenanceAttributes? provenanceAttributes,
    PhysicalFormInstance? physicalForm,
    String? physicalFormConfigVersion,
    SizeSpec? sizeSpec,
    List<OrganismAlias>? aliases,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    String? genetId,
    Map<String, ForeignKeyReference>? foreignKeys,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now().toIso8601String();
    return OrganismRecord.partial(
      id: id,
      createdAt: now,
      createdById: createdById,
      updatedAt: now,
      updatedById: createdById,
      organizationId: organizationId,
      organismKind: organismKind,
      lifeStage: lifeStage,
      measurement: measurement,
      recordName: recordName,
      speciesId: speciesId,
      localId: localId,
      siteId: siteId,
      groupId: groupId,
      zoneId: zoneId,
      subplotId: subplotId,
      outplantTagId: outplantTagId,
      provenanceType: provenanceType,
      provenanceAttributes: provenanceAttributes,
      physicalForm: physicalForm,
      physicalFormConfigVersion: physicalFormConfigVersion,
      sizeSpec: sizeSpec,
      aliases: aliases,
      ownerOrganizationId: ownerOrganizationId,
      managingOrganizationId: managingOrganizationId,
      genetId: genetId,
      foreignKeys: foreignKeys,
      metadata: metadata,
    );
  }

  @override
  ModelType get modelType => ModelType.organismRecord;

  /// Name derived from recordName/localId for GraphNodeRecord compatibility.
  @override
  String get name {
    final recordNameValue = recordName.trim();
    if (recordNameValue.isNotEmpty && recordNameValue != Missing.string) {
      return recordNameValue;
    }
    final localIdValue = localId?.trim();
    if (localIdValue != null &&
        localIdValue.isNotEmpty &&
        localIdValue != Missing.string) {
      return localIdValue;
    }
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    return 'Organism $shortId';
  }

  /// Required display name for this individual record.
  ///
  /// **Format Transition:**
  /// - Old format: `{adjective}-{localId}` (e.g., "fluffy-coral-001")
  /// - New format: `{Adjective}` or `{Adjective}{N}` (e.g., "Crimson", "Crimson2")
  ///
  /// Both formats coexist in the system. Old records may still use the hyphenated
  /// format with embedded localId, while new records use just the adjective with
  /// an optional numeric suffix for uniqueness.
  ///
  /// For the numeric identifier, reference [localId] directly rather than parsing
  /// it from recordName. Users can override recordName with any unique value
  /// within their organization.
  final String recordName;

  final OrganismKind organismKind;

  /// Species identifier for the organism.
  final String? speciesId;

  /// Required local ID for the organism's genet/lineage.
  /// This is the primary identifier used in UI and CSV exports.
  /// Pair with recordName for human-friendly record labels.
  final String? localId;

  /// Site ID (for location tracking)
  final String? siteId;

  /// Group/tank/container ID (parent container)
  final String? groupId;

  /// Zone ID within an outplant site (Site -> Zone hierarchy).
  /// Used for organizing organisms at outplanting sites into geographic zones.
  final String? zoneId;

  /// Subplot ID within a zone (Zone -> Subplot hierarchy).
  /// Used for fine-grained location tracking within zones at outplant sites.
  final String? subplotId;

  /// Individual tag identifier for this organism at an outplant site.
  /// Used to uniquely identify tagged organisms within a subplot.
  final String? outplantTagId;

  final ProvenanceType? provenanceType;
  final ProvenanceAttributes provenanceAttributes;
  final LifeStageSpec lifeStage;

  /// Physical form instance (formId + sizeBandId)
  final PhysicalFormInstance? physicalForm;

  /// Configuration version for snapshot integrity
  /// Records store the version they were created with to ensure
  /// historical accuracy when configuration changes
  final String? physicalFormConfigVersion;

  final PopulationMeasurement measurement;
  final SizeSpec sizeSpec;
  final SizeMetrics inventoryMetrics;
  final List<OrganismAlias> aliases;
  final String? ownerOrganizationId;
  final String? managingOrganizationId;

  /// Reference to the Genet record this organism belongs to.
  /// Used for five-axis provenance tracking (axis 2).
  final String? genetId;

  final Map<String, ForeignKeyReference> foreignKeys;
  @override
  final List<LifeStageTransition> lifeStageHistory;
  @override
  final List<MeasurementSnapshot> measurementHistory;
  
  /// Current health status of the organism.
  /// Accesses the 'healthStatus' field in metadata, or returns [HealthStatus.healthy]
  /// as the default assumption for organisms without explicit status.
  /// Note: This default may inflate healthy/ready-for-outplant metrics if data is missing.
  HealthStatus get healthStatus {
    final statusId = metadata?['healthStatus'] as String?;
    return HealthStatus.maybeFromId(statusId) ?? HealthStatus.healthy;
  }

  String get lifeStageId => lifeStage.stage.id;

  @override
  LifeStageSpec get lifecycleStageSpec => lifeStage;

  @override
  OrganismKind get lifecycleOrganismKind => organismKind;

  /// The current physical form ID for lifecycle tracking.
  String? get lifecycleFormId => physicalForm?.formId;

  @override
  PopulationMeasurement get canonicalMeasurement => measurement;

  @override
  SizeSpec get measurementSizeSpec => sizeSpec;

  @override
  Duration? get customMinimumStageInterval {
    final raw = super.metadata?['lifeStageIntervalDays'];
    if (raw is num && raw > 0) {
      return Duration(days: raw.round());
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Completeness Tracking
  // ---------------------------------------------------------------------------

  /// Optional fields that contribute to completeness percentage.
  /// Required fields (species, genet/provenance, quantity, location) are
  /// enforced at creation time and not included in completeness calculation.
  static const List<String> _completenessFields = ['lifeStage', 'physicalForm'];

  /// Completeness score from 0.0 to 1.0 based on optional fields.
  /// Returns 1.0 when all optional fields (life stage, physical form) are filled.
  double get completenessScore {
    int filledCount = 0;

    // Life Stage (not unknown)
    if (lifeStage.stage != LifeStage.unknown) filledCount++;

    // Physical Form (is set)
    if (physicalForm != null) filledCount++;

    return filledCount / _completenessFields.length;
  }

  /// Returns list of incomplete optional field names for display.
  List<String> get incompleteFields {
    final missing = <String>[];
    if (lifeStage.stage == LifeStage.unknown) missing.add('Life Stage');
    if (physicalForm == null) missing.add('Physical Form');
    return missing;
  }

  /// Completeness as percentage (0-100).
  int get completenessPercent => (completenessScore * 100).round();

  /// Whether all optional fields are filled.
  /// Uses incompleteFields.isEmpty for robustness against floating point issues.
  bool get isComplete => incompleteFields.isEmpty;

  @override
  OrganismRecord copyWith({
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
    String? recordName,
    OrganismKind? organismKind,
    String? speciesId,
    String? localId,
    String? siteId,
    String? groupId,
    String? zoneId,
    String? subplotId,
    String? outplantTagId,
    ProvenanceType? provenanceType,
    ProvenanceAttributes? provenanceAttributes,
    LifeStageSpec? lifeStage,
    PhysicalFormInstance? physicalForm,
    String? physicalFormConfigVersion,
    PopulationMeasurement? measurement,
    SizeSpec? sizeSpec,
    List<OrganismAlias>? aliases,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    String? genetId,
    Map<String, ForeignKeyReference>? foreignKeys,
    List<LifeStageTransition>? lifeStageHistory,
    List<MeasurementSnapshot>? measurementHistory,
  }) {
    return OrganismRecord(
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
      recordName: recordName ?? this.recordName,
      organismKind: organismKind ?? this.organismKind,
      speciesId: speciesId ?? this.speciesId,
      localId: localId ?? this.localId,
      siteId: siteId ?? this.siteId,
      groupId: groupId ?? this.groupId,
      zoneId: zoneId ?? this.zoneId,
      subplotId: subplotId ?? this.subplotId,
      outplantTagId: outplantTagId ?? this.outplantTagId,
      provenanceType: provenanceType ?? this.provenanceType,
      provenanceAttributes: provenanceAttributes ?? this.provenanceAttributes,
      lifeStage: lifeStage ?? this.lifeStage,
      physicalForm: physicalForm ?? this.physicalForm,
      physicalFormConfigVersion:
          physicalFormConfigVersion ?? this.physicalFormConfigVersion,
      measurement: measurement ?? this.measurement,
      sizeSpec: sizeSpec ?? this.sizeSpec,
      aliases: aliases ?? this.aliases,
      ownerOrganizationId: ownerOrganizationId ?? this.ownerOrganizationId,
      managingOrganizationId:
          managingOrganizationId ?? this.managingOrganizationId,
      genetId: genetId ?? this.genetId,
      foreignKeys: foreignKeys ?? this.foreignKeys,
      lifeStageHistory: lifeStageHistory ?? this.lifeStageHistory,
      measurementHistory: measurementHistory ?? this.measurementHistory,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'organismKind': organismKind.name,
      'recordName': recordName,
      'lifeStage': lifeStage.toJson(),
      'measurement': measurement.toJson(),
    };
    void put(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      payload[key] = value;
    }

    put('speciesId', speciesId);
    put('localId', localId);
    put('siteId', siteId);
    put('groupId', groupId);
    put('zoneId', zoneId);
    put('subplotId', subplotId);
    put('outplantTagId', outplantTagId);
    put('provenanceType', provenanceType?.id);
    if (provenanceType != null) {
      final attrs = provenanceAttributes.toJson();
      if (attrs.isNotEmpty) payload['provenanceAttributes'] = attrs;
    }

    // Physical form (new five-axis model)
    if (physicalForm != null) {
      payload['physicalForm'] = physicalForm!.toJson();
    }
    put('physicalFormConfigVersion', physicalFormConfigVersion);

    if (!sizeSpec.isEmpty) payload['size'] = sizeSpec.toJson();
    if (inventoryMetrics.count != null) {
      payload['inventoryCount'] = inventoryMetrics.count;
    }
    if (aliases.isNotEmpty) {
      payload['aliases'] = aliases.map((alias) => alias.toJson()).toList();
    }
    put('ownerOrganizationId', ownerOrganizationId);
    put('managingOrganizationId', managingOrganizationId);
    put('genetId', genetId);
    if (foreignKeys.isNotEmpty) {
      payload['foreignKeys'] = foreignKeys.map(
        (key, ref) => MapEntry(key, ref.toJson()),
      );
    }
    if (lifeStageHistory.isNotEmpty) {
      payload['lifeStageHistory'] = lifeStageHistory
          .map((transition) => transition.toJson())
          .toList();
    }
    if (measurementHistory.isNotEmpty) {
      payload['measurementHistory'] = measurementHistory
          .map((snapshot) => snapshot.toJson())
          .toList(growable: false);
    }

    // Merge with super (includes id, createdAt, organizationId, urlPath, etc.)
    return {...super.toJson(), ...payload};
  }

  /// Builds an [OrganismRecord] when only legacy metadata is available. This
  /// helper keeps Holding/Cohort records in sync while callers gradually swap
  /// to the canonical five-axis payload.
  static OrganismRecord inferFromMetadata({
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required PopulationMeasurement measurement,
    Map<String, dynamic>? metadata,
    String? speciesId,
    LifeStageSpec? lifeStageSpec,
    ProvenanceType? fallbackProvenanceType,
    SizeSpec? sizeSpec,
    ProvenanceAttributes? provenanceAttributes,
    List<OrganismAlias>? aliases,
    Map<String, ForeignKeyReference>? foreignKeys,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) {
    final normalizedMetadata = _normalizeMetadata(metadata);
    String? read(List<String> keys) {
      for (final key in keys) {
        if (!normalizedMetadata.containsKey(key)) continue;
        final value = normalizedMetadata[key];
        final text = _asString(value);
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
      return null;
    }

    final resolvedSpeciesId =
        speciesId ??
        read([
          'speciesId',
          'species_id',
          'species',
          'speciesCode',
          'species_code',
        ]);

    final baseLifeStageSpec = lifeStageSpec ?? LifeStageSpec(stage: lifeStage);
    final alignedLifeStageSpec = baseLifeStageSpec.stage == lifeStage
        ? baseLifeStageSpec
        : baseLifeStageSpec.copyWith(stage: lifeStage);
    final subtype = read(['lifeStageSubtype', 'life_stage_subtype']);
    final resolvedLifeStageSpec = subtype != null
        ? alignedLifeStageSpec.copyWith(subtype: subtype)
        : alignedLifeStageSpec;

    final provenanceTypeId = read([
      'provenanceType',
      'provenance_type',
      'provenanceKind',
      'lineageKind',
    ]);
    final resolvedProvenanceType =
        ProvenanceTypeX.tryParse(provenanceTypeId) ?? fallbackProvenanceType;

    final resolvedProvenanceAttributes =
        provenanceAttributes ??
        ProvenanceAttributes(
          wildCollectionMethod: read([
            'wildCollectionMethod',
            'wildMethod',
            'collectionMethod',
          ]),
        );

    final sizeMapFromMeta = safeMapCast(normalizedMetadata['size']);
    final resolvedSizeSpec = sizeSpec ??
        (sizeMapFromMeta != null ? SizeSpec.fromJson(sizeMapFromMeta) : const SizeSpec());

    final resolvedAliases =
        aliases ?? _parseAliases(normalizedMetadata['aliases']);
    final resolvedLocalId = read(['localId', 'local_id']);
    final resolvedRecordName = read(['recordName', 'record_name']);
    final resolvedForeignKeys =
        foreignKeys ?? _parseForeignKeys(normalizedMetadata['foreignKeys']);
    final resolvedLifeStageHistory = _parseLifeStageHistory(
      normalizedMetadata['lifeStageHistory'],
    );
    final resolvedMeasurementHistory = _parseMeasurementHistory(
      normalizedMetadata['measurementHistory'],
    );

    final ownerId =
        ownerOrganizationId ??
        _asString(normalizedMetadata['ownerOrganizationId']);
    final managingId =
        managingOrganizationId ??
        _asString(normalizedMetadata['managingOrganizationId']);

    // Use .partial() constructor since we don't have full InventoryRecord fields
    return OrganismRecord.partial(
      organismKind: organismKind,
      recordName: resolvedRecordName ?? Missing.string,
      speciesId: resolvedSpeciesId,
      localId: resolvedLocalId,
      provenanceType: resolvedProvenanceType,
      provenanceAttributes: resolvedProvenanceAttributes,
      lifeStage: resolvedLifeStageSpec,
      measurement: measurement,
      sizeSpec: resolvedSizeSpec,
      aliases: resolvedAliases,
      ownerOrganizationId: ownerId,
      managingOrganizationId: managingId,
      foreignKeys: resolvedForeignKeys,
      lifeStageHistory: resolvedLifeStageHistory,
      measurementHistory: resolvedMeasurementHistory,
      metadata: normalizedMetadata,
    );
  }

  static LifeStageSpec _parseLifeStage(Map<String, dynamic> json) {
    final lifeStageJson = json['lifeStage'];
    if (lifeStageJson is Map<String, dynamic>) {
      return LifeStageSpec.fromJson(lifeStageJson);
    }
    final metadata = json['metadata'];
    String? lifeStageId =
        json['lifeStageId']?.toString() ?? json['lifeStage']?.toString();
    if ((lifeStageId == null || lifeStageId.isEmpty) && metadata is Map) {
      lifeStageId =
          metadata['lifeStageId']?.toString() ??
          metadata['lifeStage']?.toString();
    }
    String? subtype = json['lifeStageSubtype']?.toString();
    if ((subtype == null || subtype.isEmpty) && metadata is Map) {
      subtype = metadata['lifeStageSubtype']?.toString();
    }
    final stage = LifeStageX.tryParse(lifeStageId) ?? LifeStage.unknown;
    return LifeStageSpec(stage: stage, subtype: subtype);
  }

  static String? _readLocalId(Map<String, dynamic>? json) {
    if (json == null) return null;
    String? read(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    // Top-level localId is canonical; no metadata fallbacks
    return read(json['localId']) ?? read(json['local_id']);
  }

  static String? _readRecordName(Map<String, dynamic>? json) {
    if (json == null) return null;
    String? read(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }
    final direct = read(json['recordName']) ?? read(json['record_name']);
    if (direct != null) return direct;
    // Fallback: use localId as recordName for backward compatibility
    return _readLocalId(json);
  }

  static List<LifeStageTransition> _parseLifeStageHistory(dynamic raw) {
    if (raw is! Iterable) return const <LifeStageTransition>[];
    final transitions = <LifeStageTransition>[];
    for (final entry in raw) {
      if (entry is Map) {
        transitions.add(LifeStageTransition.fromJson(deepNormalizeMap(entry)));
      }
    }
    return List<LifeStageTransition>.unmodifiable(transitions);
  }

  static List<MeasurementSnapshot> _parseMeasurementHistory(dynamic raw) {
    if (raw is! Iterable) return const <MeasurementSnapshot>[];
    final snapshots = <MeasurementSnapshot>[];
    for (final entry in raw) {
      if (entry is Map) {
        snapshots.add(MeasurementSnapshot.fromJson(deepNormalizeMap(entry)));
      }
    }
    return List<MeasurementSnapshot>.unmodifiable(snapshots);
  }

  static PopulationMeasurement _parseMeasurement(dynamic value) {
    if (value is Map) {
      return PopulationMeasurement.fromJson(deepNormalizeMap(value));
    }
    if (value is PopulationMeasurement) return value;
    final numeric = value is num ? value.toDouble() : 0.0;
    return PopulationMeasurement(value: numeric, unit: MeasurementUnit.count);
  }

  static SizeSpec _parseSize(Map<String, dynamic> json) {
    final sizeMap = safeMapCast(json['size']) ?? safeMapCast(json['sizeSpec']);
    if (sizeMap != null) {
      return SizeSpec.fromJson(sizeMap);
    }
    return const SizeSpec();
  }

  static Map<String, dynamic> _normalizeMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || metadata.isEmpty) {
      return <String, dynamic>{};
    }
    return deepNormalizeMap(metadata);
  }

  static Map<String, dynamic> _normalizeArchivedMetadata(
    Map<String, dynamic> json,
  ) {
    final normalizedJson = deepNormalizeMap(json);
    final metadata = Map<String, dynamic>.from(
      safeMapCast(normalizedJson['metadata']) ?? const <String, dynamic>{},
    );
    var updated = false;
    if (normalizedJson['archived'] == true && metadata[kArchivedFlagKey] != true) {
      metadata[kArchivedFlagKey] = true;
      updated = true;
    }
    if (normalizedJson['archivedAt'] != null &&
        metadata[kArchivedAtKey] == null) {
      metadata[kArchivedAtKey] = normalizedJson['archivedAt'];
      updated = true;
    }
    if (normalizedJson['isDeleted'] == true && metadata['isDeleted'] != true) {
      metadata['isDeleted'] = true;
      updated = true;
    }
    if (updated) {
      normalizedJson['metadata'] = metadata;
    }
    return normalizedJson;
  }


  static PhysicalFormInstance? _parsePhysicalForm(Map<String, dynamic> json) {
    final physicalFormMap = safeMapCast(json['physicalForm']);
    if (physicalFormMap != null) {
      final instance = PhysicalFormInstance.fromJson(physicalFormMap);
      return instance;
    }
    final formId = _asString(json['physicalFormId']);
    final sizeBandId =
        _asString(json['sizeBandId']) ?? _asString(json['size_band_id']);
    if (formId == null || sizeBandId == null) return null;
    return PhysicalFormInstance(formId: formId, sizeBandId: sizeBandId);
  }

  static List<OrganismAlias> _parseAliases(dynamic raw) {
    if (raw is! List) return const <OrganismAlias>[];
    final parsed = <OrganismAlias>[];
    for (final entry in raw) {
      if (entry is OrganismAlias) {
        parsed.add(entry);
      } else if (entry is Map) {
        parsed.add(OrganismAlias.fromJson(deepNormalizeMap(entry)));
      }
    }
    return List<OrganismAlias>.unmodifiable(parsed);
  }

  static Map<String, ForeignKeyReference> _parseForeignKeys(dynamic raw) {
    if (raw is! Map) return const <String, ForeignKeyReference>{};
    final result = <String, ForeignKeyReference>{};
    raw.forEach((dynamic key, dynamic value) {
      if (value is Map) {
        result[key.toString()] = ForeignKeyReference.fromJson(
          deepNormalizeMap(value),
        );
      } else if (value != null) {
        result[key.toString()] = ForeignKeyReference(id: value.toString());
      }
    });
    return UnmodifiableMapView(result);
  }

  /// Validates that cohort provenance types only use container or shared substrate physical forms.
  /// Per 5 Axis Overview: "Cohort can only be associated with container and shared substrate physical forms"
  ///
  /// First attempts to use PhysicalFormConstraintService if initialized, falls back to hardcoded logic.
  String? validatePhysicalFormForProvenance() {
    if (physicalForm == null) return null;

    // Try using constraint service first (config-driven validation)
    // Only check provenance constraints, not life stage (that's handled separately)
    final constraintService = PhysicalFormConstraintService.instance;
    if (constraintService.isInitialized && provenanceType != null) {
      final provenanceConstraints = constraintService.getProvenanceConstraints(
        provenanceType!,
      );
      if (provenanceConstraints != null && provenanceConstraints.isNotEmpty) {
        // Config has constraints for this provenance type, use config-driven validation
        final error = constraintService.validatePhysicalForm(
          provenanceType,
          lifeStage.stage,
          physicalForm!.formId,
        );
        if (error != null) return error;
        return null; // Config says it's valid, skip fallback
      }
    }

    // Fallback to hardcoded validation for backward compatibility
    // (used when config not loaded or no constraints defined for this provenance type)
    // Cohort validation removed (sexualCohort provenance type eliminated)
    return null;
  }

  /// Validates that gamete life stages only use volumetric/liquid physical forms.
  /// Gametes should not be on solid substrates or individual forms.
  ///
  /// First attempts to use PhysicalFormConstraintService if initialized, falls back to hardcoded logic.
  String? validatePhysicalFormForLifeStage() {
    if (physicalForm == null) return null;

    // Try using constraint service first (config-driven validation)
    // Only check life stage constraints, not provenance (that's handled separately)
    final constraintService = PhysicalFormConstraintService.instance;
    if (constraintService.isInitialized) {
      final lifeStageConstraints = constraintService.getLifeStageConstraints(
        lifeStage.stage,
      );
      if (lifeStageConstraints != null && lifeStageConstraints.isNotEmpty) {
        // Config has constraints for this life stage, use config-driven validation
        final error = constraintService.validatePhysicalForm(
          provenanceType,
          lifeStage.stage,
          physicalForm!.formId,
        );
        if (error != null) return error;
        return null; // Config says it's valid, skip fallback
      }
    }

    // Fallback to hardcoded validation for backward compatibility
    // (used when config not loaded or no constraints defined for this life stage)
    if (lifeStage.stage == LifeStage.gamete) {
      final formId = physicalForm!.formId.toLowerCase();

      // Gametes should only be in liquid/volumetric forms (vials, aliquots)
      if (formId.contains('substrate') ||
          formId.contains('fragment') ||
          formId.contains('colony') ||
          formId.contains('individual')) {
        return 'Gametes can only be stored in liquid/volumetric containers (vials, aliquots). '
            'Solid substrates and individual forms are not compatible with gamete life stage.';
      }
    }
    return null;
  }

  /// Validates that the life stage is biologically valid for the organism taxonomy.
  /// Per 5 Axis Overview: "Taxonomy determines which Life Stages are valid"
  ///
  /// Example: Coral can be: gamete, embryo, larva, juvenile, adult, broodstock
  String? validateLifeStageForTaxonomy() {
    return LifeStageConstraintService.instance
        .validateLifeStage(organismKind, lifeStage.stage);
  }

  /// Validates that measurement values are within reasonable bounds.
  /// Returns error message if validation fails, null if valid.
  String? validateMeasurementBounds() {
    // Check count-based measurements
    if (measurement.unit == MeasurementUnit.count) {
      if (measurement.value > maxReasonableCount) {
        return 'Quantity exceeds maximum reasonable count ($maxReasonableCount). Please verify the value.';
      }
    }

    // Check count override in size spec
    if (sizeSpec.countOverride != null &&
        sizeSpec.countOverride! > maxReasonableCount) {
      return 'Count override exceeds maximum reasonable count ($maxReasonableCount). Please verify the value.';
    }

    return null;
  }

  /// Validates size interpretation based on physical form category.
  /// Per 5 Axis Overview specification:
  /// - Individual forms: Size should use dimension fields (measuredDimension, dimensionUnit)
  /// - Container/Shared substrate forms: Size should use density fields (organismsPerUnit, volumeAmount, volumeUnit)
  ///
  /// This validation requires the PhysicalFormConfig to determine category.
  /// Use validateSizeInterpretationWithConfig for complete validation.
  ///
  /// Returns validation error message, or null if valid or cannot validate (no physicalForm or sizeSpec).
  String? validateSizeInterpretation({PhysicalFormConfig? config}) {
    // Skip validation if no physical form or size spec
    if (physicalForm == null || sizeSpec.isEmpty) {
      return null;
    }

    // If config not provided, we can't validate (category unknown)
    if (config == null) {
      return null;
    }

    final category = config.effectiveCategory;

    // Density-based forms (container, shared substrate) require density fields
    if (category.usesDensity) {
      if (sizeSpec.organismsPerUnit == null) {
        return 'Density-based physical forms (${category.label}) require organisms per unit to be specified';
      }
      if (sizeSpec.volumeAmount == null || sizeSpec.volumeUnit == null) {
        return 'Density-based physical forms (${category.label}) require volume amount and unit';
      }

      // Validate volume unit is appropriate (mL, L)
      if (sizeSpec.volumeUnit != null &&
          sizeSpec.volumeUnit!.category != MeasurementUnitCategory.volume) {
        return 'Density-based physical forms require volume units (mL, L), got ${sizeSpec.volumeUnit!.label}';
      }
    }

    // Dimension-based forms (individual) should use dimension fields
    if (category.usesDimension) {
      // If dimension is specified, unit must also be specified
      if (sizeSpec.measuredDimension != null &&
          sizeSpec.dimensionUnit == null) {
        return 'Dimension-based physical forms require dimension unit when dimension is specified';
      }

      // Validate dimension unit is appropriate (cm, mm, m)
      if (sizeSpec.dimensionUnit != null &&
          sizeSpec.dimensionUnit!.category != MeasurementUnitCategory.length) {
        return 'Dimension-based physical forms require length units (cm, mm, m), got ${sizeSpec.dimensionUnit!.label}';
      }

      // Warn if using legacy measuredDimension without unit
      if (sizeSpec.measuredDimension != null &&
          sizeSpec.dimensionUnit == null) {
        return 'Dimension measurement requires unit to be specified';
      }

      // Validate legacy dimensionUnit is appropriate
      if (sizeSpec.dimensionUnit != null &&
          sizeSpec.dimensionUnit!.category != MeasurementUnitCategory.length) {
        return 'Dimension-based physical forms require length units (cm, mm, m), got ${sizeSpec.dimensionUnit!.label}';
      }
    }

    return null; // Valid
  }

  /// Runs all 5-axis validation checks and returns the first error found, or null if valid.
  /// This validates constraints from the 5 Axis Overview specification:
  /// - Taxonomy determines which life stages are valid
  /// - Cohort provenance can only use container/shared substrate physical forms
  /// - Gamete life stages can only use liquid/volumetric physical forms
  /// - Size interpretation must match physical form category
  /// - Measurement values are within reasonable bounds
  ///
  /// Note: Size interpretation validation requires PhysicalFormConfig.
  /// Pass config parameter to validateSizeInterpretation for complete validation.
  String? validateFiveAxisConstraints({
    PhysicalFormConfig? physicalFormConfig,
  }) {
    return validateLifeStageForTaxonomy() ??
        validatePhysicalFormForProvenance() ??
        validatePhysicalFormForLifeStage() ??
        validateSizeInterpretation(config: physicalFormConfig) ??
        validateMeasurementBounds();
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        recordName,
        organismKind,
        speciesId,
        localId,
        siteId,
        groupId,
        zoneId,
        subplotId,
        outplantTagId,
        provenanceType,
        provenanceAttributes,
        lifeStage,
        physicalForm,
        physicalFormConfigVersion,
        measurement,
        sizeSpec,
        inventoryMetrics,
        aliases,
        ownerOrganizationId,
        managingOrganizationId,
        genetId,
        foreignKeys,
        lifeStageHistory,
        measurementHistory,
      ];

  // ---------------------------------------------------------------------------
  // Outplant Location Helpers
  // ---------------------------------------------------------------------------

  /// Whether this organism has outplant hierarchy location data.
  /// Returns true if zoneId, subplotId, or outplantTagId is set.
  bool get hasOutplantLocation =>
      zoneId != null || subplotId != null || outplantTagId != null;

  /// Whether this organism has a complete outplant location hierarchy.
  /// Returns true if all of zoneId, subplotId, and outplantTagId are set.
  bool get hasCompleteOutplantLocation =>
      zoneId != null && subplotId != null && outplantTagId != null;
}

SizeMetrics _resolveInventoryMetrics(
  SizeSpec sizeSpec,
  PopulationMeasurement measurement, {
  Map<String, dynamic>? json,
}) {
  final metrics = sizeSpec.resolvedMetrics();
  final rawCount = json?['inventoryCount'];
  final countFromJson = rawCount is num ? rawCount.toInt() : null;
  final count =
      metrics.count ??
      countFromJson ??
      (measurement.unit == MeasurementUnit.count
          ? measurement.value.toInt()
          : null);
  return metrics.copyWith(
    count: count,
  );
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
