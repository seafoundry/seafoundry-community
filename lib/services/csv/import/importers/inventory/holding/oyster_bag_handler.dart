// @tier: community
import 'package:seafoundry_app/models/holdings/oyster_bag_holding.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/oyster_bag_repository.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/holding_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_type_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_row_parser.dart';

/// Handler for oyster bag holding type.
class OysterBagHandler extends HoldingTypeHandler<OysterBagHolding> {
  OysterBagHandler({
    required Map<OrganismKind, OysterBagRepository> repositories,
  }) : _repositories = repositories;

  final Map<OrganismKind, OysterBagRepository> _repositories;

  @override
  String get holdingKind => 'oysterBagHolding';

  @override
  HoldingRepository<OysterBagHolding>? getRepository(OrganismKind organismKind) {
    return _repositories[organismKind];
  }

  @override
  OrganismRecord buildOrganismRecord(HoldingBuildParams params) {
    return OrganismRecord.partial(
      organismKind: params.organismKind,
      localId: params.localId,
      recordName: params.recordName,
      lifeStage: const LifeStageSpec(stage: LifeStage.juvenile),
      measurement: params.measurement,
      aliases: params.aliases,
      ownerOrganizationId: params.ownerOrganizationId,
      managingOrganizationId: params.managingOrganizationId,
      foreignKeys: params.foreignKeys,
      physicalForm: PhysicalFormInstance(
        formId: 'spat_bag',
        sizeBandId: params.sizeSpec.sizeBandId ?? 'medium',
      ),
      sizeSpec: params.sizeSpec,
    );
  }

  @override
  OysterBagHolding buildHolding(HoldingBuildParams params) {
    final row = params.row;
    final organismRecord = buildOrganismRecord(params);

    return OysterBagHolding(
      id: params.provenanceId,
      recordName: params.recordName,
      organismKind: params.organismKind,
      measurement: params.measurement,
      provenanceId: InventoryRowParser.emptyToNull(row['provenanceId']),
      cohortId: InventoryRowParser.emptyToNull(row['cohortId']),
      siteId: params.targetGroup.siteId,
      groupId: params.targetGroup.id,
      structureId: params.targetGroup.id,
      ownerOrganizationId: params.ownerOrganizationId,
      managingOrganizationId: params.managingOrganizationId,
      foreignKeys: params.foreignKeys,
      attributes: params.attributes,
      organismRecord: organismRecord,
      bagIdentifier: InventoryRowParser.emptyToNull(
        row['bagIdentifier'] ?? row['bagId'],
      ),
      depthMeters: InventoryRowParser.parseDouble(row['depthMeters']),
      deployedAt: InventoryRowParser.parseIsoDate(row['eventDate']),
      metadata: HoldingMetadataBuilder.build(row, params.sourceName),
    );
  }
}
