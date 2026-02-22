// @tier: community
import 'package:seafoundry_app/models/holdings/oyster_bag_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final oysterBagHoldingConfig = HoldingDialogConfig(
  title: 'Record Oyster Bag Inventory',
  defaultName: 'Oyster Bag',
  quantityLabel: 'Quantity (count)',
  dateFieldLabel: 'Deployment date',
  organismKind: OrganismKind.oyster,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: LifeStage.larva,
  initialPhysicalFormId: 'spat_bag',
  successMessage: 'Oyster bag inventory recorded successfully',
  fieldKeyPrefix: 'oyster-bag',
  fiveAxisHelpText:
      'Ensure the provenance, life stage, physical form, and size match the spat being recorded.',
  extraField: const ExtraFieldConfig(
    label: 'Depth (m)',
    helperText: 'Optional',
    controllerName: 'depth',
  ),
  holdingFactory: (params) => OysterBagHolding(
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
    bagIdentifier: params.bagIdentifier,
    depthMeters: params.extraFieldValue,
    deployedAt: params.dateValue,
  ),
);
