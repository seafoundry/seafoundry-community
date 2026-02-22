// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/models/events/gene_bank_temperature_monitoring_event.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class GeneBankTemperatureMonitoringState extends Equatable {
  const GeneBankTemperatureMonitoringState({
    this.temperatureCelsius,
    this.isWithinRange = true,
    this.minTemperature,
    this.maxTemperature,
    this.measurementLocation,
    this.comment = '',
    this.isLoading = false,
    this.isEditing = false,
    this.errorMessage,
    this.createdEvent,
  });

  final double? temperatureCelsius;
  final bool isWithinRange;
  final double? minTemperature;
  final double? maxTemperature;
  final String? measurementLocation;
  final String comment;
  final bool isLoading;
  final bool isEditing;
  final String? errorMessage;
  final GeneBankTemperatureMonitoringEvent? createdEvent;

  bool get canSubmit => !isLoading && temperatureCelsius != null;

  GeneBankTemperatureMonitoringState copyWith({
    double? temperatureCelsius,
    bool? isWithinRange,
    double? minTemperature,
    double? maxTemperature,
    String? measurementLocation,
    String? comment,
    bool? isLoading,
    bool? isEditing,
    String? errorMessage,
    GeneBankTemperatureMonitoringEvent? createdEvent,
    bool clearErrorMessage = false,
    bool clearCreatedEvent = false,
  }) {
    return GeneBankTemperatureMonitoringState(
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      isWithinRange: isWithinRange ?? this.isWithinRange,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      measurementLocation: measurementLocation ?? this.measurementLocation,
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
    temperatureCelsius,
    isWithinRange,
    minTemperature,
    maxTemperature,
    measurementLocation,
    comment,
    isLoading,
    isEditing,
    errorMessage,
    createdEvent,
  ];
}

class GeneBankTemperatureMonitoringCubit
    extends Cubit<GeneBankTemperatureMonitoringState> {
  GeneBankTemperatureMonitoringCubit({
    required this.eventRepository,
    required this.targetNode,
    GeneBankTemperatureMonitoringEvent? existingEvent,
  }) : _existingEvent = existingEvent,
       super(
         GeneBankTemperatureMonitoringState(
           isEditing: existingEvent != null,
           temperatureCelsius: existingEvent?.temperatureCelsius,
           isWithinRange: existingEvent?.isWithinRange ?? true,
           minTemperature: existingEvent?.minTemperature,
           maxTemperature: existingEvent?.maxTemperature,
           measurementLocation: existingEvent?.measurementLocation,
           comment: existingEvent?.comment ?? '',
         ),
       );

  final EventRepository eventRepository;
  final GraphNode targetNode;
  final GeneBankTemperatureMonitoringEvent? _existingEvent;

  Future<GraphNodeRecord> _resolveTargetRecord() async {
    try {
      await targetNode.awaitLoaded().timeout(const Duration(seconds: 5));
    } catch (_) {
      // If load fails or times out, fall back to current record
    }
    return targetNode.state.record;
  }

  void temperatureChanged(double? value) {
    emit(state.copyWith(temperatureCelsius: value, clearErrorMessage: true));
  }

  void minTemperatureChanged(double? value) {
    emit(state.copyWith(minTemperature: value, clearErrorMessage: true));
  }

  void maxTemperatureChanged(double? value) {
    emit(state.copyWith(maxTemperature: value, clearErrorMessage: true));
  }

  void withinRangeChanged(bool value) {
    emit(state.copyWith(isWithinRange: value, clearErrorMessage: true));
  }

  void locationChanged(String? value) {
    emit(
      state.copyWith(
        measurementLocation: value?.isEmpty == true ? null : value,
        clearErrorMessage: true,
      ),
    );
  }

  void commentChanged(String value) {
    emit(state.copyWith(comment: value, clearErrorMessage: true));
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      emit(state.copyWith(errorMessage: 'Temperature is required.'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final record = await _resolveTargetRecord();

      if (state.isEditing && _existingEvent != null) {
        final updatedEvent = _existingEvent.copyWith(
          temperatureCelsius: state.temperatureCelsius,
          isWithinRange: state.isWithinRange,
          minTemperature: state.minTemperature,
          maxTemperature: state.maxTemperature,
          measurementLocation: state.measurementLocation,
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

      final event = GeneBankTemperatureMonitoringEvent.partial(
        eventTypeId: GeneBankEventType.temperatureMonitoringId,
        temperatureCelsius: state.temperatureCelsius,
        isWithinRange: state.isWithinRange,
        minTemperature: state.minTemperature,
        maxTemperature: state.maxTemperature,
        measurementLocation: state.measurementLocation,
        comment: state.comment.isEmpty ? null : state.comment,
        recordId: record.id,
        recordModelType: record.modelType,
        urlPath: record.urlPath,
        internalPath: record.internalPath,
      );

      final createdEvent =
          await eventRepository.createEvent(event)
              as GeneBankTemperatureMonitoringEvent;

      if (!targetNode.isClosed) {
        targetNode.add(const GraphNodeReloadRequested());
      }

      emit(state.copyWith(isLoading: false, createdEvent: createdEvent));
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error('Firebase error saving temperature reading: ${e.message}', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to save temperature reading: ${e.message}',
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error saving temperature reading', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to save temperature reading: ${e.toString()}',
        ),
      );
    }
  }
}
