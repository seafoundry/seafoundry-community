// @tier: community

import 'package:seafoundry_app/cubits/spreadsheet_shared/spreadsheet_filters.dart'
    as shared;
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/filter_application_service.dart';

/// Result of inventory filter application.
class InventoryFilterResult {
  const InventoryFilterResult({
    required this.filteredRows,
    required this.appliedFilters,
  });

  final List<Map<String, dynamic>> filteredRows;
  final shared.SpreadsheetFilters appliedFilters;
}

/// Coordinates inventory-specific filtering across data.
///
/// Handles special cases:
/// - Date range filtering only applies to coral organisms
/// - Organism support checks against both supported and holding organisms
/// - Alias filtering combines with base filters
class InventoryFilterCoordinator {
  const InventoryFilterCoordinator({
    FilterApplicationService? filterService,
  }) : _filterService = filterService ?? const FilterApplicationService();

  final FilterApplicationService _filterService;

  /// Apply all inventory-specific filters to rows.
  InventoryFilterResult applyInventoryFilters({
    required List<Map<String, dynamic>> rows,
    required shared.SpreadsheetFilters filters,
    required String aliasQuery,
    required Set<OrganismKind> supportedOrganisms,
    required Set<OrganismKind> holdingOrganisms,
  }) {
    final organismFilter = filters.organismFilter;

    // Early exit if organism not supported
    if (organismFilter == null ||
        !isOrganismSupported(organismFilter, supportedOrganisms, holdingOrganisms)) {
      return InventoryFilterResult(
        filteredRows: const [],
        appliedFilters: filters,
      );
    }

    // Date range filtering only applies to coral
    final effectiveDateRange = allowsDateRangeFilter(organismFilter)
        ? filters.dateRange
        : null;

    // Build effective filters (convert to service's SpreadsheetFilters)
    final effectiveFilters = SpreadsheetFilters(
      organismKind: organismFilter,
      dateRange: effectiveDateRange,
      siteId: filters.siteId,
      speciesId: filters.speciesId,
      genetId: filters.genetId,
    );

    // Apply base filters
    var filtered = _filterService.applyFilters(rows, effectiveFilters);

    // Apply alias filter
    final normalizedQuery = aliasQuery.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      filtered = filtered
          .where((row) => _filterService.matchesAlias(row, normalizedQuery))
          .toList();
    }

    return InventoryFilterResult(
      filteredRows: filtered,
      appliedFilters: shared.SpreadsheetFilters(
        organismFilter: organismFilter,
        dateRange: effectiveDateRange,
        siteId: filters.siteId,
        speciesId: filters.speciesId,
        genetId: filters.genetId,
      ),
    );
  }

  /// Check if date range filtering is allowed for organism kind.
  /// Currently only coral supports date range filtering.
  bool allowsDateRangeFilter(OrganismKind? organismKind) {
    return organismKind == OrganismKind.coral;
  }

  /// Check if organism kind is supported.
  bool isOrganismSupported(
    OrganismKind kind,
    Set<OrganismKind> supportedOrganisms,
    Set<OrganismKind> holdingOrganisms,
  ) {
    if (kind == OrganismKind.coral) {
      return supportedOrganisms.contains(OrganismKind.coral);
    }
    return holdingOrganisms.contains(kind);
  }
}
