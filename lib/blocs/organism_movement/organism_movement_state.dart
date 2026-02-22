// @tier: community
import 'package:collection/collection.dart';
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_async.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';

class OrganismMovementState extends AsyncRecordFormState<OrganismRecord> {
  OrganismMovementState({
    required super.steps,
    this.sourceGroup,
    this.availableGroups = const <Group>[],
    this.availableOrganisms = const <OrganismRecord>[],
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    super.loadStatus,
    super.loadError,
  });

  final Group? sourceGroup;
  final List<Group> availableGroups;
  final List<OrganismRecord> availableOrganisms;

  RecordIdSetInput get selectedOrganismIds =>
      inputs.firstWhereOrNull((input) => input is RecordIdSetInput)
          as RecordIdSetInput? ??
      const RecordIdSetInput.pure();

  QuantityMapInput get selectedQuantities =>
      inputs.firstWhereOrNull((input) => input is QuantityMapInput)
          as QuantityMapInput? ??
      const QuantityMapInput.pure();

  TargetGroupInput get targetGroupInput =>
      inputs.firstWhereOrNull((input) => input is TargetGroupInput)
          as TargetGroupInput? ??
      const TargetGroupInput.pure();

  String? get targetGroupId => targetGroupInput.value;

  @override
  OrganismMovementState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    OrganismRecord? createdRecord,
    OrganismRecord? originalRecord,
    RecordFormLoadStatus? loadStatus,
    String? loadError,
    Group? sourceGroup,
    List<Group>? availableGroups,
    List<OrganismRecord>? availableOrganisms,
    bool overrideSubmissionError = false,
  }) {
    return OrganismMovementState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      loadStatus: loadStatus ?? this.loadStatus,
      loadError: loadError ?? this.loadError,
      sourceGroup: sourceGroup ?? this.sourceGroup,
      availableGroups: availableGroups ?? this.availableGroups,
      availableOrganisms: availableOrganisms ?? this.availableOrganisms,
    );
  }

  @override
  OrganismMovementState copyWithLoad({
    RecordFormLoadStatus? loadStatus,
    String? loadError,
  }) {
    return copyWith(loadStatus: loadStatus, loadError: loadError);
  }
}

class TargetGroupInput
    extends RecordFormInput<String, RecordFormInputError, TargetGroupChanged> {
  const TargetGroupInput.pure({this.isRequired = false}) : super.pure();

  const TargetGroupInput.dirty({
    String? value,
    this.isRequired = false,
  }) : super.dirty(value);

  final bool isRequired;

  @override
  String get label => 'Target Group';

  @override
  String? get hintText => 'Select a target group';

  @override
  RecordFormInputError? validator(String? value) {
    if (isRequired && (value == null || value.isEmpty)) {
      return const RecordFormInputError('Select a target group');
    }
    return null;
  }

  @override
  TargetGroupInput copyWith({required String? value}) {
    if (value == null) {
      return TargetGroupInput.pure(isRequired: isRequired);
    }
    if (value == this.value) return this;
    return TargetGroupInput.dirty(value: value, isRequired: isRequired);
  }
}
