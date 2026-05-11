import 'package:flutter/material.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';

class QuickDateRangeChips extends StatelessWidget {
  const QuickDateRangeChips({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
    this.spacing = 6,
    this.runSpacing = 6,
    this.compact = true,
  });

  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange> onRangeSelected;
  final double spacing;
  final double runSpacing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: DateRangePresets.quickFilters.map((preset) {
        final range = DateRangePresets.rangeForPreset(preset, now: now);
        final isSelected = DateRangePresets.matchesPreset(
          selectedRange,
          preset,
          now: now,
        );
        return FilterChip(
          label: Text(preset.label),
          selected: isSelected,
          onSelected: (_) => onRangeSelected(range),
          showCheckmark: false,
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          selectedColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}
