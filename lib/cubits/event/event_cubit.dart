// @tier: community
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/event/event_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/extensions.dart';

/// Resolves the people/records referenced by an [Event] so event cards can
/// render full context (actor, record, and optional move parents).
class EventCubit extends Cubit<EventState> with CubitStreamSubscriptionMixin {
  EventCubit({
    required this.event,
    required RecordRepository recordRepository,
    LoggingService? loggingService,
  }) : _recordRepository = recordRepository,
       _loggingService = loggingService ?? LoggingService.instance,
       super(const EventInitial()) {
    _loadEventData();
  }

  final Event event;
  final RecordRepository _recordRepository;
  final LoggingService _loggingService;

  EventType get eventType =>
      EventType.builtins[event.eventTypeId] ?? EventType.unknown;

  void _loadEventData() {
    // Cancel existing subscriptions via mixin
    cancelAllSubscriptions();
    // Prevent emitting to a closed cubit
    if (isClosed) return;
    emit(EventLoading(event: event));
    try {
      final snapshotStream = _buildSnapshotStream();
      listenWithKey<_EventSnapshot>(
        'eventData_${event.id}',
        snapshotStream,
        onData: _emitLoadedState,
        onError: (error, stackTrace) => _handleStreamError(
          error,
          stackTrace,
          context: 'Loading event data for ${event.id}',
        ),
      );
    } catch (e, stackTrace) {
      _handleStreamError(
        e,
        stackTrace,
        context: 'Setting up event data streams for ${event.id}',
      );
    }
  }

  Stream<_EventSnapshot> _buildSnapshotStream() {
    final isCommunityPost = event.metadata?['isCommunityPost'] == true;
    // Handle permission errors gracefully when reading user documents.
    // This can happen when the user document doesn't exist or lacks organizationId,
    // causing Firestore security rules to deny access.
    final createdByStream = isCommunityPost
        ? Stream<User?>.value(null)
        : _recordRepository
            .streamRecord<User>(
              ModelType.user,
              event.createdById,
            )
            .handleError(
              (error) {
                if (error is FirebaseException &&
                    error.code == 'permission-denied') {
                  _loggingService.warning(
                    'Permission denied reading user ${event.createdById} for event ${event.id}',
                  );
                  return null;
                }
                throw error;
              },
            )
            .onErrorReturn(null);
    final referencedRecordStream = _recordRepository
        .streamRecord<InventoryRecord>(
          event.recordModelType,
          event.recordId,
          organizationId: event.organizationId,
        )
        .handleError(
          (error) {
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              _loggingService.warning(
                'Permission denied reading ${event.recordModelType.name} ${event.recordId} for event ${event.id}',
              );
              return null;
            }
            _loggingService.warning(
              'Error streaming record ${event.recordModelType.name} ${event.recordId}: $error',
            );
            throw error;
          },
        )
        .onErrorReturn(null);
    final sharedReferencedRecordStream =
        referencedRecordStream.shareReplay(maxSize: 1);
    final relatedOrganismRecordsStream = _streamRelatedOrganismRecords();

    final moveEvent = event.asOrNull<MoveEvent>();
    if (moveEvent == null) {
      final groupRecordStream = _streamParentRecordForOrganism(
        sharedReferencedRecordStream,
        ModelType.group,
        (record) => record.groupId,
      );
      final siteRecordStream = _streamParentRecordForOrganism(
        sharedReferencedRecordStream,
        ModelType.site,
        (record) => record.siteId,
      );

      return Rx.combineLatest5<
        User?,
        InventoryRecord?,
        GraphNodeRecord?,
        GraphNodeRecord?,
        Map<String, OrganismRecord?>,
        _EventSnapshot
      >(
        createdByStream,
        sharedReferencedRecordStream,
        groupRecordStream,
        siteRecordStream,
        relatedOrganismRecordsStream,
        (
          createdByUser,
          referencedRecord,
          groupRecord,
          siteRecord,
          relatedOrganismRecords,
        ) =>
            _EventSnapshot(
              createdByUser: createdByUser,
              referencedRecord: referencedRecord,
              groupRecord: groupRecord,
              siteRecord: siteRecord,
              relatedOrganismRecords: relatedOrganismRecords,
            ),
      );
    }

    final fromParentStream = _streamGraphNodeRecord(
      moveEvent.fromModelType,
      moveEvent.fromParentId,
    );
    final toParentStream = _streamGraphNodeRecord(
      moveEvent.toModelType,
      moveEvent.toParentId,
    );

    return Rx.combineLatest5<
      User?,
      InventoryRecord?,
      GraphNodeRecord?,
      GraphNodeRecord?,
      Map<String, OrganismRecord?>,
      _EventSnapshot
    >(
      createdByStream,
      sharedReferencedRecordStream,
      fromParentStream,
      toParentStream,
      relatedOrganismRecordsStream,
      (
        createdByUser,
        referencedRecord,
        fromParentRecord,
        toParentRecord,
        relatedOrganismRecords,
      ) =>
          _EventSnapshot(
            createdByUser: createdByUser,
            referencedRecord: referencedRecord,
            fromParentRecord: fromParentRecord,
            toParentRecord: toParentRecord,
            relatedOrganismRecords: relatedOrganismRecords,
          ),
    );
  }

  Stream<GraphNodeRecord?> _streamGraphNodeRecord(
    ModelType modelType,
    String parentId,
  ) {
    if (_isMissingId(parentId)) {
      return Stream<GraphNodeRecord?>.value(null);
    }
    return _recordRepository
        .streamRecord<GraphNodeRecord>(
          modelType,
          parentId,
          organizationId: event.organizationId,
        )
        .handleError(
          (error) {
            _loggingService.warning(
              'Error streaming parent record ${modelType.name} $parentId: $error',
            );
            throw error;
          },
        )
        .onErrorReturn(null);
  }

  Stream<GraphNodeRecord?> _streamParentRecordForOrganism(
    Stream<InventoryRecord?> recordStream,
    ModelType modelType,
    String? Function(OrganismRecord record) parentIdFor,
  ) {
    return recordStream.switchMap((record) {
      if (record is! OrganismRecord) {
        return Stream<GraphNodeRecord?>.value(null);
      }
      final parentId = parentIdFor(record);
      if (_isMissingId(parentId)) {
        return Stream<GraphNodeRecord?>.value(null);
      }
      return _streamGraphNodeRecord(modelType, parentId!);
    });
  }

  Stream<Map<String, OrganismRecord?>> _streamRelatedOrganismRecords() {
    final ids = _relatedOrganismIdsForEvent(event);
    if (ids.isEmpty) {
      return Stream.value(const {});
    }

    final uniqueIds = <String>{};
    final filteredIds = <String>[];
    for (final id in ids) {
      if (_isMissingId(id)) {
        continue;
      }
      if (uniqueIds.add(id)) {
        filteredIds.add(id);
      }
    }

    if (filteredIds.isEmpty) {
      return Stream.value(const {});
    }

    final streams =
        filteredIds.map((id) {
          return _recordRepository
              .streamRecord<OrganismRecord>(
                ModelType.organismRecord,
                id,
                organizationId: event.organizationId,
              )
              .onErrorReturn(null)
              .map((record) => MapEntry(id, record));
        }).toList();

    return Rx.combineLatestList<MapEntry<String, OrganismRecord?>>(streams)
        .map(
          (entries) => {
            for (final entry in entries) entry.key: entry.value,
          },
        )
        .onErrorReturn(const {});
  }

  List<String> _relatedOrganismIdsForEvent(Event event) {
    if (event is SpawnEvent) {
      return event.parentOrganismIds;
    }
    if (event is CrossEvent) {
      return [...event.damIds, ...event.sireIds];
    }
    return const [];
  }

  bool _isMissingId(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    return trimmed.isEmpty || trimmed == Missing.string;
  }

  void _emitLoadedState(_EventSnapshot snapshot) {
    // Prevent emitting to a closed cubit (e.g., when the widget scrolls out of view
    // before the Firestore response arrives)
    if (isClosed) return;

    final organismRecordSnapshot = _extractOrganismRecordSnapshot(event);
    emit(
      EventLoaded(
        event: event,
        eventType: eventType,
        createdByUser: snapshot.createdByUser,
        referencedRecord: snapshot.referencedRecord,
        fromParentRecord: snapshot.fromParentRecord,
        toParentRecord: snapshot.toParentRecord,
        groupRecord: snapshot.groupRecord,
        siteRecord: snapshot.siteRecord,
        organismRecordSnapshot: organismRecordSnapshot,
        relatedOrganismRecords: snapshot.relatedOrganismRecords,
      ),
    );
  }

  void _handleStreamError(
    Object error,
    StackTrace stackTrace, {
    required String context,
  }) {
    // Prevent emitting to a closed cubit
    if (isClosed) return;

    final domainError = error is DomainError
        ? error
        : ErrorHandler.transformError(
            error,
            stackTrace: stackTrace,
            context: context,
          );

    _loggingService.logDomainError(domainError, context: 'EventCubit');
    emit(EventError(message: domainError.message, error: domainError));
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin

  OrganismRecord? _extractOrganismRecordSnapshot(Event event) {
    if (event is LifeStageTransitionEvent) {
      return event.organismRecordSnapshot;
    }
    if (event is PhysicalFormChangeEvent) {
      return event.organismRecordSnapshot;
    }
    if (event is SizeChangeEvent) {
      return event.organismRecordSnapshot;
    }
    if (event is QuantityChangeEvent) {
      return event.organismRecordSnapshot;
    }
    return null;
  }
}

class _EventSnapshot {
  const _EventSnapshot({
    this.createdByUser,
    this.referencedRecord,
    this.fromParentRecord,
    this.toParentRecord,
    this.groupRecord,
    this.siteRecord,
    this.relatedOrganismRecords = const {},
  });

  final User? createdByUser;
  final InventoryRecord? referencedRecord;
  final GraphNodeRecord? fromParentRecord;
  final GraphNodeRecord? toParentRecord;
  final GraphNodeRecord? groupRecord;
  final GraphNodeRecord? siteRecord;
  final Map<String, OrganismRecord?> relatedOrganismRecords;
}
