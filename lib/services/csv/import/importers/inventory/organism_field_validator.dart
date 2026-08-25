import 'package:seafoundry_community/models/alias.dart';
import 'package:seafoundry_community/models/genet.dart';
import 'package:seafoundry_community/models/group.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';
import 'package:seafoundry_community/models/population_measurement.dart';
import 'package:seafoundry_community/models/types/health_status.dart';
import 'package:seafoundry_community/models/types/measurement_unit.dart';
import 'package:seafoundry_community/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/builders/size_spec_builder.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/inventory_lookup_service.dart';
import 'package:seafoundry_community/constants/csv_schema.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/inventory_row_parser.dart';
import 'package:seafoundry_community/services/csv/import/importers/inventory/organism_raw_field_extractor.dart';
import 'package:seafoundry_community/services/species_registry.dart';
import 'package:seafoundry_community/models/inventory/size_spec.dart';

/// Validated fields extracted from an organism CSV row.
class ValidatedOrganismFields {
  const ValidatedOrganismFields({
    required this.organism,
    required this.targetGroup,
    required this.localGenetId,
    required this.tagId,
    required this.speciesId,
    required this.physicalFormId,
    required this.quantity,
    required this.populationMeasurement,
    required this.updateHealthStatus,
    required this.healthStatus,
    required this.updateSizeSpec,
    required this.sizeSpec,
    required this.shouldUpdateNotes,
    required this.notes,
    required this.updateGenet,
    required this.genet,
    required this.lastEventAt,
    required this.aliases,
  });

  final OrganismRecord organism;
  final Group targetGroup;
  final String localGenetId;
  final String tagId;
  final String speciesId;
  final String physicalFormId;
  final int quantity;
  final PopulationMeasurement? populationMeasurement;
  final bool updateHealthStatus;
  final HealthStatus? healthStatus;
  final bool updateSizeSpec;
  final SizeSpec sizeSpec;
  final bool shouldUpdateNotes;
  final String? notes;
  final bool updateGenet;
  final Genet? genet;
  final String? lastEventAt;
  final List<OrganismAlias> aliases;
}

/// Validates and extracts fields from organism CSV import rows.
///
/// Handles field extraction, type validation, and lookup operations
/// for organism records during CSV import.
class OrganismFieldValidator {
  OrganismFieldValidator({
    required InventoryLookupService lookupService,
  }) : _lookupService = lookupService;

  final InventoryLookupService _lookupService;

  /// Extracts and validates all fields from a CSV row.
  ///
  /// Returns null if validation fails, with errors added to [rowErrors].
  /// Non-blocking warnings (e.g., aliasesJson fallback) are added to [rowErrors]
  /// but don't prevent validation from succeeding.
  Future<ValidatedOrganismFields?> extractAndValidateFields(
    Map<String, String> row, {
    required int rowNumber,
    required List<CSVImportError> rowErrors,
  }) async {
    // Extract raw field values
    final rawFields = OrganismRawFieldExtractor.extract(row);

    // Collect non-blocking warnings separately
    final warnings = <CSVImportError>[];

    // Validate required fields
    _validateRequiredFields(rawFields, rowNumber, rowErrors);

    // Parse and validate typed fields
    final parsedFields = _parseTypedFields(
      row,
      rawFields,
      rowNumber,
      rowErrors,
      warnings: warnings,
    );

    // Return early if blocking validation errors exist
    if (rowErrors.isNotEmpty) {
      // Still add warnings to rowErrors for reporting
      rowErrors.addAll(warnings);
      return null;
    }

    // Perform lookup operations
    final lookupResult = await _performLookups(rawFields, rowNumber, rowErrors);

    if (lookupResult == null) {
      // Still add warnings to rowErrors for reporting
      rowErrors.addAll(warnings);
      return null;
    }

    // Add non-blocking warnings to rowErrors for reporting
    rowErrors.addAll(warnings);

    return ValidatedOrganismFields(
      organism: lookupResult.organism,
      targetGroup: lookupResult.targetGroup,
      localGenetId: rawFields.localGenetId,
      tagId: rawFields.tagId!,
      speciesId: rawFields.speciesIdRaw,
      physicalFormId: parsedFields.canonicalPhysicalFormId!,
      quantity: parsedFields.quantity!,
      populationMeasurement: parsedFields.populationMeasurement,
      updateHealthStatus: parsedFields.updateHealthStatus,
      healthStatus: parsedFields.healthStatus,
      updateSizeSpec: parsedFields.updateSizeSpec,
      sizeSpec: parsedFields.sizeSpec,
      shouldUpdateNotes: rawFields.notes != null,
      notes: rawFields.notes,
      updateGenet: lookupResult.updateGenet,
      genet: lookupResult.genet,
      lastEventAt: parsedFields.lastEventAt,
      aliases: parsedFields.aliases,
    );
  }

  void _validateRequiredFields(
    OrganismRawFields fields,
    int rowNumber,
    List<CSVImportError> rowErrors,
  ) {
    if (fields.organismId.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'organismId',
        value: '',
        message: 'Missing organismId (Firestore document ID). '
            'Use organismId or coralId column, not provenanceId.',
      ));
    }
    // Reject provenance ID format (PID- or legacy SF-) in organismId column.
    // organismId must be a Firestore document ID, not a lineage identifier.
    final isLegacyProvenance =
        CsvColumnNames.isLegacyProvenanceIdFormat(fields.organismId);
    if (fields.organismId.isNotEmpty &&
        (CsvColumnNames.isProvenanceIdFormat(fields.organismId) ||
            isLegacyProvenance)) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'organismId',
        value: fields.organismId,
        message: 'organismId must be a Firestore document ID, not a '
            'provenance/lineage ID (PID- prefix). '
            'Found "${fields.organismId}" which looks like a lineage ID. '
            'Use the provenanceId column for lineage identifiers.',
      ));
    }
    // Reject Firestore doc ID format in provenanceId column.
    // provenanceId must be a lineage ID (PID- prefix).
    if (fields.provenanceId.isNotEmpty &&
        CsvColumnNames.isLegacyProvenanceIdFormat(fields.provenanceId)) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'provenanceId',
        value: fields.provenanceId,
        message: 'provenanceId must use the PID- prefix. Legacy SF- '
            'provenance IDs are not supported.',
      ));
    } else if (fields.provenanceId.isNotEmpty &&
        CsvColumnNames.isDocIdFormat(fields.provenanceId)) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'provenanceId',
        value: fields.provenanceId,
        message: 'provenanceId must be a lineage ID (PID- prefix), '
            'not a Firestore document ID. '
            'Found "${fields.provenanceId}" which looks like a doc ID. '
            'Use the organismId column for Firestore document IDs.',
      ));
    }
    if (fields.provenanceId.isEmpty && fields.genetProvenanceIdRaw.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'provenanceId',
        value: fields.provenanceId,
        message: 'Missing provenanceId (lineage identifier)',
      ));
    }
    if (fields.groupPath.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'groupId',
        value: fields.groupPath,
        message: 'Missing groupId',
      ));
    }
    if (fields.speciesIdRaw.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'speciesId',
        value: fields.speciesIdRaw,
        message: 'Missing species identifier',
      ));
    }
    if (fields.localGenetId.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'localGenetId',
        value: fields.localGenetId,
        message: 'Missing local ID for organism',
      ));
    }

    // Derive record name if not provided
    fields.deriveRecordNameIfEmpty();
    if (fields.tagId == null || fields.tagId!.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'tagId',
        value: fields.tagId ?? '',
        message: 'Missing record name for organism',
      ));
    }
  }

  _ParsedFields _parseTypedFields(
    Map<String, String> row,
    OrganismRawFields rawFields,
    int rowNumber,
    List<CSVImportError> rowErrors, {
    List<CSVImportError>? warnings,
  }) {
    // Parse population measurement
    final populationMeasurement = InventoryRowParser.parsePopulationMeasurement(
      rowNumber: rowNumber,
      valueRaw: rawFields.populationValueRaw,
      unitRaw: rawFields.populationUnitRaw,
      existingErrors: rowErrors,
    );

    // Parse quantity
    int? quantity = int.tryParse(rawFields.quantityStr);
    if (quantity == null || quantity < 0) {
      if (populationMeasurement != null &&
          populationMeasurement.unit == MeasurementUnit.count &&
          populationMeasurement.value >= 0 &&
          populationMeasurement.value ==
              populationMeasurement.value.roundToDouble()) {
        quantity = populationMeasurement.value.toInt();
      } else {
        rowErrors.add(CSVImportError(
          row: rowNumber,
          field: 'quantity',
          value: rawFields.quantityStr,
          message: 'Quantity must be a non-negative integer',
        ));
      }
    }

    // Validate species
    final species =
        SpeciesRegistry.globalById(rawFields.speciesIdRaw, allowFallback: false);
    if (species == null) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'speciesId',
        value: rawFields.speciesIdRaw,
        message: 'Unknown species identifier',
      ));
    }

    // Validate coral type / physical form
    final canonicalPhysicalFormId = rawFields.physicalFormIdRaw.trim();
    if (canonicalPhysicalFormId.isEmpty) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'physicalFormId',
        value: rawFields.physicalFormIdRaw,
        message: 'Physical form ID is required',
      ));
    }

    // Parse optional health status
    HealthStatus? healthStatus;
    var updateHealthStatus = false;
    if (rawFields.healthStatusIdRaw.isNotEmpty) {
      updateHealthStatus = true;
      healthStatus = HealthStatus.maybeFromId(rawFields.healthStatusIdRaw);
      if (healthStatus == null) {
        rowErrors.add(CSVImportError(
          row: rowNumber,
          field: 'healthStatus',
          value: rawFields.healthStatusIdRaw,
          message: 'Unknown health status identifier',
        ));
      }
    }

    final sizeSpec = SizeSpecBuilder.build(row);
    final updateSizeSpec = !sizeSpec.isEmpty;

    // Parse optional last event timestamp
    String? lastEventAt;
    if (rawFields.lastEventAtRaw.isNotEmpty) {
      final parsedDate = DateTime.tryParse(rawFields.lastEventAtRaw);
      if (parsedDate == null) {
        rowErrors.add(CSVImportError(
          row: rowNumber,
          field: 'lastEventAt',
          value: rawFields.lastEventAtRaw,
          message: 'Invalid ISO-8601 timestamp',
        ));
      } else {
        lastEventAt = parsedDate.toIso8601String();
      }
    }

    // Parse aliases - uses warnings for non-blocking fallback errors
    final aliases = InventoryRowParser.parseAliases(
      rawFields.aliasesJson,
      fallbackRaw: rawFields.aliasesRaw,
      errors: rowErrors,
      warnings: warnings,
      rowNum: rowNumber,
    );

    return _ParsedFields(
      populationMeasurement: populationMeasurement,
      quantity: quantity,
      canonicalPhysicalFormId: canonicalPhysicalFormId,
      updateHealthStatus: updateHealthStatus,
      healthStatus: healthStatus,
      updateSizeSpec: updateSizeSpec,
      sizeSpec: sizeSpec,
      lastEventAt: lastEventAt,
      aliases: aliases,
    );
  }

  Future<_LookupResult?> _performLookups(
    OrganismRawFields rawFields,
    int rowNumber,
    List<CSVImportError> rowErrors,
  ) async {
    // Lookup organism
    final organism = await _lookupService.lookupOrganism(rawFields.organismId);
    if (organism == null) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'organismId',
        value: rawFields.organismId,
        message: 'No organism found for document ID '
            '"${rawFields.organismId}". Ensure organismId contains '
            'the Firestore document ID, not a provenanceId.',
      ));
      return null;
    }

    // Lookup group
    final group = await _lookupService.lookupGroup(rawFields.groupPath);
    if (group == null) {
      rowErrors.add(CSVImportError(
        row: rowNumber,
        field: 'groupId',
        value: rawFields.groupPath,
        message: 'Unknown group path',
      ));
      return null;
    }

    // Lookup genet if provided
    Genet? genet;
    var updateGenet = false;
    if (rawFields.genetProvenanceId.isNotEmpty) {
      updateGenet = true;
      genet = await _lookupService
          .lookupGenetByProvenanceId(rawFields.genetProvenanceId);
      if (genet == null) {
        rowErrors.add(CSVImportError(
          row: rowNumber,
          field: 'provenanceId',
          value: rawFields.genetProvenanceId,
          message: 'Unknown genet identifier',
        ));
        return null;
      }
    }

    return _LookupResult(
      organism: organism,
      targetGroup: group,
      updateGenet: updateGenet,
      genet: genet,
    );
  }
}

/// Internal helper for parsed/typed fields.
class _ParsedFields {
  const _ParsedFields({
    required this.populationMeasurement,
    required this.quantity,
    required this.canonicalPhysicalFormId,
    required this.updateHealthStatus,
    required this.healthStatus,
    required this.updateSizeSpec,
    required this.sizeSpec,
    required this.lastEventAt,
    required this.aliases,
  });

  final PopulationMeasurement? populationMeasurement;
  final int? quantity;
  final String? canonicalPhysicalFormId;
  final bool updateHealthStatus;
  final HealthStatus? healthStatus;
  final bool updateSizeSpec;
  final SizeSpec sizeSpec;
  final String? lastEventAt;
  final List<OrganismAlias> aliases;
}

/// Internal helper for lookup results.
class _LookupResult {
  const _LookupResult({
    required this.organism,
    required this.targetGroup,
    required this.updateGenet,
    required this.genet,
  });

  final OrganismRecord organism;
  final Group targetGroup;
  final bool updateGenet;
  final Genet? genet;
}
