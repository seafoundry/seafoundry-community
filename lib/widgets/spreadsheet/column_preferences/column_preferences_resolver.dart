// @tier: community
import 'package:seafoundry_app/widgets/spreadsheet/column_preferences/column_preferences.dart';

/// Resolves column order and visibility based on user preferences.
///
/// - Reorders columns to match [prefs.columnOrder]
/// - Appends new columns (not in prefs) at the end in factory order
/// - Removes hidden columns (in [prefs.hiddenColumns])
/// - Drops stale keys (in prefs but not in factory columns)
List<T> resolveColumns<T>({
  required List<T> factoryColumns,
  required ColumnPreferences prefs,
  required String Function(T) keyExtractor,
}) {
  if (!prefs.hasCustomOrder && prefs.hiddenColumns.isEmpty) {
    return factoryColumns; // Fast path: no customization
  }

  final factoryMap = {
    for (final col in factoryColumns) keyExtractor(col): col,
  };

  List<T> ordered;
  if (prefs.hasCustomOrder) {
    // Start with user-ordered columns (dropping stale keys)
    ordered = [
      for (final key in prefs.columnOrder)
        if (factoryMap.containsKey(key)) factoryMap[key]!,
    ];
    // Append new columns not in user's order
    final orderedKeys = prefs.columnOrder.toSet();
    for (final col in factoryColumns) {
      if (!orderedKeys.contains(keyExtractor(col))) {
        ordered.add(col);
      }
    }
  } else {
    ordered = List.of(factoryColumns);
  }

  // Filter out hidden columns
  if (prefs.hiddenColumns.isNotEmpty) {
    ordered = ordered
        .where((col) => !prefs.hiddenColumns.contains(keyExtractor(col)))
        .toList();
  }

  return ordered;
}
