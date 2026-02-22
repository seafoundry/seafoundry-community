// @tier: community
part of 'universal_csv_adapter_v2.dart';

/// Row validation methods for [UniversalCsvAdapterV2].
///
/// This part file contains all the validation logic for CSV v2 rows,
/// including required field checks, organism/life stage validation,
/// and measurement unit validation.
extension _UniversalCsvAdapterV2Validator on UniversalCsvAdapterV2 {
  List<CsvTranslationIssue> validateRow(
    Map<String, String> row,
    int rowNumber,
  ) {
    final issues = <CsvTranslationIssue>[];

    for (final field in UniversalCsvAdapterV2._requiredFields) {
      // Check for canonical field name only
      final hasValue = (row[field] ?? '').isNotEmpty;
      if (!hasValue) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: field,
            value: '',
            message: 'Field "$field" is required in CSV v2.',
          ),
        );
      }
    }

    final organismKind = parseOrganismKind(row['organismKind']);
    if (row['organismKind'] != null && organismKind == null) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'organismKind',
          value: row['organismKind'] ?? '',
          message:
              'Unknown organismKind. See docs/taxonomy/README.md (CSV v2 Schema section) / CSV v2 spec.',
        ),
      );
    }

    final lifeStageRaw = row['lifeStage'];
    final parsedLifeStage = parseLifeStage(lifeStageRaw);
    if (lifeStageRaw != null && lifeStageRaw.isNotEmpty) {
      if (parsedLifeStage == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'lifeStage',
            value: lifeStageRaw,
            message:
                'Unknown lifeStage "$lifeStageRaw". See docs/taxonomy/README.md CSV v2 schema.',
          ),
        );
      } else if (organismKind != null) {
        final allowedStages =
            UniversalCsvAdapterV2._lifeStageLookup[organismKind] ?? const {};
        if (!allowedStages.contains(parsedLifeStage)) {
          final expected = allowedStages.isEmpty
              ? 'no configured stages'
              : allowedStages.map((stage) => stage.name).join(', ');
          issues.add(
            CsvTranslationIssue(
              rowNumber: rowNumber,
              field: 'lifeStage',
              value: lifeStageRaw,
              message:
                  'Life stage "${parsedLifeStage.name}" is not valid for ${organismKind.name}. Expected one of: $expected.',
            ),
          );
        }
      }
    }

    // --- ID type validation (Phase 2, Team Delta — 2D.3) ---
    // Reject provenance ID format in doc ID columns.
    final organismIdRaw = row['organismId'] ?? '';
    final organismIdIsLegacy =
        CsvColumnNames.isLegacyProvenanceIdFormat(organismIdRaw);
    if (organismIdRaw.isNotEmpty &&
        (CsvColumnNames.isProvenanceIdFormat(organismIdRaw) ||
            organismIdIsLegacy)) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'organismId',
          value: organismIdRaw,
          message: 'organismId must be a Firestore document ID, not a '
              'lineage ID (PID- prefix). '
              'Use provenanceId for lineage identifiers.',
        ),
      );
    }
    final genetIdRaw = row['genetId'] ?? '';
    final genetIdIsLegacy =
        CsvColumnNames.isLegacyProvenanceIdFormat(genetIdRaw);
    if (genetIdRaw.isNotEmpty &&
        (CsvColumnNames.isProvenanceIdFormat(genetIdRaw) || genetIdIsLegacy)) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'genetId',
          value: genetIdRaw,
          message: 'genetId must be a Firestore document ID, not a '
              'lineage ID (PID- prefix). '
              'Use genetProvenanceId for genet lineage identifiers.',
        ),
      );
    }
    // Reject doc ID format in lineage ID columns.
    final provenanceIdRaw = row['provenanceId'] ?? '';
    if (provenanceIdRaw.isNotEmpty &&
        CsvColumnNames.isLegacyProvenanceIdFormat(provenanceIdRaw)) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'provenanceId',
          value: provenanceIdRaw,
          message: 'provenanceId must use the PID- prefix. Legacy SF- '
              'provenance IDs are not supported.',
          severity: CsvTranslationIssueSeverity.warning,
        ),
      );
    } else if (provenanceIdRaw.isNotEmpty &&
        CsvColumnNames.isDocIdFormat(provenanceIdRaw)) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'provenanceId',
          value: provenanceIdRaw,
          message: 'provenanceId must be a lineage ID (PID- prefix), '
              'not a Firestore document ID. '
              'Use organismId for Firestore document IDs.',
          severity: CsvTranslationIssueSeverity.warning,
        ),
      );
    }
    final measurementUnit = row['measurementUnit'];
    if (measurementUnit != null && measurementUnit.isNotEmpty) {
      if (!UniversalCsvAdapterV2._measurementUnits
          .contains(measurementUnit.toLowerCase())) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'measurementUnit',
            value: measurementUnit,
            message: 'Unsupported measurement unit for CSV v2.',
          ),
        );
      }
    }

    // physicalForm is a freeform String - no validation needed

    final provenanceTypeRaw = row['provenanceType'];
    if (provenanceTypeRaw != null && provenanceTypeRaw.isNotEmpty) {
      if (ProvenanceTypeX.tryParse(provenanceTypeRaw) == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'provenanceType',
            value: provenanceTypeRaw,
            message: 'Unknown provenanceType "$provenanceTypeRaw".',
          ),
        );
      }
    }

    final quantityValue = row['quantityValue'];
    if (quantityValue != null && quantityValue.isNotEmpty) {
      final parsed = double.tryParse(quantityValue);
      if (parsed == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'quantityValue',
            value: quantityValue,
            message: 'quantityValue must be numeric.',
          ),
        );
      }
    }

    final measuredValueRaw = row['measuredDimension'];
    if (measuredValueRaw != null && measuredValueRaw.isNotEmpty) {
      final parsed = double.tryParse(measuredValueRaw);
      if (parsed == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'measuredDimension',
            value: measuredValueRaw,
            message: 'measuredDimension must be numeric.',
          ),
        );
      }
    }

    if (_isProtectedArea(row['protectedAreaFlag'])) {
      for (final field in UniversalCsvAdapterV2._permitFields) {
        if ((row[field] ?? '').trim().isEmpty) {
          issues.add(
            CsvTranslationIssue(
              rowNumber: rowNumber,
              field: field,
              value: '',
              message: 'Protected area rows require $field per CSV v2 spec.',
            ),
          );
        }
      }
    }

    final geometryFormat = row['geometryFormat']?.toUpperCase();
    if (geometryFormat != null && geometryFormat.isNotEmpty) {
      if (geometryFormat != 'WKT' && geometryFormat != 'GEOJSON') {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryFormat',
            value: row['geometryFormat'] ?? '',
            message: 'geometryFormat must be WKT or GeoJSON.',
          ),
        );
      } else if (geometryFormat == 'WKT' &&
          (row['geometryWkt'] ?? '').isEmpty) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryWkt',
            value: '',
            message: 'Provide WKT payload when geometryFormat=WKT.',
          ),
        );
      }
    }

    final structureType = row['structureType'];
    if (structureType != null && structureType.isNotEmpty) {
      final structureLower = structureType.toLowerCase();
      if (UniversalCsvAdapterV2._kelpStructureTypes.contains(structureLower) &&
          (row['lineId'] ?? '').isEmpty) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'lineId',
            value: '',
            message:
                'Kelp structures ($structureType) require lineId in CSV v2.',
          ),
        );
      }
    }

    return issues;
  }

  void validateHoldingMeasurementUnit({
    required String holdingKind,
    required OrganismKind organismKind,
    required String measurementUnit,
    required int rowNumber,
    required List<CsvTranslationIssue> issues,
  }) {
    final normalized = measurementUnit.trim().toLowerCase();
    if (holdingKind == 'gameteBatch' || holdingKind == 'larvalBatch') {
      if (!UniversalCsvAdapterV2._countMeasurementUnits.contains(normalized)) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'measurementUnit',
            value: measurementUnit,
            message:
                '${holdingKind == 'gameteBatch' ? 'Gamete' : 'Larval'} holdings must use measurementUnit=count.',
          ),
        );
      }
      return;
    }
    if (holdingKind == 'seededLineBatch') {
      if (!UniversalCsvAdapterV2._seededLineMeasurementUnits
          .contains(normalized)) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'measurementUnit',
            value: measurementUnit,
            message: 'Seeded line holdings require measurementUnit=kg_per_m.',
          ),
        );
      }
    }
  }
}
