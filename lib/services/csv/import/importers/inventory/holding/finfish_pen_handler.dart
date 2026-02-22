// @tier: community
import 'package:seafoundry_app/models/holdings/finfish_pen_holding.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/finfish_pen_repository.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/holding_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_type_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_row_parser.dart';

/// Handler for finfish pen holding type.
class FinfishPenHandler extends HoldingTypeHandler<FinfishPenHolding> {
  FinfishPenHandler({
    required Map<OrganismKind, FinfishPenRepository> repositories,
  }) : _repositories = repositories;

  final Map<OrganismKind, FinfishPenRepository> _repositories;

  @override
  String get holdingKind => 'finfishPenHolding';

  @override
  HoldingRepository<FinfishPenHolding>? getRepository(OrganismKind organismKind) {
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
        formId: 'batch',
        sizeBandId: params.sizeSpec.sizeBandId ?? 'medium',
      ),
      sizeSpec: params.sizeSpec,
    );
  }

  @override
  FinfishPenHolding buildHolding(HoldingBuildParams params) {
    final row = params.row;
    final organismRecord = buildOrganismRecord(params);

    return FinfishPenHolding(
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
      averageWeightGrams: InventoryRowParser.parseDouble(
        row['averageWeightGrams'],
      ),
      stockedAt: InventoryRowParser.parseIsoDate(row['eventDate']),
      metadata: HoldingMetadataBuilder.build(row, params.sourceName),
    );
  }
}
