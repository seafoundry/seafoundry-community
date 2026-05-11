part of 'genetics_events_table.dart';

/// Builds the spreadsheet cell map for a hydrated genetics event row.
SpreadsheetRow _buildGeneticsEventRow(_GeneticsEventRow row) {
  final timestamp = row.createdAt != null
      ? DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!.toLocal())
      : '';
  final recordTypeLabel = _recordTypeLabel(row.recordModelType);
  final eventCell = recordTypeLabel.isEmpty
      ? row.eventLabel
      : '${row.eventLabel} • $recordTypeLabel';
  final aliasCell = SpreadsheetCell(
    child: SpreadsheetAliasBadges(aliases: row.aliases),
  );

  return SpreadsheetRow(
    raw: row.toJson(),
    key: ValueKey(row.eventId),
    cells: {
      'timestamp': SpreadsheetCell.text(timestamp),
      'event': SpreadsheetCell.text(eventCell),
      'record': SpreadsheetCell(
        child: row.recordLink ??
            Text(
              row.recordDisplay,
              overflow: TextOverflow.ellipsis,
            ),
      ),
      'details': SpreadsheetCell.text(row.description),
      'aliases': aliasCell,
      'species': SpreadsheetCell.text(row.speciesName ?? ''),
      'provenanceType':
          SpreadsheetCell.text(row.provenanceTypeLabel ?? ''),
      'lifeStage': SpreadsheetCell.text(row.lifeStageLabel ?? ''),
      'user': SpreadsheetCell.text(row.userName ?? ''),
    },
  );
}

class _GeneticsEventsToolbar extends StatelessWidget {
  const _GeneticsEventsToolbar({
    required this.allRows,
    required this.selectedEventType,
    required this.selectedRecordType,
    required this.selectedDateRange,
    required this.searchController,
    required this.hasActiveFilters,
    required this.onEventTypeChanged,
    required this.onRecordTypeChanged,
    required this.onDateRangeChanged,
    required this.onClearDateRange,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onReset,
  });

  final List<_GeneticsEventRow> allRows;
  final String? selectedEventType;
  final ModelType? selectedRecordType;
  final DateTimeRange? selectedDateRange;
  final TextEditingController searchController;
  final bool hasActiveFilters;
  final ValueChanged<String?> onEventTypeChanged;
  final ValueChanged<ModelType?> onRecordTypeChanged;
  final ValueChanged<DateTimeRange> onDateRangeChanged;
  final VoidCallback onClearDateRange;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final eventTypes = allRows.map((row) => row.eventTypeId).toSet().toList()
      ..sort((a, b) => _eventLabelFor(a).compareTo(_eventLabelFor(b)));

    final recordTypes = allRows.map((row) => row.recordModelType).toSet().toList()
      ..sort((a, b) => _recordTypeLabel(a).compareTo(_recordTypeLabel(b)));

    final dateRangeLabel = selectedDateRange == null
        ? 'Date Range'
        : '${DateFormat.yMMMd().format(selectedDateRange!.start)} – '
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
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<ModelType?>(
            initialValue: selectedRecordType,
            decoration: const InputDecoration(
              labelText: 'Record Type',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<ModelType?>(
                value: null,
                child: Text('All Record Types'),
              ),
              ...recordTypes.map(
                (recordType) => DropdownMenuItem<ModelType?>(
                  value: recordType,
                  child: Text(_recordTypeLabel(recordType)),
                ),
              ),
            ],
            onChanged: onRecordTypeChanged,
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
        QuickDateRangeChips(
          selectedRange: selectedDateRange,
          onRangeSelected: onDateRangeChanged,
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon: Icon(Icons.search, size: 18),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
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
