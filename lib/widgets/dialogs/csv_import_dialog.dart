// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/screens/import/universal_wizard/universal_create_missing_wizard.dart';
import 'package:seafoundry_app/services/csv_import_service.dart';
import 'package:seafoundry_app/services/export/export_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/csv_import_preview.dart';
import 'package:seafoundry_app/widgets/dialogs/components/csv_import_results_panel.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Multi-step CSV import dialog for genetics, inventory, and outplanting.
///
/// Composes [CsvImportPreview] and [CsvImportResultsPanel] into a flow:
/// 1. Preview + template download
/// 2. Validate CSV file
/// 3. Review results, resolve missing entities if needed
/// 4. Import data
class CsvImportDialog extends StatefulWidget {
  const CsvImportDialog({
    super.key,
    required this.importType,
    required this.csvImportService,
    required this.organization,
    this.genetRepository,
    this.groupRepository,
    this.organismRecordRepository,
    this.graphRepository,
  });

  final CSVImportType importType;
  final CSVImportService csvImportService;
  final Organization organization;
  final GenetRepository? genetRepository;
  final GroupRepository? groupRepository;
  final OrganismRecordRepository? organismRecordRepository;
  final GraphRepository? graphRepository;

  /// Shows the import dialog with proper provider capture.
  ///
  /// For inventory imports, checks genetics gating first.
  static Future<void> show(
    BuildContext context, {
    required CSVImportType importType,
  }) async {
    final csvImportService = context.read<CSVImportService>();
    final organization = context.read<Organization>();
    final genetRepository = context.maybeRead<GenetRepository>();
    final groupRepository = context.maybeRead<GroupRepository>();
    final organismRecordRepository =
        context.maybeRead<OrganismRecordRepository>();
    final graphRepository = context.maybeRead<GraphRepository>();
    final siteRepository = context.maybeRead<SiteRepository>();

    // Genetics gating for inventory imports
    if (importType == CSVImportType.inventory && genetRepository != null) {
      try {
        final genets = await genetRepository.getAll();
        if (genets.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Import genetics data first. Inventory import requires at '
                'least one genet record.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to check genetics data: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Organism gating for outplanting imports
    if (importType == CSVImportType.outplanting &&
        organismRecordRepository != null) {
      try {
        final organisms = await organismRecordRepository.getAll();
        if (organisms.isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Import inventory data first. Outplanting import requires at '
                'least one organism record (localGenetId).',
              ),
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to check organism data: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) {
        // Re-provide repositories so nested dialogs can access them.
        Widget dialog = CsvImportDialog(
          importType: importType,
          csvImportService: csvImportService,
          organization: organization,
          genetRepository: genetRepository,
          groupRepository: groupRepository,
          organismRecordRepository: organismRecordRepository,
          graphRepository: graphRepository,
        );

        if (graphRepository != null) {
          dialog = RepositoryProvider<GraphRepository>.value(
            value: graphRepository,
            child: dialog,
          );
        }
        if (groupRepository != null) {
          dialog = RepositoryProvider<GroupRepository>.value(
            value: groupRepository,
            child: dialog,
          );
        }
        if (genetRepository != null) {
          dialog = RepositoryProvider<GenetRepository>.value(
            value: genetRepository,
            child: dialog,
          );
        }
        if (organismRecordRepository != null) {
          dialog = RepositoryProvider<OrganismRecordRepository>.value(
            value: organismRecordRepository,
            child: dialog,
          );
        }
        if (siteRepository != null) {
          dialog = RepositoryProvider<SiteRepository>.value(
            value: siteRepository,
            child: dialog,
          );
        }

        return dialog;
      },
    );
  }

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

enum _ImportStep { preview, validating, results, importing }

class _CsvImportDialogState extends State<CsvImportDialog>
    with SafeDialogMixin<CsvImportDialog> {
  _ImportStep _step = _ImportStep.preview;
  CSVImportSession? _session;
  CSVImportResult? _importResult;
  bool _isLoading = false;

  CsvTemplateKind get _templateKind {
    switch (widget.importType) {
      case CSVImportType.genetics:
        return CsvTemplateKind.genetics;
      case CSVImportType.inventory:
        return CsvTemplateKind.inventory;
      case CSVImportType.outplanting:
        return CsvTemplateKind.outplantConsolidated;
    }
  }

  String get _displayName => widget.importType.displayName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_iconForType(widget.importType), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Import $_displayName',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => popDialog(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: SingleChildScrollView(
            child: _buildContent(),
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _ImportStep.preview:
        return CsvImportPreview(
          templateKind: _templateKind,
          templateDisplayName: _displayName,
          onDownloadTemplate: _handleDownloadTemplate,
        );
      case _ImportStep.validating:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Validating CSV...'),
              ],
            ),
          ),
        );
      case _ImportStep.results:
        if (_session == null) {
          return const Text('No validation results available.');
        }
        return CsvImportResultsPanel(
          result: _session!.result,
          templateKind: _templateKind,
          templateDisplayName: _displayName,
          validateOnly: true,
          isLoading: _isLoading,
          onPickAnotherFile: _handlePickFile,
          onDownloadTranslationIssues: _handleDownloadTranslationIssues,
          onDownloadErrorCsv: _handleDownloadErrorCsv,
          onLaunchCreateMissingWizard: _handleLaunchCreateMissingWizard,
        );
      case _ImportStep.importing:
        if (_importResult != null) {
          return CsvImportResultsPanel(
            result: _importResult!,
            templateKind: _templateKind,
            templateDisplayName: _displayName,
            validateOnly: false,
            isLoading: false,
            onPickAnotherFile: null,
            onDownloadTranslationIssues: _handleDownloadTranslationIssues,
            onDownloadErrorCsv: _handleDownloadErrorCsv,
            onLaunchCreateMissingWizard: _handleLaunchCreateMissingWizard,
          );
        }
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing data...'),
              ],
            ),
          ),
        );
    }
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => popDialog(),
        child: Text(_step == _ImportStep.importing && _importResult != null
            ? 'Close'
            : 'Cancel'),
      ),
      if (_step == _ImportStep.preview)
        FilledButton.icon(
          onPressed: _isLoading ? null : _handlePickFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('Select CSV File'),
        ),
      if (_step == _ImportStep.results &&
          _session != null &&
          !_session!.result.hasErrors)
        FilledButton.icon(
          onPressed: _isLoading ? null : _handleImport,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Import Data'),
        ),
    ];
  }

  Future<void> _handleDownloadTemplate() async {
    safeSetState(() => _isLoading = true);

    try {
      if (widget.importType == CSVImportType.inventory) {
        // Pre-populated template from existing inventory data
        final organismRepo = widget.organismRecordRepository;
        final groupRepo = widget.groupRepository;
        final genetRepo = widget.genetRepository;
        if (organismRepo != null && groupRepo != null && genetRepo != null) {
          await ExportService.exportInventoryCSVFromRepositories(
            organismRecordRepository: organismRepo,
            groupRepository: groupRepo,
            genetRepository: genetRepo,
            orgDomain: widget.organization.domain,
            fileName: 'inventory_import_template.csv',
            download: true,
          );
          return;
        }
      }

      if (widget.importType == CSVImportType.outplanting) {
        // Pre-populated template with existing organism localIDs
        final organismRepo = widget.organismRecordRepository;
        if (organismRepo != null) {
          final organisms = await organismRepo.getAll();
          // Filter to organisms with valid localGenetId and positive quantity
          final eligible = organisms
              .where(
                (o) =>
                    o.localGenetId != null &&
                    o.localGenetId!.isNotEmpty &&
                    o.measurement.value > 0,
              )
              .toList();
          if (eligible.isNotEmpty) {
            final rows = <Map<String, dynamic>>[];
            for (final organism in eligible) {
              rows.add(<String, dynamic>{
                'eventId': '',
                'eventDate': '',
                'siteName': '',
                'eventNotes': '',
                'structureName': '',
                'localGenetId': organism.localGenetId,
                'tagId': organism.tagId,
                'quantity': organism.measurement.value.round().toString(),
                'outplantTagId': '',
              });
            }
            await ExportService.exportTemplate(
              template: CsvTemplateKind.outplantConsolidated,
              rows: rows,
              orgDomain: widget.organization.domain,
              fileName: 'outplanting_import_template.csv',
              download: true,
            );
            return;
          }
        }
      }

      // Blank template for genetics (or fallback)
      final csvString = CSVImportService.generateTemplate(widget.importType);
      await ExportService.downloadCsvString(
        csvString,
        '${widget.importType.name}_import_template.csv',
      );
    } catch (e) {
      showDialogSnackBar('Template download failed: $e');
    } finally {
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _handlePickFile() async {
    safeSetState(() {
      _step = _ImportStep.validating;
      _isLoading = true;
    });

    try {
      final session = await widget.csvImportService.pickAndImportCSV(
        importType: widget.importType,
        validateOnly: true,
      );

      if (session == null) {
        // User cancelled file picker
        safeSetState(() {
          _step = _ImportStep.preview;
          _isLoading = false;
        });
        return;
      }

      safeSetState(() {
        _session = session;
        _step = _ImportStep.results;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _step = _ImportStep.preview;
        _isLoading = false;
      });
      showDialogSnackBar('Validation failed: $e');
    }
  }

  Future<void> _handleImport() async {
    if (_session == null) return;

    safeSetState(() {
      _step = _ImportStep.importing;
      _isLoading = true;
    });

    try {
      final result = await widget.csvImportService.importBytes(
        importType: widget.importType,
        bytes: _session!.bytes,
        validateOnly: false,
        fileName: _session!.fileName,
      );

      safeSetState(() {
        _importResult = result;
        _isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _step = _ImportStep.results;
        _isLoading = false;
      });
      showDialogSnackBar('Import failed: $e');
    }
  }

  void _handleDownloadTranslationIssues(CsvTranslationSummary summary) {
    widget.csvImportService.downloadTranslationIssues(summary);
  }

  void _handleDownloadErrorCsv(List<CSVImportError> errors) {
    widget.csvImportService.downloadErrorCsv(errors);
  }

  Future<void> _handleLaunchCreateMissingWizard(
    List<MissingEntity> entities,
  ) async {
    if (!mounted) return;
    final resolved = await UniversalCreateMissingWizard.show(
      context,
      missingEntities: entities,
    );

    // Re-validate after resolving missing entities
    if (resolved && _session != null && mounted) {
      safeSetState(() {
        _isLoading = true;
      });

      try {
        final result = await widget.csvImportService.importBytes(
          importType: widget.importType,
          bytes: _session!.bytes,
          validateOnly: true,
          fileName: _session!.fileName,
        );

        safeSetState(() {
          _session = CSVImportSession(
            bytes: _session!.bytes,
            result: result,
            importType: widget.importType,
            metadata: _session!.metadata,
            fileName: _session!.fileName,
          );
          _isLoading = false;
        });
      } catch (e) {
        safeSetState(() => _isLoading = false);
        showDialogSnackBar('Re-validation failed: $e');
      }
    }
  }

  static IconData _iconForType(CSVImportType type) {
    switch (type) {
      case CSVImportType.genetics:
        return Icons.biotech;
      case CSVImportType.inventory:
        return Icons.inventory_2;
      case CSVImportType.outplanting:
        return Icons.nature;
    }
  }
}

