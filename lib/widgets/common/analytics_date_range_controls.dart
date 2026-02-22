// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/widgets/common/quick_date_range_chips.dart';

class AnalyticsDateRangeControls extends StatelessWidget {
  const AnalyticsDateRangeControls({
    super.key,
    required this.selectedRange,
    required this.onRangeSelected,
    this.onClearRange,
    this.label = 'Time Range',
    this.emptyLabel = 'All time',
    this.firstDate,
    this.lastDate,
  });

  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange> onRangeSelected;
  final VoidCallback? onClearRange;
  final String label;
  final String emptyLabel;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.date_range,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        QuickDateRangeChips(
          selectedRange: selectedRange,
          onRangeSelected: onRangeSelected,
        ),
        OutlinedButton.icon(
          onPressed: () => _pickRange(context, now),
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            DateRangePresets.labelForRange(
              selectedRange,
              emptyLabel: emptyLabel,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onClearRange != null && selectedRange != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Clear date filter',
            onPressed: onClearRange,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context, DateTime now) async {
    final initialRange =
        selectedRange ??
        DateRangePresets.rangeForPreset(
          DateRangePresets.quickFilters[1],
          now: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? now,
      initialDateRange: initialRange,
    );
    if (picked != null) {
      onRangeSelected(picked);
    }
  }
}
