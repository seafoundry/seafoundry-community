import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_inputs.dart';
import 'package:seafoundry_community/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/services/logging_service.dart';

abstract class RecordFormState<T extends Record> extends Equatable with FormzMixin {
  RecordFormState({
    required this.steps,
    int? currentStepIndex,
    this.submissionStatus = FormzSubmissionStatus.initial,
    this.submissionError,
    this.createdRecord,
    this.originalRecord,
  }) : currentStepIndex = currentStepIndex ?? 0,
       isEditing = originalRecord != null;

  final List<RecordFormStep> steps;
  final int currentStepIndex;
  final FormzSubmissionStatus submissionStatus;
  final String? submissionError;
  final T? createdRecord;
  final T? originalRecord;
  final bool isEditing;

  String? get validationErrorMessage {
    if (isValid) return null;
    // Use validator() directly instead of displayError to catch errors on
    // pure inputs that were programmatically set (e.g., auto-populated fields)
    final errors = <String>[];
    for (final input in inputs) {
      final error = input.validator(input.value);
      if (error != null) {
        final message = error.message;
        errors.add('${input.label}: $message');
      }
    }
    return errors.isEmpty ? null : errors.join('\n');
  }

  RecordFormStep get currentStep => steps[currentStepIndex];

  bool get canGoBack => currentStepIndex > 0;
  bool get canGoForward => currentStep.isValid && !isLastStep;
  bool get isLastStep => currentStepIndex == steps.length - 1;

  @override
  List<RecordFormInput> get inputs => steps.expand((step) => step.inputs).toList();

  @override
  List<Object?> get props => [steps, currentStepIndex, submissionStatus, submissionError, createdRecord, originalRecord, isEditing];

  RecordFormState<T>? copyWithInputEvent(RecordFormInputEvent event) {
    final eventKey = event.inputType ?? event.runtimeType;
    final stepIndex = steps.indexWhere((step) => step.inputsMap.containsKey(eventKey));
    if (stepIndex == -1) {
      LoggingService.instance.error(
        '[CopyWithInputEvent] Input not found for event type: ${event.runtimeType}',
      );
      return null;
    }
    final targetStep = steps[stepIndex];
    final copiedInput = targetStep.inputsMap[eventKey]!.copyWith(value: event.value);
    final copiedStep = targetStep.copyWith(copiedInput: copiedInput);
    final updatedSteps = List<RecordFormStep>.from(steps);
    updatedSteps[stepIndex] = copiedStep;
    return copyWith(steps: updatedSteps);
  }

  /// Abstract method that subclasses must implement to maintain type safety
  RecordFormState<T> copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    T? createdRecord,
    T? originalRecord,
    bool overrideSubmissionError = false,
  });

}

/// Base implementation of RecordFormState for simple cases
class BaseRecordFormState<T extends Record> extends RecordFormState<T> {
  BaseRecordFormState({
    required super.steps,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  });

  @override
  BaseRecordFormState<T> copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    T? createdRecord,
    T? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return BaseRecordFormState<T>(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
    );
  }
}
