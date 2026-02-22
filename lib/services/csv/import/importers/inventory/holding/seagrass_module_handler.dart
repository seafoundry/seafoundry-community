// @tier: community
import 'package:seafoundry_app/models/holdings/seagrass_module_holding.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/holding_repository.dart';
import 'package:seafoundry_app/repositories/inventory/seagrass_module_repository.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/builders/holding_metadata_builder.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/holding/holding_type_handler.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_row_parser.dart';

/// Handler for seagrass module holding type.
class SeagrassModuleHandler extends HoldingTypeHandler<SeagrassModuleHolding> {
  SeagrassModuleHandler({
    required Map<OrganismKind, SeagrassModuleRepository> repositories,
  }) : _repositories = repositories;

  final Map<OrganismKind, SeagrassModuleRepository> _repositories;

  @override
  String get holdingKind => 'seagrassModuleHolding';

  @override
  HoldingRepository<SeagrassModuleHolding>? getRepository(
    OrganismKind organismKind,
  ) {
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
        formId: 'sprig_module',
        sizeBandId: params.sizeSpec.sizeBandId ?? 'medium',
      ),
      sizeSpec: params.sizeSpec,
    );
  }

  @override
  SeagrassModuleHolding buildHolding(HoldingBuildParams params) {
    final row = params.row;
    final organismRecord = buildOrganismRecord(params);

    return SeagrassModuleHolding(
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
      coveragePercent: InventoryRowParser.parseDouble(row['coveragePercent']),
      canopyHeightCm: InventoryRowParser.parseDouble(row['canopyHeightCm']),
      moduleAreaSquareMeters: InventoryRowParser.parseDouble(
        row['moduleAreaSquareMeters'],
      ),
      plantedAt: InventoryRowParser.parseIsoDate(row['eventDate']),
      metadata: HoldingMetadataBuilder.build(row, params.sourceName),
    );
  }
}
