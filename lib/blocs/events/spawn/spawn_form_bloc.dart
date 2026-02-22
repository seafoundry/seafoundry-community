// @tier: community
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/geometry_form_inputs.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/events/spawn/gamete_collection_entry.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/constants/schema.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/event_permit_metadata.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/events/spawn_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/records/archive_metadata.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/outplant_geometry_builder.dart';
import 'package:seafoundry_app/services/outplant_geometry_parser.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/utils/record_name_derived.dart';
import 'package:seafoundry_app/utils/record_name_suggester.dart';

// Event classes for form inputs
class ParentOrganismsChanged extends RecordFormInputEvent<List<String>> {
  const ParentOrganismsChanged(super.value);
}

class GameteCountChanged extends RecordFormInputEvent<int?> {
  const GameteCountChanged(super.value);
}

class GameteRoleChanged extends RecordFormInputEvent<ProvenanceGameteRole?> {
  const GameteRoleChanged(super.value);
}

class SpawnNotesChanged extends RecordFormInputEvent<String> {
  const SpawnNotesChanged(super.value);
}

class GameteLocalIdChanged extends RecordFormInputEvent<String?> {
  const GameteLocalIdChanged(super.value);
}

class GameteRecordNameChanged extends RecordFormInputEvent<String?> {
  const GameteRecordNameChanged(super.value);
}

class GametePhysicalFormChanged extends RecordFormInputEvent<String?> {
  const GametePhysicalFormChanged(super.value);
}

class GameteSizeSpecChanged extends RecordFormInputEvent<SizeSpec?> {
  const GameteSizeSpecChanged(super.value);
}

class GameteDestinationChanged extends RecordFormInputEvent<GroupNode?> {
  const GameteDestinationChanged(super.value);
}

class SpawnProvenanceSelectionChanged extends RecordFormEvent {
  const SpawnProvenanceSelectionChanged(this.selection);

  final ProvenanceLifeStageSelection selection;

  @override
  List<Object?> get props => [selection];
}

// New events for multi-gamete collection
class DamGameteCollectionChanged extends RecordFormEvent {
  const DamGameteCollectionChanged(this.entry);
  final GameteCollectionEntry entry;

  @override
  List<Object?> get props => [entry];
}

class SireGameteCollectionChanged extends RecordFormEvent {
  const SireGameteCollectionChanged(this.entry);
  final GameteCollectionEntry entry;

  @override
  List<Object?> get props => [entry];
}

// Events for cohort creation
class CohortLocalIdChanged extends RecordFormInputEvent<String?> {
  const CohortLocalIdChanged(super.value);
}

class CohortRecordNameChanged extends RecordFormInputEvent<String?> {
  const CohortRecordNameChanged(super.value);
}

class CohortPhysicalFormChanged extends RecordFormInputEvent<String?> {
  const CohortPhysicalFormChanged(super.value);
}

class CohortSizeSpecChanged extends RecordFormInputEvent<SizeSpec?> {
  const CohortSizeSpecChanged(super.value);
}

class CohortDestinationChanged extends RecordFormInputEvent<GroupNode?> {
  const CohortDestinationChanged(super.value);
}

/// Form input for parent organism selection
class ParentOrganismsInput
    extends
        RecordFormInput<
          List<String>,
          RequiredInputError,
          ParentOrganismsChanged
        > {
  const ParentOrganismsInput.pure() : super.pure();
  const ParentOrganismsInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Parent Organisms';

  @override
  String? get hintText => 'Select organisms that spawned';

  @override
  RequiredInputError? validator(List<String>? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError(
        'Please select at least one parent organism',
      );
    }
    return null;
  }

  @override
  ParentOrganismsInput copyWith({required List<String>? value}) {
    return value == null
        ? const ParentOrganismsInput.pure()
        : ParentOrganismsInput.dirty(value);
  }
}

/// Form input for gamete count
class GameteCountInput
    extends RecordFormInput<int?, RequiredInputError, GameteCountChanged> {
  const GameteCountInput.pure() : super.pure();
  const GameteCountInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Number of containers collected';

  @override
  String? get hintText => 'Enter number of containers collected';

  @override
  RequiredInputError? validator(int? value) {
    if (value == null) {
      return const RequiredInputError(
        'Please enter number of containers collected',
      );
    }
    if (value <= 0) {
      return const RequiredInputError('Count must be greater than zero');
    }
    return null;
  }

  @override
  GameteCountInput copyWith({required int? value}) {
    return value == null
        ? const GameteCountInput.pure()
        : GameteCountInput.dirty(value);
  }
}

/// Form input for gamete role (egg or sperm)
class GameteRoleInput
    extends
        RecordFormInput<
          ProvenanceGameteRole?,
          RequiredInputError,
          GameteRoleChanged
        > {
  const GameteRoleInput.pure() : super.pure();
  const GameteRoleInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Gamete Type';

  @override
  String? get hintText => 'Select eggs or sperm';

  @override
  RequiredInputError? validator(ProvenanceGameteRole? value) {
    if (value == null) {
      return const RequiredInputError('Please select eggs or sperm');
    }
    return null;
  }

  @override
  GameteRoleInput copyWith({required ProvenanceGameteRole? value}) {
    return value == null
        ? const GameteRoleInput.pure()
        : GameteRoleInput.dirty(value);
  }
}

/// Form input for spawn notes
class SpawnNotesInput
    extends RecordFormInput<String, RecordFormInputError, SpawnNotesChanged> {
  const SpawnNotesInput.pure() : super.pure();
  const SpawnNotesInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Optional spawning notes';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  SpawnNotesInput copyWith({required String? value}) {
    return value == null
        ? const SpawnNotesInput.pure()
        : SpawnNotesInput.dirty(value);
  }
}

/// Form input for gamete local ID (shared with parent organism)
class GameteLocalIdInput
    extends RecordFormInput<String, RequiredInputError, GameteLocalIdChanged> {
  const GameteLocalIdInput.pure() : super.pure();
  const GameteLocalIdInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Local ID';

  @override
  String? get hintText => 'Inherited from parent organism';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Local ID required for gamete record');
    }
    return null;
  }

  @override
  GameteLocalIdInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const GameteLocalIdInput.pure()
        : GameteLocalIdInput.dirty(trimmed);
  }
}

/// Form input for gamete record name
class GameteRecordNameInput
    extends
        RecordFormInput<String, RequiredInputError, GameteRecordNameChanged> {
  const GameteRecordNameInput.pure() : super.pure();
  const GameteRecordNameInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Record Name';

  @override
  String? get hintText => 'Suggested from local ID';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Record name required');
    }
    if (trimmed.length < 2) {
      return const RequiredInputError('Name must be at least 2 characters');
    }
    if (trimmed.length > 50) {
      return const RequiredInputError('Name must be less than 50 characters');
    }
    if (!RegExp(r'^[a-zA-Z0-9\s\-_]+$').hasMatch(trimmed)) {
      return const RequiredInputError('Name contains invalid characters');
    }
    return null;
  }

  @override
  GameteRecordNameInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const GameteRecordNameInput.pure()
        : GameteRecordNameInput.dirty(trimmed);
  }
}

/// Form input for gamete physical form selection
class GametePhysicalFormInput
    extends
        RecordFormInput<String, RequiredInputError, GametePhysicalFormChanged> {
  const GametePhysicalFormInput.pure() : super.pure();
  const GametePhysicalFormInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Physical Form';

  @override
  String? get hintText => 'Select a physical form';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const RequiredInputError('Select a physical form');
    }
    return null;
  }

  @override
  GametePhysicalFormInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const GametePhysicalFormInput.pure()
        : GametePhysicalFormInput.dirty(trimmed);
  }
}

/// Form input for gamete size spec (size class)
class GameteSizeSpecInput
    extends
        RecordFormInput<SizeSpec?, RequiredInputError, GameteSizeSpecChanged> {
  const GameteSizeSpecInput.pure() : super.pure();
  const GameteSizeSpecInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Size Class';

  @override
  String? get hintText => 'Select a size class';

  @override
  RequiredInputError? validator(SizeSpec? value) {
    final sizeClass = value?.sizeClass?.trim();
    final sizeBandId = value?.sizeBandId?.trim();
    if ((sizeClass == null || sizeClass.isEmpty) &&
        (sizeBandId == null || sizeBandId.isEmpty)) {
      return const RequiredInputError('Select a size class');
    }
    return null;
  }

  @override
  GameteSizeSpecInput copyWith({required SizeSpec? value}) {
    if (value == null || value.isEmpty) {
      return const GameteSizeSpecInput.pure();
    }
    return GameteSizeSpecInput.dirty(value);
  }
}

/// Form input for gamete destination (structure/substructure)
class GameteDestinationInput
    extends
        RecordFormInput<
          GroupNode,
          RequiredInputError,
          GameteDestinationChanged
        > {
  const GameteDestinationInput.pure() : super.pure();
  const GameteDestinationInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Destination';

  @override
  String? get hintText => 'Select a structure or substructure';

  @override
  RequiredInputError? validator(GroupNode? value) {
    if (value == null) {
      return const RequiredInputError('Select a destination structure');
    }
    return null;
  }

  @override
  GameteDestinationInput copyWith({required GroupNode? value}) {
    return value == null
        ? const GameteDestinationInput.pure()
        : GameteDestinationInput.dirty(value);
  }
}

// Cohort form inputs
class CohortLocalIdInput
    extends RecordFormInput<String, RequiredInputError, CohortLocalIdChanged> {
  const CohortLocalIdInput.pure() : super.pure();
  const CohortLocalIdInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cohort Local ID';

  @override
  String? get hintText => 'Unique identifier for the cohort';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Cohort local ID is required');
    }
    return null;
  }

  @override
  CohortLocalIdInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const CohortLocalIdInput.pure()
        : CohortLocalIdInput.dirty(trimmed);
  }
}

class CohortRecordNameInput
    extends
        RecordFormInput<String, RequiredInputError, CohortRecordNameChanged> {
  const CohortRecordNameInput.pure() : super.pure();
  const CohortRecordNameInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cohort Record Name';

  @override
  String? get hintText => 'Display name for the cohort';

  @override
  RequiredInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RequiredInputError('Cohort record name is required');
    }
    return null;
  }

  @override
  CohortRecordNameInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const CohortRecordNameInput.pure()
        : CohortRecordNameInput.dirty(trimmed);
  }
}

class CohortPhysicalFormInput
    extends
        RecordFormInput<String, RequiredInputError, CohortPhysicalFormChanged> {
  const CohortPhysicalFormInput.pure() : super.pure();
  const CohortPhysicalFormInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cohort Physical Form';

  @override
  String? get hintText => 'Select physical form for larvae';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const RequiredInputError('Select a physical form for the cohort');
    }
    return null;
  }

  @override
  CohortPhysicalFormInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty
        ? const CohortPhysicalFormInput.pure()
        : CohortPhysicalFormInput.dirty(trimmed);
  }
}

class CohortSizeSpecInput
    extends
        RecordFormInput<SizeSpec?, RequiredInputError, CohortSizeSpecChanged> {
  const CohortSizeSpecInput.pure() : super.pure();
  const CohortSizeSpecInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cohort Size Class';

  @override
  String? get hintText => 'Select size class for larvae';

  @override
  RequiredInputError? validator(SizeSpec? value) {
    // Size spec is optional for cohort
    return null;
  }

  @override
  CohortSizeSpecInput copyWith({required SizeSpec? value}) {
    if (value == null || value.isEmpty) {
      return const CohortSizeSpecInput.pure();
    }
    return CohortSizeSpecInput.dirty(value);
  }
}

class CohortDestinationInput
    extends
        RecordFormInput<
          GroupNode,
          RequiredInputError,
          CohortDestinationChanged
        > {
  const CohortDestinationInput.pure() : super.pure();
  const CohortDestinationInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cohort Destination';

  @override
  String? get hintText => 'Select destination for the cohort';

  @override
  RequiredInputError? validator(GroupNode? value) {
    if (value == null) {
      return const RequiredInputError('Select a destination for the cohort');
    }
    return null;
  }

  @override
  CohortDestinationInput copyWith({required GroupNode? value}) {
    return value == null
        ? const CohortDestinationInput.pure()
        : CohortDestinationInput.dirty(value);
  }
}

/// State for spawn event form
class SpawnFormState extends EventFormState<SpawnEvent> {
  SpawnFormState({
    ParentOrganismsInput parentOrganisms = const ParentOrganismsInput.pure(),
    GameteCountInput gameteCount = const GameteCountInput.pure(),
    GameteRoleInput gameteRole = const GameteRoleInput.pure(),
    SpawnNotesInput notes = const SpawnNotesInput.pure(),
    GameteLocalIdInput gameteLocalId = const GameteLocalIdInput.pure(),
    GameteRecordNameInput gameteRecordName = const GameteRecordNameInput.pure(),
    GametePhysicalFormInput gametePhysicalForm =
        const GametePhysicalFormInput.pure(),
    GameteSizeSpecInput gameteSizeSpec = const GameteSizeSpecInput.pure(),
    GameteDestinationInput gameteDestination =
        const GameteDestinationInput.pure(),
    GeometryTextInput geometryText = const GeometryTextInput.pure(),
    this.provenanceSelection = const ProvenanceLifeStageSelection(
      provenanceType: ProvenanceType.sexualCohort,
      lifeStage: LifeStage.gamete,
    ),
    PermitIdInput permitId = const PermitIdInput.pure(),
    PermitTypeInput permitType = const PermitTypeInput.pure(),
    IssuingAuthorityInput issuingAuthority = const IssuingAuthorityInput.pure(),
    PermitValidFromInput permitValidFrom = const PermitValidFromInput.pure(),
    PermitValidToInput permitValidTo = const PermitValidToInput.pure(),
    PermitAttachmentUrlsInput permitAttachmentUrls =
        const PermitAttachmentUrlsInput.pure(),
    // Cohort inputs
    CohortLocalIdInput cohortLocalId = const CohortLocalIdInput.pure(),
    CohortRecordNameInput cohortRecordName = const CohortRecordNameInput.pure(),
    CohortPhysicalFormInput cohortPhysicalForm =
        const CohortPhysicalFormInput.pure(),
    CohortSizeSpecInput cohortSizeSpec = const CohortSizeSpecInput.pure(),
    CohortDestinationInput cohortDestination =
        const CohortDestinationInput.pure(),
    this.geometryInput,
    this.geometryValidationMessage,
    this.site,
    this.parentOrganismKind,
    this.damGameteCollection,
    this.sireGameteCollection,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  }) : super(
         steps: [
           BaseRecordFormStep(
             title: 'Parent Selection',
             inputs: [parentOrganisms],
           ),
           BaseRecordFormStep(
             title: 'Spawn Details',
             inputs: [gameteRole, gameteCount, notes],
           ),
           BaseRecordFormStep(
             title: 'Gamete Inventory',
             inputs: [
               gameteLocalId,
               gameteRecordName,
               gametePhysicalForm,
               gameteSizeSpec,
               gameteDestination,
             ],
           ),
           BaseRecordFormStep(
             title: 'Cohort Creation',
             inputs: [
               cohortLocalId,
               cohortRecordName,
               cohortPhysicalForm,
               cohortSizeSpec,
               cohortDestination,
             ],
           ),
           BaseRecordFormStep(
             title: 'Location & Permit Metadata (optional)',
             inputs: [
               geometryText,
               permitId,
               permitType,
               issuingAuthority,
               permitValidFrom,
               permitValidTo,
               permitAttachmentUrls,
             ],
           ),
         ],
       );

  final ProvenanceLifeStageSelection provenanceSelection;
  final GameteCollectionEntry? damGameteCollection;
  final GameteCollectionEntry? sireGameteCollection;

  ParentOrganismsInput get parentOrganisms =>
      steps[0].inputs[0] as ParentOrganismsInput;
  GameteRoleInput get gameteRole => steps[1].inputs[0] as GameteRoleInput;
  GameteCountInput get gameteCount => steps[1].inputs[1] as GameteCountInput;
  SpawnNotesInput get notes => steps[1].inputs[2] as SpawnNotesInput;
  GameteLocalIdInput get gameteLocalId =>
      steps[2].inputs[0] as GameteLocalIdInput;
  GameteRecordNameInput get gameteRecordName =>
      steps[2].inputs[1] as GameteRecordNameInput;
  GametePhysicalFormInput get gametePhysicalForm =>
      steps[2].inputs[2] as GametePhysicalFormInput;
  GameteSizeSpecInput get gameteSizeSpec =>
      steps[2].inputs[3] as GameteSizeSpecInput;
  GameteDestinationInput get gameteDestination =>
      steps[2].inputs[4] as GameteDestinationInput;
  // Cohort inputs
  CohortLocalIdInput get cohortLocalId =>
      steps[3].inputs[0] as CohortLocalIdInput;
  CohortRecordNameInput get cohortRecordName =>
      steps[3].inputs[1] as CohortRecordNameInput;
  CohortPhysicalFormInput get cohortPhysicalForm =>
      steps[3].inputs[2] as CohortPhysicalFormInput;
  CohortSizeSpecInput get cohortSizeSpec =>
      steps[3].inputs[3] as CohortSizeSpecInput;
  CohortDestinationInput get cohortDestination =>
      steps[3].inputs[4] as CohortDestinationInput;
  GeometryTextInput get geometryText => steps[4].inputs[0] as GeometryTextInput;
  PermitIdInput get permitId => steps[4].inputs[1] as PermitIdInput;
  PermitTypeInput get permitType => steps[4].inputs[2] as PermitTypeInput;
  IssuingAuthorityInput get issuingAuthority =>
      steps[4].inputs[3] as IssuingAuthorityInput;
  PermitValidFromInput get permitValidFrom =>
      steps[4].inputs[4] as PermitValidFromInput;
  PermitValidToInput get permitValidTo =>
      steps[4].inputs[5] as PermitValidToInput;
  PermitAttachmentUrlsInput get permitAttachmentUrls =>
      steps[4].inputs[6] as PermitAttachmentUrlsInput;

  final OutplantGeometryInput? geometryInput;
  final String? geometryValidationMessage;
  final Site? site;
  final OrganismKind? parentOrganismKind;

  /// Whether at least one gamete collection is enabled.
  bool get hasEnabledGameteCollection =>
      (damGameteCollection?.enabled ?? false) ||
      (sireGameteCollection?.enabled ?? false);

  @override
  SpawnFormState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    SpawnEvent? createdRecord,
    SpawnEvent? originalRecord,
    bool overrideSubmissionError = false,
    ProvenanceLifeStageSelection? provenanceSelection,
    bool updateGeometryInput = false,
    OutplantGeometryInput? geometryInput,
    bool updateGeometryValidationMessage = false,
    String? geometryValidationMessage,
    bool updateSite = false,
    Site? site,
    bool updateParentOrganismKind = false,
    OrganismKind? parentOrganismKind,
    bool updateDamGameteCollection = false,
    GameteCollectionEntry? damGameteCollection,
    bool updateSireGameteCollection = false,
    GameteCollectionEntry? sireGameteCollection,
  }) {
    return SpawnFormState(
      parentOrganisms: steps != null
          ? steps[0].inputs[0] as ParentOrganismsInput
          : parentOrganisms,
      gameteRole: steps != null && steps.length > 1
          ? steps[1].inputs[0] as GameteRoleInput
          : gameteRole,
      gameteCount: steps != null && steps.length > 1
          ? steps[1].inputs[1] as GameteCountInput
          : gameteCount,
      notes: steps != null && steps.length > 1
          ? steps[1].inputs[2] as SpawnNotesInput
          : notes,
      gameteLocalId: steps != null && steps.length > 2
          ? steps[2].inputs[0] as GameteLocalIdInput
          : gameteLocalId,
      gameteRecordName: steps != null && steps.length > 2
          ? steps[2].inputs[1] as GameteRecordNameInput
          : gameteRecordName,
      gametePhysicalForm: steps != null && steps.length > 2
          ? steps[2].inputs[2] as GametePhysicalFormInput
          : gametePhysicalForm,
      gameteSizeSpec: steps != null && steps.length > 2
          ? steps[2].inputs[3] as GameteSizeSpecInput
          : gameteSizeSpec,
      gameteDestination: steps != null && steps.length > 2
          ? steps[2].inputs[4] as GameteDestinationInput
          : gameteDestination,
      cohortLocalId: steps != null && steps.length > 3
          ? steps[3].inputs[0] as CohortLocalIdInput
          : cohortLocalId,
      cohortRecordName: steps != null && steps.length > 3
          ? steps[3].inputs[1] as CohortRecordNameInput
          : cohortRecordName,
      cohortPhysicalForm: steps != null && steps.length > 3
          ? steps[3].inputs[2] as CohortPhysicalFormInput
          : cohortPhysicalForm,
      cohortSizeSpec: steps != null && steps.length > 3
          ? steps[3].inputs[3] as CohortSizeSpecInput
          : cohortSizeSpec,
      cohortDestination: steps != null && steps.length > 3
          ? steps[3].inputs[4] as CohortDestinationInput
          : cohortDestination,
      geometryText: steps != null && steps.length > 4
          ? steps[4].inputs[0] as GeometryTextInput
          : geometryText,
      permitId: steps != null && steps.length > 4
          ? steps[4].inputs[1] as PermitIdInput
          : permitId,
      permitType: steps != null && steps.length > 4
          ? steps[4].inputs[2] as PermitTypeInput
          : permitType,
      issuingAuthority: steps != null && steps.length > 4
          ? steps[4].inputs[3] as IssuingAuthorityInput
          : issuingAuthority,
      permitValidFrom: steps != null && steps.length > 4
          ? steps[4].inputs[4] as PermitValidFromInput
          : permitValidFrom,
      permitValidTo: steps != null && steps.length > 4
          ? steps[4].inputs[5] as PermitValidToInput
          : permitValidTo,
      permitAttachmentUrls: steps != null && steps.length > 4
          ? steps[4].inputs[6] as PermitAttachmentUrlsInput
          : permitAttachmentUrls,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
      provenanceSelection: provenanceSelection ?? this.provenanceSelection,
      geometryInput: updateGeometryInput ? geometryInput : this.geometryInput,
      geometryValidationMessage: updateGeometryValidationMessage
          ? geometryValidationMessage
          : this.geometryValidationMessage,
      site: updateSite ? site : this.site,
      parentOrganismKind: updateParentOrganismKind
          ? parentOrganismKind
          : this.parentOrganismKind,
      damGameteCollection: updateDamGameteCollection
          ? damGameteCollection
          : this.damGameteCollection,
      sireGameteCollection: updateSireGameteCollection
          ? sireGameteCollection
          : this.sireGameteCollection,
    );
  }

  @override
  List<Object?> get props => [
    parentOrganisms,
    gameteRole,
    gameteCount,
    notes,
    gameteLocalId,
    gameteRecordName,
    gametePhysicalForm,
    gameteSizeSpec,
    gameteDestination,
    cohortLocalId,
    cohortRecordName,
    cohortPhysicalForm,
    cohortSizeSpec,
    cohortDestination,
    geometryText,
    permitId,
    permitType,
    issuingAuthority,
    permitValidFrom,
    permitValidTo,
    permitAttachmentUrls,
    currentStepIndex,
    submissionStatus,
    submissionError,
    createdRecord,
    provenanceSelection,
    geometryInput,
    geometryValidationMessage,
    site,
    parentOrganismKind,
    damGameteCollection,
    sireGameteCollection,
  ];
}

/// BLoC for spawn event form
class SpawnFormBloc extends EventFormBloc<SpawnEvent, SpawnFormState> {
  SpawnFormBloc({
    required super.eventRepository,
    this.organismRepository,
    this.validationService,
    super.propagationService,
    super.targetNode,
    OutplantGeometryParser? geometryParser,
    OutplantGeometryBuilder? geometryBuilder,
  }) : _geometryParser = geometryParser ?? const OutplantGeometryParser(),
       _geometryBuilder = geometryBuilder ?? const OutplantGeometryBuilder(),
       super(
         initialState: SpawnFormState(site: _initialSiteFromTarget(targetNode)),
         allowPropagation: true,
         allowTaskCreation: false,
       ) {
    on<ParentOrganismsChanged>(_onParentOrganismsChanged);
    on<GameteRoleChanged>(_onGameteRoleChanged);
    on<GameteCountChanged>(_onGameteCountChanged);
    on<SpawnNotesChanged>(_onNotesChanged);
    on<GameteLocalIdChanged>(_onGameteLocalIdChanged);
    on<GameteRecordNameChanged>(_onGameteRecordNameChanged);
    on<GametePhysicalFormChanged>(_onGametePhysicalFormChanged);
    on<GameteSizeSpecChanged>(_onGameteSizeSpecChanged);
    on<GameteDestinationChanged>(_onGameteDestinationChanged);
    on<SpawnProvenanceSelectionChanged>(_onProvenanceSelectionChanged);
    on<GeometryTextChanged>(_onGeometryTextChanged);
    on<PermitIdChanged>(_onPermitIdChanged);
    on<PermitTypeChanged>(_onPermitTypeChanged);
    on<IssuingAuthorityChanged>(_onIssuingAuthorityChanged);
    on<PermitValidFromChanged>(_onPermitValidFromChanged);
    on<PermitValidToChanged>(_onPermitValidToChanged);
    on<PermitAttachmentUrlsChanged>(_onPermitAttachmentUrlsChanged);
    on<_SpawnSiteResolved>(_onSpawnSiteResolved);
    // Multi-gamete collection events
    on<DamGameteCollectionChanged>(_onDamGameteCollectionChanged);
    on<SireGameteCollectionChanged>(_onSireGameteCollectionChanged);
    // Cohort events
    on<CohortLocalIdChanged>(_onCohortLocalIdChanged);
    on<CohortRecordNameChanged>(_onCohortRecordNameChanged);
    on<CohortPhysicalFormChanged>(_onCohortPhysicalFormChanged);
    on<CohortSizeSpecChanged>(_onCohortSizeSpecChanged);
    on<CohortDestinationChanged>(_onCohortDestinationChanged);
    _scheduleSiteLoad(targetNode);
  }

  final OutplantGeometryParser _geometryParser;
  final OutplantGeometryBuilder _geometryBuilder;
  final OrganismRecordRepository? organismRepository;
  final UniqueNameValidationService? validationService;

  /// Get organism kind from target node for organism-aware operations
  OrganismKind? get organismKind {
    final node = targetNode;
    if (node == null) return null;
    final nodeState = node.state;
    if (nodeState is GraphLoadedState) {
      final record = nodeState.record;
      if (record is OrganismRecord) {
        return record.organismKind;
      }
    }
    return null;
  }

  @override
  String get eventTypeId => EventType.spawn.id;

  @override
  SpawnFormState get initialState => SpawnFormState();

  @override
  void onEvent(RecordFormEvent event) {
    super.onEvent(event);
    if (event is EventFormTargetChanged) {
      _scheduleSiteLoad(event.targetNode);
      _seedParentOrganismsFromTarget(event.targetNode);
      _seedGameteInventoryFromTarget(event.targetNode);
    }
  }

  @override
  Future<void> onEventSubmit(
    RecordFormSubmit event,
    Emitter<SpawnFormState> emit,
  ) async {
    // Reset propagation warning from any previous attempt
    propagationWarning = null;

    try {
      if (!state.isValid || !validateEventSpecific()) {
        emit(
          state.copyWith(
            submissionStatus: FormzSubmissionStatus.failure,
            submissionError:
                state.validationErrorMessage ?? 'Invalid form data',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          submissionStatus: FormzSubmissionStatus.inProgress,
          submissionError: null,
          overrideSubmissionError: true,
        ),
      );

      if (targetNode == null) {
        throw Exception('Target node is required');
      }

      final primaryTarget = targetNode!;
      final extras = <String, GraphNode>{};
      for (final node in additionalTargets) {
        if (node != primaryTarget) {
          extras[node.urlPath] = node;
        }
      }

      final createdEvents = <SpawnEvent>[];
      final shouldPropagate = propagateToParents && propagationService != null;
      final nodesNeedingReload = <GraphNode>{};
      var propagationFailed = false;
      final createdGameteRecords = <OrganismRecord>[];

      try {
        // Primary event
        final primaryEvent = await createEventFromState();
        await eventRepository.createEvent(primaryEvent);
        createdEvents.add(primaryEvent);
        nodesNeedingReload.add(primaryTarget);

        if (shouldPropagate) {
          try {
            await propagationService!.propagateToParents(
              sourceEvent: primaryEvent,
              sourceNode: primaryTarget,
              activityType: eventTypeId,
            );
          } catch (e, stackTrace) {
            propagationFailed = true;
            LoggingService.instance.error(
              'Failed to propagate event, but event was created',
              e,
              stackTrace,
            );
          }
        }

        if (extras.isNotEmpty &&
            multiTargetStrategy ==
                MultiTargetStrategy.singleEventWithReferences) {
          if (propagationService == null) {
            LoggingService.instance.warning(
              'Multi-target references skipped: EventPropagationService unavailable',
            );
          } else {
            try {
              await propagationService!.propagateToTargetNodes(
                sourceEvent: primaryEvent,
                targetNodes: extras.values,
                activityType: eventTypeId,
              );
              nodesNeedingReload.addAll(extras.values);
            } catch (e, stackTrace) {
              propagationFailed = true;
              LoggingService.instance.error(
                'Failed to create multi-target references',
                e,
                stackTrace,
              );
            }
          }
        } else {
          // Additional targets (legacy multi-event behavior)
          for (final node in extras.values) {
            final originalTarget = targetNode;
            targetNode = node;
            final extraEvent = await createEventFromState();
            await eventRepository.createEvent(extraEvent);
            createdEvents.add(extraEvent);
            nodesNeedingReload.add(node);

            if (shouldPropagate) {
              try {
                await propagationService!.propagateToParents(
                  sourceEvent: extraEvent,
                  sourceNode: node,
                  activityType: eventTypeId,
                );
              } catch (e, stackTrace) {
                propagationFailed = true;
                LoggingService.instance.error(
                  'Failed to propagate event for ${node.urlPath}',
                  e,
                  stackTrace,
                );
              }
            }

            targetNode = originalTarget;
          }
        }

        // Create dam gamete inventory record if enabled
        final damCollection = state.damGameteCollection;
        if (damCollection != null && damCollection.enabled) {
          final damRecord = await _createGameteInventoryRecordFromCollection(
            spawnEvent: createdEvents.first,
            collection: damCollection,
          );
          createdGameteRecords.add(damRecord);
          if (damCollection.destinationGroup != null) {
            nodesNeedingReload.add(damCollection.destinationGroup!);
          }
        }

        // Create sire gamete inventory record if enabled
        final sireCollection = state.sireGameteCollection;
        if (sireCollection != null && sireCollection.enabled) {
          final sireRecord = await _createGameteInventoryRecordFromCollection(
            spawnEvent: createdEvents.first,
            collection: sireCollection,
          );
          createdGameteRecords.add(sireRecord);
          if (sireCollection.destinationGroup != null) {
            nodesNeedingReload.add(sireCollection.destinationGroup!);
          }
        }

        // Fallback: Create gamete record from legacy single-gamete fields
        if (createdGameteRecords.isEmpty) {
          final destinationGroup = state.gameteDestination.value;
          if (destinationGroup != null) {
            final gameteRecord = await _createGameteInventoryRecord(
              spawnEvent: createdEvents.first,
              destinationGroup: destinationGroup,
            );
            createdGameteRecords.add(gameteRecord);
            nodesNeedingReload.add(destinationGroup);
          }
        }

        // Create cohort organism from fertilization
        final cohortDestination = state.cohortDestination.value;
        if (cohortDestination != null && createdGameteRecords.isNotEmpty) {
          final cohortRecord = await _createCohortOrganism(
            spawnEvent: createdEvents.first,
            gameteRecords: createdGameteRecords,
            destinationGroup: cohortDestination,
          );
          nodesNeedingReload.add(cohortDestination);

          // Archive gamete records after cohort creation - they were "used" in fertilization
          for (final gameteRecord in createdGameteRecords) {
            await _archiveGameteRecord(gameteRecord, cohortId: cohortRecord.id);
          }
        }

        // Handle task creation if enabled (primary event only)
        if (createTask && allowTaskCreation) {
          LoggingService.instance.info('Task creation flag set on event');
        }

        for (final node in nodesNeedingReload) {
          _requestNodeReload(node);
        }

        final primaryEvent2 = createdEvents.first;
        if (emit.isDone) return;

        propagationWarning = propagationFailed
            ? 'Event saved but activity feed may be incomplete'
            : null;

        emit(
          state.copyWith(
            submissionStatus: FormzSubmissionStatus.success,
            createdRecord: primaryEvent2,
            submissionError: null,
            overrideSubmissionError: true,
          ),
        );
      } finally {
        targetNode = primaryTarget;
        additionalTargets = [];
      }
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to create spawn event',
        error,
        stackTrace,
      );
      final domainError = ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: 'SpawnFormBloc.onSubmit',
      );
      if (emit.isDone) return;
      emit(
        state.copyWith(
          submissionStatus: FormzSubmissionStatus.failure,
          submissionError: ErrorHandler.getDisplayMessage(domainError),
        ),
      );
    }
  }

  @override
  bool validateEventSpecific() {
    // At least one gamete collection must be enabled OR legacy fields must be filled
    final hasNewStyleGametes = state.hasEnabledGameteCollection;
    final hasLegacyGametes =
        state.gameteDestination.value != null &&
        state.gameteCount.value != null &&
        state.gameteCount.value! > 0 &&
        state.gameteRole.value != null;

    if (!hasNewStyleGametes && !hasLegacyGametes) {
      return false;
    }

    // Validate that enabled gamete collections are complete (including count > 0)
    final damCollection = state.damGameteCollection;
    if (damCollection != null &&
        damCollection.enabled &&
        !damCollection.isComplete) {
      return false;
    }
    final sireCollection = state.sireGameteCollection;
    if (sireCollection != null &&
        sireCollection.enabled &&
        !sireCollection.isComplete) {
      return false;
    }

    // Cohort fields are only required when cohort destination is explicitly set
    // This allows spawning without cohort creation (gamete collection only)
    final cohortDestination = state.cohortDestination.value;
    if (cohortDestination != null) {
      // If user has set a cohort destination, cohort local ID is required
      final cohortLocalId = state.cohortLocalId.value?.trim();
      if (cohortLocalId == null || cohortLocalId.isEmpty) {
        return false;
      }
    }

    return true;
  }

  Future<void> _onParentOrganismsChanged(
    ParentOrganismsChanged event,
    Emitter<SpawnFormState> emit,
  ) async {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState == null) return;
    emit(updatedState as SpawnFormState);

    final parentIds = event.value;
    if (parentIds.isEmpty) {
      if (state.parentOrganismKind != null) {
        emit(
          state.copyWith(
            updateParentOrganismKind: true,
            parentOrganismKind: null,
          ),
        );
      }
      if (state.gameteLocalId.value != null &&
          state.gameteLocalId.value!.trim().isNotEmpty) {
        add(const GameteLocalIdChanged(null));
      }
      return;
    }

    final hasLocalId =
        state.gameteLocalId.value != null &&
        state.gameteLocalId.value!.trim().isNotEmpty;
    final isLockedToTarget = targetNode is OrganismNode;
    final parent = await _resolveParentOrganism(parentIds);
    if (isClosed) return;

    final resolvedKind = parent?.organismKind;
    if (resolvedKind != null && resolvedKind != state.parentOrganismKind) {
      emit(
        state.copyWith(
          updateParentOrganismKind: true,
          parentOrganismKind: resolvedKind,
        ),
      );
    }

    if (isLockedToTarget && hasLocalId) {
      return;
    }

    final resolvedLocalId = parent == null
        ? null
        : _resolveGameteLocalId(parent);
    if (resolvedLocalId == null || resolvedLocalId.isEmpty) return;
    add(GameteLocalIdChanged(resolvedLocalId));
  }

  void _onGameteCountChanged(
    GameteCountChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGameteRoleChanged(
    GameteRoleChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onNotesChanged(SpawnNotesChanged event, Emitter<SpawnFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGameteLocalIdChanged(
    GameteLocalIdChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState == null) return;
    var nextState = updatedState as SpawnFormState;
    final currentName = nextState.gameteRecordName.value?.trim();
    if (currentName == null || currentName.isEmpty) {
      final localId = event.value?.trim();
      final suggestion = RecordNameDerived.fromLocalId(localId);
      if (suggestion != null && suggestion.isNotEmpty) {
        final nameState = nextState.copyWithInputEvent(
          GameteRecordNameChanged(suggestion),
        );
        if (nameState != null) {
          nextState = nameState as SpawnFormState;
        }
      }
    }
    emit(nextState);
  }

  void _onGameteRecordNameChanged(
    GameteRecordNameChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGametePhysicalFormChanged(
    GametePhysicalFormChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGameteSizeSpecChanged(
    GameteSizeSpecChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGameteDestinationChanged(
    GameteDestinationChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onProvenanceSelectionChanged(
    SpawnProvenanceSelectionChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    emit(state.copyWith(provenanceSelection: event.selection));
  }

  void _onDamGameteCollectionChanged(
    DamGameteCollectionChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    emit(
      state.copyWith(
        updateDamGameteCollection: true,
        damGameteCollection: event.entry,
      ),
    );
  }

  void _onSireGameteCollectionChanged(
    SireGameteCollectionChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    emit(
      state.copyWith(
        updateSireGameteCollection: true,
        sireGameteCollection: event.entry,
      ),
    );
  }

  void _onCohortLocalIdChanged(
    CohortLocalIdChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState == null) return;
    var nextState = updatedState as SpawnFormState;
    // Auto-suggest record name from local ID
    final currentName = nextState.cohortRecordName.value?.trim();
    if (currentName == null || currentName.isEmpty) {
      final localId = event.value?.trim();
      final suggestion = RecordNameDerived.fromLocalId(localId);
      if (suggestion != null && suggestion.isNotEmpty) {
        final nameState = nextState.copyWithInputEvent(
          CohortRecordNameChanged(suggestion),
        );
        if (nameState != null) {
          nextState = nameState as SpawnFormState;
        }
      }
    }
    emit(nextState);
  }

  void _onCohortRecordNameChanged(
    CohortRecordNameChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onCohortPhysicalFormChanged(
    CohortPhysicalFormChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onCohortSizeSpecChanged(
    CohortSizeSpecChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onCohortDestinationChanged(
    CohortDestinationChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onGeometryTextChanged(
    GeometryTextChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState =
        (state.copyWithInputEvent(event) as SpawnFormState?) ?? state;
    final raw = (event.value ?? '').trim();

    if (raw.isEmpty) {
      emit(
        updatedState.copyWith(
          updateGeometryInput: true,
          geometryInput: null,
          updateGeometryValidationMessage: true,
          geometryValidationMessage: null,
        ),
      );
      return;
    }

    try {
      final parsed = _geometryParser.parseManual(raw);
      emit(
        updatedState.copyWith(
          updateGeometryInput: true,
          geometryInput: parsed.input,
          updateGeometryValidationMessage: true,
          geometryValidationMessage: null,
        ),
      );
    } on FormatException catch (error) {
      emit(
        updatedState.copyWith(
          updateGeometryInput: true,
          geometryInput: null,
          updateGeometryValidationMessage: true,
          geometryValidationMessage: error.message,
        ),
      );
    }
  }

  @override
  Future<SpawnEvent> createEventFromState() async {
    if (targetNode == null) {
      throw Exception('Target node is required to create a spawn event');
    }

    // Await loaded state
    await targetNode!.awaitLoaded();
    final targetNodeState = targetNode!.state;
    if (targetNodeState is! GraphLoadedState) {
      throw StateError('Target node failed to load');
    }
    final record = targetNodeState.record;

    // Generate event fields using helper
    final eventFields = await generateEventFields(
      recordId: record.id,
      recordModelType: record.modelType,
      parentPath: record.urlPath,
      parentInternalPath: record.internalPath,
    );
    final site = state.site ?? await _loadSiteForTarget(targetNode!);
    final geometry = _buildGeometryForSubmission(site);

    return SpawnEvent.partial(
      id: eventFields['id'],
      organizationId: eventFields['organizationId'],
      urlPath: eventFields['urlPath'],
      recordId: eventFields['recordId'],
      recordModelType: eventFields['recordModelType'],
      internalPath: eventFields['internalPath'],
      slug: eventFields['slug'],
      createdAt: eventFields['createdAt'],
      createdById: eventFields['createdById'],
      updatedAt: eventFields['updatedAt'],
      updatedById: eventFields['updatedById'],
      eventTypeId: eventTypeId,
      parentOrganismIds: state.parentOrganisms.value ?? [],
      gameteCount: state.gameteCount.value ?? 0,
      gameteRole: state.gameteRole.value,
      permitMetadata: _buildPermitMetadata(),
      metadata: _buildCanonicalMetadata(),
      geometry: geometry,
    );
  }

  Future<OrganismRecord> _createGameteInventoryRecord({
    required SpawnEvent spawnEvent,
    required GroupNode destinationGroup,
  }) async {
    final repo = organismRepository;
    if (repo == null) {
      throw StateError('Organism repository unavailable for gamete creation');
    }

    final parentIds = state.parentOrganisms.value ?? const <String>[];
    if (parentIds.isEmpty) {
      throw StateError('No parent organisms selected for gamete creation');
    }

    final parents = await Future.wait(
      parentIds.map((id) => repo.getRecordForId(id)),
      eagerError: false,
    );
    OrganismRecord? parent;
    for (final record in parents) {
      if (record is OrganismRecord) {
        parent = record;
        break;
      }
    }
    if (parent == null) {
      throw StateError('Parent organism not found for gamete creation');
    }

    final localId =
        state.gameteLocalId.value?.trim() ?? _resolveGameteLocalId(parent);
    if (localId == null || localId.isEmpty) {
      throw StateError('Gamete local ID missing');
    }

    String recordName;
    final userProvidedName = state.gameteRecordName.value?.trim();
    if (userProvidedName != null && userProvidedName.isNotEmpty) {
      recordName = userProvidedName;
    } else if (validationService != null) {
      // Use RecordNameSuggester for uniqueness-aware suggestion
      recordName =
          await RecordNameSuggester.suggestFromLocalId(
            localId: localId,
            organizationId: parent.organizationId,
            validationService: validationService!,
          ) ??
          RecordNameDerived.fromLocalId(localId) ??
          'Unknown';
    } else {
      // Fallback to deterministic (but not uniqueness-aware) derivation
      recordName = RecordNameDerived.fromLocalId(localId) ?? 'Unknown';
    }

    final gameteCount = state.gameteCount.value ?? 0;
    final measurement = PopulationMeasurement(
      value: gameteCount.toDouble(),
      unit: MeasurementUnit.count,
    );

    final physicalFormId = state.gametePhysicalForm.value?.trim();
    if (physicalFormId == null || physicalFormId.isEmpty) {
      throw StateError('Gamete physical form missing');
    }

    final rawSizeSpec = state.gameteSizeSpec.value ?? const SizeSpec();
    final resolvedSizeSpec = await _resolveGameteSizeSpec(
      organismKind: parent.organismKind,
      physicalFormId: physicalFormId,
      sizeSpec: rawSizeSpec,
    );
    final sizeBandId =
        resolvedSizeSpec.sizeBandId ?? unknownPhysicalFormSizeBandId;
    final physicalForm = PhysicalFormInstance(
      formId: physicalFormId,
      sizeBandId: sizeBandId,
    );

    final destinationRecord = destinationGroup.currentRecord;
    final provenanceAttributes = parent.provenanceAttributes.copyWith(
      gameteRole: state.gameteRole.value,
    );

    final metadata = <String, dynamic>{
      ..._buildCanonicalMetadata(provenanceType: parent.provenanceType),
      'spawnEventId': spawnEvent.id,
      if (parentIds.isNotEmpty) 'parentOrganismIds': parentIds,
    };

    final newOrganism = OrganismRecord.partial(
      organismKind: parent.organismKind,
      speciesId: parent.speciesId,
      recordName: recordName,
      localId: localId,
      measurement: measurement,
      lifeStage: LifeStageSpec(stage: LifeStage.gamete),
      genetId: GenetIdResolver.resolve(parent),
      foreignKeys: parent.foreignKeys,
      provenanceType: parent.provenanceType,
      provenanceAttributes: provenanceAttributes,
      physicalForm: physicalForm,
      sizeSpec: resolvedSizeSpec,
      metadata: metadata.isEmpty ? null : metadata,
      organizationId: parent.organizationId,
      siteId: destinationRecord.siteId,
      groupId: destinationRecord.id,
    );

    return repo.createRecord(newOrganism, destinationRecord);
  }

  Future<OrganismRecord> _createGameteInventoryRecordFromCollection({
    required SpawnEvent spawnEvent,
    required GameteCollectionEntry collection,
  }) async {
    final repo = organismRepository;
    if (repo == null) {
      throw StateError('Organism repository unavailable for gamete creation');
    }

    final parentIds = state.parentOrganisms.value ?? const <String>[];
    if (parentIds.isEmpty) {
      throw StateError('No parent organisms selected for gamete creation');
    }

    final parents = await Future.wait(
      parentIds.map((id) => repo.getRecordForId(id)),
      eagerError: false,
    );
    OrganismRecord? parent;
    for (final record in parents) {
      if (record is OrganismRecord) {
        parent = record;
        break;
      }
    }
    if (parent == null) {
      throw StateError('Parent organism not found for gamete creation');
    }

    final localId = _resolveGameteLocalId(parent);
    if (localId == null || localId.isEmpty) {
      throw StateError('Gamete local ID missing');
    }

    String recordName;
    final userProvidedName = collection.recordName?.trim();
    if (userProvidedName != null && userProvidedName.isNotEmpty) {
      recordName = userProvidedName;
    } else if (validationService != null) {
      recordName =
          await RecordNameSuggester.suggestFromLocalId(
            localId: localId,
            organizationId: parent.organizationId,
            validationService: validationService!,
          ) ??
          RecordNameDerived.fromLocalId(localId) ??
          'Unknown';
    } else {
      recordName = RecordNameDerived.fromLocalId(localId) ?? 'Unknown';
    }

    final gameteCount = collection.count;
    if (gameteCount == null || gameteCount <= 0) {
      throw StateError(
        'Gamete count must be greater than zero for ${collection.gameteRole.name} collection',
      );
    }
    final measurement = PopulationMeasurement(
      value: gameteCount.toDouble(),
      unit: MeasurementUnit.count,
    );

    final physicalFormId = collection.physicalFormId;
    if (physicalFormId == null || physicalFormId.isEmpty) {
      throw StateError('Gamete physical form missing');
    }

    final rawSizeSpec = collection.sizeSpec ?? const SizeSpec();
    final resolvedSizeSpec = await _resolveGameteSizeSpec(
      organismKind: parent.organismKind,
      physicalFormId: physicalFormId,
      sizeSpec: rawSizeSpec,
    );
    final sizeBandId =
        resolvedSizeSpec.sizeBandId ?? unknownPhysicalFormSizeBandId;
    final physicalForm = PhysicalFormInstance(
      formId: physicalFormId,
      sizeBandId: sizeBandId,
    );

    final destinationGroup = collection.destinationGroup;
    if (destinationGroup == null) {
      throw StateError('Gamete destination group missing');
    }
    final destinationRecord = destinationGroup.currentRecord;
    final provenanceAttributes = parent.provenanceAttributes.copyWith(
      gameteRole: collection.gameteRole,
    );

    final roleLabel = collection.gameteRole == ProvenanceGameteRole.egg
        ? 'dam'
        : 'sire';
    final metadata = <String, dynamic>{
      ..._buildCanonicalMetadata(provenanceType: parent.provenanceType),
      'spawnEventId': spawnEvent.id,
      'gameteCollectionRole': roleLabel,
      if (parentIds.isNotEmpty) 'parentOrganismIds': parentIds,
    };

    final newOrganism = OrganismRecord.partial(
      organismKind: parent.organismKind,
      speciesId: parent.speciesId,
      recordName: recordName,
      localId: localId,
      measurement: measurement,
      lifeStage: LifeStageSpec(stage: LifeStage.gamete),
      genetId: GenetIdResolver.resolve(parent),
      foreignKeys: parent.foreignKeys,
      provenanceType: parent.provenanceType,
      provenanceAttributes: provenanceAttributes,
      physicalForm: physicalForm,
      sizeSpec: resolvedSizeSpec,
      metadata: metadata.isEmpty ? null : metadata,
      organizationId: parent.organizationId,
      siteId: destinationRecord.siteId,
      groupId: destinationRecord.id,
    );

    return repo.createRecord(newOrganism, destinationRecord);
  }

  Future<OrganismRecord> _createCohortOrganism({
    required SpawnEvent spawnEvent,
    required List<OrganismRecord> gameteRecords,
    required GroupNode destinationGroup,
  }) async {
    final repo = organismRepository;
    if (repo == null) {
      throw StateError('Organism repository unavailable for cohort creation');
    }

    // Find dam and sire from gamete records
    OrganismRecord? damRecord;
    OrganismRecord? sireRecord;
    final damGameteLocalIds = <String>[];
    final sireGameteLocalIds = <String>[];

    for (final record in gameteRecords) {
      final role = record.provenanceAttributes.gameteRole;
      final localId = record.localId?.trim();
      if (role == ProvenanceGameteRole.egg) {
        damRecord ??= record;
        if (localId != null && localId.isNotEmpty) {
          damGameteLocalIds.add(localId);
        }
      } else if (role == ProvenanceGameteRole.sperm) {
        sireRecord ??= record;
        if (localId != null && localId.isNotEmpty) {
          sireGameteLocalIds.add(localId);
        }
      }
    }

    // Use first gamete as source for species ONLY - species is the only
    // property inherited from contributing gametes per the data model
    final sourceGamete = gameteRecords.first;
    final destinationRecord = destinationGroup.currentRecord;

    final cohortLocalId = state.cohortLocalId.value?.trim();
    if (cohortLocalId == null || cohortLocalId.isEmpty) {
      throw StateError('Cohort local ID is required');
    }

    String recordName;
    final userProvidedName = state.cohortRecordName.value?.trim();
    if (userProvidedName != null && userProvidedName.isNotEmpty) {
      recordName = userProvidedName;
    } else if (validationService != null) {
      recordName =
          await RecordNameSuggester.suggestFromLocalId(
            localId: cohortLocalId,
            organizationId: sourceGamete.organizationId,
            validationService: validationService!,
          ) ??
          RecordNameDerived.fromLocalId(cohortLocalId) ??
          'Cohort';
    } else {
      recordName = RecordNameDerived.fromLocalId(cohortLocalId) ?? 'Cohort';
    }

    final physicalFormId = state.cohortPhysicalForm.value?.trim();
    PhysicalFormInstance? physicalForm;
    SizeSpec sizeSpec = state.cohortSizeSpec.value ?? const SizeSpec();

    if (physicalFormId != null && physicalFormId.isNotEmpty) {
      sizeSpec = await _resolveGameteSizeSpec(
        organismKind: sourceGamete.organismKind,
        physicalFormId: physicalFormId,
        sizeSpec: sizeSpec,
      );
      final sizeBandId = sizeSpec.sizeBandId ?? unknownPhysicalFormSizeBandId;
      physicalForm = PhysicalFormInstance(
        formId: physicalFormId,
        sizeBandId: sizeBandId,
      );
    }

    // Build provenance attributes with parent references using gamete localIDs
    // These are the localIDs from the contributing gamete records
    final damProvenanceId = damGameteLocalIds.isNotEmpty
        ? damGameteLocalIds.first
        : ProvenanceConstants.unknownParentId;
    final sireProvenanceId = sireGameteLocalIds.isNotEmpty
        ? sireGameteLocalIds.first
        : ProvenanceConstants.unknownParentId;

    final provenanceAttributes = ProvenanceAttributes(
      damProvenanceId: damProvenanceId,
      sireProvenanceId: sireProvenanceId,
    );

    // Collect all parent gamete localIDs for the provenanceType metadata
    // This lists ALL contributing gamete localIDs as parent references
    final allParentLocalIds = <String>[
      ...damGameteLocalIds,
      ...sireGameteLocalIds,
    ];

    final metadata = <String, dynamic>{
      'provenanceTypeId': ProvenanceType.sexualCohort.id,
      'provenanceType': ProvenanceType.sexualCohort.id,
      'lifeStageId': LifeStage.larva.id,
      'lifeStage': LifeStage.larva.id,
      'spawnEventId': spawnEvent.id,
      // Store all contributing gamete localIDs as parent references
      'parentLocalIds': allParentLocalIds,
      // Also store individual dam/sire localIDs for backward compatibility
      if (damGameteLocalIds.isNotEmpty) 'damLocalIds': damGameteLocalIds,
      if (sireGameteLocalIds.isNotEmpty) 'sireLocalIds': sireGameteLocalIds,
      // Store organism record IDs for direct linking
      if (damRecord != null) 'damOrganismId': damRecord.id,
      if (sireRecord != null) 'sireOrganismId': sireRecord.id,
      'sourceGameteIds': gameteRecords.map((r) => r.id).toList(),
    };

    // Initial measurement - can be set to 1 or adjusted
    final measurement = const PopulationMeasurement(
      value: 1,
      unit: MeasurementUnit.count,
    );

    // Create cohort organism inheriting ONLY species from contributing gametes
    // All other properties (localId, recordName, physicalForm, etc.) are new
    final cohortOrganism = OrganismRecord.partial(
      organismKind: sourceGamete.organismKind,
      speciesId: sourceGamete.speciesId, // ONLY species is inherited
      recordName: recordName,
      localId: cohortLocalId,
      measurement: measurement,
      lifeStage: const LifeStageSpec(stage: LifeStage.larva),
      provenanceType: ProvenanceType.sexualCohort,
      provenanceAttributes: provenanceAttributes,
      physicalForm: physicalForm,
      sizeSpec: sizeSpec,
      metadata: metadata,
      organizationId: sourceGamete.organizationId,
      siteId: destinationRecord.siteId,
      groupId: destinationRecord.id,
    );

    return repo.createRecord(cohortOrganism, destinationRecord);
  }

  Future<void> _archiveGameteRecord(
    OrganismRecord gameteRecord, {
    required String cohortId,
  }) async {
    final repo = organismRepository;
    if (repo == null) return;

    try {
      final archivedMetadata = <String, dynamic>{
        ...?gameteRecord.metadata,
        kArchivedFlagKey: true,
        kArchivedAtKey: DateTime.now().toIso8601String(),
        kArchivedByIdKey: repo.user.id,
        kArchivedReasonTypeKey: kArchiveReasonTypeFertilization,
        kArchivedReasonIdKey: cohortId,
        // Store the cohort this gamete contributed to for traceability
        'fertilizedCohortId': cohortId,
      };

      final archivedRecord = gameteRecord.copyWith(metadata: archivedMetadata);
      await repo.updateRecord(archivedRecord);

      LoggingService.instance.info(
        'Archived gamete record after cohort creation',
        {'gameteId': gameteRecord.id, 'cohortId': cohortId},
      );
    } catch (e, stackTrace) {
      LoggingService.instance.warning('Failed to archive gamete record', {
        'gameteId': gameteRecord.id,
        'error': e.toString(),
      });
      LoggingService.instance.error(
        'Gamete archive error details',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<SpawnEvent?> createRecord() async {
    return createEventFromState();
  }

  Map<String, dynamic> buildEventData() {
    final permit = _buildPermitMetadata();
    return {
      'parentOrganismIds': state.parentOrganisms.value ?? [],
      'gameteCount': state.gameteCount.value ?? 0,
      if (state.gameteRole.value != null)
        'gameteRole': state.gameteRole.value!.name,
      'notes': state.notes.value ?? '',
      if (permit != null) 'permitMetadata': permit.toJson(),
      'metadata': _buildCanonicalMetadata(),
    };
  }

  String buildActivityDescription() {
    final parentCount = state.parentOrganisms.value?.length ?? 0;
    final gameteCount = state.gameteCount.value ?? 0;
    final gameteRole = state.gameteRole.value;
    final kind = organismKind;
    final pluralLabel = kind != null
        ? '${kind.metadata.displayName}s'
        : 'organisms';

    final roleLabel = gameteRole == null
        ? 'gametes'
        : gameteRole == ProvenanceGameteRole.egg
        ? 'eggs'
        : 'sperm';

    return 'Spawning event: $parentCount parent $pluralLabel, '
        'amount collected: $gameteCount $roleLabel';
  }

  EventPermitMetadata? _buildPermitMetadata() {
    final permitId = state.permitId.value;
    final permitType = state.permitType.value;
    final issuingAuthority = state.issuingAuthority.value;
    final validFrom = state.permitValidFrom.value;
    final validTo = state.permitValidTo.value;
    final attachments = _parseAttachmentUrls(state.permitAttachmentUrls.value);

    final hasValues =
        (permitId?.isNotEmpty ?? false) ||
        (permitType?.isNotEmpty ?? false) ||
        (issuingAuthority?.isNotEmpty ?? false) ||
        validFrom != null ||
        validTo != null ||
        attachments.isNotEmpty;

    if (!hasValues) {
      return null;
    }

    return EventPermitMetadata(
      permitId: permitId,
      permitType: permitType,
      issuingAuthority: issuingAuthority,
      validFrom: validFrom,
      validTo: validTo,
      attachmentUrls: attachments,
    );
  }

  List<String> _parseAttachmentUrls(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<SizeSpec> _resolveGameteSizeSpec({
    required OrganismKind organismKind,
    required String physicalFormId,
    required SizeSpec sizeSpec,
  }) async {
    try {
      final formConfig = await PhysicalFormRegistry.instance.getFormConfig(
        organismKind,
        LifeStage.gamete,
        physicalFormId,
      );
      final sizeBand = formConfig?.getSizeBand(
        sizeSpec.sizeBandId ?? sizeSpec.sizeClass ?? '',
      );
      final resolvedMetrics = sizeSpec.resolvedMetrics(sizeBand: sizeBand);
      return sizeSpec.copyWith(
        sizeBandId: sizeSpec.sizeBandId ?? sizeBand?.id ?? sizeSpec.sizeClass,
        countOverride: resolvedMetrics.count,
        volumeCm3Override: resolvedMetrics.volumeCm3,
        tissueAreaCm2Override: resolvedMetrics.tissueAreaCm2,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'SpawnFormBloc: Failed to resolve gamete size spec',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      return sizeSpec;
    }
  }

  Future<OrganismRecord?> _resolveParentOrganism(List<String> parentIds) async {
    final repo = organismRepository;
    if (repo == null || parentIds.isEmpty) return null;
    try {
      final parent = await repo.getRecordForId(parentIds.first);
      return parent;
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'SpawnFormBloc: Failed to resolve parent organism',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      return null;
    }
  }

  String? _resolveGameteLocalId(OrganismRecord parent) {
    final sourceCohortId = parent.provenanceAttributes.sourceCohortId?.trim();
    if (sourceCohortId != null && sourceCohortId.isNotEmpty) {
      return sourceCohortId;
    }
    final localId = parent.localId?.trim();
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }
    return null;
  }

  Map<String, dynamic> _buildCanonicalMetadata({
    ProvenanceType? provenanceType,
  }) {
    final effectiveProvenanceType =
        provenanceType ?? state.provenanceSelection.provenanceType;
    return <String, dynamic>{
      'provenanceTypeId': effectiveProvenanceType.id,
      'provenanceType': effectiveProvenanceType.id,
      'provenanceKind': effectiveProvenanceType.defaultProvenanceKind.name,
      'lifeStageId': LifeStage.gamete.id,
      'lifeStage': LifeStage.gamete.id,
    };
  }

  void _onPermitIdChanged(PermitIdChanged event, Emitter<SpawnFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onPermitTypeChanged(
    PermitTypeChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onIssuingAuthorityChanged(
    IssuingAuthorityChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onPermitValidFromChanged(
    PermitValidFromChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onPermitValidToChanged(
    PermitValidToChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onPermitAttachmentUrlsChanged(
    PermitAttachmentUrlsChanged event,
    Emitter<SpawnFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as SpawnFormState);
    }
  }

  void _onSpawnSiteResolved(
    _SpawnSiteResolved event,
    Emitter<SpawnFormState> emit,
  ) {
    emit(state.copyWith(updateSite: true, site: event.site));
  }

  void _scheduleSiteLoad(GraphNode? node) {
    if (node == null) return;
    unawaited(() async {
      final site = await _loadSiteForTarget(node);
      if (isClosed) return;
      if (state.submissionStatus != FormzSubmissionStatus.initial) {
        return;
      }
      if (site == state.site) return;
      add(_SpawnSiteResolved(site));
    }());
  }

  void _seedGameteInventoryFromTarget(GraphNode? node) {
    if (node == null) return;

    final existingLocalId = state.gameteLocalId.value?.trim();
    if ((existingLocalId == null || existingLocalId.isEmpty) &&
        node is OrganismNode) {
      final localId = _resolveGameteLocalId(node.organism);
      if (localId != null && localId.isNotEmpty) {
        add(GameteLocalIdChanged(localId));
      }
    }

    final currentDestination = state.gameteDestination.value;
    if (currentDestination != null) return;
    final destination = _resolveInitialDestinationGroup(node);
    if (destination != null) {
      add(GameteDestinationChanged(destination));
      // Also set as default cohort destination
      if (state.cohortDestination.value == null) {
        add(CohortDestinationChanged(destination));
      }
    }
  }

  void _seedParentOrganismsFromTarget(GraphNode? node) {
    if (node is! OrganismNode) return;
    final selected = state.parentOrganisms.value ?? const <String>[];
    if (selected.isNotEmpty) return;
    add(ParentOrganismsChanged([node.id]));
  }

  GroupNode? _resolveInitialDestinationGroup(GraphNode node) {
    if (node is GroupNode) {
      return node;
    }
    if (node is OrganismNode) {
      final parent = node.parent;
      if (parent is GroupNode) {
        return parent;
      }
    }
    return null;
  }

  void _requestNodeReload(GraphNode node) {
    if (!node.isClosed) {
      node.add(GraphNodeReloadRequested());
    }
  }

  static Site? _initialSiteFromTarget(GraphNode? node) {
    final siteNode = node?.siteNode;
    if (siteNode == null) return null;
    final siteState = siteNode.state;
    if (siteState is GraphLoadedState<Site>) {
      return siteState.record;
    }
    return null;
  }

  Future<Site?> _loadSiteForTarget(GraphNode target) async {
    final siteNode = target.siteNode;
    if (siteNode == null) return null;
    await siteNode.awaitLoaded();
    final siteState = siteNode.state;
    if (siteState is GraphLoadedState<Site>) {
      return siteState.record;
    }
    return null;
  }

  OutplantGeometry? _buildGeometryForSubmission(Site? site) {
    final input = state.geometryInput;
    if (input == null || !input.hasCoordinates) {
      return null;
    }
    final centroid = _siteCentroid(site);
    try {
      return _geometryBuilder.build(input: input, siteCentroid: centroid);
    } on ArgumentError catch (error) {
      throw Exception(error.message);
    }
  }

  GeoCoordinate? _siteCentroid(Site? site) {
    if (site == null) return null;
    if (site.centroid != null) return site.centroid;
    if (site.geometry?.centroid != null) {
      return site.geometry!.centroid;
    }
    if (site.latitude != null && site.longitude != null) {
      return GeoCoordinate(
        latitude: site.latitude!,
        longitude: site.longitude!,
      );
    }
    return null;
  }
}

class _SpawnSiteResolved extends RecordFormEvent {
  const _SpawnSiteResolved(this.site);

  final Site? site;

  @override
  List<Object?> get props => [site];
}
