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
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/widgets/common/quick_date_range_chips.dart';
import 'package:seafoundry_app/widgets/spreadsheet/events_table_scaffold.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';

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
/// Display chrome (load / error / empty / loaded) is owned by
/// [EventsTableScaffoldState]; this widget only provides the inventory-
/// specific columns, toolbar, hydration and filter logic.
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

class _InventoryEventsTableState
    extends EventsTableScaffoldState<InventoryEventsTable, _InventoryEventRow>
    with _InventoryEventHydrationMixin, _InventoryEventFiltersMixin {
  @override
  final PaginationService<_InventoryEventRow> paginationService =
      const PaginationService<_InventoryEventRow>();

  @override
  Set<String> get _eventTypeFilter => widget.outplantingOnly
      ? _outplantingEventTypes
      : _defaultInventoryEventTypes;

  @override
  String get title =>
      widget.outplantingOnly ? 'Outplanting Events' : 'Inventory Events';

  @override
  IconData get emptyIcon =>
      widget.outplantingOnly ? Icons.nature : Icons.event_note;

  @override
  String? get emptyMessage => widget.outplantingOnly
      ? 'Record an outplant event from the Outplanting tab to see it here.'
      : 'Create or edit an organism record and the change history will '
          'appear here.';

  @override
  List<SpreadsheetColumn> get columns => _inventoryEventColumns;

  @override
  SpreadsheetRow Function(_InventoryEventRow row) get rowBuilder =>
      _buildInventoryEventRow;

  @override
  String currentFilterKey() {
    return '${_selectedEventType ?? 'all'}-'
        '${_selectedDateRange?.start}-${_selectedDateRange?.end}';
  }

  @override
  void _onRowsLoaded() {
    applyFilters(updateState: false);
  }

  @override
  bool get hasActiveFilters => _hasActiveFilters;

  @override
  void resetFilters() => _clearFilters();

  @override
  Widget buildToolbar(BuildContext context) {
    return _InventoryEventsToolbar(
      allRows: rows,
      selectedEventType: _selectedEventType,
      selectedDateRange: _selectedDateRange,
      hasActiveFilters: _hasActiveFilters,
      onEventTypeChanged: (value) {
        setState(() {
          _selectedEventType = value;
          applyFilters(updateState: false);
        });
      },
      onDateRangeChanged: (range) {
        setState(() {
          _selectedDateRange = range;
          applyFilters(updateState: false);
        });
      },
      onClearDateRange: () {
        setState(() {
          _selectedDateRange = null;
          applyFilters(updateState: false);
        });
      },
      onRefresh: loadEvents,
      onReset: _clearFilters,
    );
  }
}
