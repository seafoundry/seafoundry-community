// @tier: community
import 'package:collection/collection.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';

class OrganismMergeState extends AsyncRecordFormState<OrganismRecord> {
  OrganismMergeState({
    required super.steps,
    this.availableOrganisms = const <OrganismRecord>[],
    this.eligibilityErrors = const <String, String>{},
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    super.loadStatus,
    super.loadError,
  });

  /// All organisms available for merging from the current group
  final List<OrganismRecord> availableOrganisms;

  /// Map of organism ID to eligibility error (if any)
  /// Empty string means eligible
  final Map<String, String> eligibilityErrors;

  /// Selected organism IDs (including target)
  MergeRecordSelectionInput get selectionInput =>
      inputs.firstWhereOrNull((input) => input is MergeRecordSelectionInput)
          as MergeRecordSelectionInput? ??
      const MergeRecordSelectionInput.pure();

  Set<String> get selectedOrganismIds => selectionInput.value ?? const <String>{};

  /// The target organism ID that will absorb others
  MergeTargetInput get targetInput =>
      inputs.firstWhereOrNull((input) => input is MergeTargetInput)
          as MergeTargetInput? ??
      const MergeTargetInput.pure();

  String? get targetOrganismId => targetInput.value;

  /// The record name for the merged organism (can be edited)
  MergeRecordNameInput get recordNameInput =>
      inputs.firstWhereOrNull((input) => input is MergeRecordNameInput)
          as MergeRecordNameInput? ??
      const MergeRecordNameInput.pure();

  String? get mergedRecordName => recordNameInput.value;

  MergeReasonInput get mergeReasonInput =>
      inputs.firstWhereOrNull((input) => input is MergeReasonInput)
          as MergeReasonInput? ??
      const MergeReasonInput.pure();

  PhysicalFormChangeReason? get mergeReason => mergeReasonInput.value;

  MergeNotesInput get mergeNotesInput =>
      inputs.firstWhereOrNull((input) => input is MergeNotesInput)
          as MergeNotesInput? ??
      const MergeNotesInput.pure();

  String? get mergeNotes => mergeNotesInput.value;

  /// Get the target organism record
  OrganismRecord? get targetOrganism => targetOrganismId == null
      ? null
      : availableOrganisms.firstWhereOrNull((o) => o.id == targetOrganismId);

  /// Get the organisms that will be absorbed (selected minus target)
  List<OrganismRecord> get absorbedOrganisms => availableOrganisms
      .where((o) =>
          selectedOrganismIds.contains(o.id) && o.id != targetOrganismId)
      .toList();

  /// Get selected organisms (all)
  List<OrganismRecord> get selectedOrganisms => availableOrganisms
      .where((o) => selectedOrganismIds.contains(o.id))
      .toList();

  /// Calculate total quantity after merge
  double get totalQuantityAfterMerge {
    return selectedOrganisms.fold<double>(
      0.0,
      (sum, o) => sum + o.measurement.value,
    );
  }

  /// Check if an organism is eligible for merging with the current selection
  bool isOrganismEligible(OrganismRecord organism) {
    return !eligibilityErrors.containsKey(organism.id) ||
        eligibilityErrors[organism.id]?.isEmpty == true;
  }

  @override
  OrganismMergeState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    OrganismRecord? createdRecord,
    OrganismRecord? originalRecord,
    RecordFormLoadStatus? loadStatus,
    String? loadError,
    List<OrganismRecord>? availableOrganisms,
    Map<String, String>? eligibilityErrors,
    bool overrideSubmissionError = false,
  }) {
    return OrganismMergeState(
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
      availableOrganisms: availableOrganisms ?? this.availableOrganisms,
      eligibilityErrors: eligibilityErrors ?? this.eligibilityErrors,
    );
  }

  @override
  OrganismMergeState copyWithLoad({
    RecordFormLoadStatus? loadStatus,
    String? loadError,
  }) {
    return copyWith(loadStatus: loadStatus, loadError: loadError);
  }
}

/// Input for selecting records to merge
class MergeRecordSelectionInput
    extends RecordFormInput<Set<String>, RecordFormInputError, MergeRecordSelectionChanged> {
  const MergeRecordSelectionInput.pure({
    this.minSelection = 2,
  }) : super.pure();

  const MergeRecordSelectionInput.dirty({
    Set<String>? value,
    this.minSelection = 2,
  }) : super.dirty(value ?? const <String>{});

  final int minSelection;

  @override
  String get label => 'Records to Merge';

  @override
  String? get hintText => 'Select at least 2 records to merge';

  @override
  RecordFormInputError? validator(Set<String>? value) {
    if (value == null || value.length < minSelection) {
      return RecordFormInputError(
        'Select at least $minSelection records to merge',
      );
    }
    return null;
  }

  @override
  MergeRecordSelectionInput copyWith({required Set<String>? value}) {
    if (value == null || value.isEmpty) {
      return MergeRecordSelectionInput.pure(minSelection: minSelection);
    }
    return MergeRecordSelectionInput.dirty(
      value: value,
      minSelection: minSelection,
    );
  }
}

/// Input for selecting the target organism
class MergeTargetInput
    extends RecordFormInput<String, RecordFormInputError, MergeTargetChanged> {
  const MergeTargetInput.pure({
    this.validTargetIds = const <String>{},
  }) : super.pure();

  const MergeTargetInput.dirty({
    String? value,
    this.validTargetIds = const <String>{},
  }) : super.dirty(value);

  final Set<String> validTargetIds;

  @override
  String get label => 'Target Record';

  @override
  String? get hintText => 'Select the record that will absorb others';

  @override
  RecordFormInputError? validator(String? value) {
    if (value == null || value.isEmpty) {
      return const RecordFormInputError('Select a target record');
    }
    if (validTargetIds.isNotEmpty && !validTargetIds.contains(value)) {
      return const RecordFormInputError('Target must be one of the selected records');
    }
    return null;
  }

  @override
  MergeTargetInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return MergeTargetInput.pure(validTargetIds: validTargetIds);
    }
    return MergeTargetInput.dirty(
      value: value,
      validTargetIds: validTargetIds,
    );
  }
}

/// Input for the merged record name
class MergeRecordNameInput
    extends RecordFormInput<String, RecordFormInputError, MergeRecordNameChanged> {
  const MergeRecordNameInput.pure({
    this.existingNames = const <String>{},
  }) : super.pure();

  const MergeRecordNameInput.dirty({
    String? value,
    this.existingNames = const <String>{},
  }) : super.dirty(value);

  final Set<String> existingNames;

  @override
  String get label => 'Merged Record Name';

  @override
  String? get hintText => 'Name for the merged record';

  @override
  RecordFormInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const RecordFormInputError('Record name is required');
    }
    if (trimmed.length < 2) {
      return const RecordFormInputError('Name must be at least 2 characters');
    }
    if (trimmed.length > 50) {
      return const RecordFormInputError('Name must be less than 50 characters');
    }
    // Don't check against existingNames if it's the current target's name
    // (handled by excluding from the set in bloc)
    if (existingNames.contains(trimmed.toLowerCase())) {
      return const RecordFormInputError(
        'This name is already in use. Please choose a unique name.',
      );
    }
    return null;
  }

  @override
  MergeRecordNameInput copyWith({required String? value}) {
    if (value == null || value.isEmpty) {
      return MergeRecordNameInput.pure(existingNames: existingNames);
    }
    return MergeRecordNameInput.dirty(
      value: value,
      existingNames: existingNames,
    );
  }
}

/// Input for merge reason
class MergeReasonInput
    extends RecordFormInput<PhysicalFormChangeReason?, RecordFormInputError, MergeReasonChanged> {
  const MergeReasonInput.pure() : super.pure();
  const MergeReasonInput.dirty({PhysicalFormChangeReason? value}) : super.dirty(value);

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
  MergeReasonInput copyWith({required PhysicalFormChangeReason? value}) {
    return MergeReasonInput.dirty(value: value);
  }
}

/// Input for merge notes
class MergeNotesInput
    extends RecordFormInput<String?, RecordFormInputError, MergeNotesChanged> {
  const MergeNotesInput.pure() : super.pure();
  const MergeNotesInput.dirty({String? value}) : super.dirty(value);

  @override
  String get label => 'Notes';

  @override
  String? get hintText => 'Add optional notes';

  @override
  RecordFormInputError? validator(String? value) {
    return null; // Optional
  }

  @override
  MergeNotesInput copyWith({required String? value}) {
    return MergeNotesInput.dirty(value: value);
  }
}

/// Event for merge record selection changes
class MergeRecordSelectionChanged extends RecordFormInputEvent<Set<String>> {
  const MergeRecordSelectionChanged(super.value, {super.inputType});
}

/// Event for merge target changes
class MergeTargetChanged extends RecordFormInputEvent<String?> {
  const MergeTargetChanged(super.value, {super.inputType});
}

/// Event for merged record name changes
class MergeRecordNameChanged extends RecordFormInputEvent<String?> {
  const MergeRecordNameChanged(super.value, {super.inputType});
}

/// Event for merge reason changes
class MergeReasonChanged extends RecordFormInputEvent<PhysicalFormChangeReason?> {
  const MergeReasonChanged(super.value, {super.inputType});
}

/// Event for merge notes changes
class MergeNotesChanged extends RecordFormInputEvent<String?> {
  const MergeNotesChanged(super.value, {super.inputType});
}
