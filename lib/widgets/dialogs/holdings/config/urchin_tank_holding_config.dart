// @tier: community
import 'package:seafoundry_app/models/holdings/urchin_tank_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final urchinTankHoldingConfig = HoldingDialogConfig(
  title: 'Record Urchin Tank Inventory',
  defaultName: 'Urchin Tank',
  quantityLabel: 'Quantity (count)',
  dateFieldLabel: 'Stocking date',
  organismKind: OrganismKind.echinoid,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: LifeStage.juvenile,
  initialPhysicalFormId: 'batch',
  successMessage: 'Urchin tank inventory recorded successfully',
  fieldKeyPrefix: 'urchin-tank',
  fiveAxisHelpText:
      'Ensure the provenance, life stage, physical form, and size match the urchins being recorded.',
  extraField: const ExtraFieldConfig(
    label: 'Average test diameter (mm)',
    helperText: 'Optional – primary size metric for urchins',
    controllerName: 'testDiameter',
  ),
  holdingFactory: (params) => UrchinTankHolding(
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
    averageTestDiameterMm: params.extraFieldValue,
    stockedAt: params.dateValue,
  ),
);
