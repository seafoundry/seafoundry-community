part of 'inventory_events_table.dart';

/// Filtering, sorting, and search controls for the inventory events table.
///
/// Operates on the inherited [rows] and writes the result into
/// [filteredRows] — both owned by [EventsTableScaffoldState].
mixin _InventoryEventFiltersMixin
    on EventsTableScaffoldState<InventoryEventsTable, _InventoryEventRow> {
  String? _selectedEventType;
  DateTimeRange? _selectedDateRange;

  bool get _hasActiveFilters =>
      _selectedEventType != null || _selectedDateRange != null;

  @override
  void applyFilters({bool updateState = true}) {
    Iterable<_InventoryEventRow> filtered = rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      filtered = filtered.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedDateRange != null) {
      final start = DateRangePresets.startOfDay(_selectedDateRange!.start);
      final end = DateRangePresets.endOfDay(_selectedDateRange!.end);
      filtered = filtered.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(start) && !createdAt.isAfter(end);
      });
    }

    final sorted = filtered.toList()
      ..sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bTime.compareTo(aTime);
      });

    if (updateState) {
      setState(() {
        filteredRows = sorted;
      });
    } else {
      filteredRows = sorted;
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedEventType = null;
      _selectedDateRange = null;
      applyFilters(updateState: false);
    });
  }
}
