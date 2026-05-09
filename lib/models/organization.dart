// @tier: community
import 'package:seafoundry_app/models/accession_config.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/bioregion.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
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
    this.bioregions = const [],
    this.accessionConfig,
    this.orgPrefix,
    super.metadata,
  })  : activities = _normalizeActivitiesInput(
          primary: activities,
          fallback: siteTypeIds,
        );

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
      bioregions = _parseBioregions(json['bioregions']),
      accessionConfig = json['accessionConfig'] != null
          ? AccessionConfig.fromJson(
              Map<String, dynamic>.from(json['accessionConfig'] as Map))
          : null,
      orgPrefix = json['orgPrefix'] as String?,
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
    List<Bioregion>? bioregions,
    AccessionConfig? accessionConfig,
    String? orgPrefix,
  }) : name = name ?? json?['name'] ?? Missing.string,
      domain = domain ?? json?['domain'] ?? Missing.string,
       activities = _normalizeActivitiesInput(
         primary: activities,
         jsonActivities: json?['activities'],
         jsonSiteTypes: json?['siteTypeIds'],
       ),
       speciesIds = speciesIds ?? List<String>.from(json?['speciesIds'] ?? []),
       tier = tier ?? Tier.fromString(json?['tier']),
       bioregions = bioregions ?? _parseBioregions(json?['bioregions']),
       accessionConfig = accessionConfig ??
           (json?['accessionConfig'] != null
               ? AccessionConfig.fromJson(
                   Map<String, dynamic>.from(
                       json!['accessionConfig'] as Map))
               : null),
       orgPrefix = orgPrefix ?? json?['orgPrefix'] as String?,
       super.partial();

  @override
  ModelType get modelType => ModelType.organization;

  @override
  final String name;
  final String domain;
  final List<String> activities;
  final List<String> speciesIds;
  final Tier tier;
  final List<Bioregion> bioregions;
  final AccessionConfig? accessionConfig;
  final String? orgPrefix;

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
      existingSites: const [],
    );
    return defaults.isNotEmpty
        ? defaults
        : const [SiteType.nursery];
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
      if (bioregions.isNotEmpty)
        'bioregions': bioregions.map((b) => b.id).toList(),
      if (accessionConfig != null) 'accessionConfig': accessionConfig!.toJson(),
      if (orgPrefix != null) 'orgPrefix': orgPrefix,
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
    List<Bioregion>? bioregions,
    AccessionConfig? accessionConfig,
    String? orgPrefix,
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
    bioregions: bioregions ?? this.bioregions,
    accessionConfig: accessionConfig ?? this.accessionConfig,
    orgPrefix: orgPrefix ?? this.orgPrefix,
    metadata: metadata ?? this.metadata,
  );

  @override
  List<Object?> get props => super.props +
      [name, domain, activities, speciesIds, tier,
       bioregions, accessionConfig, orgPrefix];

  static List<Bioregion> _parseBioregions(dynamic raw) {
    if (raw is! List) return const <Bioregion>[];
    final result = <Bioregion>[];
    for (final entry in raw) {
      final id = entry?.toString();
      if (id == null || id.isEmpty) continue;
      final region = BioregionX.tryParse(id);
      if (region != null && !result.contains(region)) {
        result.add(region);
      }
    }
    return List<Bioregion>.unmodifiable(result);
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
