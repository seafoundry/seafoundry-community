part of 'genetics_events_table.dart';

/// Filtering, sorting, and search controls for the genetics events table.
mixin _GeneticsEventFiltersMixin on State<GeneticsEventsTable> {
  List<_GeneticsEventRow> get _rows;

  List<_GeneticsEventRow> _filteredRows = const [];

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

  void _applyFilters({bool updateState = true}) {
    Iterable<_GeneticsEventRow> rows = _rows;

    if (_selectedEventType != null && _selectedEventType!.isNotEmpty) {
      rows = rows.where((row) => row.eventTypeId == _selectedEventType);
    }

    if (_selectedRecordType != null) {
      rows = rows.where((row) => row.recordModelType == _selectedRecordType);
    }

    if (_selectedDateRange != null) {
      final start = DateRangePresets.startOfDay(_selectedDateRange!.start);
      final end = DateRangePresets.endOfDay(_selectedDateRange!.end);
      rows = rows.where((row) {
        final createdAt = row.createdAt;
        if (createdAt == null) return false;
        return !createdAt.isBefore(start) && !createdAt.isAfter(end);
      });
    }

    if (_searchTerm.isNotEmpty) {
      final needle = _searchTerm.toLowerCase();
      rows = rows.where((row) {
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

    final sorted = rows
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
        _filteredRows = sorted;
      });
    } else {
      _filteredRows = sorted;
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedEventType = null;
      _selectedRecordType = null;
      _selectedDateRange = null;
      _searchTerm = '';
      _searchController.text = '';
      _applyFilters(updateState: false);
    });
  }
}
