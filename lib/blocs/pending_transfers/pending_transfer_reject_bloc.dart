// @tier: community
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/cubits/pending_transfers/pending_transfers_cubit.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';

class PendingTransferRejectBloc
    extends RecordFormBloc<TransferEvent, PendingTransferRejectState> {
  PendingTransferRejectBloc({
    required this.entry,
    required PendingTransfersCubit pendingTransfersCubit,
  }) : _pendingTransfersCubit = pendingTransfersCubit,
       super(PendingTransferRejectState.initial(entry: entry));

  final PendingTransferEntry entry;
  final PendingTransfersCubit _pendingTransfersCubit;

  @override
  PendingTransferRejectState get initialState =>
      PendingTransferRejectState.initial(entry: entry);

  @override
  Future<TransferEvent?> createRecord() async {
    final reason = state.reason.value?.trim();

    await _pendingTransfersCubit.rejectTransfer(entry: entry, reason: reason);

    return null;
  }
}

class PendingTransferRejectState extends RecordFormState<TransferEvent> {
  PendingTransferRejectState({
    required this.entry,
    List<RecordFormStep>? steps,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  }) : super(steps: steps ?? [PendingTransferRejectStep(entry: entry)]);

  factory PendingTransferRejectState.initial({
    required PendingTransferEntry entry,
  }) {
    return PendingTransferRejectState(entry: entry);
  }

  final PendingTransferEntry entry;

  PendingTransferRejectStep get rejectStep =>
      steps[currentStepIndex] as PendingTransferRejectStep;

  PendingTransferRejectReasonInput get reason => rejectStep.reason;

  @override
  PendingTransferRejectState copyWith({
    List<RecordFormStep>? steps,
    int? currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    TransferEvent? createdRecord,
    TransferEvent? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return PendingTransferRejectState(
      entry: entry,
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
    );
  }
}

class PendingTransferRejectStep extends RecordFormStep {
  PendingTransferRejectStep({
    required this.entry,
    List<RecordFormInput>? inputs,
  }) : super(
         title: 'Reject Transfer',
         inputs: inputs ?? const [PendingTransferRejectReasonInput.pure()],
       );

  final PendingTransferEntry entry;

  PendingTransferRejectReasonInput get reason =>
      inputs.whereType<PendingTransferRejectReasonInput>().first;

  @override
  PendingTransferRejectStep copyWith({required RecordFormInput copiedInput}) {
    return PendingTransferRejectStep(
      entry: entry,
      inputs: updateInputs(copiedInput),
    );
  }
}

class PendingTransferRejectReasonChanged extends RecordFormInputEvent<String?> {
  const PendingTransferRejectReasonChanged(super.value);
}

class PendingTransferRejectReasonInput
    extends
        RecordFormInput<
          String,
          RecordFormInputError,
          PendingTransferRejectReasonChanged
        > {
  const PendingTransferRejectReasonInput.pure() : super.pure();
  PendingTransferRejectReasonInput.dirty(String? value)
    : super.dirty(value?.trim());

  @override
  String get label => 'Rejection reason (optional)';

  @override
  String? get hintText => 'Provide context for the sending organization';

  @override
  RecordFormInputError? validator(String? value) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.length > 250) {
      return const RecordFormInputError('Reason must be under 250 characters');
    }
    return null;
  }

  @override
  PendingTransferRejectReasonInput copyWith({required String? value}) {
    final trimmed = value?.trim();
    if (trimmed == this.value) return this;
    if (trimmed == null || trimmed.isEmpty) {
      return const PendingTransferRejectReasonInput.pure();
    }
    return PendingTransferRejectReasonInput.dirty(trimmed);
  }
}
