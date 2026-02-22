// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_import_row.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_lookup_service.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/organism/organism_field_validator.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/organism/organism_metadata_updater.dart';

/// Result of processing an organism row.
class OrganismRowResult {
  const OrganismRowResult({
    required this.success,
    this.organism,
  });

  final bool success;
  final OrganismRecord? organism;
}

/// Processes organism record rows from CSV import.
///
/// Orchestrates field validation and metadata updates for organism records.
/// Delegates to [OrganismFieldValidator] for field extraction/validation
/// and [OrganismMetadataUpdater] for applying changes.
class OrganismRowProcessor {
  OrganismRowProcessor({
    required InventoryLookupService lookupService,
    required OrganismRecordRepository organismRecordRepository,
  })  : _fieldValidator = OrganismFieldValidator(lookupService: lookupService),
        _metadataUpdater = OrganismMetadataUpdater(
          organismRecordRepository: organismRecordRepository,
        );

  final OrganismFieldValidator _fieldValidator;
  final OrganismMetadataUpdater _metadataUpdater;

  /// Process an organism row from CSV import.
  ///
  /// Returns result with success flag and updated organism if applicable.
  Future<OrganismRowResult> processRow(
    Map<String, String> row, {
    required int rowNumber,
    required List<CSVImportError> rowErrors,
    required bool validateOnly,
    String? sourceName,
  }) async {
    // Extract and validate fields
    final validated = await _fieldValidator.extractAndValidateFields(
      row,
      rowNumber: rowNumber,
      rowErrors: rowErrors,
    );

    if (validated == null) {
      return const OrganismRowResult(success: false);
    }

    // Build the row model
    final rowModel = InventoryImportRow(
      rowNumber: rowNumber,
      organism: validated.organism,
      targetGroup: validated.targetGroup,
      localId: validated.localId,
      recordName: validated.recordName,
      speciesId: validated.speciesId,
      physicalFormId: validated.physicalFormId,
      quantity: validated.quantity,
      populationMeasurement: validated.populationMeasurement,
      updateHealthStatus: validated.updateHealthStatus,
      healthStatus: validated.healthStatus,
      updateSizeSpec: validated.updateSizeSpec,
      sizeSpec: validated.sizeSpec,
      shouldUpdateNotes: validated.shouldUpdateNotes,
      notes: validated.notes,
      updateGenet: validated.updateGenet,
      genet: validated.genet,
      lastEventAt: validated.lastEventAt,
      aliases: validated.aliases,
    );

    final updated = validateOnly
        ? rowModel.organism
        : await _metadataUpdater.applyInventoryRow(
            rowModel,
            sourceName: sourceName,
          );

    return OrganismRowResult(
      success: updated != null,
      organism: updated,
    );
  }
}
