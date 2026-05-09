import 'dart:convert';

import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/csv/v2/csv_v2_spec_extensions.dart';

/// Normalizes inventory rows before they flow through the CSV translation
/// pipeline so organism-aware metadata (permits, geometry, site IDs) survives.
class InventoryExportRowFormatter {
  const InventoryExportRowFormatter._();

  static Map<String, dynamic> canonicalize(
    Map<String, dynamic> row,
  ) {
    final holdingKind = _string(row['holdingKind']);
    if (holdingKind != null && holdingKind.isNotEmpty) {
      return _canonicalizeHoldingRow(row, holdingKind);
    }

    return _canonicalizeCoralRow(row);
  }

  static Map<String, dynamic> _canonicalizeCoralRow(
    Map<String, dynamic> row,
  ) {
    final populationUnit = _string(row['measurementUnit']) ?? 'count';
    final populationValue = _string(row['quantityValue']) ?? '0';
    final physicalFormId = _string(row['physicalFormId']);
    final physicalFormLabel = _string(row['physicalForm']) ?? '';
    final sizeBandId = _string(row['sizeBandId']) ?? '';
    final measuredDimension = _string(row['measuredDimension']);
    final dimensionUnit = _string(row['dimensionUnit']);
    final organismsPerUnit = _string(row['organismsPerUnit']);
    final volumeAmount = _string(row['volumeAmount']);
    final volumeUnit = _string(row['volumeUnit']);
    final groupPath = _string(row['groupId']) ?? '';
    final speciesId = _string(row['speciesId']) ?? '';
    final providedLifeStageId = _string(row['lifeStageId']);
    final providedLifeStage = LifeStageX.tryParse(providedLifeStageId);
    final lifeStageEnum = providedLifeStage ?? LifeStage.unknown;
    final lifeStageName = lifeStageEnum.name;

    final siteName = _string(row['siteName']) ?? '';
    final siteId = _string(row['siteId']) ?? '';
    final tagId = _string(row['tagId']);
    final localGenetId = _string(row['localGenetId']);
    final resolvedProvenanceType = _resolveProvenanceType(
      row,
      defaultValue: 'provenance_type_wild',
    );
    final canonical = <String, dynamic>{
      'provenanceId': _string(row['provenanceId']) ?? '',
      'localGenetId': localGenetId ?? '',
      'tagId': tagId ?? '',
      'speciesId': speciesId,
      'groupId': groupPath,
      'healthStatus': _string(row['healthStatus']) ?? '',
      'notes': _string(row['notes']) ?? '',
      'lastEventAt':
          _string(row['lastEventAt']) ??
          _string(row['updatedAt']) ??
          _string(row['createdAt']) ??
          '',
      'quantityValue': populationValue,
      'measurementUnit': populationUnit,
      'readyForOutplant': _boolString(row['readyForOutplant']),
      'structureType': _string(row['structureType']) ?? '',
      'siteId': siteId,
      'siteName': siteName,
      'groupIdRaw': _string(row['groupIdRaw']) ?? '',
      'organismKind': 'coral',
      'lifeStage': _string(row['lifeStage']) ?? lifeStageName,
      'lifeStageLabel': lifeStageName,
      'lifeStageId': lifeStageEnum.id,
      'lifeStageSubtype': '',
      'physicalFormId': physicalFormId ?? '',
      'physicalForm': physicalFormLabel,
      'sizeBandId': sizeBandId,
      'measuredDimension': measuredDimension ?? '',
      'dimensionUnit': dimensionUnit ?? '',
      'organismsPerUnit': organismsPerUnit ?? '',
      'volumeAmount': volumeAmount ?? '',
      'volumeUnit': volumeUnit ?? '',
      'inventoryCount': _string(row['inventoryCount']) ?? '',
      'inventoryVolumeCm3': _string(row['inventoryVolumeCm3']) ?? '',
      'inventoryTissueAreaCm2':
          _string(row['inventoryTissueAreaCm2']) ?? '',
      'ownerOrganizationId': _string(row['ownerOrganizationId']) ?? '',
      'managingOrganizationId': _string(row['managingOrganizationId']) ?? '',
      'foreignKeys': _string(row['foreignKeys']) ?? '',
      'aliasesJson': '',
      'aliases': '',
      'eventType': _string(row['eventType']) ?? 'inventory_snapshot',
      'eventDate':
          _string(row['eventDate']) ??
          _string(row['updatedAt']) ??
          _string(row['createdAt']) ??
          '',
      'provenanceType': resolvedProvenanceType,
    };

    _copyPassthrough(
      source: row,
      target: canonical,
      keys: [
        ...CsvV2SpecExtensions.permitColumns,
        ...CsvV2SpecExtensions.geometryColumns,
        'outplantPointsCsv',
      ],
    );

    canonical['provenanceKind'] = _provenanceKind(row, defaultValue: 'genet');
    final coralSelection = _deriveProvenanceSelection(
      source: row,
      canonical: canonical,
      fallbackProvenanceTypeId: resolvedProvenanceType,
      fallbackLifeStage: lifeStageEnum,
    );
    _writeCanonicalProvenanceOutputs(canonical, coralSelection);
    _applyAliasColumns(row, canonical);

    return canonical;
  }

  static Map<String, dynamic> _canonicalizeHoldingRow(
    Map<String, dynamic> row,
    String holdingKind,
  ) {
    final siteName = _string(row['siteName']) ?? '';
    final siteId = _string(row['siteId']) ?? '';
    final canonical = Map<String, dynamic>.from(row);
    canonical['holdingKind'] = holdingKind;
    canonical['organismKind'] = _string(row['organismKind']) ?? '';
    final groupPath = _string(row['groupId']) ?? '';
    canonical['groupId'] = groupPath;
    canonical['quantityValue'] =
        _string(row['quantityValue']) ?? '';
    canonical['measurementUnit'] =
        _string(row['measurementUnit']) ?? 'count';
    canonical['eventDate'] =
        _string(row['eventDate']) ??
        _string(row['lastEventAt']) ??
        _string(row['updatedAt']) ??
        _string(row['createdAt']) ??
        '';
    canonical['siteName'] = siteName;
    canonical['siteId'] = siteId;
    canonical['lifeStageLabel'] =
        _string(row['lifeStageLabel']) ?? _string(row['lifeStage']);
    canonical['lifeStageSubtype'] =
        _string(row['lifeStageSubtype']) ?? canonical['lifeStageSubtype'];
    final physicalFormId = _string(row['physicalFormId']);
    if (physicalFormId != null && physicalFormId.isNotEmpty) {
      canonical['physicalFormId'] = physicalFormId;
    }
    final physicalFormLabel = _string(row['physicalForm']);
    if (physicalFormLabel != null && physicalFormLabel.isNotEmpty) {
      canonical['physicalForm'] = physicalFormLabel;
    }
    canonical['provenanceType'] = _resolveProvenanceType(
      row,
      defaultValue: canonical['provenanceType'],
    );
    canonical['provenanceTypeLabel'] =
        _string(row['provenanceTypeLabel']) ??
        canonical['provenanceTypeLabel'] ??
        canonical['provenanceType'];
    canonical['sizeBandId'] =
        _string(row['sizeBandId']) ??
        canonical['sizeBandId'] ??
        '';
    canonical['measuredDimension'] = _string(row['measuredDimension']) ??
        canonical['measuredDimension'] ??
        '';
    canonical['dimensionUnit'] =
        _string(row['dimensionUnit']) ?? canonical['dimensionUnit'] ?? '';
    canonical['organismsPerUnit'] = _string(row['organismsPerUnit']) ??
        canonical['organismsPerUnit'] ??
        '';
    canonical['volumeAmount'] = _string(row['volumeAmount']) ??
        canonical['volumeAmount'] ??
        '';
    canonical['volumeUnit'] = _string(row['volumeUnit']) ??
        canonical['volumeUnit'] ??
        '';
    canonical['inventoryCount'] =
        _string(row['inventoryCount']) ?? canonical['inventoryCount'] ?? '';
    canonical['inventoryVolumeCm3'] = _string(row['inventoryVolumeCm3']) ??
        canonical['inventoryVolumeCm3'] ??
        '';
    canonical['inventoryTissueAreaCm2'] =
        _string(row['inventoryTissueAreaCm2']) ??
        canonical['inventoryTissueAreaCm2'] ??
        '';
    canonical['permitType'] = _string(row['permitType']) ?? '';
    canonical['permitId'] = _string(row['permitId']) ?? '';
    canonical['issuingAuthority'] = _string(row['issuingAuthority']) ?? '';
    canonical['validFrom'] = _string(row['validFrom']) ?? '';
    canonical['validTo'] = _string(row['validTo']) ?? '';
    canonical['protectedAreaFlag'] = _string(row['protectedAreaFlag']) ?? '';
    canonical['speciesScientific'] = _string(row['speciesScientific']) ?? '';
    canonical['speciesCode'] = _string(row['speciesCode']) ?? '';
    canonical['speciesId'] = _string(row['speciesId']) ?? '';
    canonical['ownerOrganizationId'] =
        canonical['ownerOrganizationId'] ??
        _string(row['ownerOrganizationId']) ??
        '';
    canonical['managingOrganizationId'] =
        canonical['managingOrganizationId'] ??
        _string(row['managingOrganizationId']) ??
        '';
    canonical['foreignKeys'] =
        canonical['foreignKeys'] ??
        _string(row['foreignKeys']) ??
        '';
    _applyAliasColumns(row, canonical);
    canonical['provenanceId'] =
        _string(row['provenanceId']) ?? '';
    canonical['siteJurisdiction'] =
        _string(row['siteJurisdiction']) ??
        canonical['siteJurisdiction'];

    final holdingLifeStage = _resolveLifeStage(row);
    if (holdingLifeStage != null) {
      canonical['lifeStageId'] = holdingLifeStage.id;
      canonical['lifeStage'] =
          canonical['lifeStageLabel'] ?? holdingLifeStage.name;
      canonical['lifeStageLabel'] =
          canonical['lifeStageLabel'] ?? holdingLifeStage.displayName;
    } else if (!canonical.containsKey('lifeStageId')) {
      final existing = _string(row['lifeStageId']);
      if (existing != null) {
        canonical['lifeStageId'] = existing;
      }
      canonical['lifeStage'] =
          canonical['lifeStageLabel'] ??
          canonical['lifeStage'] ??
          existing ??
          '';
    }

    canonical['lifeStageLabel'] =
        canonical['lifeStageLabel'] ?? canonical['lifeStage'] ?? '';
    canonical['lifeStageSubtype'] =
        canonical['lifeStageSubtype'] ?? _string(row['lifeStageSubtype']) ?? '';

    canonical['ownerOrganizationId'] =
        _string(row['ownerOrganizationId']) ??
        canonical['ownerOrganizationId'] ??
        '';
    canonical['managingOrganizationId'] =
        _string(row['managingOrganizationId']) ??
        canonical['managingOrganizationId'] ??
        '';
    canonical['foreignKeys'] =
        _string(row['foreignKeys']) ??
        canonical['foreignKeys'] ??
        '';

    final resolvedProvenanceType = canonical['provenanceType']
        ?.toString()
        .trim();
    final resolvedProvenanceKind = resolvedProvenanceType?.isNotEmpty == true
        ? resolvedProvenanceType!
        : _provenanceKind(row, defaultValue: '');
    canonical['provenanceKind'] = resolvedProvenanceKind.isEmpty
        ? 'genet'
        : resolvedProvenanceKind;
    final holdingSelection = _deriveProvenanceSelection(
      source: row,
      canonical: canonical,
      fallbackProvenanceTypeId: canonical['provenanceType']?.toString(),
      fallbackLifeStage: holdingLifeStage,
    );
    _writeCanonicalProvenanceOutputs(canonical, holdingSelection);
    return canonical;
  }

  static void _copyPassthrough({
    required Map<String, dynamic> source,
    required Map<String, dynamic> target,
    required List<String> keys,
  }) {
    for (final key in keys) {
      if (target.containsKey(key) && target[key] != null) {
        continue;
      }
      final value = source[key];
      if (value != null) {
        target[key] = value;
      }
    }
  }

  static void _applyAliasColumns(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) {
    var aliasJson = _string(source['aliasesJson']);
    final aliasLabels = _string(source['aliases']);
    if ((aliasJson == null || aliasJson.isEmpty) &&
        aliasLabels != null &&
        aliasLabels.isNotEmpty) {
      final entries = aliasLabels
          .split(RegExp(r'[;,]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .map(
            (value) => {
              'sourceSystem': 'custom',
              'value': value,
              'label': value,
            },
          )
          .toList(growable: false);
      if (entries.isNotEmpty) {
        aliasJson = jsonEncode(entries);
      }
    }
    final fallbackLabels = aliasLabels ?? _string(target['aliases']);
    target['aliasesJson'] =
        aliasJson ?? target['aliasesJson'] ?? fallbackLabels ?? '';
    target['aliases'] = fallbackLabels ?? target['aliases'] ?? '';
  }
  static ProvenanceLifeStageSelection _deriveProvenanceSelection({
    required Map<String, dynamic> source,
    required Map<String, dynamic> canonical,
    String? fallbackProvenanceTypeId,
    LifeStage? fallbackLifeStage,
  }) {
    final sources = <Map<String, dynamic>>[];
    final metadata = _extractMetadata(source);
    if (metadata.isNotEmpty) {
      sources.add(metadata);
    }

    final inline = <String, dynamic>{};
    void capture(String key, dynamic value) {
      final normalized = _string(value);
      if (normalized != null && normalized.isNotEmpty) {
        inline[key] = normalized;
      }
    }

    capture('provenanceTypeId', canonical['provenanceType']);
    capture('provenanceType', canonical['provenanceType']);
    capture('lifeStageId', canonical['lifeStageId']);
    capture('lifeStage', canonical['lifeStage']);
    capture('lifeStage', canonical['lifeStageLabel']);
    capture('provenanceKind', canonical['provenanceKind']);
    capture('provenanceTypeId', source['provenanceType']);
    capture('provenanceType', source['provenanceType']);
    capture('lifeStageId', source['lifeStageId']);
    capture('lifeStage', source['lifeStage']);
    capture('provenanceKind', source['provenanceKind']);

    if (inline.isNotEmpty) {
      sources.add(inline);
    }

    final fallbackType = ProvenanceTypeX.tryParse(fallbackProvenanceTypeId);

    var selection = ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: sources,
      fallbackProvenanceKind: _string(source['provenanceKind']),
      fallbackProvenanceType: fallbackType,
    );

    if (fallbackLifeStage != null &&
        selection.lifeStage != fallbackLifeStage) {
      selection = selection.copyWith(lifeStage: fallbackLifeStage);
    }
    return selection;
  }

  static Map<String, dynamic> _extractMetadata(Map<String, dynamic> row) {
    final candidates = [
      row['metadataRaw'],
      row['metadata'],
      row['provenanceMetadata'],
    ];
    for (final candidate in candidates) {
      final map = _normalizeMap(candidate);
      if (map != null && map.isNotEmpty) {
        return map;
      }
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic>? _normalizeMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, entryValue) {
        if (key == null) return;
        final keyString = key.toString().trim();
        if (keyString.isEmpty) return;
        result[keyString] = entryValue;
      });
      return result;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(trimmed);
          return _normalizeMap(decoded);
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static void _writeCanonicalProvenanceOutputs(
    Map<String, dynamic> target,
    ProvenanceLifeStageSelection selection,
  ) {
    final metadata = selection.provenanceType.metadata;
    target['provenanceTypeId'] = metadata.id;
    target['provenanceTypeLabel'] = metadata.displayName;
    target['lifeStageId'] = selection.lifeStage.id;
    target['lifeStageLabel'] = selection.lifeStage.displayName;
  }

  static LifeStage? _resolveLifeStage(Map<String, dynamic> row) {
    final candidates = [
      _string(row['lifeStageId']),
      _string(row['lifeStage']),
    ];
    for (final candidate in candidates) {
      final parsed = LifeStageX.tryParse(candidate);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static String _provenanceKind(
    Map<String, dynamic> row, {
    String defaultValue = '',
  }) {
    return _string(row['provenanceKind']) ??
        defaultValue;
  }

  static String _resolveProvenanceType(
    Map<String, dynamic> row, {
    String? defaultValue,
  }) {
    final explicit = _string(row['provenanceType']);
    final explicitParsed = ProvenanceTypeX.tryParse(explicit);
    if (explicitParsed != null) {
      return explicitParsed.id;
    }
    return defaultValue ?? '';
  }

  static String? _string(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  static String _boolString(dynamic value) {
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    final stringValue = value?.toString().toLowerCase().trim();
    if (stringValue == null) return 'false';
    return (stringValue == 'true' || stringValue == '1' || stringValue == 'yes')
        ? 'true'
        : 'false';
  }
}
