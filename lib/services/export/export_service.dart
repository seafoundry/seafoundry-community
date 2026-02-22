// @tier: community
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/husbandry/husbandry_schedule_entry.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/services/csv/adapters/universal_csv_adapter_v2.dart';
import 'package:seafoundry_app/services/csv/csv_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/csv_template_registry.dart';
import 'package:seafoundry_app/services/csv/csv_translation_pipeline.dart';
import 'package:seafoundry_app/services/csv/downloaders/csv_download_interface.dart';
import 'package:seafoundry_app/services/csv/downloaders/csv_download_stub.dart'
    if (dart.library.html) 'package:seafoundry_app/services/csv/downloaders/csv_download_web.dart'
    if (dart.library.io) 'package:seafoundry_app/services/csv/downloaders/csv_download_io.dart';
import 'package:seafoundry_app/services/csv/genetics_row_normalizer.dart';
import 'package:seafoundry_app/services/export/export_formatters.dart';
import 'package:seafoundry_app/services/export/inventory_export_row_formatter.dart';
import 'package:seafoundry_app/services/export/inventory_export_row_source.dart';
import 'package:seafoundry_app/repositories/inventory/archived_organism_record_repository.dart';
import 'package:seafoundry_app/services/husbandry_schedule_registry.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/services/tiered_field_registry.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/models/mission.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/operations/vessel.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

/// Unified service for exporting data to CSV and Excel formats
///
/// This service consolidates CSVExportService and ExportService functionality
/// into a single, maintainable interface with support for:
/// - CSV export with template support
/// - Excel (XLSX) export
/// - Platform-specific downloads (web, mobile, desktop)
///
/// All methods are static for backward compatibility with existing usage patterns.
/// Produces CSV/Excel exports for spreadsheets, coordinating queries + formatting.
class ExportService {
  ExportService._();

  static final CsvTemplateRegistry _registry = CsvTemplateRegistry.instance;
  static final CsvMetadataBuilder _metadataBuilder = CsvMetadataBuilder();
  static final CsvTranslationPipeline _translationPipeline =
      CsvTranslationPipeline.instance;
  static final CsvDownloadAdapter _downloadAdapter = createCsvDownloadAdapter();

  // === CSV Export Methods ===

  /// Exports a list of maps to CSV format
  ///
  /// Basic CSV export without template metadata or translation.
  /// For template-based exports, use [exportTemplate] instead.
  static String exportToCSV(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    String fileName = 'export.csv',
  }) {
    if (data.isEmpty) {
      throw ArgumentError('Data cannot be empty');
    }

    // Create CSV data with headers and rows
    final csvData = <List<dynamic>>[];

    // Add headers
    csvData.add(headers);

    // Add data rows
    for (final row in data) {
      csvData.add([for (final header in headers) row[header] ?? '']);
    }

    // Convert to CSV string
    return csvData
        .map((row) {
          return row
              .map((field) => ExportFormatters.escapeCsvField(field))
              .join(',');
        })
        .join('\n');
  }

  /// Exports data and triggers download.
  static Future<void> exportAndDownload(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    String fileName = 'export.csv',
  }) async {
    final csvData = exportToCSV(data, headers, fileName: fileName);
    return _downloadCSV(csvData, fileName);
  }

  /// Builds an export using the canonical schema defined in [CsvTemplateKind].
  ///
  /// Rows must use the canonical column names defined in the schema.
  /// Metadata rows (version, generatedAt, orgDomain) are prepended automatically.
  static Future<String> exportTemplate({
    required CsvTemplateKind template,
    required List<Map<String, dynamic>> rows,
    required String orgDomain,
    DateTime? generatedAt,
    String fileName = 'export.csv',
    bool download = false,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportTemplate',
      () => _performExportTemplate(
        template: template,
        rows: rows,
        orgDomain: orgDomain,
        generatedAt: generatedAt,
        fileName: fileName,
        download: download,
      ),
      metadata: {
        'template': template.name,
        'rowCount': rows.length,
        'download': download,
      },
    );
  }

  /// Internal implementation of exportTemplate with performance tracking.
  ///
  /// Builds CSV export with metadata rows, schema validation, and translation.
  static Future<String> _performExportTemplate({
    required CsvTemplateKind template,
    required List<Map<String, dynamic>> rows,
    required String orgDomain,
    DateTime? generatedAt,
    String fileName = 'export.csv',
    bool download = false,
  }) async {
    // Get schema for template validation
    final schema = _registry.schemaFor(template);

    // Build metadata rows (version, generatedAt, orgDomain, etc.)
    final metadataRows = _metadataBuilder.buildMetadataRows(
      kind: template,
      orgDomain: orgDomain,
      generatedAt: generatedAt,
      versionOverride: schema.version,
    );

    // Convert metadata rows to map for translation pipeline
    final metadataMap = <String, String>{
      for (final row in metadataRows.where((r) => r.length == 2))
        row[0]: row[1],
    };

    if (template == CsvTemplateKind.inventory) {
      _overrideMetadata(metadataRows, metadataMap, {
        'provenanceCsvTemplate': UniversalCsvAdapterV2.templateName,
        'provenanceCsvVersion': UniversalCsvAdapterV2.templateVersion,
        'provenanceTranslationAdapter': UniversalCsvAdapterV2.adapterKey,
      });
    }

    await SpeciesRegistry.ensureGlobalHydrated();

    // Translate export rows using adapter pipeline
    final translation = _translationPipeline.translateExportRows(
      kind: template,
      metadata: metadataMap,
      rows: rows,
      speciesRegistry: SpeciesRegistry.globalInstance,
    );
    final translatedRows = translation.rows;

    // Build CSV rows: metadata + header + data rows
    final csvRows = <List<dynamic>>[...metadataRows, schema.allColumns];

    // Convert translated rows to CSV format with proper column ordering
    for (final row in translatedRows) {
      final resolved = <dynamic>[];
      for (final column in schema.allColumns) {
        resolved.add(ExportFormatters.stringValue(row[column]));
      }
      csvRows.add(resolved);
    }

    // Convert rows to CSV string with proper escaping
    final csvString = csvRows
        .map(
          (row) => row
              .map((field) => ExportFormatters.escapeCsvField(field))
              .join(','),
        )
        .join('\n');

    // Download if requested
    if (download) {
      await _downloadCSV(csvString, fileName);
    }

    return csvString;
  }

  /// Downloads CSV data as a file
  static Future<void> _downloadCSV(String csvData, String fileName) async {
    if (!_downloadAdapter.isSupported) {
      throw UnsupportedError(
        'CSV downloads are not supported on this platform.',
      );
    }
    await _downloadAdapter.save(
      content: csvData,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Public wrapper for downloading pre-built CSV payloads.
  static Future<void> downloadCsvString(String csvData, String fileName) {
    return _downloadCSV(csvData, fileName);
  }

  static Future<String> _exportOrganismHoldings({
    required OrganismHoldingLoader holdingLoader,
    required OrganismKind organismKind,
    required Set<String> holdingKinds,
    required String orgDomain,
    required String fileName,
    bool download = true,
    List<Map<String, dynamic>>? rowsOverride,
    Tier tier = Tier.scale,
  }) async {
    if (!holdingLoader.supports(organismKind) && rowsOverride == null) {
      throw ArgumentError(
        'OrganismHoldingLoader has no repositories registered for ${organismKind.name}.',
      );
    }
    final rawRows =
        rowsOverride ??
        await holdingLoader.loadRowsFor(organismKind: organismKind);
    await TieredFieldRegistry.instance.ensureInitialized();
    final canonicalRows = rawRows
        .where(
          (row) => holdingKinds.contains(
            row['holdingKind']?.toString() ?? '',
          ),
        )
        .map((row) => InventoryExportRowFormatter.canonicalize(row, tier: tier))
        .toList(growable: false);
    return exportTemplate(
      template: CsvTemplateKind.inventory,
      rows: canonicalRows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );
  }

  /// Exports a mission manifest as a CSV file for compliance and field reporting.
  /// Includes details about the vessel, crew, and target sites.
  static Future<void> exportMissionManifest({
    required Mission mission,
    required List<User> crew,
    required List<Site> sites,
    List<Permit> permits = const [],
    Vessel? vessel,
    String fileName = 'mission_manifest.csv',
    bool download = true,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportMissionManifest',
      () async {
        final headers = [
          'Mission ID',
          'Mission Name',
          'Scheduled Date',
          'Status',
          'Permit Numbers',
          'Vessel Name',
          'Vessel Registration',
          'Crew Manifest',
          'Target Sites (Coordinates)',
          'Estimated Duration',
          'Notes',
        ];

        final crewNames = crew.map((u) => u.name).join('; ');
        final siteDetails = sites.map((s) {
          final lat = s.latitude?.toStringAsFixed(6) ?? 'N/A';
          final lng = s.longitude?.toStringAsFixed(6) ?? 'N/A';
          return '${s.name} ($lat, $lng)';
        }).join('; ');
        
        final permitNumbers = permits.map((p) => p.permitNumber).join('; ');

        final row = [
          mission.id,
          mission.name,
          mission.scheduledDate.toIso8601String(),
          mission.status.displayName,
          permitNumbers.isNotEmpty ? permitNumbers : 'N/A',
          vessel?.name ?? mission.vesselId ?? 'N/A',
          vessel?.registrationNumber ?? 'N/A',
          crewNames,
          siteDetails,
          '${mission.estimatedDurationHours ?? 0} hours',
          mission.notes ?? '',
        ];

        final csv = ExportFormatters.generateCsv(
          headers: headers,
          rows: [row],
          prefaceLines: [
            'Mission Manifest Export',
            'Organization: ${mission.organizationId}',
            'Generated: ${DateTime.now().toUtc().toIso8601String()}',
          ],
        );

        if (download) {
          await _downloadCSV(csv, fileName);
        }
      },
      metadata: {
        'missionId': mission.id,
        'crewCount': crew.length,
        'siteCount': sites.length,
      },
    );
  }

  // === Specialized Export Methods ===

  /// Exports inventory data to CSV
  static Future<void> exportInventoryCSV({
    required List<Map<String, dynamic>> inventoryData,
    required String orgDomain,
    String fileName = 'inventory_export.csv',
    bool download = true,
    Tier tier = Tier.scale,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportInventoryCSV',
      () => _performExportInventoryCSV(
        inventoryData: inventoryData,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
        tier: tier,
      ),
      metadata: {'rowCount': inventoryData.length, 'download': download},
    );
  }

  static Future<void> _performExportInventoryCSV({
    required List<Map<String, dynamic>> inventoryData,
    required String orgDomain,
    String fileName = 'inventory_export.csv',
    bool download = true,
    Tier tier = Tier.scale,
  }) async {
    await TieredFieldRegistry.instance.ensureInitialized();
    final canonicalRows = inventoryData
        .map((row) => InventoryExportRowFormatter.canonicalize(row, tier: tier))
        .toList(growable: false);

    await exportTemplate(
      template: CsvTemplateKind.inventory,
      rows: canonicalRows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );
  }

  /// Convenience helper that builds inventory export rows directly from
  /// repositories (organisms + organism holdings) before delegating to
  /// [exportInventoryCSV]. Useful for API/backfill scripts that do not already
  /// have the spreadsheet data in memory.
  static Future<void> exportInventoryCSVFromRepositories({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required GenetRepository genetRepository,
    required String orgDomain,
    Map<OrganismKind, SeededLineRepository> seededLineRepositories = const {},
    Map<OrganismKind, OysterBagRepository> oysterBagRepositories = const {},
    Map<OrganismKind, GameteBatchRepository> gameteBatchRepositories = const {},
    Map<OrganismKind, LarvalBatchRepository> larvalBatchRepositories = const {},
    Map<OrganismKind, FinfishPenRepository> finfishPenRepositories = const {},
    Map<OrganismKind, CrabPondRepository> crabPondRepositories = const {},
    Map<OrganismKind, SeagrassModuleRepository> seagrassModuleRepositories =
        const {},
    Map<OrganismKind, MangrovePlotRepository> mangrovePlotRepositories =
        const {},
    OrganismHoldingLoader? holdingLoader,
    String fileName = 'inventory_export.csv',
    bool download = true,
    Tier tier = Tier.scale,
  }) async {
    final rowSource = InventoryExportRowSource(
      organismRecordRepository: organismRecordRepository,
      archivedOrganismRecordRepository: ArchivedOrganismRecordRepository(
        organization: organismRecordRepository.organization,
        user: organismRecordRepository.user,
        firestore: organismRecordRepository.firestore,
      ),
      groupRepository: groupRepository,
      genetRepository: genetRepository,
      holdingLoader: holdingLoader,
      seededLineRepositories: seededLineRepositories,
      oysterBagRepositories: oysterBagRepositories,
      gameteBatchRepositories: gameteBatchRepositories,
      larvalBatchRepositories: larvalBatchRepositories,
      finfishPenRepositories: finfishPenRepositories,
      crabPondRepositories: crabPondRepositories,
      seagrassModuleRepositories: seagrassModuleRepositories,
      mangrovePlotRepositories: mangrovePlotRepositories,
    );

    final rows = await rowSource.loadRowMaps();
    await exportInventoryCSV(
      inventoryData: rows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
      tier: tier,
    );
  }

  /// Exports genetics data using the canonical template.
  static Future<void> exportGeneticsCSV({
    required List<Map<String, dynamic>> geneticsData,
    required String orgDomain,
    String fileName = 'genetics_export.csv',
    bool download = true,
    OrganismKind organismKind = OrganismKind.coral,
    Tier tier = Tier.scale,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportGeneticsCSV',
      () => _performExportGeneticsCSV(
        geneticsData: geneticsData,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
        organismKind: organismKind,
        tier: tier,
      ),
      metadata: {'rowCount': geneticsData.length, 'download': download},
    );
  }

  /// Exports site baseline data using the canonical template.
  static Future<void> exportSiteBaselineCSV({
    required List<Map<String, dynamic>> baselineRows,
    required String orgDomain,
    String fileName = 'site_baselines.csv',
    bool download = true,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportSiteBaselineCSV',
      () => exportTemplate(
        template: CsvTemplateKind.siteBaselines,
        rows: baselineRows,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
      ),
      metadata: {'rowCount': baselineRows.length, 'download': download},
    );
  }

  // NOTE: Environmental threshold export moved to pro-tier service.
  // See lib/services/export/pro_export_service.dart for threshold exports.

  static Future<void> exportHusbandrySchedules({
    required String orgDomain,
    Iterable<HusbandryScheduleEntry>? schedules,
    String fileName = 'husbandry_schedules.csv',
    bool download = true,
  }) async {
    final entries =
        schedules?.toList() ?? HusbandryScheduleRegistry.instance.allEntries();
    final headers = [
      'organismKind',
      'lifeStageId',
      'title',
      'frequencyDays',
      'instructions',
    ];
    final rows = entries
        .map(
          (entry) => [
            entry.organismKind.name,
            entry.lifeStage?.id ?? '',
            entry.title,
            entry.frequencyDays,
            entry.instructions ?? '',
          ],
        )
        .toList();
    final csv = ExportFormatters.generateCsv(
      headers: headers,
      rows: rows,
      prefaceLines: [
        'provenanceCsvTemplate=husbandry_schedules',
        'orgDomain=$orgDomain',
        'generatedAt=${DateTime.now().toUtc().toIso8601String()}',
      ],
    );
    if (download) {
      await _downloadCSV(csv, fileName);
    }
  }

  static Future<String> exportKelpBiomassCSV({
    required OrganismHoldingLoader holdingLoader,
    required String orgDomain,
    String fileName = 'kelp_biomass.csv',
    bool download = true,
    List<Map<String, dynamic>>? rowsOverride,
  }) {
    return _exportOrganismHoldings(
      holdingLoader: holdingLoader,
      organismKind: OrganismKind.kelp,
      holdingKinds: const {'seededLineBatch'},
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
      rowsOverride: rowsOverride,
    );
  }

  static Future<String> exportOysterGrowthCSV({
    required OrganismHoldingLoader holdingLoader,
    required String orgDomain,
    String fileName = 'oyster_growth.csv',
    bool download = true,
    List<Map<String, dynamic>>? rowsOverride,
  }) {
    return _exportOrganismHoldings(
      holdingLoader: holdingLoader,
      organismKind: OrganismKind.oyster,
      holdingKinds: const {'gameteBatch', 'larvalBatch'},
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
      rowsOverride: rowsOverride,
    );
  }

  static Future<String> exportFinfishMetricsCSV({
    required OrganismHoldingLoader holdingLoader,
    required String orgDomain,
    String fileName = 'finfish_metrics.csv',
    bool download = true,
    List<Map<String, dynamic>>? rowsOverride,
  }) {
    return _exportOrganismHoldings(
      holdingLoader: holdingLoader,
      organismKind: OrganismKind.finfish,
      holdingKinds: const {'gameteBatch', 'larvalBatch'},
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
      rowsOverride: rowsOverride,
    );
  }

  static Future<void> _performExportGeneticsCSV({
    required List<Map<String, dynamic>> geneticsData,
    required String orgDomain,
    String fileName = 'genetics_export.csv',
    bool download = true,
    OrganismKind organismKind = OrganismKind.coral,
    Tier tier = Tier.scale,
  }) async {
    await TieredFieldRegistry.instance.ensureInitialized();
    final canonicalRows = canonicalizeGeneticsRows(
      sourceRows: geneticsData,
      organismKind: organismKind,
      tier: tier,
    );

    await exportTemplate(
      template: CsvTemplateKind.genetics,
      rows: canonicalRows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> canonicalizeGeneticsRows({
    required List<Map<String, dynamic>> sourceRows,
    required OrganismKind organismKind,
    Tier tier = Tier.scale,
  }) {
    final registry = TieredFieldRegistry.instance;
    return sourceRows
        .map(
          (row) {
            final canonical = _isGenetRow(row)
                ? _canonicalizeGenetRow(row, organismKind)
                : _canonicalizeProvenanceRow(row, organismKind);
            return registry.filterFields(
              model: 'genetics_row',
              payload: canonical,
              tier: tier,
            );
          },
        )
        .toList(growable: false);
  }

  static bool _isGenetRow(Map<String, dynamic> row) {
    return row.containsKey('genetName') ||
        row.containsKey('genetType') ||
        row.containsKey('genetTypeId') ||
        row.containsKey('clonalId') ||
        row.containsKey('damGameteIds') ||
        row.containsKey('sireGameteIds') ||
        row.containsKey('cohortParentGameteIds') ||
        row.containsKey('genetNotes');
  }

  static Map<String, dynamic> _canonicalizeGenetRow(
    Map<String, dynamic> row,
    OrganismKind organismKind,
  ) {
    final metadata = GeneticsRowNormalizer.metadataFromRow(row);
    final metadataSummary = GeneticsRowNormalizer.normalizedString(
      row['metadata'] ?? row['metadataSummary'],
    );
    final parentGametes = GeneticsRowNormalizer.collectParentGameteIds(row);
    final archivedFlag =
        ExportFormatters.stringValue(row['archived']).toLowerCase() == 'true'
        ? 'true'
        : 'false';
    final habitatType = GeneticsRowNormalizer.firstNonEmpty([
      row['provenance.habitatType'],
      row['habitatType'],
      GeneticsRowNormalizer.metadataString(metadata, const [
        'habitatType',
        'habitat',
      ]),
    ]);
    final collectionDate = GeneticsRowNormalizer.firstNonEmpty([
      row['provenance.collectionDate'],
      row['collectionDate'],
      GeneticsRowNormalizer.metadataString(metadata, const [
        'collectionDate',
        'collectedAt',
      ]),
      row['crossDate'],
    ]);
    final metadataNotes = GeneticsRowNormalizer.metadataString(metadata, const [
      'notes',
      'note',
      'description',
      'provenanceNotes',
    ]);
    final metadataSummaryValue = GeneticsRowNormalizer.normalizedString(
      row['provenanceMetadataSummary'],
    );
    final provenanceNotes = GeneticsRowNormalizer.joinDistinctSegments([
      row['provenance.notes'],
      row['genotypeProvenance'],
      row['genetNotes'],
      metadataNotes,
      metadataSummary,
      metadataSummaryValue,
    ]);
    final aliases = GeneticsRowNormalizer.aliasStringFromRow(row);

    final canonicalSources =
        _buildCanonicalSources(metadata, row, includeRowValues: true);
    final provenanceSelection = ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: canonicalSources,
      fallbackProvenanceKind: _firstNonEmptyValue([
        row['provenanceKind'],
        row['genetType'],
        row['genetTypeId'],
      ]),
    );

    final result = <String, dynamic>{
      'provenanceId': ExportFormatters.stringValue(
        row['provenanceId'] ?? row['genetId'],
      ),
      'name': ExportFormatters.stringValue(row['genetName'] ?? row['name']),
      'speciesId': ExportFormatters.stringValue(row['speciesId']),
      'organismKind': organismKind.name,
      'genetTypeId': ExportFormatters.stringValue(
        row['genetType'] ?? row['genetTypeId'],
      ),
      'clonalId': ExportFormatters.stringValue(row['clonalId']),
      'parentGameteIds': parentGametes,
      'donorGenotypeId': ExportFormatters.stringValue(
        row['gameteDonorGenotypeId'] ?? row['donorGenotypeId'],
      ),
      'archived': archivedFlag,
      'archivedAt': ExportFormatters.isoString(row['archivedAt']),
      'provenance.habitatType': habitatType,
      'provenance.collectionDate': collectionDate,
      'provenance.notes': provenanceNotes,
      'aliases': aliases,
    };
    _writeCanonicalProvenanceOutputs(result, provenanceSelection);
    return result;
  }

  static Map<String, dynamic> _canonicalizeProvenanceRow(
    Map<String, dynamic> row,
    OrganismKind organismKind,
  ) {
    final metadataMap = GeneticsRowNormalizer.metadataFromRow(row);
    final habitatType = GeneticsRowNormalizer.metadataString(
      metadataMap,
      const ['habitatType', 'habitat'],
    );
    final collectionDate = GeneticsRowNormalizer.metadataString(
      metadataMap,
      const [
        'collectionDate',
        'collectedAt',
      ],
    );
    final metaNotes = GeneticsRowNormalizer.metadataString(metadataMap, const [
      'notes',
      'note',
      'description',
      'provenanceNotes',
    ]);
    final metadataSummary = ExportFormatters.stringValue(
      row['metadata'] ?? row['metadataSummary'],
    );
    final siteId = ExportFormatters.stringValue(row['siteId']).trim();
    final notesSegments = <String>[];
    if (siteId.isNotEmpty) {
      notesSegments.add('Site: $siteId');
    }
    if (metaNotes != null && metaNotes.isNotEmpty) {
      notesSegments.add(metaNotes);
    }
    if (metadataSummary.isNotEmpty &&
        metadataSummary != metaNotes &&
        !notesSegments.contains(metadataSummary)) {
      notesSegments.add(metadataSummary);
    }

    final canonicalSources =
        _buildCanonicalSources(metadataMap, row, includeRowValues: true);
    final provenanceSelection = ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: canonicalSources,
      fallbackProvenanceKind: _firstNonEmptyValue([
        row['provenanceKind'],
        row['genetTypeId'],
      ]),
    );

    final result = <String, dynamic>{
      'provenanceId': ExportFormatters.stringValue(row['provenanceId']),
      'name': ExportFormatters.stringValue(row['displayName']),
      'speciesId': ExportFormatters.stringValue(row['speciesId']),
      'organismKind': organismKind.name,
      'genetTypeId': ExportFormatters.stringValue(row['provenanceKind']),
      'clonalId': '',
      'parentGameteIds': ExportFormatters.stringValue(
        row['parentProvenanceId'],
      ),
      'donorGenotypeId': siteId,
      'archived': 'false',
      'archivedAt': '',
      'provenance.habitatType': ExportFormatters.stringValue(habitatType),
      'provenance.collectionDate': ExportFormatters.stringValue(
        collectionDate,
      ),
      'provenance.notes': notesSegments.join(' | '),
      'aliases': ExportFormatters.stringValue(row['aliases']),
    };
    _writeCanonicalProvenanceOutputs(result, provenanceSelection);
    return result;
  }

  // helper functions removed (now provided by GeneticsRowNormalizer)

  static List<Map<String, dynamic>> _buildCanonicalSources(
    Map<String, dynamic> metadata,
    Map<dynamic, dynamic> row, {
    bool includeRowValues = false,
  }) {
    final sources = <Map<String, dynamic>>[];
    if (metadata.isNotEmpty) {
      sources.add(Map<String, dynamic>.from(metadata));
    }
    if (includeRowValues) {
      final inline = <String, dynamic>{};
      void addValue(String key, dynamic value) {
        final normalized = ExportFormatters.stringValue(value);
        if (normalized.isNotEmpty) {
          inline[key] = normalized;
        }
      }

      addValue('provenanceTypeId', row['provenanceTypeId']);
      addValue('provenanceType', row['provenanceType']);
      addValue('lifeStageId', row['lifeStageId']);
      addValue('lifeStage', row['lifeStage']);
      addValue('lifeStage', row['lifeStageLabel']);
      addValue('provenanceKind', row['provenanceKind']);

      if (inline.isNotEmpty) {
        sources.add(inline);
      }
    }
    return sources;
  }

  static String? _firstNonEmptyValue(Iterable<dynamic> values) {
    for (final value in values) {
      final normalized = ExportFormatters.stringValue(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static void _writeCanonicalProvenanceOutputs(
    Map<String, dynamic> target,
    ProvenanceLifeStageSelection selection,
  ) {
    target['provenanceTypeId'] = selection.provenanceType.id;
    target['provenanceTypeLabel'] =
        selection.provenanceType.metadata.displayName;
    target['lifeStageId'] = selection.lifeStage.id;
    target['lifeStageLabel'] = selection.lifeStage.displayName;
  }

  /// Exports outplant events using the canonical template.
  static Future<void> exportOutplantCSV({
    required List<Map<String, dynamic>> rows,
    required String orgDomain,
    String fileName = 'outplant_events.csv',
    bool download = true,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportOutplantCSV',
      () => _performExportOutplantCSV(
        rows: rows,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
      ),
      metadata: {'rowCount': rows.length, 'download': download},
    );
  }

  static Future<void> _performExportOutplantCSV({
    required List<Map<String, dynamic>> rows,
    required String orgDomain,
    String fileName = 'outplant_events.csv',
    bool download = true,
  }) async {
    final allocationRows = <Map<String, dynamic>>[];
    final eventRows = <Map<String, dynamic>>[];

    for (final row in rows) {
      final rawAllocations = row['allocationsDetail'] as List?;
      final allocationsDetail = rawAllocations == null
          ? const <Map<String, dynamic>>[]
          : rawAllocations
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList(growable: false);

      for (var index = 0; index < allocationsDetail.length; index++) {
        final allocation = allocationsDetail[index];
        allocationRows.add(<String, dynamic>{
          'eventId': ExportFormatters.stringValue(
            row['eventId'],
          ),
          'allocationIndex': index.toString(),
          'organismId': ExportFormatters.stringValue(
            allocation['organismId'],
          ),
          'recordName': ExportFormatters.stringValue(
            allocation['recordName'],
          ),
          'quantity': ExportFormatters.stringValue(allocation['quantity']),
          'sourcePath': ExportFormatters.stringValue(
            allocation['sourcePath'],
          ),
          'tagId': ExportFormatters.stringValue(allocation['tagId']),
          'tagName': ExportFormatters.stringValue(allocation['tagName']),
          'tagPath': ExportFormatters.stringValue(allocation['tagPath']),
        });
      }

      final eventRow = Map<String, dynamic>.from(row);
      eventRow.remove('allocationsDetail');
      eventRows.add(eventRow);
    }

    await exportTemplate(
      template: CsvTemplateKind.outplanting,
      rows: eventRows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );

    if (allocationRows.isNotEmpty) {
      await exportTemplate(
        template: CsvTemplateKind.outplantAllocations,
        rows: allocationRows,
        orgDomain: orgDomain,
        fileName: 'outplant_allocations.csv',
        download: download,
      );
    }
  }

  /// Exports outplant events in consolidated row-per-allocation format.
  ///
  /// Each allocation becomes one CSV row with event-level fields duplicated.
  /// This format is designed for round-trip import and simpler spreadsheet editing.
  ///
  /// The [siteNameResolver] callback converts site IDs to human-readable names.
  /// If not provided, the site ID is used as-is.
  static Future<void> exportOutplantConsolidatedCSV({
    required List<OutplantEvent> events,
    required String orgDomain,
    String fileName = 'outplant_events.csv',
    bool download = true,
    Future<String?> Function(String siteId)? siteNameResolver,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportOutplantConsolidatedCSV',
      () => _performExportOutplantConsolidatedCSV(
        events: events,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
        siteNameResolver: siteNameResolver,
      ),
      metadata: {'eventCount': events.length, 'download': download},
    );
  }

  static Future<void> _performExportOutplantConsolidatedCSV({
    required List<OutplantEvent> events,
    required String orgDomain,
    String fileName = 'outplant_events.csv',
    bool download = true,
    Future<String?> Function(String siteId)? siteNameResolver,
  }) async {
    final rows = <Map<String, dynamic>>[];

    // Cache resolved site names to avoid repeated lookups
    final siteNameCache = <String, String>{};

    for (final event in events) {
      // Resolve site name (use cache or resolver or fall back to siteId)
      String siteName;
      if (siteNameCache.containsKey(event.siteId)) {
        siteName = siteNameCache[event.siteId]!;
      } else if (siteNameResolver != null) {
        final resolved = await siteNameResolver(event.siteId);
        siteName = resolved ?? event.siteId;
        siteNameCache[event.siteId] = siteName;
      } else {
        siteName = event.siteId;
        siteNameCache[event.siteId] = siteName;
      }

      final eventDateIso = event.createdAt;

      // Create one row per allocation
      for (final allocation in event.allocations) {
        rows.add(<String, dynamic>{
          // Event-level fields (duplicated per row)
          'eventId': event.id,
          'eventDate': eventDateIso,
          'siteName': siteName,
          'eventNotes': event.comment ?? '',

          // Allocation-level fields (unique per row)
          'structureName': allocation.groupName ?? '',
          'localId': allocation.organismId,
          'recordName': allocation.recordName,
          'quantity': allocation.quantity.toString(),
          'tagId': allocation.tagId ?? '',
        });
      }

      // If event has no allocations, still emit one row with empty allocation fields
      if (event.allocations.isEmpty) {
        rows.add(<String, dynamic>{
          'eventId': event.id,
          'eventDate': eventDateIso,
          'siteName': siteName,
          'eventNotes': event.comment ?? '',
          'structureName': '',
          'localId': '',
          'recordName': '',
          'quantity': '0',
          'tagId': '',
        });
      }
    }

    await exportTemplate(
      template: CsvTemplateKind.outplantConsolidated,
      rows: rows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );
  }

  /// Exports monitoring events using the canonical template.
  static Future<void> exportMonitoringCSV({
    required List<Map<String, dynamic>> rows,
    required String orgDomain,
    String fileName = 'monitoring_events.csv',
    bool download = true,
    Tier tier = Tier.scale,
  }) async {
    await TieredFieldRegistry.instance.ensureInitialized();
    final filteredRows = filterMonitoringRowsForTier(rows: rows, tier: tier);
    return PerformanceAnalyzer.measure(
      'ExportService.exportMonitoringCSV',
      () => exportTemplate(
        template: CsvTemplateKind.monitoring,
        rows: filteredRows,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
      ),
      metadata: {'rowCount': rows.length, 'download': download},
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> filterMonitoringRowsForTier({
    required List<Map<String, dynamic>> rows,
    Tier tier = Tier.scale,
  }) {
    return rows
        .map(
          (row) {
            final canonical = _canonicalizeMonitoringRow(row);
            final filtered = TieredFieldRegistry.instance.filterFields(
              model: 'monitoring_event_row',
              payload: canonical,
              tier: tier,
            );
            return filtered;
          },
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> _canonicalizeMonitoringRow(
    Map<String, dynamic> row,
  ) {
    final canonical = <String, dynamic>{};
    for (final entry in row.entries) {
      canonical[entry.key] = _normalizeMonitoringValue(entry.value);
    }
    return canonical;
  }

  static dynamic _normalizeMonitoringValue(dynamic value) {
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }


  // === Template Download Methods ===

  /// Downloads an empty CSV template for the specified template kind.
  ///
  /// Useful for users who want to populate data offline and import later.
  static Future<void> downloadEmptyTemplate({
    required CsvTemplateKind template,
    required String orgDomain,
    String? fileNameOverride,
  }) async {
    final schema = _registry.schemaFor(template);
    final fileName = fileNameOverride ?? '${template.name}_template.csv';

    // Build metadata rows
    final metadataRows = _metadataBuilder.buildMetadataRows(
      kind: template,
      orgDomain: orgDomain,
      generatedAt: DateTime.now(),
      versionOverride: schema.version,
    );

    // Build CSV with metadata + header row (no data rows)
    final csvRows = <List<dynamic>>[...metadataRows, schema.allColumns];

    final csvString = csvRows
        .map(
          (row) => row
              .map((field) => ExportFormatters.escapeCsvField(field))
              .join(','),
        )
        .join('\n');

    await _downloadCSV(csvString, fileName);
  }

  /// Returns metadata about available templates for UI display.
  static List<CsvTemplateInfo> getAvailableTemplates() {
    return [
      CsvTemplateInfo(
        kind: CsvTemplateKind.genetics,
        title: 'Genetics / Provenance',
        description: 'Import genetic lineage and provenance data',
        icon: 'dna',
        columnCount: CsvSchemas.genetics.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryMinimal,
        title: 'Inventory (Minimal)',
        description: 'Simple 5-axis inventory import with essential columns only',
        icon: 'inventory_minimal',
        columnCount: CsvSchemas.inventoryMinimal.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryCoral,
        title: 'Inventory (Coral)',
        description: 'Coral-specific inventory with bleaching and disease fields',
        icon: 'coral',
        columnCount: CsvSchemas.inventoryCoral.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryOyster,
        title: 'Inventory (Oyster)',
        description: 'Oyster-specific inventory with reef and shell metrics',
        icon: 'oyster',
        columnCount: CsvSchemas.inventoryOyster.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryKelp,
        title: 'Inventory (Kelp)',
        description: 'Kelp-specific inventory with biomass and fouling fields',
        icon: 'kelp',
        columnCount: CsvSchemas.inventoryKelp.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventorySeagrass,
        title: 'Inventory (Seagrass)',
        description: 'Seagrass-specific inventory with shoot density fields',
        icon: 'seagrass',
        columnCount: CsvSchemas.inventorySeagrass.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryMangrove,
        title: 'Inventory (Mangrove)',
        description: 'Mangrove-specific inventory with DBH and survival fields',
        icon: 'mangrove',
        columnCount: CsvSchemas.inventoryMangrove.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryFinfish,
        title: 'Inventory (Finfish)',
        description: 'Finfish-specific inventory with FCR and health fields',
        icon: 'finfish',
        columnCount: CsvSchemas.inventoryFinfish.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.inventoryCrab,
        title: 'Inventory (Crab)',
        description: 'Crab-specific inventory with molt and egg fields',
        icon: 'crab',
        columnCount: CsvSchemas.inventoryCrab.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.outplanting,
        title: 'Outplanting Events',
        description: 'Import outplanting/deployment events with permit data',
        icon: 'outplanting',
        columnCount: CsvSchemas.outplanting.allColumns.length,
      ),
      CsvTemplateInfo(
        kind: CsvTemplateKind.outplantAllocations,
        title: 'Outplant Allocations',
        description: 'Import allocation details for outplanting events',
        icon: 'allocations',
        columnCount: CsvSchemas.outplantAllocations.allColumns.length,
      ),
    ];
  }

  // === Excel Export Methods ===

  /// Generate CSV string from headers and rows (using csv package)
  ///
  /// This method uses the csv package for proper CSV generation.
  /// For simple CSV exports, use [exportToCSV] instead.
  static String generateCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<String>? prefaceLines,
  }) {
    return ExportFormatters.generateCsv(
      headers: headers,
      rows: rows,
      prefaceLines: prefaceLines,
    );
  }

  /// Generate Excel (XLSX) file from headers and rows
  ///
  /// Returns the file as Uint8List bytes that can be saved to disk.
  static Uint8List generateXlsx({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<String>? prefaceLines,
  }) {
    return ExportFormatters.generateXlsx(
      sheetName: sheetName,
      headers: headers,
      rows: rows,
      prefaceLines: prefaceLines,
    );
  }
}

void _overrideMetadata(
  List<List<String>> rows,
  Map<String, String> map,
  Map<String, String> updates,
) {
  updates.forEach((key, value) {
    var applied = false;
    for (final row in rows) {
      if (row.isNotEmpty && row.first == key) {
        if (row.length > 1) {
          row[1] = value;
        } else {
          row.add(value);
        }
        applied = true;
        break;
      }
    }
    if (!applied) {
      rows.add([key, value]);
    }
    map[key] = value;
  });
}

/// Metadata about a CSV template for UI display.
class CsvTemplateInfo {
  const CsvTemplateInfo({
    required this.kind,
    required this.title,
    required this.description,
    required this.icon,
    required this.columnCount,
  });

  final CsvTemplateKind kind;
  final String title;
  final String description;
  final String icon;
  final int columnCount;
}
