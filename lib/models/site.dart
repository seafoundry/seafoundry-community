// @tier: community
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/models/records/records.dart';
import 'package:seafoundry_app/models/site_capabilities.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

class Site extends InventoryRecord with GraphNodeRecord, GroupParent {
  Site({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.siteTypeId,
    required this.name,
    required this.groupIdHierarchy,
    List<OrganismKind>? supportedOrganismKinds,
    this.geometry,
    this.description,
    this.latitude,
    this.longitude,
    this.rowCount,
    this.colCount,
    this.groupTypeLabels,
    this.externalHoldingOrganizationId,
    this.externalHoldingSiteId,
    this.externalHoldingGroupPath,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
  }) : supportedOrganismKinds = _normalizeOrganismKinds(
         supportedOrganismKinds,
         siteTypeId,
       );

  Site.fromJson(super.json)
    : siteTypeId = _readSiteTypeId(json),
      supportedOrganismKinds = _normalizeOrganismKinds(
        _parseOrganismKinds(
          json['supportedOrganismKinds'] ?? json['organismKinds'],
        ),
        _readSiteTypeId(json),
      ),
      name = json['name'] ??
          json['createdEvent']?['name'] ??
          Missing.string,
      groupIdHierarchy = List<String>.from(
        json['groupIdHierarchy'] ??
            json['createdEvent']?['groupIdHierarchy'] ??
            [],
      ),
      groupTypeLabels = _parseGroupTypeLabels(json['groupTypeLabels']),
      description = json['description'] ?? json['createdEvent']?['description'],
      latitude =
          safeDouble(json['latitude']) ??
          safeDouble(json['createdEvent']?['latitude']),
      longitude =
          safeDouble(json['longitude']) ??
          safeDouble(json['createdEvent']?['longitude']),
      geometry = OutplantGeometry.maybeFromJson(
        json['geometry'] ?? json['createdEvent']?['geometry'],
      ),
      rowCount =
          safeInt(json['rowCount']) ??
          safeInt(json['createdEvent']?['rowCount']),
      colCount =
          safeInt(json['colCount']) ??
          safeInt(json['createdEvent']?['colCount']),
      externalHoldingOrganizationId = json['externalHoldingOrganizationId'] as String?,
      externalHoldingSiteId = json['externalHoldingSiteId'] as String?,
      externalHoldingGroupPath = json['externalHoldingGroupPath'] as String?,
      super.fromJson();

  Site.partial({
    super.json,
    super.id,
    super.internalPath,
    super.slug,
    super.urlPath,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    String? siteTypeId,
    String? name,
    List<String>? groupIdHierarchy,
    List<OrganismKind>? supportedOrganismKinds,
    Map<String, String>? groupTypeLabels,
    String? description,
    double? latitude,
    double? longitude,
    OutplantGeometry? geometry,
    int? rowCount,
    int? colCount,
    String? externalHoldingOrganizationId,
    String? externalHoldingSiteId,
    String? externalHoldingGroupPath,
  }) : siteTypeId = siteTypeId ?? json?['siteTypeId'] ?? Missing.string,
       name = name ?? json?['name'] ?? Missing.string,
       groupIdHierarchy =
           groupIdHierarchy ??
           List<String>.unmodifiable(json?['groupIdHierarchy'] ?? const []),
       groupTypeLabels =
           groupTypeLabels ?? _parseGroupTypeLabels(json?['groupTypeLabels']),
       supportedOrganismKinds = _normalizeOrganismKinds(
         supportedOrganismKinds ??
             _parseOrganismKinds(
               json?['supportedOrganismKinds'] ?? json?['organismKinds'],
             ),
         siteTypeId ?? json?['siteTypeId'] ?? Missing.string,
       ),
       description = description ?? json?['description'],
       latitude = latitude ?? safeDouble(json?['latitude']),
       longitude = longitude ?? safeDouble(json?['longitude']),
       geometry = geometry ?? OutplantGeometry.maybeFromJson(json?['geometry']),
       rowCount = rowCount ?? safeInt(json?['rowCount']),
       colCount = colCount ?? safeInt(json?['colCount']),
       externalHoldingOrganizationId = externalHoldingOrganizationId ??
           json?['externalHoldingOrganizationId'] as String?,
       externalHoldingSiteId = externalHoldingSiteId ??
           json?['externalHoldingSiteId'] as String?,
       externalHoldingGroupPath = externalHoldingGroupPath ??
           json?['externalHoldingGroupPath'] as String?,
       super.partial();

  final String siteTypeId;
  final List<String> groupIdHierarchy;

  /// Custom display labels for group types within this site.
  /// Maps group type ID to custom label (e.g., 'group_type_tank' -> 'Grow Tank').
  final Map<String, String>? groupTypeLabels;

  final OutplantGeometry? geometry;
  final String? description;
  final double? latitude;
  final double? longitude;
  final int? rowCount;
  final int? colCount;
  final List<OrganismKind> supportedOrganismKinds;

  /// Organization ID where organisms are held externally (for retained ownership).
  final String? externalHoldingOrganizationId;

  /// Site ID at the external organization where organisms are held.
  final String? externalHoldingSiteId;

  /// Group path at the external organization where organisms are held.
  final String? externalHoldingGroupPath;

  @override
  String get siteId => id;

  SiteType get siteType => _resolveSiteType(siteTypeId);

  /// Whether this site represents organisms held at an external organization.
  bool get isExternalHolding => siteType.isExternalHolding;

  List<GroupType> get groupTypeHierarchy {
    // Primary: respect persisted hierarchy
    final resolved = groupIdHierarchy
        .map((id) => GroupType.builtins[id])
        .whereType<GroupType>()
        .toList(growable: false);
    if (resolved.isNotEmpty) return resolved;

    // Log warning if groupIdHierarchy was provided but couldn't be resolved
    if (groupIdHierarchy.isNotEmpty) {
      if (kDebugMode) {
        LoggingService.instance.warning(
          'Could not resolve groupIdHierarchy $groupIdHierarchy, using defaults',
        );
      }
    }

    // Fallback: use built-in defaults for this site type so creation dialogs
    // never render empty when legacy data omitted hierarchy.
    return siteType.groupTypes;
  }

  /// Get the display label for a group type within this site.
  /// Returns custom label if configured, otherwise the group type's default name.
  String getGroupTypeLabel(GroupType groupType) {
    return groupTypeLabels?[groupType.id] ?? groupType.name;
  }

  /// Get group types from the hierarchy filtered by category.
  List<GroupType> getGroupTypesByCategory(GroupTypeCategory category) {
    return groupTypeHierarchy
        .where((t) => t.category == category)
        .toList(growable: false);
  }

  /// Get superstructure types available in this site.
  List<GroupType> get superstructureTypes =>
      getGroupTypesByCategory(GroupTypeCategory.superstructure);

  /// Get structure types available in this site.
  List<GroupType> get structureTypes =>
      getGroupTypesByCategory(GroupTypeCategory.structure);

  /// Get substructure types available in this site.
  List<GroupType> get substructureTypes =>
      getGroupTypesByCategory(GroupTypeCategory.substructure);

  @override
  ModelType get modelType => ModelType.site;

  @override
  final String name;

  @override
  Map<String, dynamic> toJson() {
    return {
      "siteTypeId": siteTypeId,
      "name": name,
      "groupIdHierarchy": groupIdHierarchy,
      if (groupTypeLabels != null && groupTypeLabels!.isNotEmpty)
        "groupTypeLabels": groupTypeLabels,
      "supportedOrganismKinds": supportedOrganismKinds
          .map((kind) => kind.name)
          .toList(growable: false),
      if (description != null) "description": description,
      if (geometry != null) "geometry": geometry!.toJson(),
      if (latitude != null) "latitude": latitude,
      if (longitude != null) "longitude": longitude,
      if (rowCount != null) "rowCount": rowCount,
      if (colCount != null) "colCount": colCount,
      if (externalHoldingOrganizationId != null)
        "externalHoldingOrganizationId": externalHoldingOrganizationId,
      if (externalHoldingSiteId != null)
        "externalHoldingSiteId": externalHoldingSiteId,
      if (externalHoldingGroupPath != null)
        "externalHoldingGroupPath": externalHoldingGroupPath,
      ...super.toJson(),
    };
  }

  @override
  Site copyWith({
    String? id,
    String? siteTypeId,
    String? name,
    List<String>? groupIdHierarchy,
    Map<String, String>? groupTypeLabels,
    bool clearGroupTypeLabels = false,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    String? description,
    double? latitude,
    double? longitude,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    int? rowCount,
    int? colCount,
    List<OrganismKind>? supportedOrganismKinds,
    Map<String, dynamic>? metadata,
    String? externalHoldingOrganizationId,
    bool clearExternalHoldingOrganizationId = false,
    String? externalHoldingSiteId,
    bool clearExternalHoldingSiteId = false,
    String? externalHoldingGroupPath,
    bool clearExternalHoldingGroupPath = false,
  }) => Site(
    id: id ?? this.id,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    siteTypeId: siteTypeId ?? this.siteTypeId,
    name: name ?? this.name,
    groupIdHierarchy: groupIdHierarchy ?? this.groupIdHierarchy,
    groupTypeLabels: clearGroupTypeLabels
        ? null
        : (groupTypeLabels ?? this.groupTypeLabels),
    geometry: clearGeometry ? null : (geometry ?? this.geometry),
    description: description ?? this.description,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    rowCount: rowCount ?? this.rowCount,
    colCount: colCount ?? this.colCount,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    slug: slug ?? this.slug,
    metadata: metadata ?? this.metadata,
    supportedOrganismKinds: supportedOrganismKinds ?? this.supportedOrganismKinds,
    externalHoldingOrganizationId: clearExternalHoldingOrganizationId
        ? null
        : (externalHoldingOrganizationId ?? this.externalHoldingOrganizationId),
    externalHoldingSiteId: clearExternalHoldingSiteId
        ? null
        : (externalHoldingSiteId ?? this.externalHoldingSiteId),
    externalHoldingGroupPath: clearExternalHoldingGroupPath
        ? null
        : (externalHoldingGroupPath ?? this.externalHoldingGroupPath),
  );

  @override
  // ignore: must_call_super
  bool validate() {
    // Check required fields explicitly
    if (siteTypeId.isEmpty || name.isEmpty) {
      return false;
    }

    // Check base record validation (required fields only)
    final baseValid =
        id.isNotEmpty &&
        createdAt.isNotEmpty &&
        createdById.isNotEmpty &&
        updatedAt.isNotEmpty &&
        updatedById.isNotEmpty &&
        organizationId.isNotEmpty &&
        urlPath.isNotEmpty &&
        internalPath.isNotEmpty &&
        slug.isNotEmpty;

    return baseValid;
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        siteTypeId,
        name,
        groupIdHierarchy,
        groupTypeLabels,
        description,
        latitude,
        longitude,
        geometry,
        rowCount,
        colCount,
        supportedOrganismKinds,
        externalHoldingOrganizationId,
        externalHoldingSiteId,
        externalHoldingGroupPath,
      ];

  bool get hasGeometry => geometry != null;

  GeoCoordinate? get centroid => geometry?.centroid;

  bool supportsOrganism(OrganismKind kind) =>
      supportedOrganismKinds.contains(kind);

  GeoBounds? get bounds => geometry?.bounds;

  List<GeoCoordinate> get placements =>
      geometry?.coordinates ?? const <GeoCoordinate>[];

  static List<OrganismKind> _normalizeOrganismKinds(
    List<OrganismKind>? kinds,
    String siteTypeId,
  ) {
    final resolved = (kinds == null || kinds.isEmpty)
        ? _defaultOrganismsForSiteType(siteTypeId)
        : kinds;
    final deduped = <OrganismKind>{...resolved}.toList(growable: false);
    return List<OrganismKind>.unmodifiable(deduped);
  }

  static List<OrganismKind> _defaultOrganismsForSiteType(String siteTypeId) {
    final siteType = _resolveSiteType(siteTypeId);
    final supported = SiteCapabilities.resolve(
      siteType,
    ).supportedOrganisms.toList();
    if (supported.isNotEmpty) {
      return List<OrganismKind>.unmodifiable(supported);
    }
    return const [OrganismKind.coral];
  }

  static SiteType _resolveSiteType(String siteTypeId) {
    return SiteType.fromId(siteTypeId);
  }

  static List<OrganismKind>? _parseOrganismKinds(dynamic raw) {
    if (raw is! List) return null;
    final kinds = <OrganismKind>[];
    for (final entry in raw) {
      final parsed = OrganismKindX.tryParse(entry?.toString());
      if (parsed != null) {
        kinds.add(parsed);
      }
    }
    return kinds;
  }

  static Map<String, String>? _parseGroupTypeLabels(dynamic raw) {
    if (raw is! Map) return null;
    final labels = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is String && entry.value is String) {
        labels[entry.key as String] = entry.value as String;
      }
    }
    return labels.isEmpty ? null : labels;
  }

  static String _readSiteTypeId(Map<String, dynamic>? json) {
    if (json == null) return SiteType.nurseryExSitu.id;
    final direct = json['siteTypeId'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }
    final createdEvent = json['createdEvent'];
    if (createdEvent is Map<String, dynamic>) {
      final createdType = createdEvent['siteTypeId'];
      if (createdType is String && createdType.isNotEmpty) {
        return createdType;
      }
    }
    return SiteType.nurseryExSitu.id;
  }
}
