part of 'inventory_events_table.dart';

/// Filtering, sorting, and search controls for the inventory events table.
mixin _InventoryEventFiltersMixin on State<InventoryEventsTable> {
  List<_InventoryEventRow> get _rows;

  List<_InventoryEventRow> _filteredRows = const [];

  String? _selectedEventType;
  DateTimeRange? _selectedDateRange;

  bool get _hasActiveFilters =>
      _selectedEventType != null || _selectedDateRange != null;

  void _applyFilters({bool updateState = true}) {
    Iterable<_InventoryEventRow> rows = _rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      rows = rows.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end
          .add(const Duration(hours: 23, minutes: 59, seconds: 59));
      rows = rows.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(start) && !createdAt.isAfter(end);
      });
    }

    final sorted = rows.toList()
      ..sort((a, b) {
        final aTime =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        final bTime =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        return bTime.compareTo(aTime);
      });

    if (updateState) {
      setState(() {
        _filteredRows = sorted;
      });
    } else {
      _filteredRows = sorted;
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedEventType = null;
      _selectedDateRange = null;
      _applyFilters(updateState: false);
    });
  }
}
