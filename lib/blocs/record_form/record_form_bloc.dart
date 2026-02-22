// @tier: community
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/services/logging_service.dart';

abstract class RecordFormBloc<T extends Record, S extends RecordFormState<T>> extends Cubit<S> {
  RecordFormBloc(super.initialState) {
    on<RecordFormInputEvent>(_onInputEvent);
    on<RecordFormReset>(_onReset);
    on<RecordFormNextStep>(_onNextStep);
    on<RecordFormPreviousStep>(_onPreviousStep);
    on<RecordFormSubmit>(_onSubmit);
    on<RecordFormInitializeForEdit>(_onInitializeForEdit);
    on<RecordFormInitialize>(_handleInitialize);
  }

  S get initialState;

  final List<_RecordFormHandlerEntry<S>> _handlers = [];

  @protected
  void on<E extends RecordFormEvent>(
    FutureOr<void> Function(E event, Emitter<S> emit) handler,
  ) {
    _handlers.add(
      _RecordFormHandlerEntry<S>(
        matches: (event) => event is E,
        handler: (event, emit) => handler(event as E, emit),
      ),
    );
  }

  void add(RecordFormEvent event) {
    onEvent(event);
    if (_handlers.isEmpty) return;
    final emitter = _RecordFormEmitter<S>(emit);
    // Find matching handlers - iterate in reverse order so subclass handlers
    // (registered last) take precedence over base class handlers
    for (int i = _handlers.length - 1; i >= 0; i--) {
      final entry = _handlers[i];
      if (!entry.matches(event)) {
        continue;
      }
      final result = entry.handler(event, emitter);
      if (result is Future) {
        unawaited(result);
      }
      // Only execute the first (most specific) matching handler
      break;
    }
  }

  void _handleInitialize(RecordFormInitialize event, Emitter<S> emit) {
    unawaited(onInitialize());
  }

  void _onInputEvent(RecordFormInputEvent event, Emitter<S> emit) {
    onInputEvent(event, emit);
  }

  @protected
  void onInputEvent(RecordFormInputEvent event, Emitter<S> emit) {
    final nextState = state.copyWithInputEvent(event) as S?;
    if (nextState != null) {
      emit(nextState);
    } else {
      LoggingService.instance.error(
        '[OnInputEvent] Input not found for event type: ${event.runtimeType}',
      );
    }
  }

  void _onReset(RecordFormReset event, Emitter<S> emit) {
    emit(initialState);
  }

  void _onNextStep(RecordFormNextStep event, Emitter<S> emit) {
    if (state.currentStepIndex < state.steps.length - 1) {
      emit(state.copyWith(currentStepIndex: state.currentStepIndex + 1) as S);
    }
  }

  void _onPreviousStep(RecordFormPreviousStep event, Emitter<S> emit) {
    if (state.currentStepIndex > 0) {
      emit(state.copyWith(currentStepIndex: state.currentStepIndex - 1) as S);
    }
  }

  void _onInitializeForEdit(
    RecordFormInitializeForEdit event,
    Emitter<S> emit,
  ) {
    emit(state.copyWith(originalRecord: event.originalRecord) as S);
  }

  Future<void> _onSubmit(RecordFormSubmit event, Emitter<S> emit) async {
    if (!state.isValid) {
      emit(
        state.copyWith(
              submissionStatus: FormzSubmissionStatus.failure,
              submissionError: state.validationErrorMessage,
            ) as S,
      );
      return;
    }
    emit(
      state.copyWith(
            submissionStatus: FormzSubmissionStatus.inProgress,
            submissionError: null,
            overrideSubmissionError: true,
          ) as S,
    );

    try {
      final createdRecord = await createRecord();
      if (emit.isDone) return;
      emit(
        state.copyWith(
              createdRecord: createdRecord,
              submissionStatus: FormzSubmissionStatus.success,
              submissionError: null,
              overrideSubmissionError: true,
            ) as S,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to create record', error, stackTrace);
      final domainError = ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: 'RecordFormBloc.onSubmit',
      );
      if (emit.isDone) return;
      emit(
        state.copyWith(
              submissionError: ErrorHandler.getDisplayMessage(domainError),
              submissionStatus: FormzSubmissionStatus.failure,
            ) as S,
      );
    }
  }

  Future<T?> createRecord();

  @protected
  Future<void> onInitialize() async {}

  @protected
  void onEvent(RecordFormEvent event) {}
}

class _RecordFormHandlerEntry<S> {
  const _RecordFormHandlerEntry({
    required this.matches,
    required this.handler,
  });

  final bool Function(RecordFormEvent event) matches;
  final FutureOr<void> Function(
    RecordFormEvent event,
    Emitter<S> emit,
  ) handler;
}

class _RecordFormEmitter<S> implements Emitter<S> {
  _RecordFormEmitter(this._emit);

  final void Function(S state) _emit;

  @override
  bool get isDone => false;

  @override
  void call(S state) {
    _emit(state);
  }

  @override
  Future<void> onEach<T>(
    Stream<T> stream, {
    required void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    final subscription = stream.listen(onData, onError: onError);
    try {
      await subscription.asFuture<void>();
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> forEach<T>(
    Stream<T> stream, {
    required S Function(T data) onData,
    S Function(Object error, StackTrace stackTrace)? onError,
  }) {
    return onEach<T>(
      stream,
      onData: (data) => call(onData(data)),
      onError: onError != null
          ? (Object error, StackTrace stackTrace) {
              call(onError(error, stackTrace));
            }
          : null,
    );
  }
}
