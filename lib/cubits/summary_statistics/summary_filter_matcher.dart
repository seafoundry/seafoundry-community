// @tier: community
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';

/// Resolved group hierarchy chain for an organism's location.
///
/// Used for hierarchical structure filtering (superstructure/structure/substructure).
class GroupChain {
  const GroupChain({
    this.superstructureId,
    this.structureId,
    this.substructureId,
  });

  final String? superstructureId;
  final String? structureId;
  final String? substructureId;
}

/// Shared utility for matching organisms against summary statistics filters.
///
/// Consolidates duplicate `_matchesSummaryFilters` logic from:
/// - `SummaryCardFilterX.predicate()` in `summary_card_filter.dart`
/// - `_SummaryStatisticsData._matchesSummaryFilters()` in `summary_statistics_data.dart`
///
/// The `ignore*` flags support cascading filter computation where each filter
/// dropdown shows options that match all OTHER active filters (excluding itself).
abstract final class SummaryFilterMatcher {
  /// Checks if an organism matches the active summary filters.
  ///
  /// Returns `true` if the organism matches all active (non-ignored) filters,
  /// or if no filters are active.
  ///
  /// **Ignore Flags:**
  /// When computing available options for a filter dropdown, pass `true` for
  /// that filter's ignore flag. This shows all options that would be valid
  /// given the other active filters.
  ///
  /// **Null/Empty Handling:**
  /// Uses [normalizeId] to treat null and empty/whitespace strings uniformly.
  /// An organism with a null/empty ID for a field will NOT match if that
  /// filter is active (and not ignored).
  ///
  /// **Hierarchical Structure Filtering:**
  /// When [groupLookup] is provided, structure filtering uses hierarchical
  /// matching against superstructure, structure, and substructure levels.
  /// The organism's group chain is resolved by walking up the parent hierarchy.
  ///
  /// - If superstructure filter is set, organism must be in a group whose
  ///   chain includes that superstructure.
  /// - If structure filter is set, organism must be in a group whose chain
  ///   includes that structure.
  /// - If substructure filter is set, organism must be in that specific
  ///   substructure (or a child of it).
  ///
  /// If [groupLookup] is null, falls back to legacy behavior (checking
  /// `organism.groupId` against `selectedStructureIds` only).
  static bool matches(
    OrganismRecord organism,
    SummaryStatisticsState? filterState, {
    Map<String, Group>? groupLookup,
    bool ignoreSite = false,
    bool ignoreSuperstructure = false,
    bool ignoreStructure = false,
    bool ignoreSubstructure = false,
    bool ignoreSpecies = false,
    bool ignoreLifeStage = false,
    bool ignoreGenet = false,
  }) {
    if (filterState == null) return true;

    if (!ignoreSite && filterState.selectedSiteIds.isNotEmpty) {
      final siteId = normalizeId(organism.siteId);
      if (siteId == null || !filterState.selectedSiteIds.contains(siteId)) {
        return false;
      }
    }

    // Hierarchical structure matching
    if (!_matchesStructureFilters(
      organism,
      filterState,
      groupLookup: groupLookup,
      ignoreSuperstructure: ignoreSuperstructure,
      ignoreStructure: ignoreStructure,
      ignoreSubstructure: ignoreSubstructure,
    )) {
      return false;
    }

    if (!ignoreSpecies && filterState.selectedSpeciesIds.isNotEmpty) {
      final speciesId = normalizeId(organism.speciesId);
      if (speciesId == null ||
          !filterState.selectedSpeciesIds.contains(speciesId)) {
        return false;
      }
    }

    if (!ignoreLifeStage && filterState.selectedLifeStageIds.isNotEmpty) {
      final lifeStageId = normalizeId(organism.lifeStageId);
      if (lifeStageId == null ||
          !filterState.selectedLifeStageIds.contains(lifeStageId)) {
        return false;
      }
    }

    if (!ignoreGenet && filterState.selectedGenetIds.isNotEmpty) {
      final genetRecordId = normalizeId(GenetIdResolver.resolve(organism));
      if (genetRecordId == null || !filterState.selectedGenetIds.contains(genetRecordId)) {
        return false;
      }
    }

    return true;
  }

  /// Checks if an organism matches the hierarchical structure filters.
  ///
  /// Returns true if all active (non-ignored) structure filters match.
  static bool _matchesStructureFilters(
    OrganismRecord organism,
    SummaryStatisticsState filterState, {
    Map<String, Group>? groupLookup,
    required bool ignoreSuperstructure,
    required bool ignoreStructure,
    required bool ignoreSubstructure,
  }) {
    final hasSuperstructureFilter = !ignoreSuperstructure &&
        filterState.selectedSuperstructureIds.isNotEmpty;
    final hasStructureFilter =
        !ignoreStructure && filterState.selectedStructureIds.isNotEmpty;
    final hasSubstructureFilter =
        !ignoreSubstructure && filterState.selectedSubstructureIds.isNotEmpty;

    // No structure filters active
    if (!hasSuperstructureFilter &&
        !hasStructureFilter &&
        !hasSubstructureFilter) {
      return true;
    }

    // If no groupLookup provided, fall back to legacy behavior
    if (groupLookup == null) {
      // Cannot check hierarchical filters without lookup - fail closed
      if (hasSuperstructureFilter || hasSubstructureFilter) {
        return false;
      }
      // Legacy: only check structure filter against groupId
      if (hasStructureFilter) {
        final groupId = normalizeId(organism.groupId);
        if (groupId == null ||
            !filterState.selectedStructureIds.contains(groupId)) {
          return false;
        }
      }
      return true;
    }

    // Resolve the group chain for this organism
    final groupId = normalizeId(organism.groupId);
    if (groupId == null) {
      // Organism has no group, can't match any structure filter
      return false;
    }

    final group = groupLookup[groupId];
    final chain = resolveGroupChain(group, groupLookup);

    // Check superstructure filter
    if (hasSuperstructureFilter) {
      if (chain.superstructureId == null ||
          !filterState.selectedSuperstructureIds
              .contains(chain.superstructureId)) {
        return false;
      }
    }

    // Check structure filter
    if (hasStructureFilter) {
      if (chain.structureId == null ||
          !filterState.selectedStructureIds.contains(chain.structureId)) {
        return false;
      }
    }

    // Check substructure filter
    if (hasSubstructureFilter) {
      if (chain.substructureId == null ||
          !filterState.selectedSubstructureIds.contains(chain.substructureId)) {
        return false;
      }
    }

    return true;
  }

  /// Resolves the group hierarchy chain for an organism's group.
  ///
  /// Walks up the parent hierarchy and categorizes groups by their type:
  /// - superstructure: top-level grouping (e.g., Life Support System, Zone)
  /// - structure: primary container (e.g., Tank, Tree, Grid)
  /// - substructure: subdivision (e.g., Tray, Branch, Tag)
  ///
  /// Uses cycle detection to prevent infinite loops in malformed data.
  /// Custom group types (not in GroupType.builtins) are skipped for
  /// categorization but the traversal continues up the parent chain.
  static GroupChain resolveGroupChain(
    Group? group,
    Map<String, Group> groupLookup,
  ) {
    if (group == null) return const GroupChain();

    String? superstructureId;
    String? structureId;
    String? substructureId;

    Group? current = group;
    final visited = <String>{};
    const maxDepth = 20;
    var depth = 0;

    while (current != null &&
        !visited.contains(current.id) &&
        depth < maxDepth) {
      visited.add(current.id);
      depth++;

      // Try to categorize by group type; skip custom types that aren't
      // in GroupType.builtins (they throw StateError)
      try {
        final groupType = current.groupType;

        if (substructureId == null && groupType.isSubstructure) {
          substructureId = current.id;
        }
        if (structureId == null && groupType.isStructure) {
          structureId = current.id;
        }
        if (superstructureId == null && groupType.isSuperstructure) {
          superstructureId = current.id;
        }
      } on StateError {
        // Custom group type - skip categorization but continue traversal
      }

      final parentId = current.parentId;
      if (parentId.isEmpty) break;
      current = groupLookup[parentId];
    }

    return GroupChain(
      superstructureId: superstructureId,
      structureId: structureId,
      substructureId: substructureId,
    );
  }

  /// Normalizes an ID string for filter matching.
  ///
  /// Returns `null` if the value is null, empty, or contains only whitespace.
  /// Otherwise returns the trimmed value.
  ///
  /// This ensures consistent treatment of null and empty strings across all
  /// filter matching logic.
  static String? normalizeId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
