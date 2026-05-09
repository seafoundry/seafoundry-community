// @tier: community
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/csv/csv_translation_pipeline.dart';
import 'package:seafoundry_app/services/csv/csv_versioning_service.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_parser.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_version_utils.dart';
import 'package:seafoundry_app/services/csv/import/importers/genetics_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplant_allocations_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplant_consolidated_csv_importer.dart';
import 'package:seafoundry_app/services/csv/import/importers/outplanting_csv_importer.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';

/// Central orchestration layer for CSV imports.
///
/// Responsibilities:
/// * Validates file metadata/version against the active organization
/// * Runs the translation pipeline to normalize rows + track issues
/// * Dispatches to the importer that owns the target template
/// * Wraps the work in PerformanceAnalyzer for observability
class CsvImportCoordinator {
  CsvImportCoordinator({
    required EventRepository eventRepository,
    required CsvVersioningService versioningService,
    required CsvTranslationPipeline translationPipeline,
    required GeneticsCsvImporter geneticsImporter,
    required InventoryCsvImporter inventoryImporter,
    required OutplantingCsvImporter outplantingImporter,
    required OutplantAllocationsCsvImporter outplantAllocationsImporter,
    required OutplantConsolidatedCsvImporter outplantConsolidatedImporter,
    SpeciesRegistry? speciesRegistry,
  }) : _eventRepository = eventRepository,
       _versioningService = versioningService,
       _translationPipeline = translationPipeline,
       _geneticsImporter = geneticsImporter,
       _inventoryImporter = inventoryImporter,
       _outplantingImporter = outplantingImporter,
       _outplantAllocationsImporter = outplantAllocationsImporter,
       _outplantConsolidatedImporter = outplantConsolidatedImporter,
       _speciesRegistry =
           speciesRegistry ?? SpeciesRegistry.globalInstance ?? SpeciesRegistry();

  final EventRepository _eventRepository;
  final CsvVersioningService _versioningService;
  final CsvTranslationPipeline _translationPipeline;
  final GeneticsCsvImporter _geneticsImporter;
  final InventoryCsvImporter _inventoryImporter;
  final OutplantingCsvImporter _outplantingImporter;
  final OutplantAllocationsCsvImporter _outplantAllocationsImporter;
  final OutplantConsolidatedCsvImporter _outplantConsolidatedImporter;
  final SpeciesRegistry _speciesRegistry;

  Future<CSVImportResult> import({
    required CSVImportType importType,
    required CsvParsedData parsed,
    required bool validateOnly,
    String? sourceName,
  }) async {
    return PerformanceAnalyzer.measure(
      'CSVImportCoordinator.import',
      () => _performImport(
        importType: importType,
        parsed: parsed,
        validateOnly: validateOnly,
        sourceName: sourceName,
      ),
      metadata: {
        'importType': importType.name,
        'rowCount': parsed.rows.length,
        'validateOnly': validateOnly,
      },
    );
  }

  Future<CSVImportResult> _performImport({
    required CSVImportType importType,
    required CsvParsedData parsed,
    required bool validateOnly,
    String? sourceName,
  }) async {
    validateCsvVersion(
      importType: importType,
      metadata: parsed.metadata,
      versioningService: _versioningService,
    );

    final templateKind = resolveTemplateKind(importType, parsed.metadata);
    final metadataOrgDomain = parsed.metadata['orgDomain']
        ?.trim()
        .toLowerCase();
    final activeOrgDomain = _eventRepository.organization.domain
        .trim()
        .toLowerCase();

    if (metadataOrgDomain != null &&
        metadataOrgDomain.isNotEmpty &&
        activeOrgDomain.isNotEmpty &&
        metadataOrgDomain != activeOrgDomain) {
      final originLabel = sourceName?.isNotEmpty == true ? sourceName! : 'CSV';
      throw FormatException(
        'Import source "$originLabel" targets "$metadataOrgDomain" but the active organization is "$activeOrgDomain".',
      );
    }

    final originalRowCount = parsed.rows.length;
    var effectiveMetadata = Map<String, String>.from(parsed.metadata);
    var effectiveRows = parsed.rows;
    final translation = _translationPipeline.translateImportRows(
      kind: templateKind,
      metadata: effectiveMetadata,
      rows: effectiveRows,
      sourceName: sourceName,
      speciesRegistry: _speciesRegistry,
    );

    final translatedRows = translation.rows;
    final summary =
        (translation.issues.isNotEmpty || translation.blockedRowCount > 0)
        ? CsvTranslationSummary.fromResult(translation)
        : null;

    if (translatedRows.isEmpty) {
      if (summary?.hasIssues ?? false) {
        return CSVImportResult(
          totalRows: originalRowCount,
          successfulImports: 0,
          errors: const [],
          importedGenets: const [],
          importedOrganisms: const [],
          translationSummary: summary,
        );
      }
      throw Exception('CSV file is empty');
    }

    switch (templateKind) {
      case CsvTemplateKind.genetics:
        return _geneticsImporter.import(
          rows: translatedRows,
          validateOnly: validateOnly,
          translationSummary: summary,
          totalRowCount: originalRowCount,
        );
      case CsvTemplateKind.inventory:
      case CsvTemplateKind.inventoryMinimal:
      case CsvTemplateKind.inventoryCoral:
        return _inventoryImporter.import(
          rows: translatedRows,
          validateOnly: validateOnly,
          metadata: effectiveMetadata,
          sourceName: sourceName,
          translationSummary: summary,
          totalRowCount: originalRowCount,
        );
      case CsvTemplateKind.outplanting:
        return _outplantingImporter.import(
          rows: translatedRows,
          validateOnly: validateOnly,
          metadata: effectiveMetadata,
          sourceName: sourceName,
          translationSummary: summary,
          totalRowCount: originalRowCount,
        );
      case CsvTemplateKind.outplantAllocations:
        return _outplantAllocationsImporter.import(
          rows: translatedRows,
          validateOnly: validateOnly,
          metadata: effectiveMetadata,
          translationSummary: summary,
          totalRowCount: originalRowCount,
        );
      case CsvTemplateKind.outplantConsolidated:
        return _outplantConsolidatedImporter.import(
          rows: translatedRows,
          validateOnly: validateOnly,
          metadata: effectiveMetadata,
          sourceName: sourceName,
          translationSummary: summary,
          totalRowCount: originalRowCount,
        );
    }
  }
}
