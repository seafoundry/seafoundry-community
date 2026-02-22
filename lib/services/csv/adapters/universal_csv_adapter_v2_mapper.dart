// @tier: community
part of 'universal_csv_adapter_v2.dart';

/// Row mapping/translation methods for [UniversalCsvAdapterV2].
///
/// This part file contains all the row translation logic for both import
/// and export operations, including holding-specific translations.
extension _UniversalCsvAdapterV2Mapper on UniversalCsvAdapterV2 {
  Map<String, String>? translateHoldingRow(
    Map<String, String> row, {
    required int rowNumber,
    required List<CsvTranslationIssue> issues,
    required String holdingKind,
    required OrganismKind organismKind,
    required CsvV2LifeStage? csvStage,
  }) {
    final provenanceId =
        _string(row['provenanceId']) ?? '';
    if (provenanceId.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'provenanceId',
          value: provenanceId,
          message: 'Holding rows require a provenanceId.',
        ),
      );
      return null;
    }

    final groupPath =
        row['groupId']?.trim() ?? row['groupUrlPath']?.trim() ?? '';
    if (groupPath.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'groupId',
          value: '',
          message:
              'groupId is required so holdings can resolve structure paths.',
        ),
      );
    }

    final quantity = row['quantityValue']?.trim() ?? '';
    final measurementUnit = row['measurementUnit']?.trim() ?? '';
    if (quantity.isEmpty || measurementUnit.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'quantityValue',
          value: quantity,
          message: 'quantityValue and measurementUnit are required.',
        ),
      );
    }

    if (groupPath.isEmpty || quantity.isEmpty || measurementUnit.isEmpty) {
      return null;
    }

    // Warn if life stage is not explicitly provided - will use organism-specific default
    final explicitLifeStageId = _string(row['lifeStageId']);
    final explicitLifeStage = _string(row['lifeStage']);
    if (csvStage == null &&
        explicitLifeStageId == null &&
        explicitLifeStage == null) {
      final defaultStage = _defaultLifeStageForHolding(holdingKind);
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'lifeStage',
          value: '',
          message:
              'No life stage specified for $holdingKind; defaulting to "${defaultStage.name}". '
              'Consider specifying lifeStage explicitly for accurate classification.',
          severity: CsvTranslationIssueSeverity.warning,
        ),
      );
    }

    validateHoldingMeasurementUnit(
      holdingKind: holdingKind,
      organismKind: organismKind,
      measurementUnit: measurementUnit,
      rowNumber: rowNumber,
      issues: issues,
    );

    final localId = _string(row['localId']);
    final translation = <String, String>{
      'holdingKind': holdingKind,
      'provenanceId': provenanceId,
      'localId': localId ?? '',
      'recordName': row['recordName'] ?? '',
      'organismKind': row['organismKind'] ?? '',
      'speciesScientific': row['speciesScientific'] ?? '',
      'speciesCode': row['speciesCode'] ?? '',
      'speciesId': row['speciesId'] ?? '',
      'lifeStage': row['lifeStage'] ?? '',
      'lifeStageSubtype': row['lifeStageSubtype'] ?? '',
      'physicalFormId': row['physicalFormId'] ?? '',
      'physicalForm': row['physicalForm'] ?? '',
      'provenanceType': row['provenanceType'] ?? '',
      'sizeBandId': row['sizeBandId'] ?? '',
      'measuredDimension': row['measuredDimension'] ?? '',
      'dimensionUnit': row['dimensionUnit'] ?? '',
      'organismsPerUnit': row['organismsPerUnit'] ?? '',
      'volumeAmount': row['volumeAmount'] ?? '',
      'volumeUnit': row['volumeUnit'] ?? '',
      'inventoryCount': row['inventoryCount'] ?? '',
      'inventoryVolumeCm3': row['inventoryVolumeCm3'] ?? '',
      'inventoryTissueAreaCm2': row['inventoryTissueAreaCm2'] ?? '',
      'measurementUnit': measurementUnit,
      'quantityValue': quantity,
      'groupId': groupPath,
      'siteId': row['siteId'] ?? '',
      'siteName': row['siteName'] ?? '',
      'enclosureId': row['enclosureId'] ?? '',
      'provenanceKind': _resolvedProvenanceKind(row, fallback: 'genet'),
      'cohortId': row['cohortId'] ?? '',
      'eventDate': row['eventDate'] ?? '',
      'notes': row['notes'] ?? '',
      'structureType': row['structureType'] ?? '',
      'permitType': row['permitType'] ?? '',
      'permitId': row['permitId'] ?? '',
      'issuingAuthority': row['issuingAuthority'] ?? '',
      'validFrom': row['validFrom'] ?? '',
      'validTo': row['validTo'] ?? '',
      'habitatType': row['habitatType'] ?? '',
      'siteJurisdiction': row['siteJurisdiction'] ?? '',
      'protectedAreaFlag': row['protectedAreaFlag'] ?? '',
      'geometryFormat': row['geometryFormat'] ?? '',
      'geometryWkt': row['geometryWkt'] ?? '',
      'geometryGeojson': row['geometryGeojson'] ?? '',
      'dropperId': row['dropperId'] ?? '',
      'ownerOrganizationId': row['ownerOrganizationId'] ?? '',
      'managingOrganizationId': row['managingOrganizationId'] ?? '',
      'foreignKeys': row['foreignKeys'] ?? '',
      'aliasesJson': '',
      'aliases': '',
    };

    void assignIfPresent(String key, {String? alias}) {
      final primary = row[key];
      if (primary != null && primary.isNotEmpty) {
        translation[key] = primary;
        return;
      }
      if (alias != null) {
        final aliasValue = row[alias];
        if (aliasValue != null && aliasValue.isNotEmpty) {
          translation[key] = aliasValue;
        }
      }
    }

    assignIfPresent('bagIdentifier', alias: 'bagId');
    assignIfPresent('depthMeters');
    assignIfPresent('averageWeightGrams');
    assignIfPresent('averageCarapaceWidthMm');
    assignIfPresent('coveragePercent');
    assignIfPresent('canopyHeightCm');
    assignIfPresent('moduleAreaSquareMeters');
    assignIfPresent('averageHeightCm');
    assignIfPresent('survivalPercent');

    if ((row['lineId'] ?? '').isNotEmpty) {
      translation['lineId'] = row['lineId']!;
      translation['lineIdentifier'] = row['lineId']!;
    } else if ((row['lineIdentifier'] ?? '').isNotEmpty) {
      translation['lineIdentifier'] = row['lineIdentifier']!;
      translation['lineId'] = row['lineIdentifier']!;
    }

    if ((row['lineLengthMeters'] ?? '').isNotEmpty) {
      translation['lineLengthMeters'] = row['lineLengthMeters']!;
    }

    if ((row['parentProvenanceIds'] ?? '').isNotEmpty) {
      translation['parentProvenanceIds'] = row['parentProvenanceIds']!;
    }

    if ((row['settlementWindowStart'] ?? '').isNotEmpty) {
      translation['settlementWindowStart'] = row['settlementWindowStart']!;
    }
    if ((row['settlementWindowEnd'] ?? '').isNotEmpty) {
      translation['settlementWindowEnd'] = row['settlementWindowEnd']!;
    }

    final normalizedLifeStageId = _normalizeLifeStageId(
      explicitId: row['lifeStageId'],
      label: row['lifeStage'],
      csvStage: csvStage,
    );
    if (normalizedLifeStageId != null) {
      translation['lifeStageId'] = normalizedLifeStageId;
    }

    final normalizedProvenanceType = _normalizeProvenanceType(
      explicitType: translation['provenanceType'],
      legacyKind: row['provenanceKind'] ?? translation['provenanceKind'],
    );
    if (normalizedProvenanceType != null) {
      translation['provenanceType'] = normalizedProvenanceType;
    }

    final aliasColumns = _aliasColumnsForImport(row);
    translation['aliasesJson'] = aliasColumns['aliasesJson'] ?? '';
    translation['aliases'] = aliasColumns['aliases'] ?? '';

    final selection = _provenanceSelectionFromImportRow(
      row: row,
      csvStage: csvStage,
      existingLifeStageId: translation['lifeStageId'],
      existingProvenanceType: translation['provenanceType'],
    );
    translation['lifeStage'] = selection.lifeStage.name;
    translation['lifeStageId'] = selection.lifeStage.id;
    translation['lifeStageLabel'] = selection.lifeStage.displayName;
    translation['provenanceType'] = selection.provenanceType.metadata.id;
    translation['provenanceTypeLabel'] =
        selection.provenanceType.metadata.displayName;
    translation['provenanceKind'] = _resolvedProvenanceKind(
      translation,
      fallback: selection.provenanceType.metadata.defaultProvenanceKind.name,
    );

    return translation;
  }

  Map<String, String>? translateImportRow(
    Map<String, String> row, {
    required int rowNumber,
    required List<CsvTranslationIssue> issues,
    required _CsvSpeciesLookup speciesLookup,
  }) {
    final organismKind = parseOrganismKind(row['organismKind']);
    final lifeStage = parseLifeStage(row['lifeStage']);
    if (organismKind == null) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'organismKind',
          value: row['organismKind'] ?? '',
          message: 'Unknown organism kind.',
        ),
      );
      return null;
    }

    final holdingKind = holdingKindFor(organismKind, lifeStage);
    if (holdingKind != null) {
      return translateHoldingRow(
        row,
        rowNumber: rowNumber,
        issues: issues,
        holdingKind: holdingKind,
        organismKind: organismKind,
        csvStage: lifeStage,
      );
    }

    if (organismKind != OrganismKind.coral) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'organismKind',
          value: row['organismKind'] ?? '',
          message:
              'Only coral inventory and supported holding types are currently enabled.',
        ),
      );
      return null;
    }

    final speciesId = resolveSpeciesId(row, rowNumber, issues, speciesLookup);
    final physicalFormId = _string(row['physicalFormId']);
    if (physicalFormId == null || physicalFormId.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'physicalFormId',
          value: row['physicalFormId'] ?? '',
          message: 'physicalFormId is required for coral inventory rows.',
        ),
      );
    }
    final groupPath = row['groupId']?.trim() ?? '';
    if (groupPath.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'groupId',
          value: '',
          message: 'groupId is required so we can resolve the structure path.',
        ),
      );
    }

    final quantity = parseQuantity(row, rowNumber, issues);
    final geom = translateGeometry(row, rowNumber, issues);

    if (speciesId == null ||
        physicalFormId == null ||
        groupPath.isEmpty ||
        quantity == null) {
      return null;
    }

    final provenanceId = row['provenanceId'] ?? '';
    final organismId = row['organismId'] ?? '';
    final readyForOutplant =
        row['readyForOutplant'] ?? row['readyForOutplantBool'] ?? '';
    final translation = <String, String>{
      'provenanceId': provenanceId,
      if (organismId.isNotEmpty) 'organismId': organismId,
      'localId': row['localId'] ?? '',
      'recordName': row['recordName'] ?? '',
      'speciesId': speciesId,
      'physicalFormId': physicalFormId,
      'physicalForm': row['physicalForm'] ?? '',
      'sizeBandId': row['sizeBandId'] ?? '',
      'groupId': groupPath,
      'quantityValue': quantity.toString(),
      'measurementUnit': row['measurementUnit'] ?? 'count',
      'healthStatus': '',
      'size': '',
      'notes': row['notes'] ?? '',
      'lastEventAt': row['eventDate'] ?? '',
      // genetProvenanceId requires an explicit lineage ID column.
      // Do NOT fall back to genetId — those are Firestore doc IDs,
      // not lineage identifiers. (Phase 2, Team Delta — 2D.3)
      'genetProvenanceId': row['genetProvenanceId'] ?? '',
      'owner': '',
      'holder': '',
      'clonalSnp': '',
      'readyForOutplant': readyForOutplant,
      'siteCenterLat': geom.centerLat ?? '',
      'siteCenterLng': geom.centerLng ?? '',
      'siteBboxNwLat': '',
      'siteBboxNwLng': '',
      'siteBboxSeLat': '',
      'siteBboxSeLng': '',
      'outplantPointsCsv': geom.outplantPointsCsv ?? '',
      'outplantKmlUrl': row['geometryKmlUrl'] ?? '',
      // Preserve canonical columns for downstream organism-aware services.
      'organismKind': row['organismKind'] ?? '',
      'lifeStage': row['lifeStage'] ?? '',
      'lifeStageSubtype': row['lifeStageSubtype'] ?? '',
      'provenanceType': row['provenanceType'] ?? '',
      'measuredDimension': row['measuredDimension'] ?? '',
      'dimensionUnit': row['dimensionUnit'] ?? '',
      'organismsPerUnit': row['organismsPerUnit'] ?? '',
      'volumeAmount': row['volumeAmount'] ?? '',
      'volumeUnit': row['volumeUnit'] ?? '',
      'inventoryCount': row['inventoryCount'] ?? '',
      'inventoryVolumeCm3': row['inventoryVolumeCm3'] ?? '',
      'inventoryTissueAreaCm2': row['inventoryTissueAreaCm2'] ?? '',
      'provenanceKind': _resolvedProvenanceKind(row, fallback: 'genet'),
      'eventType': row['eventType'] ?? '',
      'eventDate': row['eventDate'] ?? '',
      'aliasesJson': '',
      'aliases': '',
    };

    final normalizedLifeStageId = _normalizeLifeStageId(
      explicitId: row['lifeStageId'],
      label: row['lifeStage'],
      csvStage: lifeStage,
    );
    if (normalizedLifeStageId != null) {
      translation['lifeStageId'] = normalizedLifeStageId;
    }

    final aliasColumns = _aliasColumnsForImport(row);
    translation['aliasesJson'] = aliasColumns['aliasesJson'] ?? '';
    translation['aliases'] = aliasColumns['aliases'] ?? '';

    final selection = _provenanceSelectionFromImportRow(
      row: row,
      csvStage: lifeStage,
      existingLifeStageId: translation['lifeStageId'],
      existingProvenanceType: translation['provenanceType'],
    );
    translation['lifeStage'] = selection.lifeStage.name;
    translation['lifeStageId'] = selection.lifeStage.id;
    translation['lifeStageLabel'] = selection.lifeStage.displayName;
    translation['provenanceType'] = selection.provenanceType.metadata.id;
    translation['provenanceTypeLabel'] =
        selection.provenanceType.metadata.displayName;
    translation['provenanceKind'] = _resolvedProvenanceKind(
      row,
      fallback: selection.provenanceType.metadata.defaultProvenanceKind.name,
    );

    return translation;
  }

  Map<String, String>? translateExportRow(
    Map<String, dynamic> row, {
    required int rowNumber,
    required List<CsvTranslationIssue> issues,
    required _CsvSpeciesLookup speciesLookup,
  }) {
    final holdingKind = _string(row['holdingKind']);
    if (holdingKind != null && holdingKind.isNotEmpty) {
      return translateHoldingExportRow(
        row,
        holdingKind: holdingKind,
        rowNumber: rowNumber,
        issues: issues,
      );
    }

    final speciesIdRaw = _string(row['speciesId']) ?? '';
    final speciesId = speciesIdRaw.trim().toLowerCase();

    final species = speciesId.isEmpty ? null : speciesLookup.byId(speciesId);
    if (species == null) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'speciesId',
          value: speciesIdRaw,
          message:
              'Unknown species identifier; export requires taxonomy alignment.',
        ),
      );
      return null;
    }

    final providedLifeStage = _string(row['lifeStage']) ??
        _string(row['lifeStageLabel']) ??
        _string(row['lifeStageName']);
    final resolvedLifeStage = providedLifeStage ?? LifeStage.unknown.name;
    final localId = _string(row['localId']);
    final recordName = _string(row['recordName']);

    final measurement = _ExportMeasurement.fromRow(row);
    final eventDate = _resolveEventDate(row);
    final geometry = _exportGeometry(row);
    final permit = _PermitMetadata.fromRow(row);

    final translation = <String, String>{
      'organismKind': 'coral',
      'speciesScientific': '${species.genus} ${species.species}',
      'speciesCode': species.code,
      'localId': localId ?? '',
      'recordName': recordName ?? '',
      'lifeStage': resolvedLifeStage,
      'lifeStageId': LifeStageX.tryParse(resolvedLifeStage)?.id ?? '',
      'lifeStageSubtype': _string(row['lifeStageSubtype']) ?? '',
      'physicalFormId': _string(row['physicalFormId']) ?? '',
      'physicalForm': _string(row['physicalForm']) ?? '',
      'sizeBandId': _string(row['sizeBandId']) ?? '',
      'provenanceType': _string(row['provenanceType']) ?? '',
      'provenanceTypeLabel': _string(row['provenanceTypeLabel']) ?? '',
      'measuredDimension': _string(row['measuredDimension']) ?? '',
      'dimensionUnit': _string(row['dimensionUnit']) ?? '',
      'organismsPerUnit': _string(row['organismsPerUnit']) ?? '',
      'volumeAmount': _string(row['volumeAmount']) ?? '',
      'volumeUnit': _string(row['volumeUnit']) ?? '',
      'inventoryCount': _string(row['inventoryCount']) ?? '',
      'inventoryVolumeCm3': _string(row['inventoryVolumeCm3']) ?? '',
      'inventoryTissueAreaCm2':
          _string(row['inventoryTissueAreaCm2']) ?? '',
      'eventType': 'inventory_snapshot',
      'eventDate': eventDate,
      'measurementUnit': measurement.unit,
      'quantityValue': measurement.value,
      'groupId': _string(row['groupId']) ?? _string(row['groupUrlPath']) ?? '',
      'siteId': _string(row['siteId']) ?? '',
      'siteName': _string(row['siteName']) ?? '',
      // Use the actual provenanceId field for lineage. Do NOT fall back to
      // genetId which is a Firestore doc ID. (Phase 2, Team Delta — 2D.3)
      'provenanceId': _string(row['provenanceId']) ?? '',
      'provenanceKind': _resolvedProvenanceKind(row, fallback: 'genet'),
      'cohortId': '',
      'structureType': _string(row['structureType']) ?? '',
      'permitId': permit.id,
      'issuingAuthority': permit.authority,
      'validFrom': permit.validFrom,
      'validTo': permit.validTo,
      'protectedAreaFlag': permit.protectedAreaFlag,
      'geometryFormat': geometry.format ?? '',
      'geometryWkt': geometry.wkt ?? '',
      'notes': _string(row['notes']) ?? '',
      'aliasesJson': '',
      'aliases': '',
    };

    final aliasColumns = _aliasColumnsForExport(row);
    translation['aliasesJson'] = aliasColumns['aliasesJson'] ?? '';
    translation['aliases'] = aliasColumns['aliases'] ?? '';

    final selection = _provenanceSelectionFromExportRow(
      row,
      existingLifeStageId: translation['lifeStageId'],
      existingProvenanceType: translation['provenanceType'],
    );
    translation['lifeStageId'] = selection.lifeStage.id;
    translation['lifeStage'] = selection.lifeStage.name;
    translation['lifeStageLabel'] = selection.lifeStage.displayName;
    translation['provenanceType'] = selection.provenanceType.metadata.id;
    translation['provenanceTypeLabel'] =
        selection.provenanceType.metadata.displayName;
    translation['provenanceKind'] = _resolvedProvenanceKind(
      row,
      fallback: selection.provenanceType.metadata.defaultProvenanceKind.name,
    );

    _applyMetadataOverrides(
      row: row,
      target: translation,
    );

    final normalizedProvenanceType = _normalizeProvenanceType(
      explicitType: translation['provenanceType'],
      legacyKind: translation['provenanceKind'],
    );
    if (normalizedProvenanceType != null) {
      translation['provenanceType'] = normalizedProvenanceType;
    }

    return translation;
  }

  Map<String, String>? translateHoldingExportRow(
    Map<String, dynamic> row, {
    required String holdingKind,
    required int rowNumber,
    required List<CsvTranslationIssue> issues,
  }) {
    final organismKind = _string(row['organismKind']) ?? '';
    if (organismKind.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'organismKind',
          value: '',
          message: 'Holding export rows require organismKind.',
        ),
      );
      return null;
    }

    final speciesScientific = _string(row['speciesScientific']);
    final speciesCode = _string(row['speciesCode']);
    if (speciesScientific == null || speciesCode == null) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'speciesScientific',
          value: '',
          message:
              'Holding exports must include speciesScientific/speciesCode metadata.',
        ),
      );
      return null;
    }

    final groupPath =
        _string(row['groupId']) ?? _string(row['groupUrlPath']) ?? '';
    if (groupPath.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'groupId',
          value: '',
          message: 'Holding exports require groupId.',
        ),
      );
      return null;
    }

    final measurement = _ExportMeasurement.fromRow(row);
    final eventDate = _resolveEventDate(row);

    final lifeStageValue =
        _string(row['lifeStageId']) ?? _string(row['lifeStage']) ?? '';
    final physicalFormId = _string(row['physicalFormId']) ?? '';
    final provenanceTypeValue = _string(row['provenanceType']) ?? '';
    final localId = _string(row['localId']);
    final recordName = _string(row['recordName']);

    final translation = <String, String>{
      'organismKind': organismKind,
      'speciesScientific': speciesScientific,
      'speciesCode': speciesCode,
      'localId': localId ?? '',
      'recordName': recordName ?? '',
      'lifeStage': lifeStageValue,
      'lifeStageId': lifeStageValue,
      'lifeStageSubtype': _string(row['lifeStageSubtype']) ?? '',
      'physicalFormId': physicalFormId,
      'physicalForm': _string(row['physicalForm']) ?? '',
      'sizeBandId': _string(row['sizeBandId']) ?? '',
      'provenanceType': provenanceTypeValue,
      'provenanceTypeLabel': _string(row['provenanceTypeLabel']) ?? '',
      'provenanceKind': provenanceTypeValue.isNotEmpty
          ? provenanceTypeValue
          : _resolvedProvenanceKind(row, fallback: 'genet'),
      'measuredDimension': _string(row['measuredDimension']) ?? '',
      'dimensionUnit': _string(row['dimensionUnit']) ?? '',
      'organismsPerUnit': _string(row['organismsPerUnit']) ?? '',
      'volumeAmount': _string(row['volumeAmount']) ?? '',
      'volumeUnit': _string(row['volumeUnit']) ?? '',
      'inventoryCount': _string(row['inventoryCount']) ?? '',
      'inventoryVolumeCm3': _string(row['inventoryVolumeCm3']) ?? '',
      'inventoryTissueAreaCm2':
          _string(row['inventoryTissueAreaCm2']) ?? '',
      'eventType': _string(row['eventType']) ?? 'inventory_snapshot',
      'eventDate': eventDate,
      'measurementUnit': measurement.unit,
      'quantityValue': measurement.value,
      'groupId': groupPath,
      'provenanceId': _string(row['provenanceId']) ?? '',
      'cohortId': _string(row['cohortId']) ?? '',
      'notes': _string(row['notes']) ?? '',
      'holdingKind': holdingKind,
      'permitId': _string(row['permitId']) ?? '',
      'issuingAuthority': _string(row['issuingAuthority']) ?? '',
      'validFrom': _string(row['validFrom']) ?? '',
      'validTo': _string(row['validTo']) ?? '',
      'protectedAreaFlag': _string(row['protectedAreaFlag']) ?? '',
      'aliasesJson': '',
      'aliases': '',
    };

    if (holdingKind == 'seededLineBatch') {
      final lineIdentifier =
          _string(row['lineIdentifier']) ?? _string(row['lineId']) ?? '';
      translation['lineId'] = lineIdentifier;
      translation['structureType'] = _string(row['structureType']) ?? '';
    }

    final normalizedProvenanceType = _normalizeProvenanceType(
      explicitType: translation['provenanceType'],
      legacyKind: translation['provenanceKind'],
    );
    if (normalizedProvenanceType != null) {
      translation['provenanceType'] = normalizedProvenanceType;
    }

    if (holdingKind == 'gameteBatch') {
      translation['parentProvenanceIds'] =
          _string(row['parentProvenanceIds']) ?? '';
    }

    if (holdingKind == 'larvalBatch') {
      translation['settlementWindowStart'] =
          _string(row['settlementWindowStart']) ?? '';
      translation['settlementWindowEnd'] =
          _string(row['settlementWindowEnd']) ?? '';
    }

    final normalizedLifeStageId = _normalizeLifeStageId(
      explicitId: row['lifeStageId'],
      label: row['lifeStage'],
    );
    if (normalizedLifeStageId != null) {
      translation['lifeStageId'] = normalizedLifeStageId;
    }

    final aliasColumns = _aliasColumnsForExport(row);
    translation['aliasesJson'] = aliasColumns['aliasesJson'] ?? '';
    translation['aliases'] = aliasColumns['aliases'] ?? '';

    final holdingSelection = _provenanceSelectionFromExportRow(
      row,
      existingLifeStageId: translation['lifeStageId'],
      existingProvenanceType: translation['provenanceType'],
    );
    translation['lifeStageId'] = holdingSelection.lifeStage.id;
    translation['lifeStage'] = holdingSelection.lifeStage.name;
    translation['lifeStageLabel'] = holdingSelection.lifeStage.displayName;
    translation['provenanceType'] =
        holdingSelection.provenanceType.metadata.id;
    translation['provenanceTypeLabel'] =
        holdingSelection.provenanceType.metadata.displayName;
    translation['provenanceKind'] = _resolvedProvenanceKind(
      row,
      fallback:
          holdingSelection.provenanceType.metadata.defaultProvenanceKind.name,
    );

    _applyMetadataOverrides(
      row: row,
      target: translation,
    );

    return translation;
  }

  String? resolveSpeciesId(
    Map<String, String> row,
    int rowNumber,
    List<CsvTranslationIssue> issues,
    _CsvSpeciesLookup speciesLookup,
  ) {
    final code = row['speciesCode']?.trim();
    if (code != null && code.isNotEmpty) {
      final species = speciesLookup.byCode(code);
      if (species != null) {
        return species.id;
      }
    }

    final scientific = row['speciesScientific']?.trim();
    if (scientific != null && scientific.isNotEmpty) {
      final species = speciesLookup.byScientific(scientific);
      if (species != null) {
        return species.id;
      }
    }

    final explicitId = row['speciesId']?.trim();
    if (explicitId != null && explicitId.isNotEmpty) {
      final species = speciesLookup.byId(explicitId);
      if (species != null) {
        return species.id;
      }
    }

    issues.add(
      CsvTranslationIssue(
        rowNumber: rowNumber,
        field: 'speciesScientific',
        value: scientific ?? code ?? '',
        message:
            'Unknown species. Provide a SeaFoundry species code (e.g., APAL).',
      ),
    );
    return null;
  }

  int? parseQuantity(
    Map<String, String> row,
    int rowNumber,
    List<CsvTranslationIssue> issues,
  ) {
    final quantityValue = row['quantityValue'] ?? '';
    final measurementUnit = row['measurementUnit']?.trim().toLowerCase() ?? '';
    if (measurementUnit != 'count') {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'measurementUnit',
          value: row['measurementUnit'] ?? '',
          message: 'Inventory imports currently require measurementUnit=count.',
        ),
      );
      return null;
    }

    final parsed = int.tryParse(quantityValue);
    if (parsed == null || parsed < 0) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'quantityValue',
          value: quantityValue,
          message: 'Quantity must be a non-negative integer.',
        ),
      );
      return null;
    }
    return parsed;
  }

  /// Returns the appropriate default life stage for a holding kind.
  ///
  /// This provides organism-specific defaults that are more appropriate
  /// than the generic ProvenanceType.unknown fallback.
  LifeStage _defaultLifeStageForHolding(String holdingKind) {
    switch (holdingKind) {
      case 'gameteBatch':
        return LifeStage.gamete;
      case 'larvalBatch':
        return LifeStage.larva;
      case 'seededLineBatch':
      case 'oysterBagHolding':
      case 'finfishPenHolding':
      case 'crabPondHolding':
      case 'seagrassModuleHolding':
      case 'mangrovePlotHolding':
        return LifeStage.juvenile;
      default:
        return LifeStage.adult;
    }
  }
}
