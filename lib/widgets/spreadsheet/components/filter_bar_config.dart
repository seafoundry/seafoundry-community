// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/utils/spreadsheet_filter_utils.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/filter_field.dart';

/// Configuration for the [OrganismSelector] rendered by [SpreadsheetFilterBar].
class OrganismSelectorConfig {
  const OrganismSelectorConfig({
    required this.value,
    required this.onChanged,
    this.allowedKinds,
    this.preferredWidth,
  });

  final OrganismKind value;
  final ValueChanged<OrganismKind> onChanged;
  final List<OrganismKind>? allowedKinds;
  final double? preferredWidth;
}

/// Configuration for the date range controls in [SpreadsheetFilterBar].
class DateRangeConfig {
  const DateRangeConfig({
    required this.dateRangeLabel,
    required this.hasDateRange,
    required this.selectedDateRange,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onQuickRangeSelected,
    this.dateFilterEnabled = true,
    this.dateFilterTooltip,
    this.dateIcon = Icons.calendar_today,
    this.buttonPreferredWidth = 220,
    this.buttonMinWidth = 160,
  });

  final String dateRangeLabel;
  final bool hasDateRange;
  final DateTimeRange? selectedDateRange;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final ValueChanged<DateTimeRange> onQuickRangeSelected;
  final bool dateFilterEnabled;
  final String? dateFilterTooltip;
  final IconData dateIcon;
  final double buttonPreferredWidth;
  final double buttonMinWidth;
}

/// Builds a [FilterField] from the [MapEntry] format used by inventory,
/// observations, and husbandry filter bars.
///
/// This is a convenience factory that pairs with [SpreadsheetFilterUtils]
/// to avoid duplicating the entry -> dropdown item conversion across bars.
FilterField buildEntryFilterField({
  required String key,
  required String label,
  required List<MapEntry<String?, String?>> options,
  required Set<String> selectedIds,
  required ValueChanged<Set<String>> onChanged,
  required Map<String, String> lookup,
  double? preferredWidth,
  List<String> keyDependencies = const [],
  Map<String, String>? customLabels,
}) {
  return FilterField(
    key: key,
    label: label,
    selectedIds: selectedIds,
    options: {
      for (final entry in options)
        if (entry.key != null)
          entry.key!: customLabels?[entry.key] ??
              SpreadsheetFilterUtils.entryLabel(entry),
    },
    onChanged: onChanged,
    displayValue: (id) => customLabels?[id] ?? lookup[id] ?? id,
    preferredWidth: preferredWidth,
    keyDependencies: keyDependencies,
  );
}
