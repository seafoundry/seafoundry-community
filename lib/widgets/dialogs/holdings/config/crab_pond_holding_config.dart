// @tier: community
import 'package:seafoundry_app/models/holdings/crab_pond_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final crabPondHoldingConfig = HoldingDialogConfig(
  title: 'Record Crab Pond Inventory',
  defaultName: 'Crab Cohort',
  quantityLabel: 'Quantity (count)',
  dateFieldLabel: 'Stocking date',
  organismKind: OrganismKind.crab,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: ProvenanceType.sexualCohort.defaultLifeStage,
  initialPhysicalFormId: 'batch',
  successMessage: 'Crab pond inventory recorded successfully',
  fieldKeyPrefix: 'crab-pond',
  fiveAxisHelpText:
      'Keeps provenance, life stage, physical form, and size data in sync with crab cohorts.',
  extraField: const ExtraFieldConfig(
    label: 'Average carapace width (mm)',
    helperText: 'Optional',
    controllerName: 'carapace',
  ),
  holdingFactory: (params) => CrabPondHolding(
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
    averageCarapaceWidthMm: params.extraFieldValue,
    stockedAt: params.dateValue,
  ),
);
