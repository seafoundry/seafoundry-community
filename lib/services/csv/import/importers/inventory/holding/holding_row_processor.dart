// @tier: community
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/crab_pond_repository.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/gamete_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/repositories/inventory/mangrove_plot_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seeded_line_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/holding_attributes_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/size_spec_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/crab_pond_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/finfish_pen_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/gamete_batch_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_type_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/larval_batch_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/mangrove_plot_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/oyster_bag_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/seagrass_module_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/seeded_line_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_lookup_service.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_row_parser.dart';
import 'package:seafoundry_app/utils/record_name_derived.dart';

/// Coordinates holding type handlers for CSV import.
///
/// Validates common holding fields and dispatches to the appropriate handler
/// based on holding kind.
class HoldingRowProcessor {
  HoldingRowProcessor({
    required InventoryLookupService lookupService,
    required Map<OrganismKind, SeededLineRepository> seededLineRepositories,
    required Map<OrganismKind, GameteBatchRepository> gameteBatchRepositories,
    required Map<OrganismKind, LarvalBatchRepository> larvalBatchRepositories,
    required Map<OrganismKind, OysterBagRepository> oysterBagRepositories,
    required Map<OrganismKind, FinfishPenRepository> finfishPenRepositories,
    required Map<OrganismKind, CrabPondRepository> crabPondRepositories,
    required Map<OrganismKind, SeagrassModuleRepository>
        seagrassModuleRepositories,
    required Map<OrganismKind, MangrovePlotRepository> mangrovePlotRepositories,
  })  : _lookupService = lookupService,
        _handlers = [
          SeededLineHandler(repositories: seededLineRepositories),
          GameteBatchHandler(repositories: gameteBatchRepositories),
          LarvalBatchHandler(repositories: larvalBatchRepositories),
          OysterBagHandler(repositories: oysterBagRepositories),
          FinfishPenHandler(repositories: finfishPenRepositories),
          CrabPondHandler(repositories: crabPondRepositories),
          SeagrassModuleHandler(repositories: seagrassModuleRepositories),
          MangrovePlotHandler(repositories: mangrovePlotRepositories),
        ];

  static const String _populationValueField = 'quantityValue';
  static const String _populationUnitField = 'measurementUnit';

  final InventoryLookupService _lookupService;
  final List<HoldingTypeHandler> _handlers;

  /// Process a holding row from CSV import.
  ///
  /// Returns true if successful, false if validation failed or handler missing.
  Future<bool> processRow(
    Map<String, String> row, {
    required String holdingKind,
    required int rowNumber,
    required List<CSVImportError> rowErrors,
    required bool validateOnly,
    String? sourceName,
  }) async {
    final validated = await _validateCommonFields(
      row,
      rowNumber: rowNumber,
      rowErrors: rowErrors,
    );
    if (validated == null) {
      return false;
    }

    final handler = _findHandler(holdingKind);
    if (handler == null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'holdingKind',
          value: holdingKind,
          message: 'Unsupported holding type.',
        ),
      );
      return false;
    }

    final repository = handler.getRepository(validated.organismKind);
    if (repository == null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'holdingKind',
          value: holdingKind,
          message: '${handler.holdingKind} repository is not configured.',
        ),
      );
      return false;
    }

    final params = HoldingBuildParams(
      row: row,
      provenanceId: validated.provenanceId,
      targetGroup: validated.targetGroup,
      organismKind: validated.organismKind,
      measurement: validated.measurement,
      localId: validated.localId,
      recordName: validated.recordName,
      sizeSpec: validated.sizeSpec,
      attributes: validated.attributes,
      aliases: validated.aliases,
      ownerOrganizationId: validated.ownerOrganizationId,
      managingOrganizationId: validated.managingOrganizationId,
      foreignKeys: validated.foreignKeys,
      sourceName: sourceName,
    );

    final holding = handler.buildHolding(params);

    // Validate 5-axis constraints
    final validationError = holding.organismRecord.validateFiveAxisConstraints();
    if (validationError != null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'organismRecord',
          value: holdingKind,
          message: validationError,
        ),
      );
      return false;
    }

    if (validateOnly) {
      return await _previewHoldingWithCapacity(
        repository: repository,
        holding: holding,
        rowErrors: rowErrors,
        rowNumber: rowNumber,
      );
    }

    return await _saveHoldingWithCapacityGuard(
      repository: repository,
      holding: holding,
      rowErrors: rowErrors,
      rowNumber: rowNumber,
    );
  }

  HoldingTypeHandler? _findHandler(String holdingKind) {
    for (final handler in _handlers) {
      if (handler.canHandle(holdingKind)) {
        return handler;
      }
    }
    return null;
  }

  Future<_ValidatedHoldingFields?> _validateCommonFields(
    Map<String, String> row, {
    required int rowNumber,
    required List<CSVImportError> rowErrors,
  }) async {
    final provenanceId =
        (row['provenanceId'] ?? '').trim();
    if (provenanceId.isEmpty) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'provenanceId',
          value: provenanceId,
          message: 'Holding rows require provenanceId.',
        ),
      );
      return null;
    }

    if (await _lookupService.lookupGenetByProvenanceId(provenanceId) == null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'provenanceId',
          value: provenanceId,
          message: 'Unknown genet identifier. Holdings must reference an '
              'existing genet.',
        ),
      );
      return null;
    }

    final groupPath = (row['groupId'] ?? '').trim();
    if (groupPath.isEmpty) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'groupId',
          value: '',
          message: 'groupId is required for holding rows.',
        ),
      );
    }

    final organismKind =
        InventoryRowParser.parseOrganismKindValue(row['organismKind']);
    if (organismKind == null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'organismKind',
          value: row['organismKind'] ?? '',
          message: 'Unsupported organism kind for holding rows.',
        ),
      );
    }

    final measurement = InventoryRowParser.parsePopulationMeasurement(
      rowNumber: rowNumber,
      valueRaw: row[_populationValueField] ?? '',
      unitRaw: row[_populationUnitField] ?? '',
      existingErrors: rowErrors,
    );

    final localId = (row['localId'] ?? '').trim();
    final rawRecordName = row['recordName'];
    String? recordName =
        rawRecordName != null && rawRecordName.trim().isNotEmpty
            ? rawRecordName.trim()
            : null;
    if (recordName == null || recordName.isEmpty) {
      recordName = RecordNameDerived.fromLocalId(localId);
    }

    if (localId.isEmpty) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'localId',
          value: localId,
          message: 'localId is required for holding rows.',
        ),
      );
    }
    if (recordName == null || recordName.isEmpty) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'recordName',
          value: recordName ?? '',
          message: 'recordName is required for holding rows.',
        ),
      );
    }

    final sizeSpec = SizeSpecBuilder.build(row);
    final resolvedSizeSpec = sizeSpec.copyWith(
      sizeBandId: sizeSpec.sizeBandId ?? kDefaultSizeBandId,
    );
    final attributes = HoldingAttributesBuilder.build(row);

    if (groupPath.isEmpty ||
        organismKind == null ||
        measurement == null ||
        localId.isEmpty ||
        recordName == null ||
        recordName.isEmpty) {
      return null;
    }

    final targetGroup = await _lookupService.lookupGroup(groupPath);
    if (targetGroup == null) {
      rowErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'groupId',
          value: groupPath,
          message: 'Unknown group url path: $groupPath',
        ),
      );
      return null;
    }

    final ownerOrganizationId =
        InventoryRowParser.emptyToNull(row['ownerOrganizationId']);
    final managingOrganizationId =
        InventoryRowParser.emptyToNull(row['managingOrganizationId']);
    final foreignKeys = InventoryRowParser.parseForeignKeys(row['foreignKeys']);
    final aliasEntries = InventoryRowParser.parseAliases(
      row['aliasesJson'],
      fallbackRaw: row['aliases'],
      errors: rowErrors,
      rowNum: rowNumber,
    );

    return _ValidatedHoldingFields(
      provenanceId: provenanceId,
      targetGroup: targetGroup,
      organismKind: organismKind,
      measurement: measurement,
      localId: localId,
      recordName: recordName,
      sizeSpec: resolvedSizeSpec,
      attributes: attributes,
      aliases: aliasEntries,
      ownerOrganizationId: ownerOrganizationId,
      managingOrganizationId: managingOrganizationId,
      foreignKeys: foreignKeys,
    );
  }

  Future<bool> _previewHoldingWithCapacity<T extends HoldingRecord>({
    required HoldingRepository<T> repository,
    required T holding,
    required List<CSVImportError> rowErrors,
    required int rowNumber,
  }) async {
    try {
      final previous =
          holding.id.isEmpty ? null : await repository.getHolding(holding.id);
      await repository.previewOccupantCapacity(
        holding: holding,
        previousHolding: previous,
      );
      return rowErrors.isEmpty;
    } on CapabilityConstraintError catch (error) {
      _appendCapacityError(
        rowErrors: rowErrors,
        rowNumber: rowNumber,
        holding: holding,
        error: error,
      );
      return false;
    }
  }

  Future<bool> _saveHoldingWithCapacityGuard<T extends HoldingRecord>({
    required HoldingRepository<T> repository,
    required T holding,
    required List<CSVImportError> rowErrors,
    required int rowNumber,
  }) async {
    try {
      await _upsertHolding(repository, holding);
      return rowErrors.isEmpty;
    } on CapabilityConstraintError catch (error) {
      _appendCapacityError(
        rowErrors: rowErrors,
        rowNumber: rowNumber,
        holding: holding,
        error: error,
      );
      return false;
    }
  }

  Future<void> _upsertHolding<T extends HoldingRecord>(
    HoldingRepository<T> repository,
    T holding,
  ) async {
    final existing = await repository.getHolding(holding.id);
    if (existing == null) {
      await repository.createHolding(holding);
    } else {
      await repository.updateHolding(holding);
    }
  }

  void _appendCapacityError({
    required List<CSVImportError> rowErrors,
    required int rowNumber,
    required HoldingRecord holding,
    required CapabilityConstraintError error,
  }) {
    final detail = error.recoverySuggestion != null &&
            error.recoverySuggestion!.isNotEmpty
        ? '${error.message} ${error.recoverySuggestion}'
        : error.message;
    rowErrors.add(
      CSVImportError(
        row: rowNumber,
        field: 'groupId',
        value: holding.groupId ?? holding.structureId ?? 'unknown',
        message: detail,
      ),
    );
  }
}

class _ValidatedHoldingFields {
  const _ValidatedHoldingFields({
    required this.provenanceId,
    required this.targetGroup,
    required this.organismKind,
    required this.measurement,
    required this.localId,
    required this.recordName,
    required this.sizeSpec,
    required this.attributes,
    required this.aliases,
    required this.ownerOrganizationId,
    required this.managingOrganizationId,
    required this.foreignKeys,
  });

  final String provenanceId;
  final Group targetGroup;
  final OrganismKind organismKind;
  final PopulationMeasurement measurement;
  final String localId;
  final String recordName;
  final SizeSpec sizeSpec;
  final HoldingAttributes attributes;
  final List<OrganismAlias> aliases;
  final String? ownerOrganizationId;
  final String? managingOrganizationId;
  final Map<String, ForeignKeyReference> foreignKeys;
}
