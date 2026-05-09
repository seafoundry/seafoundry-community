// @tier: community
import 'dart:convert';

import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/holding_record.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Builds spreadsheet/export rows for organism holdings (gamete/larval batches)
/// so permit/site metadata survives through the CSV pipeline.
class InventoryHoldingRowBuilder {
  const InventoryHoldingRowBuilder._();

  static Map<String, dynamic> build({
    required HoldingRecord holding,
    required Group? group,
    required String holdingKind,
    Map<String, dynamic>? overrides,
  }) {
    final metadata = holding.metadata;
    final organismRecord = holding.organismRecord;
    final metadataGroupPath = metadataValue(metadata, 'groupId');
    final attributes = holding.attributes;
    final lifeStageSpec = organismRecord.lifeStage;
    final lifeStageLabel = lifeStageSpec.stage.displayName;
    final physicalFormId = organismRecord.physicalForm?.formId;
    final physicalFormLabel = organismRecord.physicalFormDisplayName ?? '';
    final provenanceType = organismRecord.provenanceType;
    final metadataProvenanceTypeId =
        metadataValue(metadata, 'provenanceTypeId');
    final metadataProvenanceType =
        metadataProvenanceTypeId.isNotEmpty
            ? metadataProvenanceTypeId
            : metadataValue(metadata, 'provenanceType');
    final resolvedProvenanceTypeId =
        provenanceType?.id ??
        (metadataProvenanceType.isNotEmpty ? metadataProvenanceType : '');
    final metadataProvenanceTypeName =
        metadataValue(metadata, 'provenanceTypeName');
    final metadataProvenanceTypeLabel =
        metadataValue(metadata, 'provenanceTypeLabel');
    final resolvedProvenanceTypeName =
        provenanceType?.displayName ??
        (metadataProvenanceTypeName.isNotEmpty
            ? metadataProvenanceTypeName
            : metadataProvenanceTypeLabel);
    final metadataProvenanceKind = metadataValue(metadata, 'provenanceKind');
    final resolvedProvenanceKind =
        metadataProvenanceKind.isNotEmpty
            ? metadataProvenanceKind
            : provenanceType?.metadata.defaultProvenanceKind.name ?? '';
    final sizeSpec = organismRecord.sizeSpec;
    final resolvedMetrics = sizeSpec.resolvedMetrics();
    final ownerOrganizationId =
        holding.ownerOrganizationId ?? organismRecord.ownerOrganizationId ?? '';
    final managingOrganizationId =
        holding.managingOrganizationId ??
        organismRecord.managingOrganizationId ??
        '';
    final foreignKeysJson = organismRecord.foreignKeys.isEmpty
        ? ''
        : jsonEncode(
            organismRecord.foreignKeys.map(
              (key, reference) => MapEntry(key, reference.toJson()),
            ),
          );
    String attrOrMetadata(String? attributeValue, String key) {
      if (attributeValue != null && attributeValue.isNotEmpty) {
        return attributeValue;
      }
      return metadataValue(metadata, key);
    }

    final groupUrlPath = group?.urlPath;
    final groupPath = (groupUrlPath != null && groupUrlPath.isNotEmpty)
        ? groupUrlPath
        : metadataGroupPath;
    final location = _parseLocationSegments(groupPath);
    // Top-level siteId is canonical; use group fallback only for legacy data
    final siteId = holding.siteId ?? group?.siteId ?? '';
    final siteNameAttr = attrOrMetadata(attributes.siteName, 'siteName');
    final siteName = siteNameAttr.isNotEmpty ? siteNameAttr : location.siteName;
    final structureType = _deriveStructureType(group, metadata);
    final permitType = attrOrMetadata(attributes.permitType, 'permitType');
    final permitId = attrOrMetadata(attributes.permitId, 'permitId');
    final issuingAuthority = attrOrMetadata(
      attributes.issuingAuthority,
      'issuingAuthority',
    );
    final validFrom = attrOrMetadata(attributes.validFrom, 'validFrom');
    final validTo = attrOrMetadata(attributes.validTo, 'validTo');
    final habitatType = attrOrMetadata(attributes.habitatType, 'habitatType');
    final siteJurisdiction = attrOrMetadata(
      attributes.siteJurisdiction,
      'siteJurisdiction',
    );
    final protectedAreaFlag = attrOrMetadata(
      attributes.protectedAreaFlag,
      'protectedAreaFlag',
    );
    final speciesId = attrOrMetadata(attributes.speciesId, 'speciesId');
    final speciesCode = attrOrMetadata(attributes.speciesCode, 'speciesCode');
    final speciesScientific = attrOrMetadata(
      attributes.speciesScientific,
      'speciesScientific',
    );
    final enclosureId = attrOrMetadata(attributes.enclosureId, 'enclosureId');
    final dropperId = attrOrMetadata(attributes.dropperId, 'dropperId');
    final geometryFormat = attrOrMetadata(
      attributes.geometryFormat,
      'geometryFormat',
    );
    final geometryWkt = attrOrMetadata(attributes.geometryWkt, 'geometryWkt');
    final geometryGeoJson = attrOrMetadata(
      attributes.geometryGeojson,
      'geometryGeojson',
    );

    final aliases = organismRecord.aliases;
    final aliasesJson = aliases.isEmpty
        ? ''
        : jsonEncode(aliases.map((alias) => alias.toJson()).toList());
    final aliasLabels = aliases.isEmpty
        ? ''
        : aliases.map((alias) => alias.label ?? alias.value).join('; ');

    final localId = holding.organismRecord.localId ?? '';
    final tagId = holding.tagId;
    final urlPath = holding.urlPath.isNotEmpty
        ? holding.urlPath
        : organismRecord.urlPath;
    final row = <String, dynamic>{
      'holdingKind': holdingKind,
      'holdingId': holding.id,
      'localId': localId,
      'tagId': tagId,
      'urlPath': urlPath,
      'organismKind': holding.organismKind.name,
      'lifeStage': lifeStageLabel,
      'lifeStageLabel': lifeStageLabel,
      'lifeStageId': lifeStageSpec.stage.id,
      'lifeStageSubtype': lifeStageSpec.subtype ?? '',
      'physicalFormId': physicalFormId ?? '',
      'physicalForm': physicalFormLabel,
      'provenanceType': resolvedProvenanceTypeId,
      'provenanceTypeId': resolvedProvenanceTypeId,
      'provenanceTypeLabel': resolvedProvenanceTypeName,
      'provenanceTypeName': resolvedProvenanceTypeName,
      'eventType': 'inventory_snapshot',
      'eventDate': metadataValue(metadata, 'eventDate'),
      'measurementUnit': holding.measurement.unit.id,
      'quantityValue': holding.measurement.value.toString(),
      'sizeBandId':
          sizeSpec.sizeBandId ?? organismRecord.physicalForm?.sizeBandId ?? '',
      'measuredDimension': sizeSpec.measuredDimension?.toString() ?? '',
      'dimensionUnit': sizeSpec.dimensionUnit?.id ?? '',
      'organismsPerUnit': sizeSpec.organismsPerUnit?.toString() ?? '',
      'volumeAmount': sizeSpec.volumeAmount?.toString() ?? '',
      'volumeUnit': sizeSpec.volumeUnit?.id ?? '',
      'inventoryCount': resolvedMetrics.count?.toString() ?? '',
      'groupId': groupPath,
      'groupIdRaw': group?.id ?? holding.groupId ?? '',
      'siteId': siteId,
      'siteName': siteName,
      'enclosureId': enclosureId,
      'structureName': location.tankName,
      'nursery': siteName,
      'tank': location.tankName,
      'rack': location.rackName,
      'structureType': structureType,
      // Fall back to holding.id if provenanceId is not set (for round-trip compatibility)
      'provenanceId': holding.provenanceId ?? holding.id,
      'provenanceKind': resolvedProvenanceKind,
      'genetId': holding.provenanceId ?? '',
      'cohortId': holding.cohortId ?? '',
      'notes': metadataValue(metadata, 'notes'),
      'permitType': permitType,
      'permitId': permitId,
      'issuingAuthority': issuingAuthority,
      'validFrom': validFrom,
      'validTo': validTo,
      'habitatType': habitatType,
      'siteJurisdiction': siteJurisdiction,
      'protectedAreaFlag': protectedAreaFlag,
      'geometryFormat': geometryFormat,
      'geometryWkt': geometryWkt,
      'geometryGeojson': geometryGeoJson,
      'speciesScientific': speciesScientific,
      'speciesCode': speciesCode,
      'speciesId': speciesId,
      'readyForOutplant': '',
      'healthStatus': '',
      'size': '',
      'dropperId': dropperId,
      'createdAt': '',
      'updatedAt': '',
      'ownerOrganizationId': ownerOrganizationId,
      'managingOrganizationId': managingOrganizationId,
      'foreignKeys': foreignKeysJson,
      'aliasesJson': aliasesJson,
      'aliases': aliasLabels,
    };

    if (overrides != null) {
      for (final entry in overrides.entries) {
        if (entry.value == null) continue;
        row[entry.key] = entry.value;
      }
    }

    return row;
  }

  static String metadataValue(Map<String, dynamic>? metadata, String key) {
    if (metadata == null) return '';
    final value = metadata[key];
    if (value == null) return '';
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  static String formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    return value.toIso8601String();
  }

  static String coalesce(String primary, String fallback) {
    if (primary.isNotEmpty) {
      return primary;
    }
    return fallback;
  }

  static String _deriveStructureType(
    Group? group,
    Map<String, dynamic>? metadata,
  ) {
    final reported = metadataValue(metadata, 'structureType');
    if (reported.isNotEmpty) {
      return reported;
    }
    return group?.groupTypeId ?? '';
  }

  static _LocationSegments _parseLocationSegments(String groupPath) {
    final segments = groupPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final siteName = segments.length > 1 ? segments[1] : '';
    final tankName = segments.length > 2 ? segments[2] : '';
    final rackName = segments.length > 3 ? segments[3] : '';
    return _LocationSegments(
      siteName: siteName,
      tankName: tankName,
      rackName: rackName,
    );
  }
}

class _LocationSegments {
  const _LocationSegments({
    required this.siteName,
    required this.tankName,
    required this.rackName,
  });

  final String siteName;
  final String tankName;
  final String rackName;
}
