// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/events/activity_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/offline/activity_event_offline_handler.dart';

/// Repository for managing activity events
class ActivityEventRepository extends EventRepository {
  ActivityEventRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
    ActivityEventOfflineHandler? offlineHandler,
    LoggingService? logger,
  }) : _offlineHandler =
           offlineHandler ?? const NoopActivityEventOfflineHandler(),
       _logger = logger ?? LoggingService.instance;

  final ActivityEventOfflineHandler _offlineHandler;
  final LoggingService _logger;

  bool get isOnline => _offlineHandler.isOnline;

  /// Create a new activity event
  Future<ActivityEvent> createActivityEvent({
    required String recordId,
    required ModelType recordModelType,
    required String activityType,
    String? description,
    Map<String, dynamic>? parameters,
    String? parentPath,
    String? parentInternalPath,
    OrganismKind? organismKindOverride,
    EventBaseParams base = const EventBaseParams(),
    WriteBatch? batch,
    bool queueOnly = false,
    bool useLocalSlug = false,
  }) async {
    final String eventId = generateId(firestore: db);
    final String eventSlug =
        useLocalSlug || queueOnly ? eventId : await nextSlugForModelType(
          ModelType.event,
        );

    // Determine parent path for the event
    final String urlPath;
    final String internalPath;

    if (parentPath != null) {
      if (parentInternalPath == null) {
        throw ArgumentError(
          'parentInternalPath is required when parentPath is provided.',
        );
      }
      urlPath = '$parentPath/$eventSlug';
      internalPath = '$parentInternalPath/$eventId';
    } else if (parentInternalPath != null) {
      throw ArgumentError(
        'parentPath must be provided when parentInternalPath is set.',
      );
    } else {
      // Default to organization path if no parent specified
      urlPath = '${organization.urlPath}/events/$eventSlug';
      internalPath = '${organization.internalPath}/events/$eventId';
    }

    final now = DateTime.now().toIso8601String();
    var event = ActivityEvent(
      id: eventId,
      activityType: activityType,
      description: description,
      parameters: parameters,
      base: base,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      recordId: recordId,
      recordModelType: recordModelType,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: eventSlug,
    );

    final metadataOverrides = organismKindOverride == null
        ? null
        : {'organismKind': organismKindOverride.name};
    event = withOrganismMetadata(
      event,
      additionalMetadata: metadataOverrides,
    );

    // CRITICAL: Do NOT cache events before batch commit succeeds.
    // When batch != null, the caller is responsible for:
    // 1. Committing the batch
    // 2. Calling cacheActivityEventAfterCommit() on success
    // 3. Calling queueActivityEventForOfflineSync() on failure
    //
    // This prevents the idempotency check from incorrectly skipping
    // events that were cached but never committed to Firestore.

    if (queueOnly) {
      await _offlineHandler.cacheEvent(event);
      await _offlineHandler.queueEvent(event);
      return event;
    }

    if (_offlineHandler.isOnline) {
      try {
        if (batch != null) {
          // Batch operation: caller handles commit and caching
          batch.set(collectionRef.doc(eventId), event.toJson());
          return event;
        } else {
          // Direct write: cache after successful commit
          await collectionRef.doc(eventId).set(event.toJson());
          await _offlineHandler.cacheEvent(event);
          return event;
        }
      } catch (e, stackTrace) {
        _logger.warning(
          'Online activity event create failed, queueing for offline sync',
          {'error': e.toString(), 'stackTrace': stackTrace.toString()},
        );
      }
    }

    // Offline: queue for sync (which also caches)
    await _offlineHandler.queueEvent(event);

    return event;
  }

  /// Check local cache and offline queue for existing activity events.
  /// Used for idempotent propagation while offline.
  Future<ActivityEvent?> findCachedActivityEventBySourceAndParent({
    required String sourceEventId,
    required String parentRecordId,
  }) async {
    return _offlineHandler.findCachedActivityEventBySourceAndParent(
      sourceEventId: sourceEventId,
      parentRecordId: parentRecordId,
    );
  }

  /// Exposed for batch commit fallbacks.
  Future<void> queueActivityEventForOfflineSync(ActivityEvent event) async {
    await _offlineHandler.queueEvent(event);
  }

  /// Cache an activity event after successful batch commit.
  ///
  /// This should be called by the caller after a batch containing activity
  /// events has been successfully committed. This ensures events are only
  /// cached after they are confirmed to exist in Firestore, preventing
  /// idempotency check failures on retry.
  Future<void> cacheActivityEventAfterCommit(ActivityEvent event) async {
    await _offlineHandler.cacheEvent(event);
  }

  /// Cache multiple activity events after successful batch commit.
  Future<void> cacheActivityEventsAfterCommit(List<ActivityEvent> events) async {
    for (final event in events) {
      await _offlineHandler.cacheEvent(event);
    }
  }

  /// Get activity events for a specific record
  Stream<List<ActivityEvent>> getActivitiesForRecord(String recordId, {int limit = 1000}) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('recordId', isEqualTo: recordId)
        .where('eventTypeId', isEqualTo: EventType.activity.id)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) {
                try {
                  return ActivityEvent.fromJson(FirestoreDocumentHelpers.injectDocumentId(doc));
                } catch (e, stackTrace) {
                  LoggingService.instance.error(
                    'Failed to parse ActivityEvent from Firestore doc=${doc.id}',
                    e,
                    stackTrace,
                  );
                  return null;
                }
              })
              .where((event) => event != null)
              .cast<ActivityEvent>()
              .toList();
          // Sort in-memory instead of using orderBy
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return events;
        });
  }

  /// Get activity events by type
  Stream<List<ActivityEvent>> getActivitiesByType(String activityType) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('eventTypeId', isEqualTo: EventType.activity.id)
        .where('activityType', isEqualTo: activityType)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) {
                try {
                  return ActivityEvent.fromJson(FirestoreDocumentHelpers.injectDocumentId(doc));
                } catch (e, stackTrace) {
                  LoggingService.instance.error(
                    'Failed to parse ActivityEvent from Firestore doc=${doc.id}',
                    e,
                    stackTrace,
                  );
                  return null;
                }
              })
              .where((event) => event != null)
              .cast<ActivityEvent>()
              .toList();
          // Sort in-memory instead of using orderBy
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return events;
        });
  }

  /// Check if an activity event already exists for this source event and parent record.
  /// Used for idempotent propagation - prevents duplicate events on retry.
  Future<ActivityEvent?> findActivityEventBySourceAndParent({
    required String sourceEventId,
    required String parentRecordId,
  }) async {
    try {
      // CRITICAL: Must include organizationId filter to satisfy security rules
      final snapshot = await collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('recordId', isEqualTo: parentRecordId)
          .where('eventTypeId', isEqualTo: EventType.activity.id)
          .where('parameters.sourceEventId', isEqualTo: sourceEventId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return ActivityEvent.fromJson(FirestoreDocumentHelpers.injectDocumentId(doc));
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to check for existing activity event (source: $sourceEventId, parent: $parentRecordId)',
        e,
      );
      return null;
    }
  }
}
