// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/events/event_form_bloc.dart';
import 'package:seafoundry_app/blocs/events/permit_form_inputs.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/treatment_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';

// Event classes for form inputs
class TreatmentTypeChanged extends RecordFormInputEvent<String> {
  const TreatmentTypeChanged(super.value);
}

class MedicationNameChanged extends RecordFormInputEvent<String> {
  const MedicationNameChanged(super.value);
}

class DosageChanged extends RecordFormInputEvent<double?> {
  const DosageChanged(super.value);
}

class DosageUnitChanged extends RecordFormInputEvent<String> {
  const DosageUnitChanged(super.value);
}

class DurationMinutesChanged extends RecordFormInputEvent<int?> {
  const DurationMinutesChanged(super.value);
}

class TreatmentNotesChanged extends RecordFormInputEvent<String> {
  const TreatmentNotesChanged(super.value);
}

/// Form input for treatment type selection
class TreatmentTypeInput
    extends RecordFormInput<String, RequiredInputError, TreatmentTypeChanged> {
  const TreatmentTypeInput.pure() : super.pure();
  const TreatmentTypeInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Treatment Type';

  @override
  String? get hintText => 'Select the type of treatment';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Please select a treatment type');
    }
    return null;
  }

  @override
  TreatmentTypeInput copyWith({required String? value}) {
    return value == null
        ? const TreatmentTypeInput.pure()
        : TreatmentTypeInput.dirty(value);
  }
}

/// Form input for medication name
class MedicationNameInput
    extends
        RecordFormInput<String, RecordFormInputError, MedicationNameChanged> {
  const MedicationNameInput.pure() : super.pure();
  const MedicationNameInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Medication/Product Name';

  @override
  String? get hintText => 'Enter the name of medication or product used';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  MedicationNameInput copyWith({required String? value}) {
    return value == null
        ? const MedicationNameInput.pure()
        : MedicationNameInput.dirty(value);
  }
}

/// Form input for dosage
class DosageInput
    extends RecordFormInput<double?, RecordFormInputError, DosageChanged> {
  const DosageInput.pure() : super.pure();
  const DosageInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Dosage';

  @override
  String? get hintText => 'Enter the dosage amount';

  @override
  RecordFormInputError? validator(double? value) {
    if (value != null && value <= 0) {
      return const RecordFormInputError('Dosage must be positive');
    }
    return null;
  }

  @override
  DosageInput copyWith({required double? value}) {
    return value == null ? const DosageInput.pure() : DosageInput.dirty(value);
  }
}

/// Form input for dosage unit
class DosageUnitInput
    extends RecordFormInput<String, RecordFormInputError, DosageUnitChanged> {
  const DosageUnitInput.pure() : _value = 'ml', super.pure();
  const DosageUnitInput.dirty(String super.value)
    : _value = value,
      super.dirty();

  final String _value;

  @override
  String? get value => _value;

  @override
  String get label => 'Unit';

  @override
  String? get hintText => 'Select unit of measurement';

  @override
  RecordFormInputError? validator(String? value) => null; // Always valid

  static const List<String> availableUnits = [
    'ml',
    'g',
    'mg',
    'tsp',
    'tbsp',
    'cup',
    'oz',
    'lb',
  ];

  @override
  DosageUnitInput copyWith({required String? value}) {
    return value == null
        ? const DosageUnitInput.pure()
        : DosageUnitInput.dirty(value);
  }
}

/// Form input for duration in minutes
class DurationMinutesInput
    extends
        RecordFormInput<int?, RecordFormInputError, DurationMinutesChanged> {
  const DurationMinutesInput.pure() : super.pure();
  const DurationMinutesInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Duration (minutes)';

  @override
  String? get hintText => 'How long was the treatment?';

  @override
  RecordFormInputError? validator(int? value) {
    if (value != null && value <= 0) {
      return const RecordFormInputError('Duration must be positive');
    }
    return null;
  }

  @override
  DurationMinutesInput copyWith({required int? value}) {
    return value == null
        ? const DurationMinutesInput.pure()
        : DurationMinutesInput.dirty(value);
  }
}

/// Form input for treatment notes
class TreatmentNotesInput
    extends
        RecordFormInput<String, RecordFormInputError, TreatmentNotesChanged> {
  const TreatmentNotesInput.pure() : super.pure();
  const TreatmentNotesInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Optional treatment notes';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  TreatmentNotesInput copyWith({required String? value}) {
    return value == null
        ? const TreatmentNotesInput.pure()
        : TreatmentNotesInput.dirty(value);
  }
}

/// State for treatment event form
class TreatmentFormState extends EventFormState<TreatmentEvent> {
  TreatmentFormState({
    TreatmentTypeInput treatmentType = const TreatmentTypeInput.pure(),
    MedicationNameInput medicationName = const MedicationNameInput.pure(),
    DosageInput dosage = const DosageInput.pure(),
    DosageUnitInput dosageUnit = const DosageUnitInput.pure(),
    DurationMinutesInput durationMinutes = const DurationMinutesInput.pure(),
    TreatmentNotesInput notes = const TreatmentNotesInput.pure(),
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
             title: 'Treatment Details',
             inputs: [treatmentType, medicationName],
           ),
          BaseRecordFormStep(
            title: 'Dosage & Duration',
            inputs: [dosage, dosageUnit, durationMinutes, notes],
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

  TreatmentTypeInput get treatmentType =>
      steps[0].inputs[0] as TreatmentTypeInput;
  MedicationNameInput get medicationName =>
      steps[0].inputs[1] as MedicationNameInput;
  DosageInput get dosage => steps[1].inputs[0] as DosageInput;
  DosageUnitInput get dosageUnit => steps[1].inputs[1] as DosageUnitInput;
  DurationMinutesInput get durationMinutes =>
      steps[1].inputs[2] as DurationMinutesInput;
  TreatmentNotesInput get notes => steps[1].inputs[3] as TreatmentNotesInput;
  PermitIdInput get permitId => steps[2].inputs[0] as PermitIdInput;
  PermitTypeInput get permitType => steps[2].inputs[1] as PermitTypeInput;
  IssuingAuthorityInput get issuingAuthority =>
      steps[2].inputs[2] as IssuingAuthorityInput;
  PermitValidFromInput get permitValidFrom =>
      steps[2].inputs[3] as PermitValidFromInput;
  PermitValidToInput get permitValidTo =>
      steps[2].inputs[4] as PermitValidToInput;
  PermitAttachmentUrlsInput get permitAttachmentUrls =>
      steps[2].inputs[5] as PermitAttachmentUrlsInput;

  @override
  TreatmentFormState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    TreatmentEvent? createdRecord,
    TreatmentEvent? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return TreatmentFormState(
      treatmentType: steps != null
          ? steps[0].inputs[0] as TreatmentTypeInput
          : treatmentType,
      medicationName: steps != null
          ? steps[0].inputs[1] as MedicationNameInput
          : medicationName,
      dosage: steps != null && steps.length > 1
          ? steps[1].inputs[0] as DosageInput
          : dosage,
      dosageUnit: steps != null && steps.length > 1
          ? steps[1].inputs[1] as DosageUnitInput
          : dosageUnit,
      durationMinutes: steps != null && steps.length > 1
          ? steps[1].inputs[2] as DurationMinutesInput
          : durationMinutes,
      notes: steps != null && steps.length > 1
          ? steps[1].inputs[3] as TreatmentNotesInput
          : notes,
      permitId: steps != null && steps.length > 2
          ? steps[2].inputs[0] as PermitIdInput
          : permitId,
      permitType: steps != null && steps.length > 2
          ? steps[2].inputs[1] as PermitTypeInput
          : permitType,
      issuingAuthority: steps != null && steps.length > 2
          ? steps[2].inputs[2] as IssuingAuthorityInput
          : issuingAuthority,
      permitValidFrom: steps != null && steps.length > 2
          ? steps[2].inputs[3] as PermitValidFromInput
          : permitValidFrom,
      permitValidTo: steps != null && steps.length > 2
          ? steps[2].inputs[4] as PermitValidToInput
          : permitValidTo,
      permitAttachmentUrls: steps != null && steps.length > 2
          ? steps[2].inputs[5] as PermitAttachmentUrlsInput
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
    treatmentType,
    medicationName,
    dosage,
    dosageUnit,
    durationMinutes,
    notes,
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

/// BLoC for treatment event form
class TreatmentFormBloc
    extends EventFormBloc<TreatmentEvent, TreatmentFormState> {
  TreatmentFormBloc({
    required super.eventRepository,
    super.propagationService,
    super.targetNode,
  }) : super(
         initialState: TreatmentFormState(),
         allowPropagation: true,
         allowTaskCreation: false,
         multiTargetStrategy: MultiTargetStrategy.singleEventWithReferences,
         selectAllTargetsByDefault: true,
       ) {
    on<TreatmentTypeChanged>(_onTreatmentTypeChanged);
    on<MedicationNameChanged>(_onMedicationNameChanged);
    on<DosageChanged>(_onDosageChanged);
    on<DosageUnitChanged>(_onDosageUnitChanged);
    on<DurationMinutesChanged>(_onDurationMinutesChanged);
    on<TreatmentNotesChanged>(_onNotesChanged);
    on<PermitIdChanged>(_onPermitInputChanged);
    on<PermitTypeChanged>(_onPermitInputChanged);
    on<IssuingAuthorityChanged>(_onPermitInputChanged);
    on<PermitValidFromChanged>(_onPermitInputChanged);
    on<PermitValidToChanged>(_onPermitInputChanged);
    on<PermitAttachmentUrlsChanged>(_onPermitInputChanged);
  }

  @override
  String get eventTypeId => HusbandryEventType.treatment.id;

  @override
  TreatmentFormState get initialState => TreatmentFormState();

  /// Initialize the bloc for editing an existing treatment event
  void initializeForEdit(TreatmentEvent event) {
    add(TreatmentTypeChanged(event.treatmentTypeId));
    if (event.medicationName != null && event.medicationName!.isNotEmpty) {
      add(MedicationNameChanged(event.medicationName!));
    }
    if (event.dosage != null) {
      add(DosageChanged(event.dosage));
    }
    if (event.dosageUnit != null && event.dosageUnit!.isNotEmpty) {
      add(DosageUnitChanged(event.dosageUnit!));
    }
    if (event.durationMinutes != null) {
      add(DurationMinutesChanged(event.durationMinutes));
    }
    if (event.comment != null && event.comment!.isNotEmpty) {
      add(TreatmentNotesChanged(event.comment!));
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

  void _onTreatmentTypeChanged(
    TreatmentTypeChanged event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onMedicationNameChanged(
    MedicationNameChanged event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onDosageChanged(DosageChanged event, Emitter<TreatmentFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onDosageUnitChanged(
    DosageUnitChanged event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onDurationMinutesChanged(
    DurationMinutesChanged event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onNotesChanged(
    TreatmentNotesChanged event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  void _onPermitInputChanged(
    RecordFormInputEvent event,
    Emitter<TreatmentFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as TreatmentFormState);
    }
  }

  @override
  Future<TreatmentEvent> createEventFromState() async {
    if (targetNode == null) {
      throw Exception('Target node is required to create a treatment event');
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

    return TreatmentEvent.partial(
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
      treatmentTypeId: state.treatmentType.value,
      medicationName: state.medicationName.value,
      dosage: state.dosage.value,
      dosageUnit: state.dosageUnit.value,
      durationMinutes: state.durationMinutes.value,
      comment: state.notes.value,
      base: EventBaseParams(
        permitMetadata: _buildPermitMetadata(),
      ),
    );
  }

  @override
  Future<TreatmentEvent?> createRecord() async {
    return createEventFromState();
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
