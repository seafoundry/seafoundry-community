// @tier: community
import 'package:seafoundry_app/utils/spreadsheet_filter_utils.dart';

/// A builder for cascading filter options in spreadsheets.
///
/// Cascading filters work in a hierarchy where selecting values in upstream
/// filters narrows the available options in downstream filters. This utility
/// provides a declarative API for building such filter chains.
///
/// Filter hierarchy example:
/// Site -> Structure -> Species -> Genet -> Life Stage -> Provenance Type
///
/// Usage:
/// ```dart
/// final builder = CascadingFilterBuilder(rows);
///
/// // Build options for the first level (no upstream filters)
/// final siteOptions = builder.buildOptions(
///   idGetter: (row) => row.siteId,
///   labelGetter: (row) => row.siteName,
/// );
///
/// // Build options for subsequent levels with upstream filters
/// final structureOptions = builder.buildOptions(
///   idGetter: (row) => row.structureId,
///   labelGetter: (row) => row.structureName,
///   upstreamFilters: [
///     CascadingFilter(
///       selectedIds: selectedSiteIds,
///       idGetter: (row) => row.siteId,
///     ),
///   ],
/// );
/// ```
class CascadingFilterBuilder<T> {
  /// Creates a cascading filter builder for the given rows.
  const CascadingFilterBuilder(this.rows);

  /// The source rows to build filter options from.
  final List<T> rows;

  /// Builds filter options based on the current state of upstream filters.
  ///
  /// Returns a [CascadingFilterResult] containing both the deduplicated options
  /// as `MapEntry<String?, String?>` pairs and a lookup map for display values.
  ///
  /// Parameters:
  /// - [idGetter]: Extracts the filter ID from a row
  /// - [labelGetter]: Extracts the display label from a row (defaults to ID)
  /// - [upstreamFilters]: Filters to apply before computing options
  /// - [preFilter]: Optional function to pre-filter rows before computing options
  CascadingFilterResult buildOptions({
    required String? Function(T row) idGetter,
    String? Function(T row)? labelGetter,
    List<CascadingFilter<T>> upstreamFilters = const [],
    bool Function(T row)? preFilter,
  }) {
    // Start with all rows, optionally pre-filtered
    Iterable<T> filtered = preFilter != null ? rows.where(preFilter) : rows;

    // Apply upstream filters in order
    for (final filter in upstreamFilters) {
      if (filter.selectedIds.isNotEmpty) {
        filtered = filtered.where((row) {
          final id = filter.idGetter(row);
          return id != null && filter.selectedIds.contains(id);
        });
      }
    }

    // Build the deduplicated entries
    final entries = SpreadsheetFilterUtils.dedupeEntries(
      filtered.map((row) {
        final id = idGetter(row);
        final label = labelGetter?.call(row) ?? id;
        return MapEntry(id, label);
      }),
    );

    // Build lookup map
    final lookup = <String, String>{};
    for (final entry in entries) {
      if (entry.key != null) {
        lookup[entry.key!] = entry.value ?? entry.key!;
      }
    }

    return CascadingFilterResult(
      options: entries,
      lookup: lookup,
    );
  }

  /// Builds filter options from a list field that may contain multiple values.
  ///
  /// Useful for fields like `structurePaths`, `lifeStageIds`, etc. where each
  /// row may contain multiple values.
  CascadingFilterResult buildOptionsFromList({
    required List<String> Function(T row) valuesGetter,
    String Function(String id)? labelFormatter,
    List<CascadingFilter<T>> upstreamFilters = const [],
    bool Function(T row)? preFilter,
  }) {
    // Start with all rows, optionally pre-filtered
    Iterable<T> filtered = preFilter != null ? rows.where(preFilter) : rows;

    // Apply upstream filters in order
    for (final filter in upstreamFilters) {
      if (filter.selectedIds.isNotEmpty) {
        filtered = filtered.where((row) {
          final id = filter.idGetter(row);
          return id != null && filter.selectedIds.contains(id);
        });
      }
    }

    // Collect all unique values from the list fields
    final uniqueValues = <String>{};
    for (final row in filtered) {
      final values = valuesGetter(row);
      uniqueValues.addAll(values.where((v) => v.isNotEmpty));
    }

    // Build entries sorted by label
    final sortedValues = uniqueValues.toList()..sort();
    final entries = sortedValues
        .map((v) => MapEntry<String?, String?>(
              v,
              labelFormatter?.call(v) ?? v,
            ))
        .toList();

    // Build lookup map
    final lookup = <String, String>{};
    for (final entry in entries) {
      if (entry.key != null) {
        lookup[entry.key!] = entry.value ?? entry.key!;
      }
    }

    return CascadingFilterResult(
      options: entries,
      lookup: lookup,
    );
  }

  /// Builds options by applying a list-based upstream filter.
  ///
  /// Use this when the upstream filter matches against a list field in the row.
  CascadingFilterResult buildOptionsWithListUpstream({
    required String? Function(T row) idGetter,
    String? Function(T row)? labelGetter,
    required CascadingListFilter<T> listFilter,
    List<CascadingFilter<T>> additionalFilters = const [],
    bool Function(T row)? preFilter,
  }) {
    // Start with all rows, optionally pre-filtered
    Iterable<T> filtered = preFilter != null ? rows.where(preFilter) : rows;

    // Apply additional single-value filters first
    for (final filter in additionalFilters) {
      if (filter.selectedIds.isNotEmpty) {
        filtered = filtered.where((row) {
          final id = filter.idGetter(row);
          return id != null && filter.selectedIds.contains(id);
        });
      }
    }

    // Apply the list filter
    if (listFilter.selectedIds.isNotEmpty) {
      filtered = filtered.where((row) {
        final values = listFilter.valuesGetter(row);
        return values.any((v) => listFilter.selectedIds.contains(v));
      });
    }

    // Build the deduplicated entries
    final entries = SpreadsheetFilterUtils.dedupeEntries(
      filtered.map((row) {
        final id = idGetter(row);
        final label = labelGetter?.call(row) ?? id;
        return MapEntry(id, label);
      }),
    );

    // Build lookup map
    final lookup = <String, String>{};
    for (final entry in entries) {
      if (entry.key != null) {
        lookup[entry.key!] = entry.value ?? entry.key!;
      }
    }

    return CascadingFilterResult(
      options: entries,
      lookup: lookup,
    );
  }

  /// Extracts just the IDs from filter options.
  static List<String> extractIds(List<MapEntry<String?, String?>> options) {
    return options.where((e) => e.key != null).map((e) => e.key!).toList();
  }
}

/// Represents an upstream filter in the cascade.
class CascadingFilter<T> {
  /// Creates a cascading filter.
  const CascadingFilter({
    required this.selectedIds,
    required this.idGetter,
  });

  /// The currently selected IDs for this filter.
  final Set<String> selectedIds;

  /// Extracts the filter ID from a row.
  final String? Function(T row) idGetter;

  /// Creates an empty filter that passes all rows.
  static CascadingFilter<T> empty<T>(String? Function(T row) idGetter) {
    return CascadingFilter<T>(
      selectedIds: const {},
      idGetter: idGetter,
    );
  }
}

/// Represents an upstream filter that matches against a list field.
class CascadingListFilter<T> {
  /// Creates a cascading list filter.
  const CascadingListFilter({
    required this.selectedIds,
    required this.valuesGetter,
  });

  /// The currently selected IDs for this filter.
  final Set<String> selectedIds;

  /// Extracts the list of values from a row.
  final List<String> Function(T row) valuesGetter;
}

/// The result of building cascading filter options.
class CascadingFilterResult {
  /// Creates a cascading filter result.
  const CascadingFilterResult({
    required this.options,
    required this.lookup,
  });

  /// Creates an empty result.
  const CascadingFilterResult.empty()
      : options = const [],
        lookup = const {};

  /// The deduplicated filter options as (id, label) pairs.
  final List<MapEntry<String?, String?>> options;

  /// A lookup map from ID to display label.
  final Map<String, String> lookup;

  /// Whether there are any options available.
  bool get isEmpty => options.isEmpty;

  /// Whether there are options available.
  bool get isNotEmpty => options.isNotEmpty;

  /// Gets the number of options.
  int get length => options.length;

  /// Extracts just the IDs from the options.
  List<String> get ids =>
      options.where((e) => e.key != null).map((e) => e.key!).toList();

  /// Gets the label for an ID.
  String labelFor(String id) => lookup[id] ?? id;
}

/// Extension for easily building a filter chain.
extension CascadingFilterChain<T> on CascadingFilterBuilder<T> {
  /// Creates a filter definition for use in building subsequent options.
  CascadingFilter<T> filter(
    Set<String> selectedIds,
    String? Function(T row) idGetter,
  ) {
    return CascadingFilter<T>(
      selectedIds: selectedIds,
      idGetter: idGetter,
    );
  }

  /// Creates a list filter definition for use in building subsequent options.
  CascadingListFilter<T> listFilter(
    Set<String> selectedIds,
    List<String> Function(T row) valuesGetter,
  ) {
    return CascadingListFilter<T>(
      selectedIds: selectedIds,
      valuesGetter: valuesGetter,
    );
  }
}
