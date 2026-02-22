// @tier: community
import 'package:seafoundry_app/models/holdings/seeded_line_batch.dart';
import 'package:seafoundry_app/models/inventory/holding_attributes.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/dialogs/holdings/holding_dialog_config.dart';

final seededLineHoldingConfig = HoldingDialogConfig(
  title: 'Record Seeded Line Batch',
  defaultName: 'Seeded Line',
  quantityLabel: 'Biomass (kg/m)',
  dateFieldLabel: 'Deployment date',
  organismKind: OrganismKind.kelp,
  initialProvenanceType: ProvenanceType.sexualCohort,
  initialLifeStage: ProvenanceType.sexualCohort.defaultLifeStage,
  initialPhysicalFormId: 'seeded_line_segment',
  successMessage: 'Seeded line batch recorded successfully',
  fieldKeyPrefix: 'seeded-line',
  fiveAxisHelpText:
      'Captures provenance, life stage, physical form, and size for the batch.',
  extraField: const ExtraFieldConfig(
    label: 'Line length (m)',
    helperText: 'Optional',
    controllerName: 'lineLength',
  ),
  holdingFactory: (params) => SeededLineBatch(
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
    lineIdentifier: null,
    lineLengthMeters: params.extraFieldValue,
    deployedAt: params.dateValue,
  ),
);
