import 'package:collection/collection.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_async.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_event.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/cubits/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';

class OrganismSplitState extends AsyncRecordFormState<OrganismRecord> {
  OrganismSplitState({
    required super.steps,
    this.sourceOrganism,
    this.suggestedRecordName,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    super.loadStatus,
    super.loadError,
  });

  final OrganismRecord? sourceOrganism;
  final String? suggestedRecordName;

  SplitQuantityInput get splitQuantityInput =>
      inputs.firstWhereOrNull((input) => input is SplitQuantityInput)
          as SplitQuantityInput? ??
      const SplitQuantityInput.pure();

  double get splitQuantity => splitQuantityInput.value ?? 1.0;

  SplitRecordNameInput get splitRecordNameInput =>
      inputs.firstWhereOrNull((input) => input is SplitRecordNameInput)
          as SplitRecordNameInput? ??
      const SplitRecordNameInput.pure();

  String? get splitRecordName => splitRecordNameInput.value;

  SplitReasonInput get splitReasonInput =>
      inputs.firstWhereOrNull((input) => input is SplitReasonInput)
          as SplitReasonInput? ??
      const SplitReasonInput.pure();

  PhysicalFormChangeReason? get splitReason => splitReasonInput.value;

  SplitNotesInput get splitNotesInput =>
      inputs.firstWhereOrNull((input) => input is SplitNotesInput)
          as SplitNotesInput? ??
      const SplitNotesInput.pure();

  String? get splitNotes => splitNotesInput.value;

  double get sourceQuantity => sourceOrganism?.measurement.value ?? 0.0;

  double get remainingQuantity => sourceQuantity - splitQuantity;

  @override
  OrganismSplitState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    OrganismRecord? createdRecord,
    OrganismRecord? originalRecord,
    RecordFormLoadStatus? loadStatus,
    String? loadError,
    OrganismRecord? sourceOrganism,
    String? suggestedRecordName,
    bool overrideSubmissionError = false,
    bool clearSuggestedRecordName = false,
  }) {
    return OrganismSplitState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
      loadStatus: loadStatus ?? this.loadStatus,
      loadError: loadError ?? this.loadError,
      sourceOrganism: sourceOrganism ?? this.sourceOrganism,
      suggestedRecordName: clearSuggestedRecordName
          ? null
          : (suggestedRecordName ?? this.suggestedRecordName),
    );
  }

  @override
  OrganismSplitState copyWithLoad({
    RecordFormLoadStatus? loadStatus,
    String? loadError,
  }) {
    return copyWith(loadStatus: loadStatus, loadError: loadError);
  }
}

/// Input for split quantity selection
class SplitQuantityInput
    extends RecordFormInput<double, RecordFormInputError, SplitQuantityChanged> {
  const SplitQuantityInput.pure({
    this.minQuantity = 1.0,
    this.maxQuantity = double.infinity,
  }) : super.pure();

  const SplitQuantityInput.dirty({
    double? value,
    this.minQuantity = 1.0,
    this.maxQuantity = double.infinity,
  }) : super.dirty(value);

  final double minQuantity;
  final double maxQuantity;

  @override
  String get label => 'Quantity to Split';

  @override
  String? get hintText => 'Enter quantity for new record';

  @override
  RecordFormInputError? validator(double? value) {
    if (value == null || value <= 0) {
      return const RecordFormInputError('Quantity must be greater than 0');
    }
    if (value < minQuantity) {
      return RecordFormInputError(
        'Quantity must be at least ${minQuantity.toStringAsFixed(0)}',
      );
    }
    if (value >= maxQuantity) {
      return RecordFormInputError(
        'Quantity must be less than ${maxQuantity.toStringAsFixed(0)}',
      );
    }
    return null;
  }

  @override
  SplitQuantityInput copyWith({required double? value}) {
    if (value == null) {
      return SplitQuantityInput.pure(
        minQuantity: minQuantity,
        maxQuantity: maxQuantity,
      );
    }
    if (value == this.value) return this;
    return SplitQuantityInput.dirty(
      value: value,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
    );
  }
}

/// Input for new record name
class SplitRecordNameInput
    extends RecordFormInput<String, RecordFormInputError, SplitRecordNameChanged> {
  const SplitRecordNameInput.pure({
    this.isRequired = true,
    this.existingNames = const <String>{},
  }) : super.pure();

  const SplitRecordNameInput.dirty({
    String? value,
    this.isRequired = true,
    this.existingNames = const <String>{},
  }) : super.dirty(value);

  final bool isRequired;
  final Set<String> existingNames;

  @override
  String get label => 'New Record Name';

  @override
  String? get hintText => 'Enter a unique name for the split record';

  @override
  RecordFormInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (isRequired && (trimmed == null || trimmed.isEmpty)) {
      return const RecordFormInputError('Record name is required');
    }
    if (trimmed != null && trimmed.length < 2) {
      return const RecordFormInputError('Name must be at least 2 characters');
    }
    if (trimmed != null && trimmed.length > 50) {
      return const RecordFormInputError('Name must be less than 50 characters');
    }
    if (trimmed != null &&
        existingNames.contains(trimmed.toLowerCase())) {
      return const RecordFormInputError(
        'This name is already in use. Please choose a unique name.',
      );
    }
    return null;
  }

  @override
  SplitRecordNameInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return SplitRecordNameInput.pure(
        isRequired: isRequired,
        existingNames: existingNames,
      );
    }
    return SplitRecordNameInput.dirty(
      value: value,
      isRequired: isRequired,
      existingNames: existingNames,
    );
  }
}

/// Input for split reason
class SplitReasonInput
    extends RecordFormInput<PhysicalFormChangeReason?, RecordFormInputError, SplitReasonChanged> {
  const SplitReasonInput.pure() : super.pure();
  const SplitReasonInput.dirty({PhysicalFormChangeReason? value}) : super.dirty(value);

  @override
  String get label => 'Reason';

  @override
  String? get hintText => 'Select a reason';

  @override
  RecordFormInputError? validator(PhysicalFormChangeReason? value) {
    if (value == null) {
      return const RecordFormInputError('Reason is required');
    }
    return null;
  }

  @override
  SplitReasonInput copyWith({required PhysicalFormChangeReason? value}) {
    return SplitReasonInput.dirty(value: value);
  }
}

/// Input for split notes
class SplitNotesInput
    extends RecordFormInput<String?, RecordFormInputError, SplitNotesChanged> {
  const SplitNotesInput.pure() : super.pure();
  const SplitNotesInput.dirty({String? value}) : super.dirty(value);

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Add optional notes';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Optional
  }

  @override
  SplitNotesInput copyWith({required String? value}) {
    return SplitNotesInput.dirty(value: value);
  }
}

/// Event for split quantity changes
class SplitQuantityChanged extends RecordFormInputEvent<double?> {
  const SplitQuantityChanged(super.value, {super.inputType});
}

/// Event for split record name changes
class SplitRecordNameChanged extends RecordFormInputEvent<String?> {
  const SplitRecordNameChanged(super.value, {super.inputType});
}

/// Event for split reason changes
class SplitReasonChanged extends RecordFormInputEvent<PhysicalFormChangeReason?> {
  const SplitReasonChanged(super.value, {super.inputType});
}

/// Event for split notes changes
class SplitNotesChanged extends RecordFormInputEvent<String?> {
  const SplitNotesChanged(super.value, {super.inputType});
}
