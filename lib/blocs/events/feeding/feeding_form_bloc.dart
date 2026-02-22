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
import 'package:seafoundry_app/models/events/feeding_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';

// Event classes for form inputs
class FoodTypeChanged extends RecordFormInputEvent<String> {
  const FoodTypeChanged(super.value);
}

class AmountChanged extends RecordFormInputEvent<double?> {
  const AmountChanged(super.value);
}

class UnitChanged extends RecordFormInputEvent<String> {
  const UnitChanged(super.value);
}

class FeedingNotesChanged extends RecordFormInputEvent<String> {
  const FeedingNotesChanged(super.value);
}

/// Form input for food type selection
class FoodTypeInput
    extends RecordFormInput<String, RequiredInputError, FoodTypeChanged> {
  const FoodTypeInput.pure() : super.pure();
  const FoodTypeInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Food Type';

  @override
  String? get hintText => 'Select the type of food';

  @override
  RequiredInputError? validator(String? value) {
    if (value == null || value.isEmpty) {
      return const RequiredInputError('Please select a food type');
    }
    if (!FoodType.values.any((ft) => ft.id == value)) {
      return const RequiredInputError('Invalid food type');
    }
    return null;
  }

  @override
  FoodTypeInput copyWith({required String? value}) {
    return value == null
        ? const FoodTypeInput.pure()
        : FoodTypeInput.dirty(value);
  }
}

/// Form input for amount
class AmountInput
    extends RecordFormInput<double?, RecordFormInputError, AmountChanged> {
  const AmountInput.pure() : super.pure();
  const AmountInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Amount';

  @override
  String? get hintText => 'Enter the amount fed';

  @override
  RecordFormInputError? validator(double? value) {
    if (value != null && value <= 0) {
      return const RecordFormInputError('Amount must be positive');
    }
    return null;
  }

  @override
  AmountInput copyWith({required double? value}) {
    return value == null ? const AmountInput.pure() : AmountInput.dirty(value);
  }
}

/// Form input for unit
class UnitInput
    extends RecordFormInput<String, RecordFormInputError, UnitChanged> {
  const UnitInput.pure() : _value = 'ml', super.pure();
  const UnitInput.dirty(String super.value) : _value = value, super.dirty();

  final String _value;

  @override
  String? get value => _value;

  @override
  String get label => 'Unit';

  @override
  String? get hintText => 'Select unit of measurement';

  @override
  RecordFormInputError? validator(String? value) => null; // Always valid

  @override
  UnitInput copyWith({required String? value}) {
    return value == null ? const UnitInput.pure() : UnitInput.dirty(value);
  }

  /// Available units for feeding
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
}

/// Form input for notes
class FeedingNotesInput
    extends RecordFormInput<String, RecordFormInputError, FeedingNotesChanged> {
  const FeedingNotesInput.pure() : super.pure();
  const FeedingNotesInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Optional feeding notes';

  @override
  RecordFormInputError? validator(String? value) => null; // Optional field

  @override
  FeedingNotesInput copyWith({required String? value}) {
    return value == null
        ? const FeedingNotesInput.pure()
        : FeedingNotesInput.dirty(value);
  }
}

/// State for feeding event form
class FeedingFormState extends EventFormState<FeedingEvent> {
  FeedingFormState({
    FoodTypeInput foodType = const FoodTypeInput.pure(),
    AmountInput amount = const AmountInput.pure(),
    UnitInput unit = const UnitInput.pure(),
    FeedingNotesInput notes = const FeedingNotesInput.pure(),
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
             title: 'Feeding Details',
             inputs: [foodType, amount, unit, notes],
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

  FoodTypeInput get foodType => steps[0].inputs[0] as FoodTypeInput;
  AmountInput get amount => steps[0].inputs[1] as AmountInput;
  UnitInput get unit => steps[0].inputs[2] as UnitInput;
  FeedingNotesInput get notes => steps[0].inputs[3] as FeedingNotesInput;
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
  FeedingFormState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    FeedingEvent? createdRecord,
    FeedingEvent? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return FeedingFormState(
      foodType: steps != null ? steps[0].inputs[0] as FoodTypeInput : foodType,
      amount: steps != null ? steps[0].inputs[1] as AmountInput : amount,
      unit: steps != null ? steps[0].inputs[2] as UnitInput : unit,
      notes: steps != null ? steps[0].inputs[3] as FeedingNotesInput : notes,
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
    foodType,
    amount,
    unit,
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

/// BLoC for feeding event form
class FeedingFormBloc extends EventFormBloc<FeedingEvent, FeedingFormState> {
  FeedingFormBloc({
    required super.eventRepository,
    super.propagationService,
    super.targetNode,
  }) : super(
         initialState: FeedingFormState(),
         allowPropagation: true,
         allowTaskCreation: false,
         multiTargetStrategy: MultiTargetStrategy.singleEventWithReferences,
         selectAllTargetsByDefault: true,
       ) {
    on<FoodTypeChanged>(_onFoodTypeChanged);
    on<AmountChanged>(_onAmountChanged);
    on<UnitChanged>(_onUnitChanged);
    on<FeedingNotesChanged>(_onNotesChanged);
    on<PermitIdChanged>(_onPermitInputChanged);
    on<PermitTypeChanged>(_onPermitInputChanged);
    on<IssuingAuthorityChanged>(_onPermitInputChanged);
    on<PermitValidFromChanged>(_onPermitInputChanged);
    on<PermitValidToChanged>(_onPermitInputChanged);
    on<PermitAttachmentUrlsChanged>(_onPermitInputChanged);
  }

  @override
  String get eventTypeId => HusbandryEventType.feeding.id;

  @override
  FeedingFormState get initialState => FeedingFormState();

  /// Initialize the bloc for editing an existing feeding event
  void initializeForEdit(FeedingEvent event) {
    add(FoodTypeChanged(event.foodTypeId));
    if (event.amount != null) {
      add(AmountChanged(event.amount));
    }
    if (event.unit != null && event.unit!.isNotEmpty) {
      add(UnitChanged(event.unit!));
    }
    if (event.comment != null && event.comment!.isNotEmpty) {
      add(FeedingNotesChanged(event.comment!));
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

  void _onFoodTypeChanged(
    FoodTypeChanged event,
    Emitter<FeedingFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as FeedingFormState);
    }
  }

  void _onAmountChanged(AmountChanged event, Emitter<FeedingFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as FeedingFormState);
    }
  }

  void _onUnitChanged(UnitChanged event, Emitter<FeedingFormState> emit) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as FeedingFormState);
    }
  }

  void _onNotesChanged(
    FeedingNotesChanged event,
    Emitter<FeedingFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as FeedingFormState);
    }
  }

  void _onPermitInputChanged(
    RecordFormInputEvent event,
    Emitter<FeedingFormState> emit,
  ) {
    final updatedState = state.copyWithInputEvent(event);
    if (updatedState != null) {
      emit(updatedState as FeedingFormState);
    }
  }

  @override
  Future<FeedingEvent> createEventFromState() async {
    if (targetNode == null) {
      throw Exception('Target node is required to create a feeding event');
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

    return FeedingEvent.partial(
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
      foodTypeId: state.foodType.value,
      amount: state.amount.value,
      unit: state.unit.value,
      comment: state.notes.value,
      base: EventBaseParams(
        permitMetadata: _buildPermitMetadata(),
      ),
    );
  }

  @override
  Future<FeedingEvent?> createRecord() async {
    return createEventFromState();
  }

  Map<String, dynamic> buildEventData() {
    final permit = _buildPermitMetadata();
    return {
      'foodTypeId': state.foodType.value ?? '',
      'amount': state.amount.value,
      'unit': state.unit.value ?? 'ml',
      'notes': state.notes.value ?? '',
      if (permit != null) 'permitMetadata': permit.toJson(),
    };
  }

  String buildActivityDescription() {
    final foodType = FoodType.fromId(state.foodType.value)?.label ?? 'Unknown';
    final amount = state.amount.value;
    final unit = state.unit.value ?? 'ml';

    var description = 'Fed: $foodType';
    if (amount != null) {
      description += ' ($amount $unit)';
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
