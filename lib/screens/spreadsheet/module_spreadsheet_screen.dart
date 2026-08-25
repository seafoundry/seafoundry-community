import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_community/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_community/cubits/genetics_spreadsheet/genetics_spreadsheet_cubit.dart';
import 'package:seafoundry_community/cubits/inventory_spreadsheet/inventory_spreadsheet_cubit.dart';
import 'package:seafoundry_community/models/organization.dart';
import 'package:seafoundry_community/repositories/graph_repository.dart';
import 'package:seafoundry_community/repositories/inventory/event_repository.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_community/repositories/inventory/site_repository.dart';
import 'package:seafoundry_community/services/csv_import_service.dart';
import 'package:seafoundry_community/services/export/export_service.dart';
import 'package:seafoundry_community/widgets/dialogs/csv_import_dialog.dart';
import 'package:seafoundry_community/widgets/spreadsheet/genetics/genetics_events_table.dart';
import 'package:seafoundry_community/widgets/spreadsheet/genetics/genetics_holdings_view.dart';
import 'package:seafoundry_community/widgets/spreadsheet/inventory/inventory_events_table.dart';
import 'package:seafoundry_community/widgets/spreadsheet/inventory/inventory_holdings_view.dart';
import 'package:seafoundry_community/widgets/spreadsheet/outplanting/outplanting_holdings_view.dart';

/// Enum representing the supported spreadsheet modules.
enum SpreadsheetModule {
  genetics,
  inventory,
  outplanting;

  String get label {
    switch (this) {
      case SpreadsheetModule.genetics:
        return 'Genetics';
      case SpreadsheetModule.inventory:
        return 'Inventory';
      case SpreadsheetModule.outplanting:
        return 'Outplanting';
    }
  }

  IconData get icon {
    switch (this) {
      case SpreadsheetModule.genetics:
        return Icons.biotech;
      case SpreadsheetModule.inventory:
        return Icons.inventory_2;
      case SpreadsheetModule.outplanting:
        return Icons.nature;
    }
  }
}

/// A parameterized two-tab spreadsheet screen (Holdings + Events) that works
/// for genetics, inventory, and outplanting modules.
///
/// Provider dependencies are captured from the drawer context and passed
/// through the constructor, then re-provided to the widget tree so child
/// views can access them via `context.read<T>()`.
class ModuleSpreadsheetScreen extends StatelessWidget {
  const ModuleSpreadsheetScreen({
    super.key,
    required this.module,
    required this.organismRecordRepository,
    required this.organization,
    required this.currentUser,
    this.provenanceRepository,
    this.genetRepository,
    this.groupRepository,
    this.siteRepository,
    this.eventRepository,
    this.graphRepository,
    this.csvImportService,
  });

  final SpreadsheetModule module;
  final OrganismRecordRepository organismRecordRepository;
  final Organization organization;
  final CurrentUser currentUser;
  final ProvenanceRepository? provenanceRepository;
  final GenetRepository? genetRepository;
  final GroupRepository? groupRepository;
  final SiteRepository? siteRepository;
  final EventRepository? eventRepository;
  final GraphRepository? graphRepository;
  final CSVImportService? csvImportService;

  @override
  Widget build(BuildContext context) {
    // Provide all captured repositories to the widget tree so child views
    // can access them via context.read<T>().
    final providers = <SingleChildWidget>[
      RepositoryProvider<OrganismRecordRepository>.value(
        value: organismRecordRepository,
      ),
      Provider<Organization>.value(value: organization),
      BlocProvider<CurrentUser>.value(value: currentUser),
      if (provenanceRepository != null)
        RepositoryProvider<ProvenanceRepository>.value(
          value: provenanceRepository!,
        ),
      if (genetRepository != null)
        RepositoryProvider<GenetRepository>.value(value: genetRepository!),
      if (groupRepository != null)
        RepositoryProvider<GroupRepository>.value(value: groupRepository!),
      if (siteRepository != null)
        RepositoryProvider<SiteRepository>.value(value: siteRepository!),
      if (eventRepository != null)
        RepositoryProvider<EventRepository>.value(value: eventRepository!),
      if (graphRepository != null)
        RepositoryProvider<GraphRepository>.value(value: graphRepository!),
      if (csvImportService != null)
        RepositoryProvider<CSVImportService>.value(value: csvImportService!),
    ];

    Widget body = DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, size: 20),
              const SizedBox(width: 8),
              Text(module.label),
            ],
          ),
          actions: _buildAppBarActions(context),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Holdings'),
              Tab(text: 'Events'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _KeepAliveTab(child: _buildHoldingsView()),
            _KeepAliveTab(child: _buildEventsView()),
          ],
        ),
      ),
    );

    // Wrap with module-specific cubits.
    if (module == SpreadsheetModule.genetics &&
        provenanceRepository != null) {
      body = BlocProvider<GeneticsSpreadsheetCubit>(
        create: (_) => GeneticsSpreadsheetCubit(
          provenanceRepository: provenanceRepository!,
          organismRepository: organismRecordRepository,
          currentUser: currentUser,
        ),
        child: body,
      );
    } else if (module == SpreadsheetModule.inventory &&
        groupRepository != null &&
        siteRepository != null) {
      body = BlocProvider<InventorySpreadsheetCubit>(
        create: (_) => InventorySpreadsheetCubit(
          organismRecordRepository: organismRecordRepository,
          groupRepository: groupRepository!,
          siteRepository: siteRepository!,
          organization: organization,
        ),
        child: body,
      );
    }

    return MultiProvider(providers: providers, child: body);
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.upload_file),
        tooltip: 'Import CSV',
        onPressed: () => _handleImport(context),
      ),
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Export CSV',
        onPressed: () => _handleExport(context),
      ),
    ];
  }

  void _handleImport(BuildContext context) {
    final importType = _importTypeForModule(module);
    CsvImportDialog.show(context, importType: importType);
  }

  // Export is intentionally NOT gated on genetics existence (unlike import).
  // Users may want to export current inventory state regardless of genet data.
  Future<void> _handleExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (module) {
        case SpreadsheetModule.genetics:
          messenger.showSnackBar(
            const SnackBar(content: Text('Genetics export coming soon.')),
          );
          break;
        case SpreadsheetModule.inventory:
          if (groupRepository != null && genetRepository != null) {
            await ExportService.exportInventoryCSVFromRepositories(
              organismRecordRepository: organismRecordRepository,
              groupRepository: groupRepository!,
              genetRepository: genetRepository!,
              orgDomain: organization.domain,
              download: true,
            );
          }
          break;
        case SpreadsheetModule.outplanting:
          messenger.showSnackBar(
            const SnackBar(content: Text('Outplanting export coming soon.')),
          );
          break;
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  static CSVImportType _importTypeForModule(SpreadsheetModule module) {
    switch (module) {
      case SpreadsheetModule.genetics:
        return CSVImportType.genetics;
      case SpreadsheetModule.inventory:
        return CSVImportType.inventory;
      case SpreadsheetModule.outplanting:
        return CSVImportType.outplanting;
    }
  }

  Widget _buildHoldingsView() {
    switch (module) {
      case SpreadsheetModule.genetics:
        return const GeneticsHoldingsView();
      case SpreadsheetModule.inventory:
        return const InventoryHoldingsView();
      case SpreadsheetModule.outplanting:
        return const OutplantingHoldingsView();
    }
  }

  Widget _buildEventsView() {
    switch (module) {
      case SpreadsheetModule.genetics:
        return const GeneticsEventsTable();
      case SpreadsheetModule.inventory:
        return const InventoryEventsTable();
      case SpreadsheetModule.outplanting:
        return const InventoryEventsTable(outplantingOnly: true);
    }
  }
}

/// Wraps a child widget with [AutomaticKeepAliveClientMixin] so that tab
/// content is lazily loaded and retained when the user switches tabs.
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
