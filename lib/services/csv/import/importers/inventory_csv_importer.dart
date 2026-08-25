import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/models/types/organism_kind.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/inventory_lookup_service.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/organism_row_processor.dart';
import 'package:seafoundry_community/services/csv/import/models/dual_path_validation_result.dart';
import 'package:seafoundry_community/utils/performance_analyzer.dart';
import 'package:seafoundry_community/services/logging_service.dart';

class InventoryCsvImporter {
  InventoryCsvImporter({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required GenetRepository genetRepository,
  })  : _organismRecordRepository = organismRecordRepository,
        _lookupService = InventoryLookupService(
          organismRecordRepository: organismRecordRepository,
          groupRepository: groupRepository,
          genetRepository: genetRepository,
        );

  final OrganismRecordRepository _organismRecordRepository;
  final InventoryLookupService _lookupService;

  late final OrganismRowProcessor _organismRowProcessor = OrganismRowProcessor(
    lookupService: _lookupService,
    organismRecordRepository: _organismRecordRepository,
  );

  /// Validate that organism records exist.
  /// Returns validation summary.
  Future<DualPathValidationResult> validateDualPath() async {
    try {
      final organismRecords = await _organismRecordRepository.getAll();
      final coralRecords = organismRecords
          .where((record) => record.organismKind == OrganismKind.coral)
          .toList();

      final organismCount = coralRecords.length;
      final discrepancies = <String>[];

      // Aggregate measurement
      var totalOrganismCount = 0.0;

      for (final organismRecord in coralRecords) {
        if (organismRecord.measurement.unit == MeasurementUnit.count) {
          totalOrganismCount += organismRecord.measurement.value;
        }
      }

      return DualPathValidationResult(
        isEnabled: true,
        coralCount: organismCount,
        organismRecordCount: organismCount,
        totalCoralQuantity: totalOrganismCount.toInt(),
        totalOrganismQuantity: totalOrganismCount.toInt(),
        orphanedCoralCount: 0,
        discrepancies: discrepancies,
        message: discrepancies.isEmpty
            ? 'Validation passed: $organismCount records, '
                '${totalOrganismCount.toInt()} total quantity'
            : 'Validation found ${discrepancies.length} discrepancies',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Validation failed',
        e,
        stackTrace,
      );
      return DualPathValidationResult(
        isEnabled: true,
        message: 'Validation error: ${e.toString()}',
        discrepancies: ['Exception during validation: ${e.toString()}'],
      );
    }
  }

  Future<CSVImportResult> import({
    required List<Map<String, String>> rows,
    bool validateOnly = false,
    Map<String, String>? metadata,
    String? sourceName,
    CsvTranslationSummary? translationSummary,
    int? totalRowCount,
  }) {
    return PerformanceAnalyzer.measure(
      'CSVImportService.importInventory',
      () async {
        final errors = <CSVImportError>[];
        final updatedOrganisms = <OrganismRecord>[];
        _lookupService.clearCaches();
        int successCount = 0;

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final rowNum = i + 2;
          final rowErrors = <CSVImportError>[];

          // Process organism row
          final result = await _organismRowProcessor.processRow(
            row,
            rowNumber: rowNum,
            rowErrors: rowErrors,
            validateOnly: validateOnly,
            sourceName: sourceName,
          );

          if (rowErrors.isNotEmpty) {
            errors.addAll(rowErrors);
          }

          if (result.success && result.organism != null) {
            updatedOrganisms.add(result.organism!);
            successCount++;
          }
        }

        return CSVImportResult(
          totalRows: totalRowCount ?? rows.length,
          successfulImports: successCount,
          errors: errors,
          importedGenets: const [],
          importedOrganisms: const [],
          updatedOrganisms: updatedOrganisms,
          translationSummary: translationSummary,
        );
      },
      metadata: {
        'validateOnly': validateOnly,
        'totalRows': totalRowCount ?? rows.length,
        if (metadata != null) ...metadata,
        if (sourceName != null) 'sourceName': sourceName,
      },
    );
  }
}
