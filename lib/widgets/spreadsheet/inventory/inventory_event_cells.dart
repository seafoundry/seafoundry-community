part of 'inventory_events_table.dart';

/// Resolves a human-readable label for an inventory event type id.
String _eventLabelFor(String eventTypeId) {
  return _inventoryEventLabels[eventTypeId] ??
      EventType.builtins[eventTypeId]?.name ??
      eventTypeId;
}

/// Builds the spreadsheet cell map for a single hydrated inventory event row.
SpreadsheetRow _buildInventoryEventRow(_InventoryEventRow row) {
  final dateStr = row.createdAt != null
      ? DateFormat.yMMMd().format(row.createdAt!)
      : '';
  return SpreadsheetRow(
    cells: {
      'timestamp': SpreadsheetCell.text(dateStr),
      'eventType': SpreadsheetCell.text(row.eventLabel),
      'record': SpreadsheetCell.text(row.recordDisplay),
      'genet': SpreadsheetCell.text(row.genetLocalId),
      'details': SpreadsheetCell.text(row.details),
      'site': SpreadsheetCell.text(row.siteName),
      'user': SpreadsheetCell.text(row.userName),
    },
  );
}

const List<SpreadsheetColumn> _inventoryEventColumns = [
  SpreadsheetColumn(
    key: 'timestamp',
    title: 'Date',
    width: 120,
    type: SpreadsheetColumnType.date,
  ),
  SpreadsheetColumn(
    key: 'eventType',
    title: 'Event Type',
    width: 150,
  ),
  SpreadsheetColumn(
    key: 'record',
    title: 'Record',
    width: 150,
  ),
  SpreadsheetColumn(
    key: 'genet',
    title: 'Genet',
    width: 130,
  ),
  SpreadsheetColumn(
    key: 'details',
    title: 'Details',
    width: 250,
  ),
  SpreadsheetColumn(
    key: 'site',
    title: 'Site',
    width: 130,
  ),
  SpreadsheetColumn(
    key: 'user',
    title: 'User',
    width: 140,
  ),
];

/// Filter toolbar widget rendering event-type, date-range and reset controls.
class _InventoryEventsToolbar extends StatelessWidget {
  const _InventoryEventsToolbar({
    required this.allRows,
    required this.selectedEventType,
    required this.selectedDateRange,
    required this.hasActiveFilters,
    required this.onEventTypeChanged,
    required this.onDateRangeChanged,
    required this.onClearDateRange,
    required this.onRefresh,
    required this.onReset,
  });

  final List<_InventoryEventRow> allRows;
  final String? selectedEventType;
  final DateTimeRange? selectedDateRange;
  final bool hasActiveFilters;
  final ValueChanged<String?> onEventTypeChanged;
  final ValueChanged<DateTimeRange> onDateRangeChanged;
  final VoidCallback onClearDateRange;
  final VoidCallback onRefresh;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final eventTypes = allRows.map((row) => row.eventTypeId).toSet().toList()
      ..sort((a, b) => _eventLabelFor(a).compareTo(_eventLabelFor(b)));

    final dateRangeLabel = selectedDateRange == null
        ? 'Date Range'
        : '${DateFormat.yMMMd().format(selectedDateRange!.start)} - '
            '${DateFormat.yMMMd().format(selectedDateRange!.end)}';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: selectedEventType,
            decoration: const InputDecoration(
              labelText: 'Event Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Event Types'),
              ),
              ...eventTypes.map(
                (eventTypeId) => DropdownMenuItem<String?>(
                  value: eventTypeId,
                  child: Text(_eventLabelFor(eventTypeId)),
                ),
              ),
            ],
            onChanged: onEventTypeChanged,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2015),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: selectedDateRange ??
                  DateTimeRange(
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now(),
                  ),
            );
            if (picked != null) {
              onDateRangeChanged(picked);
            }
          },
          icon: const Icon(Icons.date_range),
          label: Text(dateRangeLabel),
        ),
        if (selectedDateRange != null)
          TextButton.icon(
            onPressed: onClearDateRange,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Dates'),
          ),
        FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        if (hasActiveFilters)
          TextButton(
            onPressed: onReset,
            child: const Text('Reset Filters'),
          ),
      ],
    );
  }
}
