// @tier: community
import 'package:collection/collection.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/coral_creation/coral_form_inputs.dart';
import 'package:seafoundry_app/blocs/inventory_event/inventory_event_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/models/types/inventory_event_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/population_loss_reason.dart';
import 'package:seafoundry_app/models/types/status_event_type.dart';

class InventoryEventFormState extends RecordFormState<Event> {
  InventoryEventFormState({
    required super.steps,
    super.currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    super.submissionError,
    super.createdRecord,
    EventTypeSelection? eventType,
    this.ongoingEvent,
  }) : _eventType = eventType,
       super(
         submissionStatus: submissionStatus ?? FormzSubmissionStatus.initial,
       );

  InventoryEventFormState.populationLossOrganism({
    required OrganismRecord organism,
    super.currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    super.submissionError,
    super.createdRecord,
  }) : _eventType = EventTypeSelection.dirty(
         InventoryEventType.populationLoss,
         options: [],
       ),
       ongoingEvent = null,
       super(
         steps: [
           BaseRecordFormStep(
             inputs: [
               QuantityInput.dirty(organism.measurement.value.toInt()),
               InventoryEventComment.pure(),
               InventoryEventPopulationLossReason.dirty(
                 PopulationLossReason.other,
               ),
               InventoryEventPopulationGainReason.dirty(
                 PopulationGainReason.other,
               ),
               InventoryEventMortalityReason.pure(),
               InventoryEventDiseaseType.pure(),
             ],
             title: 'Report ${organism.organismKind.metadata.displayName} Loss',
           ),
         ],
       );

  InventoryEventFormState.organismSize({
    required OrganismRecord organism,
    this.ongoingEvent,
  }) : _eventType = null,
       super(
         steps: organism.sizeSpec.hasSize
             ? [
                 CoralSizeChangeTypeStep(),
                 BaseRecordFormStep(
                   inputs: [
                     SizeClassInput.dirty(organism.sizeSpec.sizeClass),
                     MeasuredDimensionInput.dirty(
                       organism.sizeSpec.measuredDimension,
                     ),
                     DimensionUnitInput.dirty(
                       organism.sizeSpec.dimensionUnit,
                     ),
                     InventoryEventComment.pure(),
                   ],
                   title: 'Report ${organism.organismKind.metadata.displayName} Size Change',
                 ),
               ]
             : [
                 BaseRecordFormStep(
                   inputs: [
                     SizeClassInput.dirty(organism.sizeSpec.sizeClass),
                     MeasuredDimensionInput.dirty(
                       organism.sizeSpec.measuredDimension,
                     ),
                     DimensionUnitInput.dirty(
                       organism.sizeSpec.dimensionUnit,
                     ),
                     InventoryEventComment.pure(),
                   ],
                   title: 'Track ${organism.organismKind.metadata.displayName} Size',
                 ),
               ],
       );

  InventoryEventFormState.organismPropagationReady({
    required OrganismRecord organism,
    this.ongoingEvent,
  }) : _eventType = EventTypeSelection.dirty(
        StatusEventType.propagationReady,
        options: [],
      ),
       super(
         steps: [
           BaseRecordFormStep(
             inputs: [
               ongoingEvent != null
                   ? OrganismPropagatableInput.dirty(true)
                   : OrganismPropagatableInput.pure(),
               InventoryEventComment.pure(),
             ],
             title: ongoingEvent != null
                 ? 'Clear ready to propagate status'
                 : 'Mark as ready to propagate',
           ),
         ],
       );

  final EventTypeSelection? _eventType;
  final StatusEvent? ongoingEvent;

  EventTypeSelection? get eventType =>
      _eventType ??
      inputs.firstWhereOrNull((input) => input is EventTypeSelection)
          as EventTypeSelection?;

  // Generic quantity getter that works with both CoralQuantity (coral path) and QuantityInput (organism path)
  FormzInput<int?, Object>? get quantity {
    final coralQty = inputs.firstWhereOrNull((input) => input is CoralQuantity);
    if (coralQty != null) return coralQty as CoralQuantity;

    final organismQty = inputs.firstWhereOrNull((input) => input is QuantityInput);
    return organismQty as QuantityInput?;
  }
  InventoryEventComment? get comment =>
      inputs.firstWhereOrNull((input) => input is InventoryEventComment)
          as InventoryEventComment?;
  InventoryEventPopulationLossReason? get populationLossReason =>
      inputs.firstWhereOrNull(
            (input) => input is InventoryEventPopulationLossReason,
          )
          as InventoryEventPopulationLossReason?;
  InventoryEventPopulationGainReason? get populationGainReason =>
      inputs.firstWhereOrNull(
            (input) => input is InventoryEventPopulationGainReason,
          )
          as InventoryEventPopulationGainReason?;
  InventoryEventMortalityReason? get mortalityReason =>
      inputs.firstWhereOrNull((input) => input is InventoryEventMortalityReason)
          as InventoryEventMortalityReason?;
  InventoryEventDiseaseType? get diseaseType =>
      inputs.firstWhereOrNull((input) => input is InventoryEventDiseaseType)
          as InventoryEventDiseaseType?;

  CoralSizeSelection? get coralSize =>
      inputs.firstWhereOrNull((input) => input is CoralSizeSelection)
          as CoralSizeSelection?;

  OrganismPropagatableInput? get isPropagatable =>
      inputs.firstWhereOrNull((input) => input is OrganismPropagatableInput)
          as OrganismPropagatableInput?;

  CoralSizeSelection get size =>
      inputs.firstWhere((input) => input is CoralSizeSelection)
          as CoralSizeSelection;

  SizeClassInput? get sizeClass =>
      inputs.firstWhereOrNull((input) => input is SizeClassInput)
          as SizeClassInput?;
  MeasuredDimensionInput? get measuredDimension =>
      inputs.firstWhereOrNull((input) => input is MeasuredDimensionInput)
          as MeasuredDimensionInput?;
  DimensionUnitInput? get dimensionUnit =>
      inputs.firstWhereOrNull((input) => input is DimensionUnitInput)
          as DimensionUnitInput?;

  @override
  List<Object?> get props => super.props + [_eventType, ongoingEvent];

  @override
  InventoryEventFormState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    Event? createdRecord,
    Event? originalRecord,
    StatusEvent? ongoingEvent,
    bool overrideSubmissionError = false,
  }) {
    return InventoryEventFormState(
      eventType: _eventType,
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      ongoingEvent: ongoingEvent ?? this.ongoingEvent,
    );
  }
}

class CoralSizeChangeTypeStep extends RecordFormStep {
  CoralSizeChangeTypeStep({List<RecordFormInput>? inputs})
    : super(
        inputs:
            inputs ??
            [
              EventTypeSelection.pure(
                options: [
                  CoralSizeEventType.growth,
                  CoralSizeEventType.tissueLoss,
                ],
              ),
            ],
        title: 'Change Reason',
      );

  @override
  CoralSizeChangeTypeStep copyWith({required RecordFormInput copiedInput}) {
    return CoralSizeChangeTypeStep(inputs: updateInputs(copiedInput));
  }
}
