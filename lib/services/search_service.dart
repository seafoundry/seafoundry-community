import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/human_sort.dart';

/// Result of a search operation
class SearchResult {
  final GraphNodeRecord record;
  final SearchResultType type;
  final String matchedField;
  final double relevanceScore;
  final List<String>? hierarchySegments;

  const SearchResult({
    required this.record,
    required this.type,
    required this.matchedField,
    this.relevanceScore = 1.0,
    this.hierarchySegments,
  });

  /// Human-friendly preview of where this record lives in the hierarchy.
  /// Drops the organization segment and joins the remaining url segments.
  String get hierarchyPath {
    try {
      if (hierarchySegments != null && hierarchySegments!.isNotEmpty) {
        return hierarchySegments!.join(' / ');
      }
      final urlPath = record.urlPath;
      final parts = urlPath
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (parts.isEmpty) {
        return urlPath;
      }
      if (parts.length == 1) {
        return parts.first;
      }
      return parts.skip(1).join(' / ');
    } catch (_) {
      // Fallback for unexpected errors
      return '';
    }
  }
}

/// Types of search results
enum SearchResultType {
  site('Site'),
  group('Group'),
  organism('Organism');

  final String displayName;
  const SearchResultType(this.displayName);
}

/// Extension to build display-friendly subtitles for search results.
extension SearchResultSubtitle on SearchResult {
  /// Build subtitle showing organism details or type/location for other records.
  ///
  /// For organisms: "Acropora cervicornis · Wild · Adult · Fragment · 5 ct · Site / Tank A1"
  /// For sites/groups: "Site · Organization / Site Name"
  String buildSubtitle({bool showTypeForNonOrganism = true}) {
    try {
      if (record is OrganismRecord) {
        return _buildOrganismSubtitle(record as OrganismRecord);
      }
      final path = hierarchyPath;
      if (showTypeForNonOrganism) {
        return path.isNotEmpty
            ? '${type.displayName} · $path'
            : type.displayName;
      }
      if (path.isNotEmpty) {
        return path;
      }
      return 'Matched: $matchedField';
    } catch (_) {
      // Fallback for any unexpected errors during subtitle building
      return type.displayName;
    }
  }

  String _buildOrganismSubtitle(OrganismRecord organism) {
    final parts = <String>[];

    final species = SpeciesRegistry.globalById(organism.speciesId);
    final speciesName = species?.name ?? organism.speciesId;
    if (speciesName != null && speciesName.trim().isNotEmpty) {
      parts.add(speciesName);
    }

    final provenance = organism.provenanceDisplayName;
    if (provenance != null && provenance.isNotEmpty) {
      parts.add(provenance);
    }

    // Life stage (skip unknown)
    if (organism.lifeStage.stage != LifeStage.unknown) {
      final stageLabel = organism.lifeStage.displayName;
      if (stageLabel.trim().isNotEmpty) {
        parts.add(stageLabel);
      }
    }

    final formName = organism.physicalFormDisplayName;
    if (formName != null && formName.isNotEmpty) {
      parts.add(formName);
    }

    final count = _resolveOrganismCount(organism);
    if (count != null && count > 0) {
      parts.add('$count ct');
    }

    final path = hierarchyPath;
    if (path.isNotEmpty) {
      parts.add(path);
    }

    return parts.isNotEmpty ? parts.join(' · ') : path;
  }

  int? _resolveOrganismCount(OrganismRecord organism) {
    final count = organism.inventoryMetrics.count;
    if (count != null && count > 0) {
      return count;
    }
    if (organism.measurement.unit.category == MeasurementUnitCategory.count) {
      final value = organism.measurement.value.toInt();
      return value > 0 ? value : null;
    }
    return null;
  }
}

/// Service for searching across various entities in the app
class SearchService {
  final SiteRepository siteRepository;
  final GroupRepository groupRepository;
  final OrganismRecordRepository organismRecordRepository;

  SearchService({
    required this.siteRepository,
    required this.groupRepository,
    required this.organismRecordRepository,
  });

  /// Search across all entity types
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    final results = <SearchResult>[];

    // Fetch data with defensive null handling
    List<Site> sites;
    List<Group> groups;
    List<OrganismRecord> organisms;

    try {
      final data = await Future.wait([
        siteRepository.getAll(),
        groupRepository.getAll(),
        organismRecordRepository.getAll(),
      ]);
      sites = data[0] as List<Site>? ?? [];
      groups = data[1] as List<Group>? ?? [];
      organisms = data[2] as List<OrganismRecord>? ?? [];
    } catch (e) {
      LoggingService.instance.warning(
        'SearchService: Failed to fetch data: $e',
      );
      return [];
    }

    final organizationName = siteRepository.organization.name;
    final siteMap = {for (final site in sites) site.id: site};
    final groupMap = {for (final group in groups) group.id: group};

    results.addAll(
      await _searchSites(normalizedQuery, organizationName, sites),
    );
    results.addAll(
      await _searchGroups(
        normalizedQuery,
        organizationName,
        sites: siteMap,
        groups: groupMap,
      ),
    );
    results.addAll(
      await _searchOrganisms(
        normalizedQuery,
        organizationName,
        sites: siteMap,
        groups: groupMap,
        organisms: organisms,
      ),
    );

    // Sort by relevance score (highest first), then by human-friendly label
    results.sort((a, b) {
      final score = b.relevanceScore.compareTo(a.relevanceScore);
      if (score != 0) return score;
      return compareHumanReadable(_resultLabel(a), _resultLabel(b));
    });

    // Limit to top 50 results
    return results.take(50).toList();
  }

  /// Search for matching sites
  Future<List<SearchResult>> _searchSites(
    String query,
    String organizationName,
    List<Site> sites,
  ) async {
    final results = <SearchResult>[];

    for (final site in sites) {
      double score = 0.0;
      String matchedField = '';

      // Check name (highest priority)
      if (site.name.toLowerCase().contains(query)) {
        score = site.name.toLowerCase().startsWith(query) ? 0.9 : 0.7;
        matchedField = 'name';
      }
      // Sites don't have notes field

      if (score > 0) {
        results.add(
          SearchResult(
            record: site,
            type: SearchResultType.site,
            matchedField: matchedField,
            relevanceScore: score,
            hierarchySegments: [organizationName, site.name],
          ),
        );
      }
    }

    return results;
  }

  /// Search for matching groups
  Future<List<SearchResult>> _searchGroups(
    String query,
    String organizationName, {
    required Map<String, Site> sites,
    required Map<String, Group> groups,
  }) async {
    final results = <SearchResult>[];

    for (final group in groups.values) {
      double score = 0.0;
      String matchedField = '';

      // Check name
      if (group.name.toLowerCase().contains(query)) {
        score = group.name.toLowerCase().startsWith(query) ? 0.9 : 0.7;
        matchedField = 'name';
      }
      // Check group type
      else if (group.groupTypeId.toLowerCase().contains(query)) {
        score = 0.6;
        matchedField = 'type';
      }
      // Groups don't have notes field

      if (score > 0) {
        final hierarchy = _buildGroupHierarchy(
          group,
          organizationName,
          sites,
          groups,
        );
        results.add(
          SearchResult(
            record: group,
            type: SearchResultType.group,
            matchedField: matchedField,
            relevanceScore: score,
            hierarchySegments: hierarchy,
          ),
        );
      }
    }

    return results;
  }

  /// Search for matching organisms
  Future<List<SearchResult>> _searchOrganisms(
    String query,
    String organizationName, {
    required Map<String, Site> sites,
    required Map<String, Group> groups,
    required List<OrganismRecord> organisms,
  }) async {
    final results = <SearchResult>[];

    for (final organism in organisms) {
      try {
        double score = 0.0;
        String matchedField = '';

        // Check record name first (primary label)
        // Use null-safe access in case tagId is unexpectedly null
        final tagId = organism.tagId.trim();
        if (tagId.isNotEmpty && tagId.toLowerCase().contains(query)) {
          score = tagId.toLowerCase().startsWith(query) ? 0.95 : 0.8;
          matchedField = 'tagId';
        }
        // Check local ID (genet label)
        else if ((organism.localGenetId ?? '').toLowerCase().contains(query)) {
          final localGenetId = organism.localGenetId ?? '';
          score = localGenetId.toLowerCase().startsWith(query) ? 0.9 : 0.7;
          matchedField = 'localGenetId';
        }
        // Check tag (stored in metadata)
        else if ((organism.metadata?['tag'] as String?)?.toLowerCase().contains(
              query,
            ) ??
            false) {
          score = 0.8;
          matchedField = 'tag';
        }
        // Check notes (stored in metadata)
        else if ((organism.metadata?['notes'] as String?)
                ?.toLowerCase()
                .contains(query) ??
            false) {
          score = 0.5;
          matchedField = 'notes';
        }
        // Check life stage (e.g., "adult", "juvenile", "gamete")
        else if (_matchesLifeStage(organism, query)) {
          score = 0.65;
          matchedField = 'lifeStage';
        }
        // Check provenance type (e.g., "wild", "asexual", "sexual cohort")
        else if (_matchesProvenanceType(organism, query)) {
          score = 0.65;
          matchedField = 'provenanceType';
        }
        // Check physical form (e.g., "fragment", "colony", "plug")
        else if (_matchesPhysicalForm(organism, query)) {
          score = 0.6;
          matchedField = 'physicalForm';
        }
        // Check size class (e.g., "xs", "small", "medium", "large", "xl")
        else if (_matchesSizeClass(organism, query)) {
          score = 0.55;
          matchedField = 'sizeClass';
        }
        // Check aliases (clonal IDs, accession numbers, external identifiers)
        else if (_matchesAliases(organism, query)) {
          score = 0.85;
          matchedField = 'alias';
        }
        // Check genetRecordId directly
        else if ((organism.genetRecordId ?? '').toLowerCase().contains(query)) {
          score = 0.75;
          matchedField = 'genetRecordId';
        }
        // Check foreignKeys (genetRecordId, clonalId, accessionNumber, provenanceId)
        else if (_matchesForeignKeys(organism, query)) {
          score = 0.7;
          matchedField = 'foreignKey';
        }

        if (score > 0) {
          final hierarchy = _buildOrganismHierarchy(
            organism,
            organizationName,
            sites,
            groups,
          );
          results.add(
            SearchResult(
              record: organism,
              type: SearchResultType.organism,
              matchedField: matchedField,
              relevanceScore: score,
              hierarchySegments: hierarchy,
            ),
          );
        }
      } catch (e) {
        // Skip organisms that fail to process (malformed data)
        // This prevents one bad record from breaking the entire search
        LoggingService.instance.warning(
          'SearchService: Failed to process organism ${organism.id}: $e',
        );
      }
    }

    return results;
  }

  /// Check if organism's life stage matches the query
  bool _matchesLifeStage(OrganismRecord organism, String query) {
    final stage = organism.lifeStage.stage;
    if (stage == LifeStage.unknown) return false;

    final stageDisplay = stage.displayName.toLowerCase();
    final stageName = stage.name.toLowerCase();

    // Also check aliases for common terms
    final stageAliases = _lifeStageAliases[stage] ?? [];

    return stageDisplay.contains(query) ||
        stageName.contains(query) ||
        stageAliases.any((alias) => alias.contains(query));
  }

  /// Check if organism's provenance type matches the query
  bool _matchesProvenanceType(OrganismRecord organism, String query) {
    final provenance = organism.provenanceType;
    if (provenance == null) return false;

    final provenanceDisplay = provenance.displayName.toLowerCase();
    final provenanceName = provenance.name.toLowerCase();

    // Check for common provenance term aliases
    final provenanceAliases = _provenanceTypeAliases[provenance] ?? [];

    return provenanceDisplay.contains(query) ||
        provenanceName.contains(query) ||
        provenanceAliases.any((alias) => alias.contains(query));
  }

  /// Check if organism's physical form matches the query
  bool _matchesPhysicalForm(OrganismRecord organism, String query) {
    final formName = organism.physicalFormDisplayName?.toLowerCase();
    if (formName == null || formName.isEmpty) return false;

    final formId = organism.physicalForm?.formId.toLowerCase();

    return formName.contains(query) ||
        (formId != null && formId.contains(query));
  }

  /// Check if organism's size class matches the query
  bool _matchesSizeClass(OrganismRecord organism, String query) {
    final sizeClass = organism.sizeSpec.sizeClass?.toLowerCase();
    if (sizeClass == null || sizeClass.isEmpty) return false;

    // Map abbreviations to full names for better matching
    final sizeAliases = _sizeClassAliases[sizeClass] ?? [];

    return sizeClass.contains(query) ||
        sizeAliases.any((alias) => alias.contains(query));
  }

  /// Life stage aliases for improved search matching
  static const _lifeStageAliases = <LifeStage, List<String>>{
    LifeStage.gamete: ['egg', 'eggs', 'sperm', 'reproductive'],
    LifeStage.embryo: ['embryos', 'developing'],
    LifeStage.larva: ['larvae', 'larval', 'planula', 'planulae'],
    LifeStage.juvenile: ['juveniles', 'young', 'recruit', 'recruits'],
    LifeStage.adult: ['adults', 'mature', 'colony', 'colonies'],
    LifeStage.broodstock: ['brood', 'breeding', 'breeder', 'breeders'],
  };

  /// Provenance type aliases for improved search matching
  static const _provenanceTypeAliases = <ProvenanceType, List<String>>{
    ProvenanceType.wild: ['wildcaught', 'wild-caught', 'natural', 'collected'],
    ProvenanceType.transfer: ['transferred', 'moved', 'received'],
    ProvenanceType.unknown: ['unspecified'],
  };

  /// Size class aliases for improved search matching
  static const _sizeClassAliases = <String, List<String>>{
    'xs': ['extra small', 'extrasmall', 'xsmall', 'tiny'],
    's': ['small', 'sm'],
    'm': ['medium', 'med', 'mid'],
    'l': ['large', 'lg', 'big'],
    'xl': ['extra large', 'extralarge', 'xlarge', 'huge'],
  };

  /// Check if organism's aliases match the query
  /// Aliases include clonal IDs, accession numbers, and external identifiers
  bool _matchesAliases(OrganismRecord organism, String query) {
    final aliases = organism.aliases;
    if (aliases.isEmpty) return false;

    for (final alias in aliases) {
      // Check alias value (the actual identifier)
      if (alias.value.toLowerCase().contains(query)) {
        return true;
      }
      // Check alias label (human-readable name)
      if (alias.label != null && alias.label!.toLowerCase().contains(query)) {
        return true;
      }
      // Check source system (e.g., "NOAA", "CRC", "internal")
      if (alias.sourceSystem.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  /// Check if organism's foreign keys match the query
  /// Includes genetRecordId, clonalId, accessionNumber, provenanceId references
  bool _matchesForeignKeys(OrganismRecord organism, String query) {
    final foreignKeys = organism.foreignKeys;
    if (foreignKeys.isEmpty) return false;

    for (final entry in foreignKeys.entries) {
      final key = entry.key.toLowerCase();
      final ref = entry.value;

      // Check key name (e.g., "genetRecordId", "clonalId", "accessionNumber")
      if (key.contains(query)) {
        return true;
      }
      // Check reference ID
      if (ref.id.toLowerCase().contains(query)) {
        return true;
      }
      // Check metadata values if any
      for (final metaValue in ref.metadata.values) {
        if (metaValue.toString().toLowerCase().contains(query)) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> _buildGroupHierarchy(
    Group group,
    String organizationName,
    Map<String, Site> sites,
    Map<String, Group> groups,
  ) {
    final segments = <String>[organizationName];

    final site = sites[group.siteId];
    if (site != null) {
      segments.add(site.name);
    }

    final ancestors = <String>[];
    Group? current = group;
    while (current != null) {
      ancestors.insert(0, current.name);
      final parentId = current.parentId;
      if (parentId.isEmpty) {
        break;
      }
      current = groups[parentId];
    }

    segments.addAll(ancestors);
    return segments;
  }

  List<String> _buildOrganismHierarchy(
    OrganismRecord organism,
    String organizationName,
    Map<String, Site> sites,
    Map<String, Group> groups,
  ) {
    final segments = <String>[organizationName];

    if (organism.siteId != null) {
      final site = sites[organism.siteId];
      if (site != null) {
        segments.add(site.name);
      }
    }

    if (organism.groupId != null) {
      final group = groups[organism.groupId];
      if (group != null) {
        final groupSegments = _buildGroupHierarchy(
          group,
          organizationName,
          sites,
          groups,
        );
        final skipCount = segments.length;
        if (groupSegments.length > skipCount) {
          segments.addAll(groupSegments.sublist(skipCount));
        }
      }
    }

    return segments;
  }

  String _resultLabel(SearchResult result) {
    return result.record.name;
  }
}
