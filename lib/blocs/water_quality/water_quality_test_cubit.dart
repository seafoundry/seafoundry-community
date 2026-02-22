// @tier: community
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/models/events/event.dart' show EventBaseParams;
import 'package:seafoundry_app/models/events/event_permit_metadata.dart';
import 'package:seafoundry_app/models/events/water_quality_test_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/water_quality_parameter.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/activity_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

const Object _unset = Object();

class WaterQualityTestState extends Equatable {
  const WaterQualityTestState({
    this.comment = '',
    this.selectedParameterIds = const [],
    this.parameterValues = const {},
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.isLoading = false,
    this.isEditing = false,
    this.errorMessage,
    this.createdEvent,
  });

  final String comment;
  final List<String> selectedParameterIds;
  final Map<String, double> parameterValues;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final bool isLoading;
  final bool isEditing;
  final String? errorMessage;
  final WaterQualityTestEvent? createdEvent;

  bool get hasParameters => parameterValues.isNotEmpty;
  bool get canSubmit => !isLoading && hasParameters;

  WaterQualityTestState copyWith({
    String? comment,
    List<String>? selectedParameterIds,
    Map<String, double>? parameterValues,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    Object? permitValidFrom = _unset,
    Object? permitValidTo = _unset,
    bool? isLoading,
    bool? isEditing,
    String? errorMessage,
    WaterQualityTestEvent? createdEvent,
    bool clearErrorMessage = false,
    bool clearCreatedEvent = false,
  }) {
    return WaterQualityTestState(
      comment: comment ?? this.comment,
      selectedParameterIds: selectedParameterIds ?? this.selectedParameterIds,
      parameterValues: parameterValues ?? this.parameterValues,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: identical(permitValidFrom, _unset)
          ? this.permitValidFrom
          : permitValidFrom as DateTime?,
      permitValidTo: identical(permitValidTo, _unset)
          ? this.permitValidTo
          : permitValidTo as DateTime?,
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
    comment,
    selectedParameterIds,
    parameterValues,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    isLoading,
    isEditing,
    errorMessage,
    createdEvent,
  ];
}

class WaterQualityTestCubit extends Cubit<WaterQualityTestState> {
  WaterQualityTestCubit({
    required this.eventRepository,
    required this.targetNode,
    WaterQualityTestEvent? existingTest,
  }) : _existingTest = existingTest,
       super(
         WaterQualityTestState(
           isEditing: existingTest != null,
           comment: existingTest?.comment ?? '',
           selectedParameterIds: existingTest != null
               ? existingTest.parameterValues.keys.toList()
               : [
                   WaterQualityParameter.temperature.id,
                   WaterQualityParameter.pH.id,
                   WaterQualityParameter.salinity.id,
                 ],
           parameterValues: existingTest?.parameterValues ?? {},
            permitId: existingTest?.permitMetadata.permitId ?? '',
            permitType: existingTest?.permitMetadata.permitType ?? '',
            issuingAuthority:
                existingTest?.permitMetadata.issuingAuthority ?? '',
            permitAttachmentUrls: existingTest == null
                ? ''
                : existingTest.permitMetadata.attachmentUrls.isEmpty
                    ? ''
                    : existingTest.permitMetadata.attachmentUrls.join('\n'),
            permitValidFrom: existingTest?.permitMetadata.validFrom,
            permitValidTo: existingTest?.permitMetadata.validTo,
         ),
       );

  final EventRepository eventRepository;
  final GraphNode targetNode;
  final WaterQualityTestEvent? _existingTest;

  void commentChanged(String value) {
    emit(state.copyWith(comment: value, clearErrorMessage: true));
  }

  void addParameter(String parameterId) {
    if (!state.selectedParameterIds.contains(parameterId)) {
      emit(
        state.copyWith(
          selectedParameterIds: [...state.selectedParameterIds, parameterId],
          clearErrorMessage: true,
        ),
      );
    }
  }

  void removeParameter(String parameterId) {
    final newParameterIds = state.selectedParameterIds
        .where((id) => id != parameterId)
        .toList();
    final newValues = Map<String, double>.from(state.parameterValues);
    newValues.remove(parameterId);

    emit(
      state.copyWith(
        selectedParameterIds: newParameterIds,
        parameterValues: newValues,
        clearErrorMessage: true,
      ),
    );
  }

  void parameterValueChanged(String parameterId, double? value) {
    if (value == null) {
      final newValues = Map<String, double>.from(state.parameterValues);
      newValues.remove(parameterId);
      emit(state.copyWith(parameterValues: newValues, clearErrorMessage: true));
    } else {
      final newValues = Map<String, double>.from(state.parameterValues);
      newValues[parameterId] = value;
      emit(state.copyWith(parameterValues: newValues, clearErrorMessage: true));
    }
  }

  void permitIdChanged(String value) {
    emit(state.copyWith(permitId: value));
  }

  void permitTypeChanged(String value) {
    emit(state.copyWith(permitType: value));
  }

  void issuingAuthorityChanged(String value) {
    emit(state.copyWith(issuingAuthority: value));
  }

  void permitAttachmentUrlsChanged(String value) {
    emit(state.copyWith(permitAttachmentUrls: value));
  }

  void permitValidFromChanged(DateTime? value) {
    emit(state.copyWith(permitValidFrom: value));
  }

  void permitValidToChanged(DateTime? value) {
    emit(state.copyWith(permitValidTo: value));
  }

  Future<void> submit({
    required List<GraphNode> targetNodes,
    Function(WaterQualityTestEvent)? onSuccess,
    Function(String)? onError,
  }) async {
    if (!state.canSubmit) {
      final error = 'Please enter at least one parameter value';
      emit(state.copyWith(errorMessage: error));
      onError?.call(error);
      return;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final permitMetadata = _buildPermitMetadata();
      if (state.isEditing && _existingTest != null) {
        // Update existing test
        final updatedEvent = _existingTest.copyWith(
          parameterValues: Map<String, double>.from(state.parameterValues),
          comment: state.comment.isNotEmpty ? state.comment : null,
          permitMetadata: permitMetadata,
        );

        final enrichedEvent =
            eventRepository.withOrganismMetadata(updatedEvent);

        await eventRepository.collectionRef
            .doc(enrichedEvent.id)
            .update(enrichedEvent.toJson());

        targetNode.add(const GraphNodeReloadRequested());

        LoggingService.instance.info(
          'Water quality test updated: ${updatedEvent.id}',
        );

        emit(state.copyWith(isLoading: false, createdEvent: enrichedEvent));
        onSuccess?.call(enrichedEvent);
      } else {
        // Create a single parent event and reference it for targets.
        final activeTargets =
            targetNodes.where((node) => !node.isClosed).toList();
        if (activeTargets.isEmpty) {
          throw Exception('Failed to create water quality test');
        }

        final primaryNode = activeTargets.first;
        await primaryNode.awaitLoaded();
        final nodeState = primaryNode.state;
        if (nodeState is! GraphLoadedState) {
          throw Exception('Failed to load water quality test target');
        }
        final record = nodeState.record;

        final eventId = generateId(firestore: eventRepository.db);
        final eventSlug = await eventRepository.nextSlugForModelType(
          ModelType.event,
        );

        final now = DateTime.now().toIso8601String();

        final newEvent = WaterQualityTestEvent(
          id: eventId,
          parameterValues: Map<String, double>.from(state.parameterValues),
          comment: state.comment.isNotEmpty ? state.comment : null,
          base: EventBaseParams(
            permitMetadata: permitMetadata,
          ),
          createdById: eventRepository.user.id,
          createdAt: now,
          updatedAt: now,
          updatedById: eventRepository.user.id,
          organizationId: eventRepository.organization.id,
          recordId: record.id,
          recordModelType: record.modelType,
          urlPath: '${record.urlPath}/$eventSlug',
          internalPath: '${record.internalPath}/$eventId',
          slug: eventSlug,
        );

        final enrichedEvent = eventRepository.withOrganismMetadata(newEvent);

        await eventRepository.collectionRef
            .doc(eventId)
            .set(enrichedEvent.toJson());

        primaryNode.add(const GraphNodeReloadRequested());

        LoggingService.instance.info(
          'Water quality test created: $eventId (${state.parameterValues.length} parameters)',
        );

        if (activeTargets.length > 1) {
          final activityRepository = ActivityEventRepository(
            organization: eventRepository.organization,
            user: eventRepository.user,
            firestore: eventRepository.db,
            organismContext: eventRepository.organismContext,
          );
          final propagationService = EventPropagationService(
            activityEventRepository: activityRepository,
            organismContext: eventRepository.organismContext,
          );
          await propagationService.propagateToTargetNodes(
            sourceEvent: enrichedEvent,
            targetNodes: activeTargets.skip(1),
            activityType: HusbandryEventType.waterQualityTest.id,
          );
          for (final node in activeTargets.skip(1)) {
            node.add(const GraphNodeReloadRequested());
          }
        }

        emit(state.copyWith(isLoading: false, createdEvent: enrichedEvent));
        onSuccess?.call(enrichedEvent);
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error saving water quality test',
        e,
        stackTrace,
      );
      final error = 'Failed to save: ${e.toString()}';
      emit(state.copyWith(isLoading: false, errorMessage: error));
      onError?.call(error);
    }
  }

  EventPermitMetadata? _buildPermitMetadata() {
    final hadInitialPermit =
        _existingTest?.permitMetadata.isEmpty == false;
    return buildPermitMetadataFromTextInputs(
      permitIdText: state.permitId,
      permitTypeText: state.permitType,
      issuingAuthorityText: state.issuingAuthority,
      attachmentsText: state.permitAttachmentUrls,
      validFrom: state.permitValidFrom,
      validTo: state.permitValidTo,
      hadInitialPermit: hadInitialPermit,
      isEditMode: state.isEditing,
    );
  }
}
