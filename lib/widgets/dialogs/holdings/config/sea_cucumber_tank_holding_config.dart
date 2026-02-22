// @tier: community
import 'package:seafoundry_app/models/holdings/sea_cucumber_tank_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final seaCucumberTankHoldingConfig = HoldingDialogConfig(
  title: 'Record Sea Cucumber Inventory',
  defaultName: 'Sea Cucumber Tank',
  quantityLabel: 'Quantity (count)',
  dateFieldLabel: 'Stocking date',
  organismKind: OrganismKind.seaCucumber,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: LifeStage.juvenile,
  initialPhysicalFormId: 'batch',
  successMessage: 'Sea cucumber tank inventory recorded successfully',
  fieldKeyPrefix: 'sea-cucumber-tank',
  fiveAxisHelpText:
      'Ensure the provenance, life stage, physical form, and size match the sea cucumbers being recorded.',
  extraField: const ExtraFieldConfig(
    label: 'Avg. weight (g)',
    helperText: 'Optional',
    controllerName: 'weight',
  ),
  holdingFactory: (params) => SeaCucumberTankHolding(
    id: '',
    recordName: params.recordName,
    localId: params.localId,
    organismKind: params.organismKind,
    measurement: params.measurement,
    siteId: params.siteId,
    groupId: params.groupId,
    structureId: params.groupId,
    ownerOrganizationId: params.ownerOrganizationId,
    managingOrganizationId: params.managingOrganizationId,
    attributes: const HoldingAttributes(),
    organismRecord: params.organismRecord,
    organismLifeStage: params.organismLifeStage,
    tankIdentifier: null,
    averageBodyWeightGrams: params.extraFieldValue,
    averageLengthCm: null,
    stockedAt: params.dateValue,
  ),
);
