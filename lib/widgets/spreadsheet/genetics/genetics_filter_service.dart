// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';

/// Service for filtering genetics spreadsheet rows based on user-selected criteria.
class GeneticsFilterService {
  const GeneticsFilterService();

  /// Applies filters to a list of genetics rows and returns filtered results.
  ///
  /// Filters applied:
  /// - Include archived genets flag
  /// - Site filter
  /// - Structure filter
  /// - Species filter
  /// - Genet filter
  /// - Date range filter
  /// - Provenance type filter
  List<Map<String, dynamic>> applyFilters({
    required List<Map<String, dynamic>> allRows,
    required bool includeArchived,
    String? siteFilter,
    String? structureFilter,
    String? speciesFilter,
    String? genetFilter,
    DateTimeRange? dateRange,
    String? provenanceTypeFilter,
  }) {
    final rangeStart = dateRange != null ? DateRangePresets.startOfDay(dateRange.start) : null;
    final rangeEnd = dateRange != null ? DateRangePresets.endOfDay(dateRange.end) : null;

    final results = allRows
        .where((row) {
          // Site filter
          if (siteFilter != null && siteFilter.isNotEmpty) {
            final siteNames = _stringListFor(row, const ['siteNames', 'site_names']);
            if (siteNames.isEmpty || !siteNames.contains(siteFilter)) {
              return false;
            }
          }

          if (structureFilter != null && structureFilter.isNotEmpty) {
            final structures = _stringListFor(
              row,
              const ['locationBreadcrumbs', 'location_breadcrumbs'],
            );
            if (structures.isEmpty || !structures.contains(structureFilter)) {
              return false;
            }
          }

          // Include archived genets
          if (!includeArchived) {
            final archived = _boolFor(row, const ['archived']);
            if (archived) return false;
          }

          // Species filter
          if (speciesFilter != null &&
              speciesFilter.isNotEmpty) {
            final speciesId = _stringFor(row, const ['speciesId', 'species_id']);
            if (speciesId != speciesFilter) {
              return false;
            }
          }

          // Genet filter
          if (genetFilter != null &&
              genetFilter.isNotEmpty) {
            final genetRecordId = _stringFor(row, const ['genetRecordId', 'genet_id']);
            if (genetRecordId != genetFilter) {
              return false;
            }
          }

          // Date range filter
          if (rangeStart != null && rangeEnd != null) {
            final createdAt =
                _dateFor(row, const ['createdAt', 'created_at']);
            if (createdAt == null ||
                createdAt.isBefore(rangeStart) ||
                createdAt.isAfter(rangeEnd)) {
              return false;
            }
          }

          // Provenance type filter
          if (provenanceTypeFilter != null && provenanceTypeFilter.isNotEmpty) {
            final rowValue = _stringFor(row, const [
              'provenanceType',
              'provenance_type',
              'provenanceKind',
              'provenance_kind',
            ]);
            if (rowValue != provenanceTypeFilter) {
              return false;
            }
          }

          return true;
        })
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);

    // Sort by genet name
    results.sort((a, b) {
      final aName = _stringFor(
        a,
        const ['genetName', 'genet_name'],
      ).toLowerCase();
      final bName = _stringFor(
        b,
        const ['genetName', 'genet_name'],
      ).toLowerCase();
      return aName.compareTo(bName);
    });

    return results;
  }

  /// Extracts available site names from rows for filter dropdown.
  List<String> extractAvailableSites(List<Map<String, dynamic>> rows) {
    final sites = <String>{};
    for (final row in rows) {
      final entries = _stringListFor(row, const ['siteNames', 'site_names']);
      for (final site in entries) {
        if (site.isNotEmpty) sites.add(site);
      }
    }
    final sorted = sites.toList()..sort();
    return sorted;
  }

  List<String> extractAvailableStructures(List<Map<String, dynamic>> rows) {
    final structures = <String>{};
    for (final row in rows) {
      final entries = _stringListFor(
        row,
        const ['locationBreadcrumbs', 'location_breadcrumbs'],
      );
      for (final structure in entries) {
        if (structure.isNotEmpty) {
          structures.add(structure);
        }
      }
    }
    final sorted = structures.toList()..sort();
    return sorted;
  }

  /// Extracts available species IDs from rows for filter dropdown.
  List<String> extractAvailableSpeciesIds(List<Map<String, dynamic>> rows) {
    final ids = <String>{};
    for (final row in rows) {
      final id = _stringFor(row, const ['speciesId', 'species_id']);
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    final sorted = ids.toList()..sort();
    return sorted;
  }

  /// Extracts available genet IDs from rows for filter dropdown.
  List<String> extractAvailableGenetIds(List<Map<String, dynamic>> rows) {
    final ids = <String>{};
    for (final row in rows) {
      final id = _stringFor(row, const ['genetRecordId', 'genet_id']);
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    final sorted = ids.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Gets species label from row data.
  String getSpeciesLabel(String speciesId, List<Map<String, dynamic>> allRows) {
    if (speciesId.isEmpty) return 'Unknown';
    final row = allRows.firstWhere(
      (element) =>
          element['speciesId'] == speciesId ||
          element['species_id'] == speciesId,
      orElse: () => <String, dynamic>{},
    );
    return (row['speciesName'] as String?) ??
        (row['species_name'] as String?) ??
        speciesId;
  }

  /// Returns sorted list of provenance types present in [rows].
  List<String> extractAvailableProvenanceTypes(
    List<Map<String, dynamic>> rows,
  ) {
    final types = <String>{};
    for (final row in rows) {
      final value = _stringFor(row, const [
        'provenanceType',
        'provenance_type',
        'provenanceKind',
        'provenance_kind',
      ]);
      if (value.isNotEmpty) {
        types.add(value);
      }
    }
    final sorted = types.toList()..sort();
    return sorted;
  }

  String _stringFor(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  List<String> _stringListFor(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is List) {
        return value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value.trim()];
      }
    }
    return const [];
  }

  DateTime? _dateFor(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  bool _boolFor(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return false;
  }
}
