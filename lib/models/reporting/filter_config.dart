// @tier: community
import 'package:equatable/equatable.dart';

/// Configuration for multi-level report filtering.
///
/// Supports filtering at multiple levels of the hierarchy:
/// - Site → Structure → Organism
/// - Species, Genet, Life Stage, Health Status, Zone
///
/// Empty sets mean "no filter" (include all).
class FilterConfig extends Equatable {
  const FilterConfig({
    this.siteIds = const {},
    this.structureIds = const {},
    this.speciesIds = const {},
    this.genetIds = const {},
    this.lifeStageIds = const {},
    this.healthStatusIds = const {},
    this.zoneIds = const {},
    this.crossSiteAggregation = false,
    this.excludeOutplantingSites = true,
  });

  /// Site IDs to include. Empty = all sites.
  final Set<String> siteIds;

  /// Structure IDs to include. Empty = all structures within selected sites.
  final Set<String> structureIds;

  /// Species IDs to include. Empty = all species.
  final Set<String> speciesIds;

  /// Genet IDs to include (Pro feature). Empty = all genets.
  final Set<String> genetIds;

  /// Life stage IDs to include (Pro feature). Empty = all life stages.
  final Set<String> lifeStageIds;

  /// Health status IDs to include (Pro feature). Empty = all statuses.
  final Set<String> healthStatusIds;

  /// Zone IDs to include (Pro feature). Empty = all zones.
  final Set<String> zoneIds;

  /// Whether to aggregate data across all selected sites (Pro feature).
  final bool crossSiteAggregation;

  /// Whether to exclude outplanting sites from nursery reports.
  final bool excludeOutplantingSites;

  /// Returns true if no filters are applied.
  bool get isEmpty =>
      siteIds.isEmpty &&
      structureIds.isEmpty &&
      speciesIds.isEmpty &&
      genetIds.isEmpty &&
      lifeStageIds.isEmpty &&
      healthStatusIds.isEmpty &&
      zoneIds.isEmpty;

  /// Returns true if any filter is applied.
  bool get hasFilters => !isEmpty;

  /// Returns the number of active filters.
  int get activeFilterCount {
    var count = 0;
    if (siteIds.isNotEmpty) count++;
    if (structureIds.isNotEmpty) count++;
    if (speciesIds.isNotEmpty) count++;
    if (genetIds.isNotEmpty) count++;
    if (lifeStageIds.isNotEmpty) count++;
    if (healthStatusIds.isNotEmpty) count++;
    if (zoneIds.isNotEmpty) count++;
    return count;
  }

  /// Summary description of active filters.
  String get filterSummary {
    if (isEmpty) return 'No filters';
    final parts = <String>[];
    if (siteIds.isNotEmpty) {
      parts.add('${siteIds.length} site${siteIds.length == 1 ? '' : 's'}');
    }
    if (structureIds.isNotEmpty) {
      parts.add(
          '${structureIds.length} structure${structureIds.length == 1 ? '' : 's'}');
    }
    if (speciesIds.isNotEmpty) {
      parts.add(
          '${speciesIds.length} species');
    }
    if (genetIds.isNotEmpty) {
      parts.add('${genetIds.length} genet${genetIds.length == 1 ? '' : 's'}');
    }
    if (lifeStageIds.isNotEmpty) {
      parts.add(
          '${lifeStageIds.length} life stage${lifeStageIds.length == 1 ? '' : 's'}');
    }
    if (healthStatusIds.isNotEmpty) {
      parts.add(
          '${healthStatusIds.length} health status${healthStatusIds.length == 1 ? '' : 'es'}');
    }
    if (zoneIds.isNotEmpty) {
      parts.add('${zoneIds.length} zone${zoneIds.length == 1 ? '' : 's'}');
    }
    return parts.join(', ');
  }

  /// Unique signature for caching.
  String get filterSignature {
    final parts = <String>[
      'sites:${_sortedJoin(siteIds)}',
      'structures:${_sortedJoin(structureIds)}',
      'species:${_sortedJoin(speciesIds)}',
      'genets:${_sortedJoin(genetIds)}',
      'stages:${_sortedJoin(lifeStageIds)}',
      'health:${_sortedJoin(healthStatusIds)}',
      'zones:${_sortedJoin(zoneIds)}',
      'cross:$crossSiteAggregation',
      'exclOp:$excludeOutplantingSites',
    ];
    return parts.join('|');
  }

  String _sortedJoin(Set<String> set) {
    if (set.isEmpty) return '*';
    final sorted = set.toList()..sort();
    // Escape delimiter characters in IDs to prevent signature collision
    return sorted.map((id) => id
        .replaceAll('%', '%25') // Escape % first
        .replaceAll(',', '%2C')
        .replaceAll('|', '%7C')
        .replaceAll(':', '%3A')).join(',');
  }

  FilterConfig copyWith({
    Set<String>? siteIds,
    Set<String>? structureIds,
    Set<String>? speciesIds,
    Set<String>? genetIds,
    Set<String>? lifeStageIds,
    Set<String>? healthStatusIds,
    Set<String>? zoneIds,
    bool? crossSiteAggregation,
    bool? excludeOutplantingSites,
  }) {
    return FilterConfig(
      siteIds: siteIds ?? this.siteIds,
      structureIds: structureIds ?? this.structureIds,
      speciesIds: speciesIds ?? this.speciesIds,
      genetIds: genetIds ?? this.genetIds,
      lifeStageIds: lifeStageIds ?? this.lifeStageIds,
      healthStatusIds: healthStatusIds ?? this.healthStatusIds,
      zoneIds: zoneIds ?? this.zoneIds,
      crossSiteAggregation: crossSiteAggregation ?? this.crossSiteAggregation,
      excludeOutplantingSites:
          excludeOutplantingSites ?? this.excludeOutplantingSites,
    );
  }

  /// Add a site to the filter.
  FilterConfig addSite(String siteId) {
    return copyWith(siteIds: {...siteIds, siteId});
  }

  /// Remove a site from the filter.
  FilterConfig removeSite(String siteId) {
    final newSites = Set<String>.from(siteIds)..remove(siteId);
    return copyWith(siteIds: newSites);
  }

  /// Toggle a site in the filter.
  FilterConfig toggleSite(String siteId) {
    return siteIds.contains(siteId) ? removeSite(siteId) : addSite(siteId);
  }

  /// Clear all filters.
  FilterConfig clear() {
    return const FilterConfig();
  }

  Map<String, dynamic> toJson() {
    return {
      if (siteIds.isNotEmpty) 'siteIds': siteIds.toList(),
      if (structureIds.isNotEmpty) 'structureIds': structureIds.toList(),
      if (speciesIds.isNotEmpty) 'speciesIds': speciesIds.toList(),
      if (genetIds.isNotEmpty) 'genetIds': genetIds.toList(),
      if (lifeStageIds.isNotEmpty) 'lifeStageIds': lifeStageIds.toList(),
      if (healthStatusIds.isNotEmpty)
        'healthStatusIds': healthStatusIds.toList(),
      if (zoneIds.isNotEmpty) 'zoneIds': zoneIds.toList(),
      'crossSiteAggregation': crossSiteAggregation,
      'excludeOutplantingSites': excludeOutplantingSites,
    };
  }

  factory FilterConfig.fromJson(Map<String, dynamic> json) {
    return FilterConfig(
      siteIds: _parseStringSet(json['siteIds']),
      structureIds: _parseStringSet(json['structureIds']),
      speciesIds: _parseStringSet(json['speciesIds']),
      genetIds: _parseStringSet(json['genetIds']),
      lifeStageIds: _parseStringSet(json['lifeStageIds']),
      healthStatusIds: _parseStringSet(json['healthStatusIds']),
      zoneIds: _parseStringSet(json['zoneIds']),
      crossSiteAggregation: json['crossSiteAggregation'] as bool? ?? false,
      excludeOutplantingSites:
          json['excludeOutplantingSites'] as bool? ?? true,
    );
  }

  static Set<String> _parseStringSet(dynamic value) {
    if (value == null) return const {};
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    return const {};
  }

  @override
  List<Object?> get props => [
        siteIds,
        structureIds,
        speciesIds,
        genetIds,
        lifeStageIds,
        healthStatusIds,
        zoneIds,
        crossSiteAggregation,
        excludeOutplantingSites,
      ];
}
