import 'package:seafoundry_app/models/alias.dart';

import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Contract for services that can register a genet manually (without a
/// transfer manifest) while preserving alias and ownership metadata.
abstract class ManualTransferRegistrationService {
  Future<ProvenanceRecord> registerManualGenet({
    required String name,
    required String speciesId,
    required ProvenanceType provenanceType,
    required LifeStage lifeStage,
    OrganismKind organismKind,
    String? physicalFormId,
    SizeSpec sizeSpec,
    String? comment,
    String? fromOrganizationId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
    String? sourceContactEmail,
    String? sourceProvenanceId,
    List<OrganismAlias> aliases,
  });
}
