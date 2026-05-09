import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/responsive_filter_section.dart';

part 'inventory_event_rows.dart';
part 'inventory_event_hydration.dart';
part 'inventory_event_filters.dart';
part 'inventory_event_cells.dart';

/// A parameterized events table that works for both inventory and outplanting events.
///
/// When [outplantingOnly] is true, the table filters to show only
/// outplanting-related event types. Otherwise it shows the default set
/// of inventory event types.
///
/// Uses [EventRepository] to fetch events and [PaginationService] for
/// client-side pagination via [SpreadsheetBase].
class InventoryEventsTable extends StatefulWidget {
  const InventoryEventsTable({
    super.key,
    this.outplantingOnly = false,
  });

  /// When true, filters events to show only outplanting-related types.
  final bool outplantingOnly;

  @override
  State<InventoryEventsTable> createState() => _InventoryEventsTableState();
}

class _InventoryEventsTableState extends State<InventoryEventsTable>
    with
        SafeProviderReadMixin<InventoryEventsTable>,
        _InventoryEventHydrationMixin,
        _InventoryEventFiltersMixin {
  final PaginationService<_InventoryEventRow> _paginationService =
      const PaginationService<_InventoryEventRow>();

  @override
  Set<String> get _eventTypeFilter => widget.outplantingOnly
      ? _outplantingEventTypes
      : _defaultInventoryEventTypes;

  @override
  String get _title =>
      widget.outplantingOnly ? 'Outplanting Events' : 'Inventory Events';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvents());
  }

  @override
  void _onRowsLoaded() {
    _applyFilters(updateState: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _InventoryEventsLoading(
        status: _loadingStatus,
        progress: _loadingProgress,
      );
    }

    if (_error != null) {
      return _InventoryEventsError(
        error: _error!,
        onRetry: _loadEvents,
      );
    }

    if (_rows.isEmpty) {
      return _InventoryEventsEmpty(
        title: _title,
        icon: widget.outplantingOnly ? Icons.nature : Icons.event_note,
      );
    }

    final headerWidgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveFilterSection(
              label: 'Filters',
              initiallyExpanded: false,
              child: _InventoryEventsToolbar(
                allRows: _rows,
                selectedEventType: _selectedEventType,
                selectedDateRange: _selectedDateRange,
                hasActiveFilters: _hasActiveFilters,
                onEventTypeChanged: (value) {
                  setState(() {
                    _selectedEventType = value;
                    _applyFilters(updateState: false);
                  });
                },
                onDateRangeChanged: (range) {
                  setState(() {
                    _selectedDateRange = range;
                    _applyFilters(updateState: false);
                  });
                },
                onClearDateRange: () {
                  setState(() {
                    _selectedDateRange = null;
                    _applyFilters(updateState: false);
                  });
                },
                onRefresh: _loadEvents,
                onReset: _clearFilters,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ];

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: _filteredRows.isEmpty
          ? const Center(
              child: Text(
                'No events match the current filters.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : SpreadsheetBase<_InventoryEventRow>(
              key: ValueKey(
                '${_selectedEventType ?? 'all'}-${_selectedDateRange?.start}-${_selectedDateRange?.end}',
              ),
              columns: _inventoryEventColumns,
              rowBuilder: _buildInventoryEventRow,
              pageLoader: _paginationService.buildListLoader(
                () => _filteredRows,
              ),
              sortField: 'timestamp',
              descending: true,
              header: Text('$_title - ${_filteredRows.length} records'),
            ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }
}
