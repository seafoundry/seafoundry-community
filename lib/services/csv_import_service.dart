// @tier: community
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/services/csv/csv_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/csv_template_registry.dart';
import 'package:seafoundry_app/services/csv/csv_translation_pipeline.dart';
import 'package:seafoundry_app/services/csv/csv_versioning_service.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_coordinator.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_parser.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_version_utils.dart';
import 'package:seafoundry_app/services/csv/import/importers/genetics_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/monitoring_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplant_allocations_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplant_consolidated_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplanting_csv_importer.dart';
import 'package:seafoundry_app/services/export/export_service.dart';
import 'package:seafoundry_app/services/error_reporter.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';

export 'package:seafoundry_app/services/csv/import/csv_import_models.dart';

/// Service for importing CSV data
class CSVImportService {
  final GenetRepository _genetRepository;
  final OrganismRecordRepository _organismRecordRepository;
  final GroupRepository _groupRepository;
  final SiteRepository _siteRepository;
  final EventRepository _eventRepository;
  final CsvVersioningService _versioningService;
  final CsvImportParser _parser;
  final CsvTranslationPipeline _translationPipeline;
  final ErrorReporter _errorReporter;
  final SpeciesRegistry _speciesRegistry;
  final Map<OrganismKind, SeededLineRepository> _seededLineRepositories;
  final Map<OrganismKind, GameteBatchRepository> _gameteBatchRepositories;
  final Map<OrganismKind, LarvalBatchRepository> _larvalBatchRepositories;
  final Map<OrganismKind, OysterBagRepository> _oysterBagRepositories;
  final Map<OrganismKind, FinfishPenRepository> _finfishPenRepositories;
  final Map<OrganismKind, CrabPondRepository> _crabPondRepositories;
  final Map<OrganismKind, SeagrassModuleRepository> _seagrassModuleRepositories;
  final Map<OrganismKind, MangrovePlotRepository> _mangrovePlotRepositories;
  late final GeneticsCsvImporter _geneticsImporter;
  late final InventoryCsvImporter _inventoryImporter;
  late final OutplantingCsvImporter _outplantingImporter;
  late final OutplantAllocationsCsvImporter _outplantAllocationsImporter;
  late final OutplantConsolidatedCsvImporter _outplantConsolidatedImporter;
  late final MonitoringCsvImporter _monitoringImporter;
  late final CsvImportCoordinator _coordinator;

  static final Set<String> _metadataKeys = {
    for (final schema in CsvSchemas.all) ...schema.metadataFields.keys,
    'sfCsvVersion',
    'sfCsvTemplate',
    'sfTranslationAdapter',
    'sfCsvUpgradedFrom',
    'provenanceCsvUpgradedFrom',
  };

  CSVImportService({
    required GenetRepository genetRepository,
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required SiteRepository siteRepository,
    required EventRepository eventRepository,
    CsvVersioningService? versioningService,
    CsvImportParser? parser,
    CsvTranslationPipeline? translationPipeline,
    ErrorReporter? errorReporter,
    SpeciesRegistry? speciesRegistry,
    Map<OrganismKind, SeededLineRepository>? seededLineRepositories,
    Map<OrganismKind, GameteBatchRepository>? gameteBatchRepositories,
    Map<OrganismKind, LarvalBatchRepository>? larvalBatchRepositories,
    Map<OrganismKind, OysterBagRepository>? oysterBagRepositories,
    Map<OrganismKind, FinfishPenRepository>? finfishPenRepositories,
    Map<OrganismKind, CrabPondRepository>? crabPondRepositories,
    Map<OrganismKind, SeagrassModuleRepository>? seagrassModuleRepositories,
    Map<OrganismKind, MangrovePlotRepository>? mangrovePlotRepositories,
  }) : _genetRepository = genetRepository,
       _organismRecordRepository = organismRecordRepository,
       _groupRepository = groupRepository,
       _siteRepository = siteRepository,
       _eventRepository = eventRepository,
       _versioningService = versioningService ?? CsvVersioningService(),
       _parser = parser ?? CsvImportParser(metadataKeys: _metadataKeys),
       _translationPipeline =
           translationPipeline ?? CsvTranslationPipeline.instance,
       _errorReporter = errorReporter ?? ErrorReporter(),
       _speciesRegistry =
           speciesRegistry ??
           SpeciesRegistry.globalInstance ??
           SpeciesRegistry(),
       _seededLineRepositories = seededLineRepositories ?? const {},
       _gameteBatchRepositories = gameteBatchRepositories ?? const {},
       _larvalBatchRepositories = larvalBatchRepositories ?? const {},
       _oysterBagRepositories = oysterBagRepositories ?? const {},
       _finfishPenRepositories = finfishPenRepositories ?? const {},
       _crabPondRepositories = crabPondRepositories ?? const {},
       _seagrassModuleRepositories = seagrassModuleRepositories ?? const {},
       _mangrovePlotRepositories = mangrovePlotRepositories ?? const {} {
    _geneticsImporter = GeneticsCsvImporter(
      genetRepository: _genetRepository,
      organismRecordRepository: _organismRecordRepository,
      groupRepository: _groupRepository,
      errorReporter: _errorReporter,
    );
    _inventoryImporter = InventoryCsvImporter(
      organismRecordRepository: _organismRecordRepository,
      groupRepository: _groupRepository,
      genetRepository: _genetRepository,
      seededLineRepositories: _seededLineRepositories,
      gameteBatchRepositories: _gameteBatchRepositories,
      larvalBatchRepositories: _larvalBatchRepositories,
      oysterBagRepositories: _oysterBagRepositories,
      finfishPenRepositories: _finfishPenRepositories,
      crabPondRepositories: _crabPondRepositories,
      seagrassModuleRepositories: _seagrassModuleRepositories,
      mangrovePlotRepositories: _mangrovePlotRepositories,
    );
    _outplantingImporter = OutplantingCsvImporter(
      eventRepository: _eventRepository,
      siteRepository: _siteRepository,
    );
    _outplantAllocationsImporter = OutplantAllocationsCsvImporter(
      eventRepository: _eventRepository,
      organismRecordRepository: _organismRecordRepository,
    );
    _outplantConsolidatedImporter = OutplantConsolidatedCsvImporter(
      eventRepository: _eventRepository,
      siteRepository: _siteRepository,
      groupRepository: _groupRepository,
      organismRecordRepository: _organismRecordRepository,
    );
    _monitoringImporter = MonitoringCsvImporter(
      eventRepository: _eventRepository,
      siteRepository: _siteRepository,
    );
    _coordinator = CsvImportCoordinator(
      eventRepository: _eventRepository,
      versioningService: _versioningService,
      translationPipeline: _translationPipeline,
      geneticsImporter: _geneticsImporter,
      inventoryImporter: _inventoryImporter,
      outplantingImporter: _outplantingImporter,
      outplantAllocationsImporter: _outplantAllocationsImporter,
      outplantConsolidatedImporter: _outplantConsolidatedImporter,
      monitoringImporter: _monitoringImporter,
      speciesRegistry: _speciesRegistry,
    );
  }

  /// Pick and import a CSV file
  Future<CSVImportSession?> pickAndImportCSV({
    required CSVImportType importType,
    bool validateOnly = false,
  }) {
    return _errorReporter.guard<CSVImportSession?>(
      'CSVImportService.pickAndImportCSV',
      () async {
        // Pick CSV file
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv'],
          withData: true,
        );

        if (result == null || result.files.isEmpty) {
          return null;
        }

        final file = result.files.first;
        if (file.bytes == null) {
          throw Exception('Failed to read file data');
        }

        // Parse CSV data
        final bytes = file.bytes!;
        final csvString = utf8.decode(bytes);
        final parsed = _parser.parse(csvString);
        await _speciesRegistry.ensureHydrated();
        final resultData = await _coordinator.import(
          importType: importType,
          parsed: parsed,
          validateOnly: validateOnly,
          sourceName: file.name,
        );
        return CSVImportSession(
          bytes: bytes,
          importType: importType,
          metadata: parsed.metadata,
          fileName: file.name,
          result: resultData,
        );
      },
      category: AppErrorCategory.data,
      metadata: {'importType': importType.name, 'validateOnly': validateOnly},
    );
  }

  /// Replays an import using previously captured bytes (e.g. after validation).
  Future<CSVImportResult> importBytes({
    required CSVImportType importType,
    required Uint8List bytes,
    bool validateOnly = false,
    String? fileName,
  }) async {
    final csvString = utf8.decode(bytes);
    final parsed = _parser.parse(csvString);
    await _speciesRegistry.ensureHydrated();
    return _coordinator.import(
      importType: importType,
      parsed: parsed,
      validateOnly: validateOnly,
      sourceName: fileName,
    );
  }

  String buildErrorCsv(List<CSVImportError> errors) {
    if (errors.isEmpty) {
      return 'Row,Field,Value,Message';
    }
    final data = errors
        .map(
          (error) => <String, dynamic>{
            'Row': error.row.toString(),
            'Field': error.field,
            'Value': error.value,
            'Message': error.message,
          },
        )
        .toList(growable: false);
    return ExportService.exportToCSV(data, const [
      'Row',
      'Field',
      'Value',
      'Message',
    ]);
  }

  Future<void> downloadErrorCsv(
    List<CSVImportError> errors, {
    String? fileName,
  }) async {
    final csvString = buildErrorCsv(errors);
    final resolvedName = fileName ?? 'csv_validation_errors.csv';
    ExportService.downloadCsvString(csvString, resolvedName);
  }

  Future<void> downloadTranslationIssues(
    CsvTranslationSummary summary, {
    String? fileName,
  }) async {
    final csvString = summary.issueCsv;
    if (csvString == null || csvString.isEmpty) {
      LoggingService.instance.warning(
        'CSV translation issue download skipped – no CSV payload generated',
        {'adapterId': summary.adapterId},
      );
      return;
    }
    final resolvedName = fileName ?? 'csv_translation_issues.csv';
    ExportService.downloadCsvString(csvString, resolvedName);
  }

  /// Generate a template CSV for download
  static String generateTemplate(CSVImportType type) {
    final registry = CsvTemplateRegistry.instance;
    final kind = templateKindForImportType(type);
    final schema = registry.schemaFor(kind);
    final metadataRows = CsvMetadataBuilder(
      registry: registry,
    ).buildMetadataRows(kind: kind, orgDomain: 'your-org-domain');

    final lines = <String>[
      for (final row in metadataRows) row.join(','),
      schema.allColumns.join(','),
      List.filled(schema.allColumns.length, '').join(','),
    ];

    return lines.join('\n');
  }
}
