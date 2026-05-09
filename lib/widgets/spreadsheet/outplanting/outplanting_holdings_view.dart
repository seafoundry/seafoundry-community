// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/site_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/spreadsheet_scroll_view.dart';

/// Displays organism records currently held at outplanting sites in a PlutoGrid.
///
/// Data is loaded directly into local state (no separate cubit) since this is a
/// read-only summary view. Sites are filtered to those with an outplanting site
/// type, and organism records are filtered to those assigned to one of those
/// sites.
class OutplantingHoldingsView extends StatefulWidget {
  const OutplantingHoldingsView({super.key});

  @override
  State<OutplantingHoldingsView> createState() =>
      _OutplantingHoldingsViewState();
}

class _OutplantingHoldingsViewState extends State<OutplantingHoldingsView>
    with SafeProviderReadMixin {
  bool _isLoading = true;
  String? _error;

  List<OrganismRecord> _records = [];
  Map<String, Site> _sitesById = {};
  Map<String, Group> _groupsById = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final result = safeReadProviders(() => (
          context.read<SiteRepository>(),
          context.read<OrganismRecordRepository>(),
          context.read<GroupRepository>(),
        ));

    if (!result.success) {
      if (mounted) {
        setState(() {
          _error = result.errorMessage;
          _isLoading = false;
        });
      }
      return;
    }

    final (siteRepo, organismRepo, groupRepo) = result.value!;

    try {
      final sites = await siteRepo.getAll();
      final outplantingSites = sites
          .where((s) => SiteType.fromId(s.siteTypeId).isOutplanting)
          .toList();
      final outplantingSiteIds =
          outplantingSites.map((s) => s.id).toSet();

      final allRecords = await organismRepo.getAll();
      final outplantingRecords = allRecords
          .where((r) =>
              r.siteId != null && outplantingSiteIds.contains(r.siteId))
          .toList();

      final groups = await groupRepo.getAll();

      if (!mounted) return;

      setState(() {
        _records = outplantingRecords;
        _sitesById = {for (final s in outplantingSites) s.id: s};
        _groupsById = {for (final g in groups) g.id: g};
        _isLoading = false;
      });
    } catch (e, stack) {
      LoggingService.instance.error(
        'Failed to load outplanting holdings',
        {'error': e.toString()},
        stack,
      );
      if (mounted) {
        setState(() {
          _error = 'Failed to load outplanting data: $e';
          _isLoading = false;
        });
      }
    }
  }

  int get _totalQuantity => _records.fold<int>(
        0,
        (sum, r) => sum + (r.inventoryMetrics.count ?? 0),
      );

  List<PlutoColumn> _buildColumns() => [
        PlutoColumn(
          title: 'Record',
          field: 'tagId',
          type: PlutoColumnType.text(),
          width: 160,
        ),
        PlutoColumn(
          title: 'Genet',
          field: 'localGenetId',
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
          title: 'Site',
          field: 'siteName',
          type: PlutoColumnType.text(),
          width: 160,
        ),
        PlutoColumn(
          title: 'Zone',
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

  List<PlutoRow> _buildRows() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return _records.map((record) {
      final siteName = record.siteId != null
          ? _sitesById[record.siteId]?.name ?? ''
          : '';
      final structureName = record.groupId != null
          ? _groupsById[record.groupId]?.name ?? ''
          : '';
      final speciesName =
          SpeciesRegistry.globalById(record.speciesId)?.name ?? '';
      final createdAtFormatted = dateFormat.format(
        DateTime.parse(record.createdAt).toLocal(),
      );

      return PlutoRow(cells: {
        'tagId': PlutoCell(value: record.tagId),
        'localGenetId': PlutoCell(value: record.localGenetId ?? ''),
        'speciesName': PlutoCell(value: speciesName),
        'quantity': PlutoCell(value: record.inventoryMetrics.count ?? 0),
        'siteName': PlutoCell(value: siteName),
        'structureName': PlutoCell(value: structureName),
        'createdAt': PlutoCell(value: createdAtFormatted),
      });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No organisms at outplanting sites'),
        ),
      );
    }

    final columns = _buildColumns();
    final rows = _buildRows();

    return SpreadsheetScrollView(
      header: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${_records.length} organisms  |  $_totalQuantity total quantity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
      body: PlutoGrid(
        columns: columns,
        rows: rows,
        mode: PlutoGridMode.readOnly,
        configuration: const PlutoGridConfiguration(
          columnSize: PlutoGridColumnSizeConfig(
            autoSizeMode: PlutoAutoSizeMode.none,
          ),
        ),
      ),
    );
  }
}
