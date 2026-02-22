// @tier: community
import 'dart:async';

import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/services/logging_service.dart';

enum RecordFormLoadStatus { initial, loading, success, failure }

abstract class AsyncRecordFormState<T extends Record>
    extends RecordFormState<T> {
  AsyncRecordFormState({
    required super.steps,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
    this.loadStatus = RecordFormLoadStatus.initial,
    this.loadError,
  });

  final RecordFormLoadStatus loadStatus;
  final String? loadError;

  AsyncRecordFormState<T> copyWithLoad({
    RecordFormLoadStatus? loadStatus,
    String? loadError,
  });
}

abstract class AsyncRecordFormBlocBase {
  void initialize();
}

abstract class AsyncRecordFormBloc<T extends Record,
    S extends AsyncRecordFormState<T>> extends RecordFormBloc<T, S>
    implements AsyncRecordFormBlocBase {
  AsyncRecordFormBloc(super.initialState);

  final LoggingService _logger = LoggingService.instance;
  bool _hasRequestedInitialization = false;

  Future<S> loadInitialData();

  @override
  void initialize() {
    if (_hasRequestedInitialization) return;
    _hasRequestedInitialization = true;
    add(const RecordFormInitialize());
  }

  @override
  Future<void> onInitialize() async {
    emit(
      state.copyWithLoad(
        loadStatus: RecordFormLoadStatus.loading,
        loadError: null,
      ) as S,
    );

    try {
      // Add timeout to prevent indefinite loading
      final loadedState = await loadInitialData().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.warning(
            'AsyncRecordFormBloc: loadInitialData() timed out after 10s',
          );
          throw TimeoutException(
            'Form initialization timed out',
            const Duration(seconds: 10),
          );
        },
      );
      emit(
        loadedState.copyWithLoad(
          loadStatus: RecordFormLoadStatus.success,
          loadError: null,
        ) as S,
      );
    } on TimeoutException catch (error, stackTrace) {
      _logger.error(
        'Form initialization timed out',
        error,
        stackTrace,
      );
      emit(
        state.copyWithLoad(
          loadStatus: RecordFormLoadStatus.failure,
          loadError: 'Loading timed out. Please try again.',
        ) as S,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load form initialization data',
        error,
        stackTrace,
      );
      final domainError = ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: 'AsyncRecordFormBloc._onInitialize',
      );
      emit(
        state.copyWithLoad(
          loadStatus: RecordFormLoadStatus.failure,
          loadError: ErrorHandler.getDisplayMessage(domainError),
        ) as S,
      );
    }
    // Note: _hasRequestedInitialization is intentionally NOT reset here.
    // The flag prevents multiple initialization attempts. Once initialize()
    // is called, we don't want it called again - the user should close and
    // reopen the form to retry initialization.
  }
}
