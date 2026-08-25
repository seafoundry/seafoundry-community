import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:seafoundry_community/cubits/inventory_spreadsheet/inventory_spreadsheet_cubit.dart';
import 'package:seafoundry_community/widgets/spreadsheet/components/toolbar_dropdown.dart';

/// Displays current inventory organism records in a PlutoGrid spreadsheet.
///
/// Uses [InventorySpreadsheetCubit] to load and filter data. Provides
/// site and species filter dropdowns, summary counts, and a read-only
/// PlutoGrid table.
class InventoryHoldingsView extends StatefulWidget {
  const InventoryHoldingsView({super.key});

  @override
  State<InventoryHoldingsView> createState() => _InventoryHoldingsViewState();
}

class _InventoryHoldingsViewState extends State<InventoryHoldingsView> {
  @override
  void initState() {
    super.initState();
    context.read<InventorySpreadsheetCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventorySpreadsheetCubit, InventorySpreadsheetState>(
      builder: (context, state) {
        if (state.isInitializing) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () =>
                      context.read<InventorySpreadsheetCubit>().refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state.allRows.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No inventory records found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryRow(context, state),
            _buildFilterRow(context, state),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: state.filteredRows.isEmpty
                    ? const Center(
                        child: Text(
                          'No records match the current filters.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : PlutoGrid(
                        key: ValueKey(state.reloadToken),
                        mode: PlutoGridMode.readOnly,
                        columns: _buildPlutoColumns(),
                        rows: _buildPlutoRows(state.filteredRows),
                        configuration: const PlutoGridConfiguration(
                          columnSize: PlutoGridColumnSizeConfig(
                            autoSizeMode: PlutoAutoSizeMode.scale,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, InventorySpreadsheetState state) {
    final totalOrganisms = state.filteredRows.length;
    final totalQuantity = state.filteredRows.fold<int>(0, (sum, row) {
      final qty = row['quantity'];
      if (qty is int) return sum + qty;
      if (qty is num) return sum + qty.toInt();
      return sum;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Text(
            'Inventory Holdings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 16),
          Chip(
            label: Text('$totalOrganisms records'),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text('$totalQuantity total qty'),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          if (state.isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
      BuildContext context, InventorySpreadsheetState state) {
    final cubit = context.read<InventorySpreadsheetCubit>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ToolbarDropdown(
            width: 200,
            label: 'Site',
            value: state.siteFilter,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Sites'),
              ),
              ...state.availableSites.map(
                (siteId) => DropdownMenuItem<String?>(
                  value: siteId,
                  child: Text(cubit.siteLabel(siteId)),
                ),
              ),
            ],
            onChanged: cubit.updateSiteFilter,
          ),
          ToolbarDropdown(
            width: 220,
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
                  child: Text(cubit.speciesLabel(speciesId)),
                ),
              ),
            ],
            onChanged: cubit.updateSpeciesFilter,
          ),
          if (state.siteFilter != null || state.speciesFilter != null)
            TextButton(
              onPressed: () {
                cubit.updateSiteFilter(null);
                cubit.updateSpeciesFilter(null);
              },
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  List<PlutoColumn> _buildPlutoColumns() {
    return [
      PlutoColumn(
        title: 'Local ID',
        field: 'localGenetId',
        type: PlutoColumnType.text(),
        width: 130,
      ),
      PlutoColumn(
        title: 'Record Name',
        field: 'tagId',
        type: PlutoColumnType.text(),
        width: 140,
      ),
      PlutoColumn(
        title: 'Species',
        field: 'speciesName',
        type: PlutoColumnType.text(),
        width: 180,
      ),
      PlutoColumn(
        title: 'Quantity',
        field: 'quantity',
        type: PlutoColumnType.number(),
        width: 100,
      ),
      PlutoColumn(
        title: 'Life Stage',
        field: 'lifeStage',
        type: PlutoColumnType.text(),
        width: 120,
      ),
      PlutoColumn(
        title: 'Form',
        field: 'physicalForm',
        type: PlutoColumnType.text(),
        width: 110,
      ),
      PlutoColumn(
        title: 'Site',
        field: 'siteName',
        type: PlutoColumnType.text(),
        width: 140,
      ),
      PlutoColumn(
        title: 'Structure',
        field: 'structureName',
        type: PlutoColumnType.text(),
        width: 140,
      ),
      PlutoColumn(
        title: 'Created',
        field: 'createdAt',
        type: PlutoColumnType.text(),
        width: 120,
      ),
    ];
  }

  List<PlutoRow> _buildPlutoRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) {
      return PlutoRow(
        cells: {
          'localGenetId': PlutoCell(value: row['localGenetId'] ?? ''),
          'tagId': PlutoCell(value: row['tagId'] ?? ''),
          'speciesName': PlutoCell(value: row['speciesName'] ?? ''),
          'quantity': PlutoCell(value: row['quantity'] ?? 0),
          'lifeStage': PlutoCell(value: row['lifeStage'] ?? ''),
          'physicalForm': PlutoCell(value: row['physicalForm'] ?? ''),
          'siteName': PlutoCell(value: row['siteName'] ?? ''),
          'structureName': PlutoCell(value: row['structureName'] ?? ''),
          'createdAt': PlutoCell(value: _formatDate(row['createdAt'])),
        },
      );
    }).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      final month = value.month.toString().padLeft(2, '0');
      final day = value.day.toString().padLeft(2, '0');
      return '${value.year}-$month-$day';
    }
    if (value is String && value.isNotEmpty) {
      try {
        final dt = DateTime.parse(value);
        final month = dt.month.toString().padLeft(2, '0');
        final day = dt.day.toString().padLeft(2, '0');
        return '${dt.year}-$month-$day';
      } catch (_) {
        return value;
      }
    }
    return value.toString();
  }
}
