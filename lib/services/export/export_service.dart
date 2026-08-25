import 'package:seafoundry_community/constants/csv_schema.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/services/csv/adapters/universal_csv_adapter_v2.dart';
import 'package:seafoundry_community/services/csv/csv_metadata_builder.dart';
import 'package:seafoundry_community/services/csv/csv_template_registry.dart';
import 'package:seafoundry_community/services/csv/csv_translation_pipeline.dart';
import 'package:seafoundry_community/services/csv/downloaders/csv_download_interface.dart';
import 'package:seafoundry_community/services/csv/downloaders/csv_download_stub.dart'
    if (dart.library.html) 'package:seafoundry_community/services/csv/downloaders/csv_download_web.dart'
    if (dart.library.io) 'package:seafoundry_community/services/csv/downloaders/csv_download_io.dart';
import 'package:seafoundry_community/services/export/export_formatters.dart';
import 'package:seafoundry_community/services/export/inventory_export_row_formatter.dart';
import 'package:seafoundry_community/services/export/inventory_export_row_source.dart';
import 'package:seafoundry_community/repositories/inventory/archived_organism_record_repository.dart';
import 'package:seafoundry_community/services/organism_holding_loader.dart';
import 'package:seafoundry_community/services/species_registry.dart';
import 'package:seafoundry_community/utils/performance_analyzer.dart';

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

  // _exportOrganismHoldings removed in coral-only simplification

  // === Specialized Export Methods ===

  /// Exports inventory data to CSV
  static Future<void> exportInventoryCSV({
    required List<Map<String, dynamic>> inventoryData,
    required String orgDomain,
    String fileName = 'inventory_export.csv',
    bool download = true,
  }) async {
    return PerformanceAnalyzer.measure(
      'ExportService.exportInventoryCSV',
      () => _performExportInventoryCSV(
        inventoryData: inventoryData,
        orgDomain: orgDomain,
        fileName: fileName,
        download: download,
      ),
      metadata: {'rowCount': inventoryData.length, 'download': download},
    );
  }

  static Future<void> _performExportInventoryCSV({
    required List<Map<String, dynamic>> inventoryData,
    required String orgDomain,
    String fileName = 'inventory_export.csv',
    bool download = true,
  }) async {
    final canonicalRows = inventoryData
        .map((row) => InventoryExportRowFormatter.canonicalize(row))
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
    OrganismHoldingLoader? holdingLoader,
    String fileName = 'inventory_export.csv',
    bool download = true,
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
    );

    final rows = await rowSource.loadRowMaps();
    await exportInventoryCSV(
      inventoryData: rows,
      orgDomain: orgDomain,
      fileName: fileName,
      download: download,
    );
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

