// @tier: community
import 'dart:collection';
import 'dart:convert';

import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';

/// Canonical DTO for inventory export rows. Normalises both coral inventory
/// records and organism holdings (seeded lines, gamete batches, larval batches)
/// into a flat map that can be fed directly into `InventoryExportRowFormatter`
/// and, ultimately, `UniversalCsvAdapterV2`.
class InventoryExportRow {
  InventoryExportRow._(Map<String, dynamic> data)
    : _data = UnmodifiableMapView(Map<String, dynamic>.from(data));

  final Map<String, dynamic> _data;

  Map<String, dynamic> toMap() => _data;

  static InventoryExportRow fromOrganism({
    required OrganismRecord organism,
    Group? group,
    Genet? genet,
  }) {
    final measurement = organism.measurement;
    final measurementUnit = measurement.unit.id;
    final measurementValue = measurement.value.toString();

    final groupPath = group?.urlPath ?? organism.urlPath;
    final segments = groupPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final nurseryName = segments.length > 1 ? segments[1] : '';
    final tankName = segments.length > 2 ? segments[2] : '';
    final rackName = segments.length > 3 ? segments[3] : '';

    final lifeStage = organism.lifeStage.stage;
    final provenanceSelection = buildProvenanceSelection(organism: organism);
    final provenanceMetadata = provenanceSelection.provenanceType.metadata;
    final provenanceKind = provenanceMetadata.defaultProvenanceKind.name;

    final metadata = organism.metadata ?? const <String, dynamic>{};
    final ownerOrgId = (organism.ownerOrganizationId ?? '').trim();
    final managingOrgId = (organism.managingOrganizationId ?? '').trim();
    final recordName = organism.recordName.trim();

    final aliasEntries = organism.aliases;
    final aliasJson = aliasEntries.isEmpty
        ? ''
        : jsonEncode(aliasEntries.map((alias) => alias.toJson()).toList());
    final aliasLabels = aliasEntries.isEmpty
        ? ''
        : aliasEntries
              .map(
                (alias) => (alias.label?.trim().isNotEmpty == true
                    ? alias.label!.trim()
                    : alias.value.trim()),
              )
              .where((label) => label.isNotEmpty)
              .join('; ');

    final healthStatus = organism.healthStatus;
    final size = organism.coralSize?.toString() ?? '';
    final notes = organism.notes ?? '';
    final genetId = genet?.id ?? GenetIdResolver.resolve(organism) ?? '';
    // Provenance ID comes from the actual Genet record, not from stale FK
    // metadata. If no genet is loaded, leave empty.
    final lineageProvenanceId = genet?.provenanceId ?? '';
    final readyForOutplant = metadata['readyForOutplant'] as bool? ?? false;

    // Five-axis fields: physical form + size spec
    final physicalForm = organism.physicalForm;
    final sizeSpec = organism.sizeSpec;
    final sizeBandId =
        physicalForm?.sizeBandId ?? sizeSpec.sizeBandId ?? '';
    final resolvedMetrics = sizeSpec.resolvedMetrics();

    final row = <String, dynamic>{
      'coralId': organism.id,
      'provenanceId': lineageProvenanceId,
      'localId': organism.localId ?? '',
      'recordName': recordName,
      'organismKind': organism.organismKind.name,
      'lifeStage': lifeStage.name,
      'eventType': 'inventory_snapshot',
      'eventDate': organism.updatedAt,
      'speciesId': organism.speciesId ?? '',
      'groupId': groupPath,
      'groupIdRaw': organism.groupId,
      'quantityValue': measurementValue,
      'measurementUnit': measurementUnit,
      'healthStatus': healthStatus.id,
      'size': size,
      'notes': notes,
      'lastEventAt': organism.updatedAt,
      'genetId': genetId,
      'lifeStageId': lifeStage.id,
      'lifeStageName': lifeStage.displayName,
      'provenanceType': provenanceMetadata.id,
      'provenanceTypeId': provenanceMetadata.id,
      'provenanceTypeName': provenanceMetadata.displayName,
      'provenanceKind': provenanceKind,
      'readyForOutplant': readyForOutplant,
      'siteId': organism.siteId,
      'siteName': nurseryName,
      'nursery': nurseryName,
      'tank': tankName,
      'rack': rackName,
      'structureName': tankName,
      'structureType': group?.groupTypeId ?? '',
      'createdAt': organism.createdAt,
      'updatedAt': organism.updatedAt,
      'dropperId': '',
      'ownerOrganizationId': ownerOrgId,
      'managingOrganizationId': managingOrgId,
      'aliasesJson': aliasJson,
      'aliases': aliasLabels,
      // Five-axis: Physical Form
      'physicalFormId': physicalForm?.formId ?? '',
      'physicalForm': organism.physicalFormDisplayName ?? '',
      // Five-axis: Size Spec
      'sizeBandId': sizeBandId,
      'measuredDimension': sizeSpec.measuredDimension?.toString() ?? '',
      'dimensionUnit': sizeSpec.dimensionUnit?.id ?? '',
      'organismsPerUnit': sizeSpec.organismsPerUnit?.toString() ?? '',
      'volumeAmount': sizeSpec.volumeAmount?.toString() ?? '',
      'volumeUnit': sizeSpec.volumeUnit?.id ?? '',
      'inventoryCount': resolvedMetrics.count?.toString() ?? '',
    };

    return InventoryExportRow._(row);
  }

  static InventoryExportRow fromHoldingMap(Map<String, dynamic> map) {
    return InventoryExportRow._(map);
  }
}
