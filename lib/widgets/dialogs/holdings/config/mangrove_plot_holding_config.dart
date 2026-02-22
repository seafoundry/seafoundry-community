// @tier: community
import 'package:seafoundry_app/models/holdings/mangrove_plot_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final mangrovePlotHoldingConfig = HoldingDialogConfig(
  title: 'Record Mangrove Planting',
  defaultName: 'Mangrove Planting',
  quantityLabel: 'Sapling count',
  dateFieldLabel: 'Planting date',
  organismKind: OrganismKind.mangrove,
  initialProvenanceType: ProvenanceType.wild,
  initialLifeStage: ProvenanceType.wild.defaultLifeStage,
  initialPhysicalFormId: 'plot_mat',
  successMessage: 'Mangrove planting recorded successfully',
  fieldKeyPrefix: 'mangrove-plot',
  fiveAxisHelpText:
      'Use this to align provenance, life stage, physical form, and size metadata with the plot inventory.',
  extraField: const ExtraFieldConfig(
    label: 'Average height (cm)',
    helperText: 'Optional',
    controllerName: 'height',
  ),
  holdingFactory: (params) => MangrovePlotHolding(
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
    averageHeightCm: params.extraFieldValue,
    survivalPercent: null,
    plantedAt: params.dateValue,
  ),
);
