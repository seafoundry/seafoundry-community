// @tier: community
import 'package:seafoundry_app/models/holdings/larval_batch.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/larval_batch_repository.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/holding_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_type_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_row_parser.dart';

/// Handler for larval batch holding type.
class LarvalBatchHandler extends HoldingTypeHandler<LarvalBatch> {
  LarvalBatchHandler({
    required Map<OrganismKind, LarvalBatchRepository> repositories,
  }) : _repositories = repositories;

  final Map<OrganismKind, LarvalBatchRepository> _repositories;

  @override
  String get holdingKind => 'larvalBatch';

  @override
  HoldingRepository<LarvalBatch>? getRepository(OrganismKind organismKind) {
    return _repositories[organismKind];
  }

  @override
  OrganismRecord buildOrganismRecord(HoldingBuildParams params) {
    return OrganismRecord.partial(
      organismKind: params.organismKind,
      localId: params.localId,
      recordName: params.recordName,
      lifeStage: const LifeStageSpec(stage: LifeStage.larva),
      measurement: params.measurement,
      aliases: params.aliases,
      ownerOrganizationId: params.ownerOrganizationId,
      managingOrganizationId: params.managingOrganizationId,
      foreignKeys: params.foreignKeys,
      sizeSpec: params.sizeSpec,
    );
  }

  @override
  LarvalBatch buildHolding(HoldingBuildParams params) {
    final row = params.row;
    final organismRecord = buildOrganismRecord(params);

    return LarvalBatch(
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
      settlementWindowStart:
          InventoryRowParser.parseIsoDate(row['settlementWindowStart']) ??
              InventoryRowParser.parseIsoDate(row['eventDate']),
      settlementWindowEnd:
          InventoryRowParser.parseIsoDate(row['settlementWindowEnd']),
      metadata: HoldingMetadataBuilder.build(row, params.sourceName),
    );
  }
}
