// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_row_processor.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_lookup_service.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/organism/organism_row_processor.dart';
import 'package:seafoundry_app/services/csv/import/models/dual_path_validation_result.dart';
import 'package:seafoundry_app/utils/performance_analyzer.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class InventoryCsvImporter {
  InventoryCsvImporter({
    required OrganismRecordRepository organismRecordRepository,
    required GroupRepository groupRepository,
    required GenetRepository genetRepository,
    Map<OrganismKind, SeededLineRepository>? seededLineRepositories,
    Map<OrganismKind, GameteBatchRepository>? gameteBatchRepositories,
    Map<OrganismKind, LarvalBatchRepository>? larvalBatchRepositories,
    Map<OrganismKind, OysterBagRepository>? oysterBagRepositories,
    Map<OrganismKind, FinfishPenRepository>? finfishPenRepositories,
    Map<OrganismKind, CrabPondRepository>? crabPondRepositories,
    Map<OrganismKind, SeagrassModuleRepository>? seagrassModuleRepositories,
    Map<OrganismKind, MangrovePlotRepository>? mangrovePlotRepositories,
  })  : _organismRecordRepository = organismRecordRepository,
        _lookupService = InventoryLookupService(
          organismRecordRepository: organismRecordRepository,
          groupRepository: groupRepository,
          genetRepository: genetRepository,
        ),
        _seededLineRepositories = seededLineRepositories ?? const {},
        _gameteBatchRepositories = gameteBatchRepositories ?? const {},
        _larvalBatchRepositories = larvalBatchRepositories ?? const {},
        _oysterBagRepositories = oysterBagRepositories ?? const {},
        _finfishPenRepositories = finfishPenRepositories ?? const {},
        _crabPondRepositories = crabPondRepositories ?? const {},
        _seagrassModuleRepositories = seagrassModuleRepositories ?? const {},
        _mangrovePlotRepositories = mangrovePlotRepositories ?? const {};

  final OrganismRecordRepository _organismRecordRepository;
  final InventoryLookupService _lookupService;
  final Map<OrganismKind, SeededLineRepository> _seededLineRepositories;
  final Map<OrganismKind, GameteBatchRepository> _gameteBatchRepositories;
  final Map<OrganismKind, LarvalBatchRepository> _larvalBatchRepositories;
  final Map<OrganismKind, OysterBagRepository> _oysterBagRepositories;
  final Map<OrganismKind, FinfishPenRepository> _finfishPenRepositories;
  final Map<OrganismKind, CrabPondRepository> _crabPondRepositories;
  final Map<OrganismKind, SeagrassModuleRepository> _seagrassModuleRepositories;
  final Map<OrganismKind, MangrovePlotRepository> _mangrovePlotRepositories;

  late final HoldingRowProcessor _holdingRowProcessor = HoldingRowProcessor(
    lookupService: _lookupService,
    seededLineRepositories: _seededLineRepositories,
    gameteBatchRepositories: _gameteBatchRepositories,
    larvalBatchRepositories: _larvalBatchRepositories,
    oysterBagRepositories: _oysterBagRepositories,
    finfishPenRepositories: _finfishPenRepositories,
    crabPondRepositories: _crabPondRepositories,
    seagrassModuleRepositories: _seagrassModuleRepositories,
    mangrovePlotRepositories: _mangrovePlotRepositories,
  );

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

          // Check for holding row
          final holdingKind = (row['holdingKind'] ?? '').trim();
          if (holdingKind.isNotEmpty) {
            final handled = await _holdingRowProcessor.processRow(
              row,
              holdingKind: holdingKind,
              rowNumber: rowNum,
              rowErrors: rowErrors,
              validateOnly: validateOnly,
              sourceName: sourceName,
            );
            if (rowErrors.isNotEmpty) {
              errors.addAll(rowErrors);
            } else if (handled) {
              successCount += 1;
            }
            continue;
          }

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
