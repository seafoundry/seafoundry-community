// @tier: community
import 'package:flutter/material.dart';

/// Data class describing a single multiselect filter dropdown in a
/// [SpreadsheetFilterBar].
///
/// Each field maps directly to one [MultiselectDropdown] in the rendered bar.
/// [keyDependencies] lists other [FilterField.key] values whose selection
/// hashes are folded into this field's [ValueKey] so that the dropdown
/// rebuilds when upstream filters change.
class FilterField {
  const FilterField({
    required this.key,
    required this.label,
    required this.selectedIds,
    required this.options,
    required this.onChanged,
    required this.displayValue,
    this.preferredWidth,
    this.keyDependencies = const [],
  });

  /// Unique identifier for this field (used in [ValueKey] generation).
  final String key;

  /// Human-readable label shown on the dropdown.
  final String label;

  /// Currently selected option IDs.
  final Set<String> selectedIds;

  /// Available options as `{id: displayLabel}`.
  final Map<String, String> options;

  /// Callback when selection changes.
  final ValueChanged<Set<String>> onChanged;

  /// Resolves an option ID to a display string for chips/summary.
  final String Function(String) displayValue;

  /// Optional width override. Falls back to the bar's default dropdown width.
  final double? preferredWidth;

  /// Keys of other [FilterField]s whose selection hashes should be included
  /// in this field's [ValueKey] to trigger rebuilds on upstream changes.
  final List<String> keyDependencies;
}
