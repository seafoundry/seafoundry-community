// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/models/events/gene_bank_viability_test_event.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class GeneBankViabilityTestState extends Equatable {
  const GeneBankViabilityTestState({
    this.testType = 'visual',
    this.viabilityPercentage,
    this.samplesTested,
    this.result,
    this.testNotes,
    this.comment = '',
    this.isLoading = false,
    this.isEditing = false,
    this.errorMessage,
    this.createdEvent,
  });

  final String testType;
  final double? viabilityPercentage;
  final int? samplesTested;
  final String? result;
  final String? testNotes;
  final String comment;
  final bool isLoading;
  final bool isEditing;
  final String? errorMessage;
  final GeneBankViabilityTestEvent? createdEvent;

  bool get canSubmit => !isLoading && testType.trim().isNotEmpty;

  GeneBankViabilityTestState copyWith({
    String? testType,
    double? viabilityPercentage,
    int? samplesTested,
    String? result,
    String? testNotes,
    String? comment,
    bool? isLoading,
    bool? isEditing,
    String? errorMessage,
    GeneBankViabilityTestEvent? createdEvent,
    bool clearErrorMessage = false,
    bool clearCreatedEvent = false,
  }) {
    return GeneBankViabilityTestState(
      testType: testType ?? this.testType,
      viabilityPercentage: viabilityPercentage ?? this.viabilityPercentage,
      samplesTested: samplesTested ?? this.samplesTested,
      result: result ?? this.result,
      testNotes: testNotes ?? this.testNotes,
      comment: comment ?? this.comment,
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      createdEvent: clearCreatedEvent
          ? null
          : (createdEvent ?? this.createdEvent),
    );
  }

  @override
  List<Object?> get props => [
    testType,
    viabilityPercentage,
    samplesTested,
    result,
    testNotes,
    comment,
    isLoading,
    isEditing,
    errorMessage,
    createdEvent,
  ];
}

class GeneBankViabilityTestCubit extends Cubit<GeneBankViabilityTestState> {
  GeneBankViabilityTestCubit({
    required this.eventRepository,
    required this.targetNode,
    GeneBankViabilityTestEvent? existingEvent,
  }) : _existingEvent = existingEvent,
       super(
         GeneBankViabilityTestState(
           isEditing: existingEvent != null,
           testType: existingEvent?.testType ?? 'visual',
           viabilityPercentage: existingEvent?.viabilityPercentage,
           samplesTested: existingEvent?.samplesTested,
           result: existingEvent?.result,
           testNotes: existingEvent?.testNotes,
           comment: existingEvent?.comment ?? '',
         ),
       );

  final EventRepository eventRepository;
  final GraphNode targetNode;
  final GeneBankViabilityTestEvent? _existingEvent;

  Future<GraphNodeRecord> _resolveTargetRecord() async {
    try {
      await targetNode.awaitLoaded().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fall back to current record if load fails or times out
    }
    return targetNode.state.record;
  }

  void testTypeChanged(String value) {
    emit(state.copyWith(testType: value.trim(), clearErrorMessage: true));
  }

  void viabilityChanged(double? value) {
    emit(state.copyWith(viabilityPercentage: value, clearErrorMessage: true));
  }

  void samplesTestedChanged(int? value) {
    emit(state.copyWith(samplesTested: value, clearErrorMessage: true));
  }

  void resultChanged(String? value) {
    emit(state.copyWith(result: value, clearErrorMessage: true));
  }

  void notesChanged(String? value) {
    emit(state.copyWith(testNotes: value, clearErrorMessage: true));
  }

  void commentChanged(String value) {
    emit(state.copyWith(comment: value, clearErrorMessage: true));
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      emit(state.copyWith(errorMessage: 'Test type is required.'));
      return;
    }

    if (state.viabilityPercentage != null &&
        (state.viabilityPercentage! < 0 || state.viabilityPercentage! > 100)) {
      emit(
        state.copyWith(
          errorMessage: 'Viability percentage must be between 0 and 100.',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final record = await _resolveTargetRecord();

      if (state.isEditing && _existingEvent != null) {
        final updatedEvent = _existingEvent.copyWith(
          testType: state.testType,
          viabilityPercentage: state.viabilityPercentage,
          samplesTested: state.samplesTested,
          result: state.result,
          testNotes: state.testNotes,
          comment: state.comment.isEmpty ? null : state.comment,
          updatedAt: DateTime.now().toIso8601String(),
          updatedById: eventRepository.user.id,
        );

        final enrichedEvent =
            eventRepository.withOrganismMetadata(updatedEvent);

        await eventRepository.collectionRef
            .doc(enrichedEvent.id)
            .update(enrichedEvent.toJson());

        if (!targetNode.isClosed) {
          targetNode.add(const GraphNodeReloadRequested());
        }

        emit(state.copyWith(isLoading: false, createdEvent: enrichedEvent));
        return;
      }

      final event = GeneBankViabilityTestEvent.partial(
        eventTypeId: GeneBankEventType.viabilityTestId,
        testType: state.testType,
        viabilityPercentage: state.viabilityPercentage,
        samplesTested: state.samplesTested,
        result: state.result,
        testNotes: state.testNotes,
        comment: state.comment.isEmpty ? null : state.comment,
        recordId: record.id,
        recordModelType: record.modelType,
        urlPath: record.urlPath,
        internalPath: record.internalPath,
      );

      final createdEvent =
          await eventRepository.createEvent(event)
              as GeneBankViabilityTestEvent;

      if (!targetNode.isClosed) {
        targetNode.add(const GraphNodeReloadRequested());
      }

      emit(state.copyWith(isLoading: false, createdEvent: createdEvent));
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error('Firebase error saving viability test: ${e.message}', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to save viability test: ${e.message}',
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error saving viability test', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to save viability test: ${e.toString()}',
        ),
      );
    }
  }
}
