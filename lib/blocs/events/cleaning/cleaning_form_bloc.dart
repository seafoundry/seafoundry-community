// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/events/cleaning_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';

// Event classes for form inputs
class CleaningTypeChanged extends RecordFormInputEvent<String> {
  const CleaningTypeChanged(super.value);
}

class DurationChanged extends RecordFormInputEvent<int?> {
  const DurationChanged(super.value);
}

class AreaChanged extends RecordFormInputEvent<String> {
  const AreaChanged(super.value);
}

class CommentChanged extends RecordFormInputEvent<String> {
  const CommentChanged(super.value);
}

/// Form input for cleaning type selection
class CleaningTypeInput
    extends RecordFormInput<String, RequiredInputError, CleaningTypeChanged> {
  const CleaningTypeInput.pure() : super.pure();
  const CleaningTypeInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Cleaning Type';

  @override
  String? get hintText => 'Select the type of cleaning';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Please select a cleaning type');
    }
    return null;
  }

  @override
  CleaningTypeInput copyWith({required String? value}) {
    return value == null
        ? const CleaningTypeInput.pure()
        : CleaningTypeInput.dirty(value);
  }
}

/// Form input for duration in minutes
class DurationInput
    extends RecordFormInput<int?, RecordFormInputError, DurationChanged> {
  const DurationInput.pure() : super.pure();
  const DurationInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Duration (minutes)';

  @override
  String? get hintText => 'How long did the cleaning take?';

  @override
  RecordFormInputError? validator(int? value) {
    if (value != null && value <= 0) {
      return const RecordFormInputError('Duration must be positive');
    }
    return null;
  }

  @override
  DurationInput copyWith({required int? value}) {
    return value == null
        ? const DurationInput.pure()
        : DurationInput.dirty(value);
  }
}

/// Form input for area/equipment cleaned
class AreaInput
    extends RecordFormInput<String, RecordFormInputError, AreaChanged> {
  const AreaInput.pure() : super.pure();
  const AreaInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Area/Equipment';

  @override
  String? get hintText => 'What area or equipment was cleaned?';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  AreaInput copyWith({required String? value}) {
    return value == null ? const AreaInput.pure() : AreaInput.dirty(value);
  }
}

/// Form input for comments
class CommentInput
    extends RecordFormInput<String, RecordFormInputError, CommentChanged> {
  const CommentInput.pure() : super.pure();
  const CommentInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Comments';

  @override
  String? get hintText => 'Optional notes about this cleaning';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  CommentInput copyWith({required String? value}) {
    return value == null
        ? const CommentInput.pure()
        : CommentInput.dirty(value);
  }
}

/// State for cleaning event form
class CleaningFormState extends EventFormState<CleaningEvent> {
  CleaningFormState({
    CleaningTypeInput cleaningType = const CleaningTypeInput.pure(),
    DurationInput duration = const DurationInput.pure(),
    AreaInput area = const AreaInput.pure(),
    CommentInput comment = const CommentInput.pure(),
    PermitIdInput permitId = const PermitIdInput.pure(),
    PermitTypeInput permitType = const PermitTypeInput.pure(),
    IssuingAuthorityInput issuingAuthority =
        const IssuingAuthorityInput.pure(),
    PermitValidFromInput permitValidFrom = const PermitValidFromInput.pure(),
    PermitValidToInput permitValidTo = const PermitValidToInput.pure(),
    PermitAttachmentUrlsInput permitAttachmentUrls =
        const PermitAttachmentUrlsInput.pure(),
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  }) : super(
         steps: [
           BaseRecordFormStep(
             title: 'Cleaning Details',
             inputs: [cleaningType, duration, area, comment],
           ),
           BaseRecordFormStep(
             title: 'Permit Metadata (optional)',
             inputs: [
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

  CleaningTypeInput get cleaningType => steps[0].inputs[0] as CleaningTypeInput;
  DurationInput get duration => steps[0].inputs[1] as DurationInput;
  AreaInput get area => steps[0].inputs[2] as AreaInput;
  CommentInput get comment => steps[0].inputs[3] as CommentInput;
  PermitIdInput get permitId => steps[1].inputs[0] as PermitIdInput;
  PermitTypeInput get permitType => steps[1].inputs[1] as PermitTypeInput;
  IssuingAuthorityInput get issuingAuthority =>
      steps[1].inputs[2] as IssuingAuthorityInput;
  PermitValidFromInput get permitValidFrom =>
      steps[1].inputs[3] as PermitValidFromInput;
  PermitValidToInput get permitValidTo =>
      steps[1].inputs[4] as PermitValidToInput;
  PermitAttachmentUrlsInput get permitAttachmentUrls =>
      steps[1].inputs[5] as PermitAttachmentUrlsInput;

  @override
  CleaningFormState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    CleaningEvent? createdRecord,
    CleaningEvent? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return CleaningFormState(
      cleaningType: steps != null
          ? steps[0].inputs[0] as CleaningTypeInput
          : cleaningType,
      duration: steps != null ? steps[0].inputs[1] as DurationInput : duration,
      area: steps != null ? steps[0].inputs[2] as AreaInput : area,
      comment: steps != null ? steps[0].inputs[3] as CommentInput : comment,
      permitId: steps != null ? steps[1].inputs[0] as PermitIdInput : permitId,
      permitType:
          steps != null ? steps[1].inputs[1] as PermitTypeInput : permitType,
      issuingAuthority: steps != null
          ? steps[1].inputs[2] as IssuingAuthorityInput
          : issuingAuthority,
      permitValidFrom: steps != null
          ? steps[1].inputs[3] as PermitValidFromInput
          : permitValidFrom,
      permitValidTo: steps != null
          ? steps[1].inputs[4] as PermitValidToInput
          : permitValidTo,
      permitAttachmentUrls: steps != null
          ? steps[1].inputs[5] as PermitAttachmentUrlsInput
          : permitAttachmentUrls,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
    );
  }

  @override
  List<Object?> get props => [
    cleaningType,
    duration,
    area,
    comment,
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
  ];
}

/// BLoC for cleaning event form
class CleaningFormBloc extends EventFormBloc<CleaningEvent, CleaningFormState> {
  CleaningFormBloc({
    required super.eventRepository,
    super.propagationService,
    super.targetNode,
  }) : super(
         initialState: CleaningFormState(),
         allowPropagation: true,
         allowTaskCreation: false,
         multiTargetStrategy: MultiTargetStrategy.singleEventWithReferences,
         selectAllTargetsByDefault: true,
       ) {
    on<CleaningTypeChanged>(_onCleaningTypeChanged);
    on<DurationChanged>(_onDurationChanged);
    on<AreaChanged>(_onAreaChanged);
    on<CommentChanged>(_onCommentChanged);
    on<PermitIdChanged>(_onPermitInputChanged);
    on<PermitTypeChanged>(_onPermitInputChanged);
    on<IssuingAuthorityChanged>(_onPermitInputChanged);
    on<PermitValidFromChanged>(_onPermitInputChanged);
    on<PermitValidToChanged>(_onPermitInputChanged);
    on<PermitAttachmentUrlsChanged>(_onPermitInputChanged);
  }

  @override
  String get eventTypeId => HusbandryEventType.cleaning.id;

  @override
  CleaningFormState get initialState => CleaningFormState();

  /// Initialize the bloc for editing an existing cleaning event
  void initializeForEdit(CleaningEvent event) {
    add(CleaningTypeChanged(event.cleaningTypeId));
    if (event.durationMinutes != null) {
      add(DurationChanged(event.durationMinutes));
    }
    if (event.area != null && event.area!.isNotEmpty) {
      add(AreaChanged(event.area!));
    }
    if (event.comment != null && event.comment!.isNotEmpty) {
      add(CommentChanged(event.comment!));
    }
    final permit = event.permitMetadata;
    if (!permit.isEmpty) {
      add(PermitIdChanged(permit.permitId));
      add(PermitTypeChanged(permit.permitType));
      add(IssuingAuthorityChanged(permit.issuingAuthority));
      add(PermitValidFromChanged(permit.validFrom));
      add(PermitValidToChanged(permit.validTo));
      if (permit.attachmentUrls.isNotEmpty) {
        add(
          PermitAttachmentUrlsChanged(
            permit.attachmentUrls.join('\n'),
          ),
        );
      }
    }
    // Store the original event for reference
    add(RecordFormInitializeForEdit(event));
  }

  void _onCleaningTypeChanged(
    CleaningTypeChanged event,
    Emitter<CleaningFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CleaningFormState);
    }
  }

  void _onDurationChanged(
    DurationChanged event,
    Emitter<CleaningFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CleaningFormState);
    }
  }

  void _onAreaChanged(AreaChanged event, Emitter<CleaningFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CleaningFormState);
    }
  }

  void _onCommentChanged(
    CommentChanged event,
    Emitter<CleaningFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CleaningFormState);
    }
  }

  void _onPermitInputChanged(
    RecordFormInputEvent event,
    Emitter<CleaningFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as CleaningFormState);
    }
  }

  @override
  Future<CleaningEvent> createEventFromState() async {
    if (targetNode == null) {
      throw Exception('Target node is required to create a cleaning event');
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

    return CleaningEvent.partial(
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
      cleaningTypeId: state.cleaningType.value,
      durationMinutes: state.duration.value,
      area: state.area.value,
      comment: state.comment.value,
      base: EventBaseParams(
        permitMetadata: _buildPermitMetadata(),
      ),
    );
  }

  @override
  Future<CleaningEvent?> createRecord() async {
    return createEventFromState();
  }

  Map<String, dynamic> buildEventData() {
    final permit = _buildPermitMetadata();
    return {
      'cleaningTypeId': state.cleaningType.value ?? '',
      'durationMinutes': state.duration.value,
      'area': state.area.value ?? '',
      'comment': state.comment.value ?? '',
      if (permit != null) 'permitMetadata': permit.toJson(),
    };
  }

  String buildActivityDescription() {
    final type = state.cleaningType.value ?? 'Unknown';
    final duration = state.duration.value;
    final area = state.area.value;

    var description = 'Cleaning performed: $type';
    if (duration != null) {
      description += ' ($duration minutes)';
    }
    if (area != null && area.isNotEmpty) {
      description += ' - $area';
    }
    return description;
  }

  EventPermitMetadata? _buildPermitMetadata() {
    final hadInitialPermit =
        state.originalRecord?.permitMetadata.isEmpty == false;
    return buildPermitMetadataFromTextInputs(
      permitIdText: state.permitId.value ?? '',
      permitTypeText: state.permitType.value ?? '',
      issuingAuthorityText: state.issuingAuthority.value ?? '',
      attachmentsText: state.permitAttachmentUrls.value ?? '',
      validFrom: state.permitValidFrom.value,
      validTo: state.permitValidTo.value,
      hadInitialPermit: hadInitialPermit,
      isEditMode: state.isEditing,
    );
  }
}
