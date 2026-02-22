// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/events/cross_event.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

// Event classes for form inputs
class DamsChanged extends RecordFormInputEvent<List<String>> {
  const DamsChanged(super.value);
}

class SiresChanged extends RecordFormInputEvent<List<String>> {
  const SiresChanged(super.value);
}

class CrossNotesChanged extends RecordFormInputEvent<String> {
  const CrossNotesChanged(super.value);
}

/// Form input for dam (female parent) selection
class DamsInput
    extends RecordFormInput<List<String>, RequiredInputError, DamsChanged> {
  const DamsInput.pure() : super.pure();
  const DamsInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Dam Gametes';

  @override
  String? get hintText => 'Select egg gametes';

  @override
  RequiredInputError? validator(List<String>? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Please select at least one dam');
    }
    return null;
  }

  @override
  DamsInput copyWith({required List<String>? value}) {
    return value == null ? const DamsInput.pure() : DamsInput.dirty(value);
  }
}

/// Form input for sire (male parent) selection
class SiresInput
    extends RecordFormInput<List<String>, RequiredInputError, SiresChanged> {
  const SiresInput.pure() : super.pure();
  const SiresInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Sire Gametes';

  @override
  String? get hintText => 'Select sperm gametes';

  @override
  RequiredInputError? validator(List<String>? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Please select at least one sire');
    }
    return null;
  }

  @override
  SiresInput copyWith({required List<String>? value}) {
    return value == null ? const SiresInput.pure() : SiresInput.dirty(value);
  }
}

/// Form input for cross notes
class CrossNotesInput
    extends RecordFormInput<String, RecordFormInputError, CrossNotesChanged> {
  const CrossNotesInput.pure() : super.pure();
  const CrossNotesInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Optional notes about this cross';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  CrossNotesInput copyWith({required String? value}) {
    return value == null
        ? const CrossNotesInput.pure()
        : CrossNotesInput.dirty(value);
  }
}

/// State for cross event form
class CrossFormState extends EventFormState<CrossEvent> {
  CrossFormState({
    DamsInput dams = const DamsInput.pure(),
    SiresInput sires = const SiresInput.pure(),
    CrossNotesInput notes = const CrossNotesInput.pure(),
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
  }) : super(
         steps: [
           BaseRecordFormStep(title: 'Parent Selection', inputs: [dams, sires]),
           BaseRecordFormStep(title: 'Cross Details', inputs: [notes]),
         ],
       );

  DamsInput get dams => steps[0].inputs[0] as DamsInput;
  SiresInput get sires => steps[0].inputs[1] as SiresInput;
  CrossNotesInput get notes => steps[1].inputs[0] as CrossNotesInput;

  @override
  CrossFormState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    CrossEvent? createdRecord,
    CrossEvent? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return CrossFormState(
      dams: steps != null ? steps[0].inputs[0] as DamsInput : dams,
      sires: steps != null ? steps[0].inputs[1] as SiresInput : sires,
      notes: steps != null && steps.length > 1
          ? steps[1].inputs[0] as CrossNotesInput
          : notes,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
    );
  }

  @override
  List<Object?> get props => [
    dams,
    sires,
    notes,
    currentStepIndex,
    submissionStatus,
    submissionError,
    createdRecord,
  ];
}

/// BLoC for cross event form
class CrossFormBloc extends EventFormBloc<CrossEvent, CrossFormState> {
  CrossFormBloc({
    required super.eventRepository,
    super.propagationService,
    super.targetNode,
  }) : super(
         initialState: CrossFormState(),
         allowPropagation: true,
         allowTaskCreation: false,
       ) {
    on<DamsChanged>(_onDamsChanged);
    on<SiresChanged>(_onSiresChanged);
    on<CrossNotesChanged>(_onNotesChanged);
  }

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
  String get eventTypeId => EventType.cross.id;

  @override
  CrossFormState get initialState => CrossFormState();

  void _onDamsChanged(DamsChanged event, Emitter<CrossFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CrossFormState);
    }
  }

  void _onSiresChanged(SiresChanged event, Emitter<CrossFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CrossFormState);
    }
  }

  void _onNotesChanged(CrossNotesChanged event, Emitter<CrossFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CrossFormState);
    }
  }

  /// Validation error from the last [validateEventSpecific] call.
  /// This field is set as a side effect of validation to allow
  /// [validationError] to return the specific error message.
  String? _validationError;

  @override
  Future<void> onEventSubmit(RecordFormSubmit event, Emitter<CrossFormState> emit) async {
    // Call parent's onEventSubmit which will invoke validateEventSpecific()
    await super.onEventSubmit(event, emit);
    if (emit.isDone) return;

    // If validation failed with a custom error, update the submission error message
    if (_validationError != null && state.submissionStatus == FormzSubmissionStatus.failure) {
      emit(
        state.copyWith(
          submissionStatus: FormzSubmissionStatus.failure,
          submissionError: _validationError,
        ),
      );
    }
  }

  @override
  bool validateEventSpecific() {
    // Clear any previous validation error
    _validationError = null;

    // Check for dam/sire overlap
    final damIds = state.dams.value ?? [];
    final sireIds = state.sires.value ?? [];
    final damSet = damIds.toSet();
    final sireSet = sireIds.toSet();
    final overlap = damSet.intersection(sireSet);

    if (overlap.isNotEmpty) {
      _validationError =
          'The same organism cannot be selected as both dam and sire.';
      return false;
    }

    // Validate that all selected parents are still gametes
    if (targetNode == null) return true;

    final nodeState = targetNode!.state;
    if (nodeState is! GraphLoadedState) return true;

    final allParentIds = [...damIds, ...sireIds];

    // Find and validate each parent organism
    for (final parentId in allParentIds) {
      final organism = _findOrganismInNodeHierarchy(parentId, targetNode!);

      // Only fail if organism IS found but is NOT a gamete
      // If not found, assume valid (e.g., for tests or stale cache)
      if (organism != null && organism.lifeStage.stage != LifeStage.gamete) {
        _validationError =
            'All parents must be gametes. One or more selected organisms have '
            'transitioned to ${organism.lifeStage.stage.displayName}. '
            'Please update your selection.';
        return false;
      }

      // Gamete role validation
      if (organism != null) {
        final role = organism.provenanceAttributes.gameteRole;
        final isDam = damIds.contains(parentId);
        final expectedRole =
            isDam ? ProvenanceGameteRole.egg : ProvenanceGameteRole.sperm;

        if (role != expectedRole) {
          final expectedLabel = isDam ? 'egg' : 'sperm';
          final actualLabel = role?.name ?? 'unknown';
          final parentLabel = isDam ? 'Dam' : 'Sire';
          _validationError =
              'Organism "${organism.name}" is assigned as $parentLabel but has '
              'gamete role "$actualLabel" (expected "$expectedLabel").';
          return false;
        }
      }
    }

    return true;
  }

  /// Recursively search for an organism in the graph node hierarchy
  OrganismRecord? _findOrganismInNodeHierarchy(
    String organismId,
    GraphNode node,
  ) {
    final nodeState = node.state;
    if (nodeState is! GraphLoadedState) return null;

    // Check if this node itself is the organism we're looking for
    final record = nodeState.record;
    if (record is OrganismRecord && record.id == organismId) {
      return record;
    }

    // Search through child nodes
    for (final child in nodeState.children) {
      final found = _findOrganismInNodeHierarchy(organismId, child);
      if (found != null) return found;
    }

    return null;
  }

  @override
  Future<CrossEvent> createEventFromState() async {
    if (targetNode == null) {
      throw Exception('Target node is required to create a cross event');
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

    return CrossEvent(
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
      damIds: state.dams.value ?? [],
      sireIds: state.sires.value ?? [],
    );
  }

  @override
  Future<CrossEvent?> createRecord() async {
    return createEventFromState();
  }

  Map<String, dynamic> buildEventData() {
    return {
      'damIds': state.dams.value ?? [],
      'sireIds': state.sires.value ?? [],
    };
  }

  String buildActivityDescription() {
    final damsCount = state.dams.value?.length ?? 0;
    final siresCount = state.sires.value?.length ?? 0;

    return 'Cross event: $damsCount dam(s) × $siresCount sire(s)';
  }
}
