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
import 'package:seafoundry_app/widgets/spreadsheet/components/responsive_filter_section.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_models.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

part 'genetics_event_rows.dart';
part 'genetics_event_labels.dart';
part 'genetics_event_descriptions.dart';
part 'genetics_event_row_factory.dart';
part 'genetics_event_hydration.dart';
part 'genetics_event_filters.dart';
part 'genetics_event_cells.dart';

class GeneticsEventsTable extends StatefulWidget {
  const GeneticsEventsTable({super.key, this.leadingHeader = const <Widget>[]});

  final List<Widget> leadingHeader;

  @override
  State<GeneticsEventsTable> createState() => _GeneticsEventsTableState();
}

class _GeneticsEventsTableState extends State<GeneticsEventsTable>
    with
        SafeProviderReadMixin<GeneticsEventsTable>,
        _GeneticsEventHydrationMixin,
        _GeneticsEventFiltersMixin {
  final PaginationService<_GeneticsEventRow> _paginationService =
      const PaginationService<_GeneticsEventRow>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      return _GeneticsEventsLoading(
        status: _loadingStatus,
        progress: _loadingProgress,
      );
    }

    if (_error != null) {
      return _GeneticsEventsError(error: _error!, onRetry: _loadEvents);
    }

    if (_rows.isEmpty) {
      return const _GeneticsEventsNoData();
    }

    final headerWidgets = <Widget>[
      ...widget.leadingHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveFilterSection(
              label: 'Filters',
              initiallyExpanded: false,
              child: _GeneticsEventsToolbar(
                allRows: _rows,
                selectedEventType: _selectedEventType,
                selectedRecordType: _selectedRecordType,
                selectedDateRange: _selectedDateRange,
                searchController: _searchController,
                hasActiveFilters: _hasActiveFilters,
                onEventTypeChanged: (value) {
                  setState(() {
                    _selectedEventType = value;
                    _applyFilters(updateState: false);
                  });
                },
                onRecordTypeChanged: (value) {
                  setState(() {
                    _selectedRecordType = value;
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
                onSearchChanged: (value) {
                  setState(() {
                    _searchTerm = value.trim();
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
          ? _GeneticsEventsNoMatches(
              hasActiveFilters: _hasActiveFilters,
              onReset: _clearFilters,
            )
          : SpreadsheetBase<_GeneticsEventRow>(
              key: ValueKey(
                '${_selectedEventType ?? 'all'}-${_selectedRecordType?.name ?? 'all'}-${_selectedDateRange?.start}-${_selectedDateRange?.end}-$_searchTerm',
              ),
              columns: _geneticsEventColumns,
              rowBuilder: _buildGeneticsEventRow,
              pageLoader: _paginationService.buildListLoader(
                () => _filteredRows,
              ),
              sortField: 'timestamp',
              descending: true,
              header: Text('Genetics Events • ${_filteredRows.length} records'),
            ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }
}
