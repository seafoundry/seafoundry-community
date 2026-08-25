part of 'genetics_events_table.dart';

/// Filtering, sorting, and search controls for the genetics events table.
///
/// Operates on the inherited [rows] and writes the result into
/// [filteredRows] — both owned by [EventsTableScaffoldState].
mixin _GeneticsEventFiltersMixin
    on EventsTableScaffoldState<GeneticsEventsTable, _GeneticsEventRow> {
  String? _selectedEventType;
  ModelType? _selectedRecordType;
  DateTimeRange? _selectedDateRange;
  String _searchTerm = '';

  late final TextEditingController _searchController =
      TextEditingController();

  bool get _hasActiveFilters =>
      _selectedEventType != null ||
      _selectedRecordType != null ||
      _selectedDateRange != null ||
      _searchTerm.isNotEmpty;

  @override
  void applyFilters({bool updateState = true}) {
    Iterable<_GeneticsEventRow> filtered = rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      filtered = filtered.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedRecordType != null) {
      filtered =
          filtered.where((row) => row.recordModelType == _selectedRecordType);
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

    if (_searchTerm.isNotEmpty) {
      final needle = _searchTerm.toLowerCase();
      filtered = filtered.where((row) {
        final fields = [
          row.recordDisplay,
          row.description,
          row.speciesName ?? '',
          row.provenanceTypeLabel ?? '',
          row.lifeStageLabel ?? '',
          row.userName ?? '',
          ...row.aliases.map((alias) => alias.label ?? alias.value),
          ...row.aliases.map((alias) => alias.sourceSystem),
        ];
        return fields.any((value) => value.toLowerCase().contains(needle));
      });
    }

    final sorted = filtered
        .sorted((a, b) {
          final aTime = a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final bTime = b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          return bTime.compareTo(aTime);
        })
        .toList(growable: false);

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
      _selectedRecordType = null;
      _selectedDateRange = null;
      _searchTerm = '';
      _searchController.text = '';
      applyFilters(updateState: false);
    });
  }
}
