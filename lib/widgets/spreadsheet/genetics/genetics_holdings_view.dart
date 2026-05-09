import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genetics_spreadsheet/genetics_spreadsheet_cubit.dart';
import 'package:seafoundry_app/services/pagination_service.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/spreadsheet_state_views.dart';
import 'package:seafoundry_app/widgets/spreadsheet/components/toolbar_dropdown.dart';
import 'package:seafoundry_app/widgets/spreadsheet/genetics/genetics_summary_cards.dart';
import 'package:seafoundry_app/widgets/spreadsheet/genetics_columns.dart';
import 'package:seafoundry_app/services/spreadsheet/genetics_spreadsheet_helper.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_base.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';

/// Displays genetics holdings data in a spreadsheet layout.
///
/// Integrates with [GeneticsSpreadsheetCubit] for state management and uses
/// [GeneticsSpreadsheetHelper] for column building and row rendering.
/// Designed to be placed inside a tab view and retains its state across
/// tab switches via [AutomaticKeepAliveClientMixin].
class GeneticsHoldingsView extends StatefulWidget {
  const GeneticsHoldingsView({super.key});

  @override
  State<GeneticsHoldingsView> createState() => _GeneticsHoldingsViewState();
}

class _GeneticsHoldingsViewState extends State<GeneticsHoldingsView> {
  final PaginationService<Map<String, dynamic>> _paginationService =
      const PaginationService<Map<String, dynamic>>();

  static final List<GeneticsColumnDefinition> _columns = [
    GeneticsColumnDefinition(
      key: 'genetName',
      title: 'Genet',
      width: 160,
      valueBuilder: (row) => row['genetName']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'speciesName',
      title: 'Species',
      width: 180,
      valueBuilder: (row) => row['speciesName']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'provenanceTypeLabel',
      title: 'Provenance',
      width: 140,
      valueBuilder: (row) => row['provenanceTypeLabel']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'totalQuantity',
      title: 'Quantity',
      width: 100,
      valueBuilder: (row) => row['totalQuantity']?.toString() ?? '0',
    ),
    GeneticsColumnDefinition(
      key: 'numNurseries',
      title: 'Sites',
      width: 80,
      valueBuilder: (row) => row['numNurseries']?.toString() ?? '0',
    ),
    GeneticsColumnDefinition(
      key: 'physicalForm',
      title: 'Form',
      width: 100,
      valueBuilder: (row) => row['physicalForm']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'createdAtDisplay',
      title: 'Created',
      width: 120,
      valueBuilder: (row) => row['createdAtDisplay']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'clonalIdDisplay',
      title: 'Clonal ID',
      width: 120,
      valueBuilder: (row) => row['clonalIdDisplay']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'accessionNumber',
      title: 'Accession #',
      width: 130,
      valueBuilder: (row) => row['accessionNumber']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'provenanceId',
      title: 'PID',
      width: 150,
      valueBuilder: (row) => row['provenanceId']?.toString() ?? '',
    ),
    GeneticsColumnDefinition(
      key: 'aliases',
      title: 'Aliases',
      width: 180,
      valueBuilder: (row) => row['aliases']?.toString() ?? '',
    ),
  ];

  @override
  void initState() {
    super.initState();
    context.read<GeneticsSpreadsheetCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GeneticsSpreadsheetCubit, GeneticsSpreadsheetState>(
      builder: (context, state) {
        if (state.isInitializing) {
          return const SpreadsheetLoadingView(
            status: 'Loading genetics data...',
          );
        }

        if (state.errorMessage != null) {
          return SpreadsheetErrorView(
            message: state.errorMessage!,
            onRetry: () =>
                context.read<GeneticsSpreadsheetCubit>().refresh(forceRemote: true),
          );
        }

        if (state.filteredRows.isEmpty && !state.isRefreshing) {
          return _buildEmptyState(context);
        }

        return _buildContent(context, state);
      },
    );
  }

  Widget _buildContent(BuildContext context, GeneticsSpreadsheetState state) {
    final stats = GeneticsSpreadsheetHelper.summarizeCounts(state.filteredRows);
    final typeCounts =
        GeneticsSpreadsheetHelper.countByField(state.filteredRows, 'provenanceType');
    final spreadsheetColumns = GeneticsSpreadsheetHelper.buildColumns(_columns);

    final headerWidgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: GeneticsSummaryCards(
          hasRows: state.filteredRows.isNotEmpty,
          stats: stats,
          typeCounts: typeCounts,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: _buildFilterRow(context, state),
      ),
    ];

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SpreadsheetBase<Map<String, dynamic>>(
        key: ValueKey('genetics_holdings_${state.reloadToken}'),
        columns: spreadsheetColumns,
        rowBuilder: (row) => GeneticsSpreadsheetHelper.buildRow(
          context,
          row,
          _columns,
        ),
        pageLoader: _paginationService.buildListLoader(
          () => state.filteredRows,
        ),
        sortField: 'genetName',
        descending: false,
        reloadToken: state.reloadToken,
        header: Text(
          'Genetics Holdings  ${state.filteredRows.length} genets',
        ),
      ),
    );

    return SpreadsheetScrollView(header: headerWidgets, body: body);
  }

  Widget _buildFilterRow(BuildContext context, GeneticsSpreadsheetState state) {
    final cubit = context.read<GeneticsSpreadsheetCubit>();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ToolbarDropdown(
          width: 180,
          label: 'Site',
          value: state.siteFilter,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Sites'),
            ),
            ...state.availableSites.map(
              (site) => DropdownMenuItem<String?>(
                value: site,
                child: Text(site, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: cubit.updateSite,
        ),
        ToolbarDropdown(
          width: 200,
          label: 'Species',
          value: state.speciesFilter,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Species'),
            ),
            ...state.availableSpecies.map(
              (speciesId) => DropdownMenuItem<String?>(
                value: speciesId,
                child: Text(
                  cubit.speciesLabel(speciesId),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: cubit.updateSpecies,
        ),
        ToolbarDropdown(
          width: 180,
          label: 'Provenance Type',
          value: state.provenanceTypeFilter,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Types'),
            ),
            ...state.availableProvenanceTypes.map(
              (type) => DropdownMenuItem<String?>(
                value: type,
                child: Text(type, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: cubit.updateProvenanceType,
        ),
        if (state.siteFilter != null ||
            state.speciesFilter != null ||
            state.provenanceTypeFilter != null)
          TextButton.icon(
            onPressed: () {
              cubit.updateSite(null);
              cubit.updateSpecies(null);
              cubit.updateProvenanceType(null);
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
          ),
        if (state.isRefreshing)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.biotech, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No genetics holdings found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create genets and organism records to populate this view.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context
                  .read<GeneticsSpreadsheetCubit>()
                  .refresh(forceRemote: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
