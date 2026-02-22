// @tier: community
import 'package:seafoundry_app/models/holdings/finfish_pen_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final finfishPenHoldingConfig = HoldingDialogConfig(
  title: 'Record Finfish Pen Inventory',
  defaultName: 'Finfish Batch',
  quantityLabel: 'Quantity (count)',
  dateFieldLabel: 'Stocking date',
  organismKind: OrganismKind.finfish,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: ProvenanceType.sexualCohort.defaultLifeStage,
  initialPhysicalFormId: 'batch',
  successMessage: 'Finfish pen inventory recorded successfully',
  fieldKeyPrefix: 'finfish-pen',
  fiveAxisHelpText:
      'Select the provenance, life stage, physical form, and size class for this pen population.',
  extraField: const ExtraFieldConfig(
    label: 'Average weight (g)',
    helperText: 'Optional',
    controllerName: 'weight',
  ),
  holdingFactory: (params) => FinfishPenHolding(
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
    averageWeightGrams: params.extraFieldValue,
    stockedAt: params.dateValue,
  ),
);
