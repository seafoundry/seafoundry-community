// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Centralized service for applying common filter logic across spreadsheet cubits.
///
/// This service standardizes filter operations that were previously duplicated
/// across monitoring_entries, outplant_events, inventory, and observations
/// spreadsheet cubits. It handles:
/// - Date range filtering with multiple field name fallbacks
/// - Site/species/genet filtering with field name normalization
/// - Life stage and provenance type filtering (including array fields)
/// - Organism kind filtering
/// - Case-insensitive search across multiple fields
///
/// Usage:
/// ```dart
/// final service = FilterApplicationService();
/// final filtered = service.applyFilters(rows, filters);
/// ```
class FilterApplicationService {
  const FilterApplicationService();

  /// Apply all filters to a list of spreadsheet rows.
  ///
  /// Returns a new filtered list based on the provided [SpreadsheetFilters].
  /// Filters are applied in order: organism kind, date range, site, species,
  /// genet, life stage, provenance type, and search term.
  List<Map<String, dynamic>> applyFilters(
    List<Map<String, dynamic>> rows,
    SpreadsheetFilters filters,
  ) {
    return rows.where((row) => matchesFilters(row, filters)).toList();
  }

  /// Check if a single row matches all the specified filters.
  ///
  /// Returns true only if the row passes ALL active filters.
  bool matchesFilters(Map<String, dynamic> row, SpreadsheetFilters filters) {
    // Organism kind filter
    if (filters.organismKind != null &&
        !matchesOrganismKind(row, filters.organismKind!)) {
      return false;
    }

    // Date range filter
    if (filters.dateRange != null &&
        !matchesDateRange(row, filters.dateRange!)) {
      return false;
    }

    // Site filter
    if (filters.siteId != null &&
        filters.siteId!.isNotEmpty &&
        !matchesSite(row, filters.siteId!)) {
      return false;
    }

    // Species filter
    if (filters.speciesId != null &&
        filters.speciesId!.isNotEmpty &&
        !matchesSpecies(row, filters.speciesId!)) {
      return false;
    }

    // Genet filter
    if (filters.genetId != null &&
        filters.genetId!.isNotEmpty &&
        !matchesGenet(row, filters.genetId!)) {
      return false;
    }

    // Life stage filter
    if (filters.lifeStageId != null &&
        filters.lifeStageId!.isNotEmpty &&
        !matchesLifeStage(row, filters.lifeStageId!)) {
      return false;
    }

    // Provenance type filter
    if (filters.provenanceTypeId != null &&
        filters.provenanceTypeId!.isNotEmpty &&
        !matchesProvenanceType(row, filters.provenanceTypeId!)) {
      return false;
    }

    // Search term filter
    if (filters.searchTerm != null &&
        filters.searchTerm!.isNotEmpty &&
        !matchesSearchTerm(row, filters.searchTerm!)) {
      return false;
    }

    return true;
  }

  /// Check if row matches the specified site ID.
  bool matchesSite(Map<String, dynamic> row, String siteId) {
    final rowSiteId = _getString(row, ['siteId']);
    return rowSiteId == siteId;
  }

  /// Check if row matches the specified species ID.
  bool matchesSpecies(Map<String, dynamic> row, String speciesId) {
    final rowSpeciesId = _getString(row, ['speciesId']);
    return rowSpeciesId == speciesId;
  }

  /// Check if row matches the specified genet ID (provenance ID).
  bool matchesGenet(Map<String, dynamic> row, String genetId) {
    final rowGenetId = _getString(row, ['provenanceId']);
    return rowGenetId == genetId;
  }

  /// Check if row matches the specified life stage ID.
  ///
  /// Supports both single values and arrays. For arrays (like `lifeStageIds`),
  /// returns true if the array contains the target life stage ID.
  bool matchesLifeStage(Map<String, dynamic> row, String lifeStageId) {
    // Try array fields first (common in monitoring/outplant spreadsheets)
    final arrayValue = row['lifeStageIds'];
    if (arrayValue is List) {
      return arrayValue.any((id) => id.toString() == lifeStageId);
    }

    // Fallback to single value field
    final rowLifeStageId = _getString(row, ['lifeStageId']);
    return rowLifeStageId == lifeStageId;
  }

  /// Check if row matches the specified provenance type ID.
  ///
  /// Supports both single values and arrays.
  bool matchesProvenanceType(Map<String, dynamic> row, String provenanceTypeId) {
    // Try array field first
    final arrayValue = row['provenanceTypeIds'];
    if (arrayValue is List) {
      return arrayValue.any((id) => id.toString() == provenanceTypeId);
    }

    // Try single value field
    final rowProvenanceType = _getString(row, ['provenanceType']);
    return rowProvenanceType == provenanceTypeId;
  }

  /// Check if row's date falls within the specified date range.
  ///
  /// Tries multiple date field names in order of preference:
  /// `date`, `eventDate`, `created_at`, `createdAt`, `updated_at`, `updatedAt`.
  ///
  /// The date range is inclusive, with the start time set to 00:00:00 and
  /// end time set to 23:59:59.999 in local time. Row dates are normalized
  /// to local time to align with user-selected ranges.
  bool matchesDateRange(Map<String, dynamic> row, DateTimeRange range) {
    final date = _getDateTime(
      row,
      ['date', 'eventDate', 'created_at', 'createdAt', 'updated_at', 'updatedAt'],
    );

    if (date == null) {
      return false;
    }

    // Normalize to local time for comparison with user-selected ranges.
    final dateLocal = date.isUtc ? date.toLocal() : date;
    final startLocal = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endLocal = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    return !dateLocal.isBefore(startLocal) && !dateLocal.isAfter(endLocal);
  }

  /// Check if row matches the specified organism kind.
  ///
  /// Returns true if no kind is found in the row (defaults to coral).
  bool matchesOrganismKind(Map<String, dynamic> row, OrganismKind kind) {
    final raw = row['organismKind'];

    if (raw == null) {
      // Default to coral for backward compatibility
      return kind == OrganismKind.coral;
    }

    if (raw is OrganismKind) {
      return raw == kind;
    }

    if (raw is String) {
      final normalized = raw.toLowerCase();
      return normalized == kind.name.toLowerCase();
    }

    return false;
  }

  /// Check if row matches the search term across multiple searchable fields.
  ///
  /// Performs case-insensitive matching against common fields.
  ///
  /// Returns true if ANY field contains the search term (case-insensitive).
  bool matchesSearchTerm(Map<String, dynamic> row, String searchTerm) {
    final query = searchTerm.toLowerCase();

    // Define searchable fields (canonical names only)
    final searchableFields = [
      'site',
      'siteName',
      'species',
      'species_name',
      'provenanceId',
      'genet_name',
      'genetId',
      'event_notes',
      'entry_notes',
      'notes',
      'comment',
      'permit_summary',
      'permit_authority',
      'permit_window',
      'record_name',
      'localId',
    ];

    for (final field in searchableFields) {
      final value = row[field];
      if (value != null) {
        final text = value.toString().toLowerCase();
        if (text.contains(query)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if row matches alias query (inventory-specific).
  ///
  /// Searches across both structured `aliasEntries` list and fallback `aliases` string.
  /// Matches against alias label, value, and source system fields (case-insensitive).
  bool matchesAlias(Map<String, dynamic> row, String aliasQuery) {
    final query = aliasQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    // Check structured alias entries first
    final entries = row['aliasEntries'];
    if (entries is Iterable) {
      for (final raw in entries) {
        final alias = _asOrganismAlias(raw);
        if (alias == null) continue;
        final label = alias.label?.toLowerCase().trim();
        final value = alias.value.toLowerCase().trim();
        final source = alias.sourceSystem.toLowerCase().trim();
        if (label?.contains(query) == true ||
            value.contains(query) ||
            source.contains(query)) {
          return true;
        }
      }
    }

    // Fallback to string-based aliases field
    final fallback = row['aliases']?.toString().toLowerCase();
    if (fallback != null && fallback.contains(query)) {
      return true;
    }

    return false;
  }

  // ========== Private Helper Methods ==========

  /// Convert dynamic value to OrganismAlias if possible.
  OrganismAlias? _asOrganismAlias(dynamic value) {
    if (value is OrganismAlias) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      try {
        return OrganismAlias.fromJson(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Extract a string value from row, trying multiple field names in order.
  ///
  /// Returns the first non-empty string found, or empty string if none found.
  String _getString(Map<String, dynamic> row, List<String> fieldNames) {
    for (final field in fieldNames) {
      final value = row[field];
      if (value is String && value.isNotEmpty) {
        return value;
      }
      if (value != null) {
        final text = value.toString();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return '';
  }

  /// Extract a DateTime value from row, trying multiple field names in order.
  ///
  /// Returns the first valid DateTime found, or null if none found.
  DateTime? _getDateTime(Map<String, dynamic> row, List<String> fieldNames) {
    for (final field in fieldNames) {
      final value = row[field];

      if (value is DateTime) {
        return value;
      }

      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

/// Container for spreadsheet filter criteria.
///
/// All fields are optional - only non-null filters are applied.
class SpreadsheetFilters {
  const SpreadsheetFilters({
    this.organismKind,
    this.dateRange,
    this.siteId,
    this.speciesId,
    this.genetId,
    this.lifeStageId,
    this.provenanceTypeId,
    this.searchTerm,
  });

  final OrganismKind? organismKind;
  final DateTimeRange? dateRange;
  final String? siteId;
  final String? speciesId;
  final String? genetId;
  final String? lifeStageId;
  final String? provenanceTypeId;
  final String? searchTerm;

  /// Create a copy with updated values.
  SpreadsheetFilters copyWith({
    OrganismKind? organismKind,
    DateTimeRange? dateRange,
    String? siteId,
    String? speciesId,
    String? genetId,
    String? lifeStageId,
    String? provenanceTypeId,
    String? searchTerm,
    bool clearDateRange = false,
  }) {
    return SpreadsheetFilters(
      organismKind: organismKind ?? this.organismKind,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      siteId: siteId ?? this.siteId,
      speciesId: speciesId ?? this.speciesId,
      genetId: genetId ?? this.genetId,
      lifeStageId: lifeStageId ?? this.lifeStageId,
      provenanceTypeId: provenanceTypeId ?? this.provenanceTypeId,
      searchTerm: searchTerm ?? this.searchTerm,
    );
  }
}
