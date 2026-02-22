// @tier: community
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/services/site_limits_service.dart';
import 'package:seafoundry_app/services/tier.dart';

class Organization extends InventoryRecord with GraphNodeRecord {
  Organization({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required this.name,
    required this.domain,
    List<String>? siteTypeIds,
    List<String>? activities,
    this.speciesIds = const [],
    this.tier = Tier.community,
    List<OrganismKind>? supportedOrganismKinds,
    super.metadata,
  })  : activities = _normalizeActivitiesInput(
          primary: activities,
          fallback: siteTypeIds,
        ),
        supportedOrganismKinds =
            supportedOrganismKinds ?? const [OrganismKind.coral];

  Organization.fromJson(super.json)
    : name = json['name'] ?? json['createdEvent']?['name'],
      domain = json['domain'] ?? json['createdEvent']?['domain'],
      activities = _normalizeActivitiesInput(
        jsonActivities: json['activities'] ?? json['createdEvent']?['activities'],
        jsonSiteTypes: json['siteTypeIds'] ?? json['createdEvent']?['siteTypeIds'],
      ),
      speciesIds = List<String>.from(
        json['speciesIds'] ?? json['createdEvent']?['speciesIds'] ?? [],
      ),
      tier = Tier.fromString(
        json['tier'] ?? json['createdEvent']?['tier'],
      ),
      supportedOrganismKinds = _parseOrganismKinds(
        json['supportedOrganismKinds'] ??
            json['createdEvent']?['supportedOrganismKinds'],
      ),
      super.fromJson();

  Organization.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
    String? name,
    String? domain,
    List<String>? siteTypeIds,
    List<String>? activities,
    List<String>? speciesIds,
    Tier? tier,
    List<OrganismKind>? supportedOrganismKinds,
  }) : name = name ?? json?['name'] ?? Missing.string,
      domain = domain ?? json?['domain'] ?? Missing.string,
       activities = _normalizeActivitiesInput(
         primary: activities,
         jsonActivities: json?['activities'],
         jsonSiteTypes: json?['siteTypeIds'],
       ),
       speciesIds = speciesIds ?? List<String>.from(json?['speciesIds'] ?? []),
       tier = tier ?? Tier.fromString(json?['tier']),
       supportedOrganismKinds =
           _normalizeOrganismKinds(
             supportedOrganismKinds,
             fallbackSource: json?['supportedOrganismKinds'],
           ),
       super.partial();

  @override
  ModelType get modelType => ModelType.organization;

  @override
  final String name;
  final String domain;
  final List<String> activities;
  final List<String> speciesIds;
  final Tier tier;
  final List<OrganismKind> supportedOrganismKinds;

  @override
  String get slug => domain;
  @override
  String get urlPath => domain;
  @override
  String get internalPath => id;

  List<SiteType> get siteTypes {
    final configuredIds = activities;
    final resolved = configuredIds
        .map((id) => SiteType.builtins[id] ?? SiteType.maybeFromId(id))
        .whereType<SiteType>()
        .toList(growable: false);
    if (resolved.isNotEmpty) return resolved;

    final defaults = SiteLimitsService.getAvailableSiteTypes(
      tier: tier,
      existingSites: const [],
    );
    return defaults.isNotEmpty
        ? defaults
        : const [SiteType.outplanting];
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'name': name,
      'domain': domain,
      'siteTypeIds': activities,
      'activities': activities,
      'speciesIds': speciesIds,
      'tier': tier.name,
      'supportedOrganismKinds':
          supportedOrganismKinds.map((kind) => kind.name).toList(),
    };
  }

  @override
  Organization copyWith({
    String? id,
    String? name,
    String? domain,
    List<String>? siteTypeIds,
    List<String>? activities,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    List<String>? speciesIds,
    Tier? tier,
    List<OrganismKind>? supportedOrganismKinds,
    Map<String, dynamic>? metadata,
  }) => Organization(
    id: id ?? this.id,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    slug: slug ?? this.slug,
    createdById: createdById ?? this.createdById,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    name: name ?? this.name,
    domain: domain ?? this.domain,
    siteTypeIds: siteTypeIds,
    activities: activities ?? siteTypeIds ?? this.activities,
    speciesIds: speciesIds ?? this.speciesIds,
    tier: tier ?? this.tier,
    supportedOrganismKinds:
        supportedOrganismKinds ?? this.supportedOrganismKinds,
    metadata: metadata ?? this.metadata,
  );

  @override
  List<Object?> get props => super.props +
      [name, domain, activities, speciesIds, tier, supportedOrganismKinds];

  OrganismKind get primaryOrganismKind => supportedOrganismKinds.first;

  static List<OrganismKind> _normalizeOrganismKinds(
    List<OrganismKind>? kinds, {
    dynamic fallbackSource,
  }) {
    if (kinds != null && kinds.isNotEmpty) {
      return List<OrganismKind>.unmodifiable(
        _dedupeKinds(kinds),
      );
    }
    if (fallbackSource != null) {
      return _parseOrganismKinds(fallbackSource);
    }
    return const [OrganismKind.coral];
  }

  static List<OrganismKind> _parseOrganismKinds(dynamic source) {
    if (source is List && source.isNotEmpty) {
      final parsed = <OrganismKind>[];
      for (final value in source) {
        final kind = _kindFromValue(value);
        if (kind != null && !parsed.contains(kind)) {
          parsed.add(kind);
        }
      }
      if (parsed.isNotEmpty) {
        return List<OrganismKind>.unmodifiable(parsed);
      }
    }
    return const [OrganismKind.coral];
  }

  static List<OrganismKind> _dedupeKinds(List<OrganismKind> kinds) {
    final deduped = <OrganismKind>[];
    for (final kind in kinds) {
      if (!deduped.contains(kind)) {
        deduped.add(kind);
      }
    }
    return deduped;
  }

  static OrganismKind? _kindFromValue(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final kind in OrganismKind.values) {
      if (kind.name.toLowerCase() == normalized) {
        return kind;
      }
    }
    return null;
  }

  static List<String> _normalizeActivitiesInput({
    List<String>? primary,
    List<String>? fallback,
    dynamic jsonActivities,
    dynamic jsonSiteTypes,
  }) {
    final primaryList = primary ?? _coerceStringList(jsonActivities);
    final fallbackList = fallback ?? _coerceStringList(jsonSiteTypes);
    final combined = <String>[
      ...?primaryList,
      if (primaryList == null || primaryList.isEmpty) ...?fallbackList,
    ];

    final normalized = <String>[];
    for (final value in combined) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (!normalized.contains(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return List<String>.unmodifiable(normalized);
  }

  static List<String>? _coerceStringList(dynamic source) {
    if (source is List && source.isNotEmpty) {
      final results = <String>[];
      for (final entry in source) {
        final value = entry?.toString().trim();
        if (value != null && value.isNotEmpty) {
          results.add(value);
        }
      }
      return results;
    }
    return null;
  }
}
