import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/events/create_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/genet_modification_event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/models/events/update_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/loan_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/date_range_utils.dart';
import 'package:seafoundry_app/utils/user_display_name.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/widgets/common/quick_date_range_chips.dart';
import '../../common/organism_reference_links.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/alias_badge.dart';
import 'package:seafoundry_app/widgets/spreadsheet/events_table_scaffold.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';

part 'genetics_event_rows.dart';
part 'genetics_event_labels.dart';
part 'genetics_event_descriptions.dart';
part 'genetics_event_row_factory.dart';
part 'genetics_event_hydration.dart';
part 'genetics_event_filters.dart';
part 'genetics_event_cells.dart';

/// Genetics-events history view.
///
/// Display chrome (load / error / empty / loaded) is owned by
/// [EventsTableScaffoldState]; this widget provides the genetics-specific
/// columns, toolbar, hydration, filter logic, and the "no-match" affordance.
class GeneticsEventsTable extends StatefulWidget {
  const GeneticsEventsTable({super.key, this.leadingHeader = const <Widget>[]});

  final List<Widget> leadingHeader;

  @override
  State<GeneticsEventsTable> createState() => _GeneticsEventsTableState();
}

class _GeneticsEventsTableState
    extends EventsTableScaffoldState<GeneticsEventsTable, _GeneticsEventRow>
    with _GeneticsEventHydrationMixin, _GeneticsEventFiltersMixin {
  @override
  final PaginationService<_GeneticsEventRow> paginationService =
      const PaginationService<_GeneticsEventRow>();

  @override
  String get title => 'Genetics Events';

  @override
  IconData get emptyIcon => Icons.event_note;

  @override
  String? get emptyMessage =>
      'Create corals, genets, or transfers and they will appear here.';

  @override
  List<SpreadsheetColumn> get columns => _geneticsEventColumns;

  @override
  SpreadsheetRow Function(_GeneticsEventRow row) get rowBuilder =>
      _buildGeneticsEventRow;

  @override
  List<Widget> get leadingHeader => widget.leadingHeader;

  @override
  String currentFilterKey() {
    return '${_selectedEventType ?? 'all'}-'
        '${_selectedRecordType?.name ?? 'all'}-'
        '${_selectedDateRange?.start}-${_selectedDateRange?.end}-'
        '$_searchTerm';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void _onRowsLoaded() {
    applyFilters(updateState: false);
  }

  @override
  Widget buildEmptyFilteredState(BuildContext context) {
    return _GeneticsEventsNoMatches(
      hasActiveFilters: _hasActiveFilters,
      onReset: _clearFilters,
    );
  }

  @override
  Widget buildToolbar(BuildContext context) {
    return _GeneticsEventsToolbar(
      allRows: rows,
      selectedEventType: _selectedEventType,
      selectedRecordType: _selectedRecordType,
      selectedDateRange: _selectedDateRange,
      searchController: _searchController,
      hasActiveFilters: _hasActiveFilters,
      onEventTypeChanged: (value) {
        setState(() {
          _selectedEventType = value;
          applyFilters(updateState: false);
        });
      },
      onRecordTypeChanged: (value) {
        setState(() {
          _selectedRecordType = value;
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
      onSearchChanged: (value) {
        setState(() {
          _searchTerm = value.trim();
          applyFilters(updateState: false);
        });
      },
      onRefresh: loadEvents,
      onReset: _clearFilters,
    );
  }
}
