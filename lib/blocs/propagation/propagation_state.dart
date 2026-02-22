// @tier: community
import 'package:collection/collection.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/propagation/propagation_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/events/propagation/propagation_event.dart';
import 'package:seafoundry_app/models/events/propagation/propagation_ready_event.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';

/// Default base name used when genet name is unavailable during propagation.
const String kDefaultPropagationBaseName = 'Fragment';

class PropagationState extends RecordFormState<PropagationEvent> {
  PropagationState({
    required super.steps,
    super.currentStepIndex = 0,
    FormzSubmissionStatus? submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    this.isLoading = false,
    this.loadError,
    this.organismSelection = const OrganismSelectionInput(),
    this.fragmentsPerInput,
    this.newOrganisms = const <NewOrganismInput>[],
    this.propagationReadyEvents = const <PropagationReadyStatus>[],
    this.genet,
    ProvenanceLifeStageSelection? provenanceSelection,
    this.selectedPhysicalFormId = 'fragment',
    this.sizeSpec = const SizeSpec(),
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
  }) : provenanceSelection =
           provenanceSelection ?? ProvenanceLifeStageSelection.fallback(),
       super(submissionStatus: submissionStatus ?? FormzSubmissionStatus.initial);

  final bool isLoading;
  final String? loadError;
  final OrganismSelectionInput organismSelection;
  final PropagationFragmentsPerInputInput? fragmentsPerInput;
  final List<NewOrganismInput> newOrganisms;
  final List<PropagationReadyStatus> propagationReadyEvents;
  final Genet? genet;
  final ProvenanceLifeStageSelection provenanceSelection;
  final String selectedPhysicalFormId;
  final SizeSpec sizeSpec;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;

  @override
  List<Object?> get props =>
      super.props +
      [
        isLoading,
        loadError,
        organismSelection,
        fragmentsPerInput,
        newOrganisms,
        propagationReadyEvents,
        genet,
        provenanceSelection,
        selectedPhysicalFormId,
        sizeSpec,
        permitId,
        permitType,
        issuingAuthority,
        permitAttachmentUrls,
        permitValidFrom,
        permitValidTo,
      ];

  static PropagationState initial(OrganismRecord initialOrganism) {
    return PropagationState(
      steps: [
        BaseRecordFormStep(inputs: const [], title: 'Select Organisms'),
        BaseRecordFormStep(inputs: const [], title: 'Fragments per input'),
        BaseRecordFormStep(inputs: const [], title: 'Place Fragments'),
      ],
      isLoading: true,
      provenanceSelection: ProvenanceLifeStageSelection.fallback(),
      selectedPhysicalFormId: 'fragment',
      sizeSpec: const SizeSpec(),
    );
  }

  PropagationState loaded({
    required List<OrganismRecord> allOrganisms,
    required List<PropagationReadyStatus> propagationReadyEvents,
    required OrganismRecord initialOrganism,
    required Genet genet,
    required ProvenanceLifeStageSelection provenanceSelection,
    required String selectedPhysicalFormId,
    required SizeSpec sizeSpec,
  }) {
    // Only pre-select the initial organism if it's actually in allOrganisms
    // (i.e., it passed propagation validation). This maintains the invariant:
    // selectedOrganisms ⊆ allOrganisms
    final matchingOrganism = allOrganisms.firstWhereOrNull(
      (organism) => organism.id == initialOrganism.id,
    );
    final selectedOrganisms = matchingOrganism != null
        ? {matchingOrganism}
        : <OrganismRecord>{};
    final selectedQuantities =
        matchingOrganism != null
            ? {matchingOrganism.id: matchingOrganism.measurement.value.toInt()}
            : <String, int>{};

    final selection = OrganismSelectionInput(
      allOrganisms: allOrganisms,
      selectedOrganisms: selectedOrganisms,
      selectedQuantities: selectedQuantities,
    );

    return copyWith(
      isLoading: false,
      organismSelection: selection,
      propagationReadyEvents: propagationReadyEvents,
      genet: genet,
      provenanceSelection: provenanceSelection,
      selectedPhysicalFormId: selectedPhysicalFormId,
      sizeSpec: sizeSpec,
    );
  }

  PropagationState withLoadError(String error) {
    return copyWith(isLoading: false, loadError: error);
  }

  // Step navigation helpers
  bool get isFirstStep => currentStepIndex == 0;
  bool get isSecondStep => currentStepIndex == 1;
  bool get isThirdStep => currentStepIndex == 2;

  // Step 1 validation
  bool get canProceedFromStep1 => organismSelection.isValid;

  // Step 2 validation
  bool get canProceedFromStep2 => fragmentsPerInput?.isValid == true;

  // Step 3 validation
  int get inputQuantity => organismSelection.totalQuantity;
  int get totalOutputCount {
    final fragments = fragmentsPerInput?.value ?? 0;
    if (fragments <= 0) return 0;
    return inputQuantity * fragments;
  }
  int get totalNewOrganismQuantity => newOrganisms.fold(
    0,
    (sum, organism) => sum + organism.quantity,
  );
  int get remainingOutput => totalOutputCount - totalNewOrganismQuantity;
  bool get allFragmentsPlaced => remainingOutput == 0;
  bool get allOrganismsHaveLocations => newOrganisms.every((organism) => organism.isValid);
  bool get canSubmit => allFragmentsPlaced && allOrganismsHaveLocations && newOrganisms.isNotEmpty;

  PopulationMeasurement get fiveAxisMeasurement {
    final count =
        totalOutputCount > 0 ? totalOutputCount : organismSelection.totalQuantity;
    final value = count <= 0 ? 0.0 : count.toDouble();
    return PopulationMeasurement(
      value: value,
      unit: MeasurementUnit.count,
    );
  }

  @override
  bool get isValid {
    if (isFirstStep) return canProceedFromStep1;
    if (isSecondStep) return canProceedFromStep2;
    if (isThirdStep) return canSubmit;
    return false;
  }

  @override
  PropagationState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    PropagationEvent? createdRecord,
    PropagationEvent? originalRecord,
    bool? isLoading,
    String? loadError,
    OrganismSelectionInput? organismSelection,
    PropagationFragmentsPerInputInput? fragmentsPerInput,
    List<NewOrganismInput>? newOrganisms,
    List<PropagationReadyStatus>? propagationReadyEvents,
    Genet? genet,
    ProvenanceLifeStageSelection? provenanceSelection,
    String? selectedPhysicalFormId,
    SizeSpec? sizeSpec,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    DateTime? permitValidFrom,
    DateTime? permitValidTo,
    bool overrideSubmissionError = false,
  }) {
    return PropagationState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      isLoading: isLoading ?? this.isLoading,
      loadError: loadError ?? this.loadError,
      organismSelection: organismSelection ?? this.organismSelection,
      fragmentsPerInput: fragmentsPerInput ?? this.fragmentsPerInput,
      newOrganisms: newOrganisms ?? this.newOrganisms,
      propagationReadyEvents: propagationReadyEvents ?? this.propagationReadyEvents,
      genet: genet ?? this.genet,
      provenanceSelection: provenanceSelection ?? this.provenanceSelection,
      selectedPhysicalFormId: selectedPhysicalFormId ?? this.selectedPhysicalFormId,
      sizeSpec: sizeSpec ?? this.sizeSpec,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom ?? this.permitValidFrom,
      permitValidTo: permitValidTo ?? this.permitValidTo,
    );
  }

  // Helper methods for updating specific aspects of state
  PropagationState updateOrganismSelection(OrganismSelectionInput newSelection) {
    return copyWith(organismSelection: newSelection);
  }

  PropagationState updateFragmentsPerInput(int count) {
    final newFragmentsPerInput = PropagationFragmentsPerInputInput.dirty(
      count,
      minFragmentsPerInput: 1,
    );
    return copyWith(fragmentsPerInput: newFragmentsPerInput);
  }

  /// Returns true if selected organisms have different localIds
  bool get hasMultipleLocalIds {
    final localIds = organismSelection.selectedOrganisms
        .map((o) => o.localId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    return localIds.length > 1;
  }

  PropagationState addNewOrganism({
    int quantity = 1,
    GroupNode? groupNode,
  }) {
    // Get localIds from all selected organisms
    final localIds = organismSelection.selectedOrganisms
        .map((o) => o.localId ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // If all selected organisms share the same localId, inherit it
    // Otherwise, leave empty to indicate mixed source
    final sourceLocalId = localIds.length == 1 ? localIds.first : '';

    final baseRecordName = genet?.name ?? kDefaultPropagationBaseName;

    // Find next available suffix index by parsing existing record names
    final nextIndex = _findNextAvailableSuffix(baseRecordName);
    final generatedRecordName = '$baseRecordName-$nextIndex';

    final updatedOrganisms = List<NewOrganismInput>.from(newOrganisms)
      ..add(NewOrganismInput(
        localId: sourceLocalId,
        recordName: generatedRecordName,
        quantity: quantity,
        groupNode: groupNode,
      ));
    return copyWith(newOrganisms: updatedOrganisms);
  }

  PropagationState seedNewOrganismIfEmpty({
    required int totalOutput,
    GroupNode? groupNode,
  }) {
    if (totalOutput <= 0 || newOrganisms.isNotEmpty) {
      return this;
    }
    return addNewOrganism(quantity: totalOutput, groupNode: groupNode);
  }

  /// Finds the next available numeric suffix for the given base name.
  /// Parses existing newOrganisms to find used suffixes and returns the
  /// smallest positive integer not in use.
  int _findNextAvailableSuffix(String baseRecordName) {
    final prefix = '$baseRecordName-';
    final usedIndices = <int>{};

    for (final organism in newOrganisms) {
      final name = organism.recordName;
      if (name.startsWith(prefix)) {
        final suffix = name.substring(prefix.length);
        final index = int.tryParse(suffix);
        if (index != null && index > 0) {
          usedIndices.add(index);
        }
      }
    }

    // Find smallest positive integer not in usedIndices
    var nextIndex = 1;
    while (usedIndices.contains(nextIndex)) {
      nextIndex++;
    }
    return nextIndex;
  }

  PropagationState removeNewOrganism(int index) {
    if (index < 0 || index >= newOrganisms.length) return this;
    final updatedOrganisms = List<NewOrganismInput>.from(newOrganisms)..removeAt(index);
    return copyWith(newOrganisms: updatedOrganisms);
  }

  PropagationState updateNewOrganism(int index, NewOrganismInput newOrganism) {
    if (index < 0 || index >= newOrganisms.length) return this;
    final updatedOrganisms = List<NewOrganismInput>.from(newOrganisms);
    updatedOrganisms[index] = newOrganism;
    return copyWith(newOrganisms: updatedOrganisms);
  }
}
