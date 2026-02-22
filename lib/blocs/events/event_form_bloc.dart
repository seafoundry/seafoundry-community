// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:meta/meta.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Base state for all event forms, now using standard RecordFormState
/// Event-specific properties (targetNode, propagation) are handled in the BLoC
abstract class EventFormState<E extends Event> extends RecordFormState<E> {
  EventFormState({
    required super.steps,
    super.currentStepIndex,
    super.submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  });
}

/// Base BLoC for all event creation forms
/// Now stores event-specific properties directly in the BLoC
abstract class EventFormBloc<E extends Event, S extends EventFormState<E>>
    extends RecordFormBloc<E, S> {
  EventFormBloc({
    required S initialState,
    required this.eventRepository,
    this.propagationService,
    this.allowTaskCreation = false,
    this.allowPropagation = true,
    this.multiTargetStrategy = MultiTargetStrategy.multipleEvents,
    this.selectAllTargetsByDefault = false,
    this.targetNode,
  }) : super(initialState) {
    on<RecordFormSubmit>(onEventSubmit);
    on<EventFormTargetChanged>(_onTargetChanged);
    on<EventFormPropagationToggled>(_onPropagationToggled);
    on<EventFormTaskToggled>(_onTaskToggled);
    on<EventFormAdditionalTargetsChanged>(_onAdditionalTargetsChanged);
  }

  final EventRepository eventRepository;
  final EventPropagationService? propagationService;
  final bool allowTaskCreation;
  final bool allowPropagation;
  final MultiTargetStrategy multiTargetStrategy;
  final bool selectAllTargetsByDefault;

  // Event-specific properties now stored in BLoC
  GraphNode? targetNode;
  List<GraphNode> additionalTargets = [];
  bool propagateToParents = true; // Always propagate to parent structures
  bool createTask = false;

  /// Warning message when event was saved but propagation to parents failed.
  /// This indicates a partial success - the primary event exists but activity
  /// feeds may be incomplete. Reset on each new submission attempt.
  String? propagationWarning;

  /// Whether there is a propagation warning to display after successful submission.
  bool get hasPropagationWarning => propagationWarning != null;

  /// Get the event type ID for this event
  String get eventTypeId;

  /// Create the event from current state
  Future<E> createEventFromState();

  /// Optional hook for additional validation
  bool validateEventSpecific() => true;

  @protected
  Future<void> onEventSubmit(RecordFormSubmit event, Emitter<S> emit) async {
    // Reset propagation warning from any previous attempt
    propagationWarning = null;

    try {
      if (!state.isValid || !validateEventSpecific()) {
        emit(
          state.copyWith(
                submissionStatus: FormzSubmissionStatus.failure,
                submissionError:
                    state.validationErrorMessage ?? 'Invalid form data',
              )
              as S,
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

      if (targetNode == null) {
        throw Exception('Target node is required');
      }

      final primaryTarget = targetNode!;
      final extras = <String, GraphNode>{};
      for (final node in additionalTargets) {
        if (node != primaryTarget) {
          extras[node.urlPath] = node;
        }
      }

      final createdEvents = <E>[];
      final shouldPropagate = propagateToParents && propagationService != null;

      final nodesNeedingReload = <GraphNode>{};

      // Track propagation failures to surface as warnings
      var propagationFailed = false;

      try {
        // Primary event
        final primaryEvent = await createEventFromState();
        await eventRepository.createEvent(primaryEvent);
        createdEvents.add(primaryEvent);
        nodesNeedingReload.add(primaryTarget);

        if (shouldPropagate) {
          try {
            await propagationService!.propagateToParents(
              sourceEvent: primaryEvent,
              sourceNode: primaryTarget,
              activityType: eventTypeId,
            );
          } catch (e, stackTrace) {
            propagationFailed = true;
            LoggingService.instance.error(
              'Failed to propagate event, but event was created',
              e,
              stackTrace,
            );
          }
        }

        if (extras.isNotEmpty &&
            multiTargetStrategy == MultiTargetStrategy.singleEventWithReferences) {
          if (propagationService == null) {
            LoggingService.instance.warning(
              'Multi-target references skipped: EventPropagationService unavailable',
            );
          } else {
            try {
              await propagationService!.propagateToTargetNodes(
                sourceEvent: primaryEvent,
                targetNodes: extras.values,
                activityType: eventTypeId,
              );
              nodesNeedingReload.addAll(extras.values);
            } catch (e, stackTrace) {
              propagationFailed = true;
              LoggingService.instance.error(
                'Failed to create multi-target references',
                e,
                stackTrace,
              );
            }
          }
        } else {
          // Additional targets (legacy multi-event behavior)
          for (final node in extras.values) {
            final originalTarget = targetNode;
            targetNode = node;
            final extraEvent = await createEventFromState();
            await eventRepository.createEvent(extraEvent);
            createdEvents.add(extraEvent);
            nodesNeedingReload.add(node);

            if (shouldPropagate) {
              try {
                await propagationService!.propagateToParents(
                  sourceEvent: extraEvent,
                  sourceNode: node,
                  activityType: eventTypeId,
                );
              } catch (e, stackTrace) {
                propagationFailed = true;
                LoggingService.instance.error(
                  'Failed to propagate event for ${node.urlPath}',
                  e,
                  stackTrace,
                );
              }
            }

            targetNode = originalTarget;
          }
        }
      } finally {
        targetNode = primaryTarget;
        additionalTargets = [];
      }

      // Handle task creation if enabled (primary event only)
      if (createTask && allowTaskCreation) {
        LoggingService.instance.info('Task creation flag set on event');
      }

      for (final node in nodesNeedingReload) {
        _requestNodeReload(node);
      }

      final primaryEvent = createdEvents.first;
      if (emit.isDone) return;

      // Set propagation warning in BLoC for UI to display
      propagationWarning = propagationFailed
          ? 'Event saved but activity feed may be incomplete'
          : null;

      emit(
        state.copyWith(
              submissionStatus: FormzSubmissionStatus.success,
              createdRecord: primaryEvent,
              submissionError: null,
              overrideSubmissionError: true,
            )
            as S,
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error('Failed to create event', error, stackTrace);
      final domainError = ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: 'EventFormBloc.onSubmit',
      );
      if (emit.isDone) return;
      emit(
        state.copyWith(
              submissionStatus: FormzSubmissionStatus.failure,
              submissionError: ErrorHandler.getDisplayMessage(domainError),
            )
            as S,
      );
    }
  }

  void _onTargetChanged(EventFormTargetChanged event, Emitter<S> emit) {
    targetNode = event.targetNode;
    additionalTargets = [];
  }

  void _onPropagationToggled(
    EventFormPropagationToggled event,
    Emitter<S> emit,
  ) {
    if (allowPropagation) {
      propagateToParents = event.enabled;
    }
  }

  void _onTaskToggled(EventFormTaskToggled event, Emitter<S> emit) {
    if (allowTaskCreation) {
      createTask = event.enabled;
    }
  }

  void _onAdditionalTargetsChanged(
    EventFormAdditionalTargetsChanged event,
    Emitter<S> emit,
  ) {
    final unique = <String, GraphNode>{};
    for (final node in event.targets) {
      unique[node.urlPath] = node;
    }
    additionalTargets = unique.values.toList();
  }

  /// Helper to generate common event fields
  Future<Map<String, dynamic>> generateEventFields({
    required String recordId,
    required ModelType recordModelType,
    required String parentPath,
    required String parentInternalPath,
  }) async {
    final id = generateId(firestore: eventRepository.db);
    final slug = await eventRepository.nextSlugForModelType(ModelType.event);
    final now = DateTime.now().toIso8601String();

    return {
      'id': id,
      'createdById': eventRepository.user.id,
      'createdAt': now,
      'updatedById': eventRepository.user.id,
      'updatedAt': now,
      'organizationId': eventRepository.organization.id,
      'recordId': recordId,
      'recordModelType': recordModelType,
      'urlPath': '$parentPath/$slug',
      'internalPath': '$parentInternalPath/$id',
      'slug': slug,
    };
  }

  void _requestNodeReload(GraphNode node) {
    if (!node.isClosed) {
      node.add(const GraphNodeReloadRequested());
    }
  }
}

/// Strategy for handling events that target multiple records.
///
/// When a user performs an action on multiple targets (e.g., a bulk health
/// status update or an observation applied to multiple organisms), this
/// strategy determines how events are created in the database.
enum MultiTargetStrategy {
  /// Creates one event per target. Use when each target needs independent
  /// tracking (e.g., propagation events where each child has unique metadata).
  ///
  /// Results in N events for N targets. Each event is a full, standalone
  /// record that can be queried and modified independently.
  ///
  /// **When to use**: Propagation, fragmentation, or any action where each
  /// target may have different outcomes or require independent audit trails.
  multipleEvents,

  /// Creates one parent event with ActivityEvent references to each target.
  /// Use when a single action applies to multiple targets simultaneously
  /// (e.g., bulk observations, tasks affecting multiple organisms, health
  /// status updates).
  ///
  /// Results in 1 parent event + N lightweight activity references.
  /// This is more efficient and provides clearer audit trails by:
  /// - Reducing storage costs (one full event vs N full events)
  /// - Clearly indicating these were part of a single user action
  /// - Enabling activity feed entries on each target without duplication
  ///
  /// **When to use**: Bulk status changes, observations across multiple
  /// targets, or any action where all targets share the same parameters.
  singleEventWithReferences,
}

/// Events for EventFormBloc
class EventFormTargetChanged extends RecordFormEvent {
  final GraphNode targetNode;
  const EventFormTargetChanged(this.targetNode);

  @override
  List<Object?> get props => [targetNode];
}

class EventFormPropagationToggled extends RecordFormEvent {
  final bool enabled;
  const EventFormPropagationToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class EventFormTaskToggled extends RecordFormEvent {
  final bool enabled;
  const EventFormTaskToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class EventFormAdditionalTargetsChanged extends RecordFormEvent {
  final List<GraphNode> targets;
  const EventFormAdditionalTargetsChanged(this.targets);

  @override
  List<Object?> get props => [targets];
}
