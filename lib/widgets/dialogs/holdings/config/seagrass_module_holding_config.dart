// @tier: community
import 'package:seafoundry_app/models/holdings/seagrass_module_holding.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final seagrassModuleHoldingConfig = HoldingDialogConfig(
  title: 'Record Seagrass Module Inventory',
  defaultName: 'Seagrass Module',
  quantityLabel: 'Module count',
  dateFieldLabel: 'Deployment date',
  organismKind: OrganismKind.seagrass,
  initialProvenanceType: ProvenanceType.wild,
  initialLifeStage: ProvenanceType.wild.defaultLifeStage,
  initialPhysicalFormId: 'sprig_module',
  successMessage: 'Seagrass module inventory recorded successfully',
  fieldKeyPrefix: 'seagrass-module',
  fiveAxisHelpText:
      'Captures provenance, life stage, physical form, and size spec for this module.',
  extraField: const ExtraFieldConfig(
    label: 'Coverage (%)',
    helperText: 'Optional',
    controllerName: 'coverage',
  ),
  holdingFactory: (params) => SeagrassModuleHolding(
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
    coveragePercent: params.extraFieldValue,
    canopyHeightCm: null,
    moduleAreaSquareMeters: null,
    plantedAt: params.dateValue,
  ),
);
