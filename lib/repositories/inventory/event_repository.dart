import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/factories/event_factory.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/stream_cache.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';

/// Cache key for streamEventsForUrlPath using type-safe Dart records.
/// Prevents cache key collisions and provides better debugging.
typedef _EventStreamCacheKey = ({
  String urlPath,
  String? recordId,
  bool shallow,
  int limit,
});

abstract class _EventRepositoryBase
    extends InventoryRecordRepository<Event> {
  _EventRepositoryBase({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  }) : super(modelType: ModelType.event);

  DateTime? _timestampOverride;

  /// Check if a model type represents an organism (coral or organismRecord).
  bool _isOrganismType(ModelType type) {
    return type == ModelType.organismRecord;
  }

}

class EventRepository extends _EventRepositoryBase {
  EventRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  });

  // Stream caches to prevent duplicate Firestore subscriptions
  // Uses StreamCache with Dart records for type-safe, collision-free keys
  final _urlPathEventCache = StreamCache<_EventStreamCacheKey, List<Event>>();

  @override
  void dispose() {
    // Clean up stream caches to prevent memory leaks
    _urlPathEventCache.dispose();
    super.dispose();
  }

  @visibleForTesting
  static ({OutplantEvent updatedEvent, Map<String, Object?> payload})
  prepareOutplantGeometryUpdate({
    required OutplantEvent event,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    required String updatedAt,
    required String updatedById,
  }) {
    final shouldClear = clearGeometry || geometry == null;
    OutplantGeometry? resolvedGeometry;
    if (!shouldClear) {
      resolvedGeometry = geometry.copyWith(updatedAtIso: updatedAt);
    }

    final updatedEvent = event.copyWith(
      geometry: resolvedGeometry,
      clearGeometry: shouldClear,
      updatedAt: updatedAt,
      updatedById: updatedById,
    );

    final payload = <String, Object?>{
      'updatedAt': updatedAt,
      'updatedById': updatedById,
    };

    if (shouldClear) {
      payload['geometry'] = FieldValue.delete();
    } else if (resolvedGeometry != null) {
      payload['geometry'] = resolvedGeometry.toJson();
    }

    return (updatedEvent: updatedEvent, payload: payload);
  }

  // ═══════════════════ SECTION: Helpers ═══════════════════

  Stream<T> _guardStream<T>(
    Stream<T> source, {
    required String debugLabel,
  }) {
    return source.onErrorResume((error, stackTrace) {
      if (shouldSuppressAuthError(error)) {
        LoggingService.instance.debug(
          'Suppressing event stream error after sign out',
          {'stream': debugLabel},
        );
        return Stream<T>.empty();
      }
      LoggingService.instance.error(
        'Stream error ($debugLabel)',
        error,
        stackTrace,
      );
      return Stream<T>.error(error, stackTrace);
    });
  }

  String _isoNow([DateTime? explicit]) {
    final source = explicit ?? _timestampOverride ?? DateTime.now();
    return DateTimeConverter.toIso8601String(source);
  }

  Future<T> withTimestampOverride<T>(
    DateTime timestamp,
    Future<T> Function() action,
  ) async {
    final previous = _timestampOverride;
    _timestampOverride = timestamp;
    try {
      return await action();
    } finally {
      _timestampOverride = previous;
    }
  }

  /// Helper to create exclusive upper bound for urlPath range queries.
  ///
  /// For typical URL paths (alphanumeric), increments the last character.
  /// Handles edge cases: empty strings throw, high Unicode appends sentinel.
  ///
  /// Examples:
  /// - "sites/123" -> "sites/124" (typical usage)
  /// - "abc" -> "abd" (simple case)
  String _incrementLastChar(String input) {
    if (input.isEmpty) {
      // Empty string would create invalid query bounds (x >= "" AND x < "")
      // This should never happen in practice - urlPath is always non-empty
      throw ArgumentError('Cannot create range query for empty urlPath');
    }

    final lastCharCode = input.codeUnitAt(input.length - 1);

    // Check for high Unicode that would overflow (surrogate pairs, max BMP)
    // In practice, URL paths use ASCII characters, but be defensive
    if (lastCharCode >= 0xD800) {
      // Surrogate pair or near-max Unicode - append high character instead
      return '$input\uFFFF';
    }

    return input.substring(0, input.length - 1) +
        String.fromCharCode(lastCharCode + 1);
  }

  bool _isIndexError(Object error) {
    if (error is FirebaseException) {
      final message = error.message?.toLowerCase() ?? '';
      if (error.code == 'failed-precondition' && message.contains('index')) {
        return true;
      }
    }

    final text = error.toString().toLowerCase();
    if (!text.contains('index')) {
      return false;
    }
    return text.contains('requires an index') ||
        text.contains('index is currently building') ||
        text.contains('failed-precondition');
  }

  Duration _indexRetryDelay(int attempt) {
    const baseSeconds = 2;
    const maxSeconds = 30;
    final seconds = baseSeconds * (1 << (attempt - 1));
    return Duration(seconds: seconds > maxSeconds ? maxSeconds : seconds);
  }

  Stream<T> _retryIndexStream<T>(
    Stream<T> Function() sourceFactory, {
    required String debugLabel,
  }) async* {
    var attempt = 0;
    while (true) {
      try {
        await for (final value in sourceFactory()) {
          attempt = 0;
          yield value;
        }
        break;
      } catch (error, stackTrace) {
        if (shouldSuppressAuthError(error)) {
          LoggingService.instance.debug(
            'Suppressing event stream error after sign out',
            {'stream': debugLabel},
          );
          return;
        }
        if (!_isIndexError(error)) {
          LoggingService.instance.error(
            'Stream error ($debugLabel)',
            error,
            stackTrace,
          );
          rethrow;
        }
        attempt += 1;
        final delay = _indexRetryDelay(attempt);
        LoggingService.instance.warning(
          'Index not ready for $debugLabel; retrying in ${delay.inSeconds}s',
          {'error': error.toString()},
        );
        await Future.delayed(delay);
      }
    }
  }

  @override
  Query<Object?> collectionQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    // Note: super.collectionQuery filters by organizationId
    // CRITICAL: Avoid orderBy to prevent composite index requirements
    // Sorting is handled in-memory by consumers
    return super.collectionQuery(collectionRef);
  }


  /// Injects the Firestore document ID into the JSON data.
  ///
  /// Delegates to [FirestoreDocumentHelpers.injectDocumentId].
  Map<String, dynamic> _injectDocId(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => FirestoreDocumentHelpers.injectDocumentId(doc);

  /// Helper to safely parse an Event from a Firestore DocumentSnapshot.
  /// Returns null if parsing fails, logging the error.
  Event? _parseEventSafe(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return RecordFactory.eventFromJson(_injectDocId(doc));
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to parse event ${doc.id}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  T withOrganismMetadata<T extends Event>(
    T event, {
    Map<String, dynamic>? additionalMetadata,
  }) {
    final existing = event.metadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(event.metadata!);
    existing['organismKind'] = organismContext.kind.name;
    if (additionalMetadata != null) {
      existing.addAll(additionalMetadata);
    }
    final enrichedJson = event.toJson();
    enrichedJson['metadata'] = existing;
    return RecordFactory.eventFromJson(enrichedJson) as T;
  }

  Map<String, dynamic> _organismRecordMetadata(
    String recordId,
    OrganismRecord snapshot,
  ) {
    final metadata = <String, dynamic>{'organismRecordId': recordId};
    if (snapshot.speciesId != null) {
      metadata['speciesId'] = snapshot.speciesId;
    }
    metadata['organismKind'] = snapshot.organismKind.name;
    return metadata;
  }

  // ═══════════════════ SECTION: History ═══════════════════

  /// Stream events for a specific URL path using server-side range query.
  ///
  /// Uses Firestore range query on urlPath (requires no composite index beyond
  /// organizationId) to efficiently filter events. Orders by urlPath then createdAt
  /// descending to guarantee recent events are included.
  ///
  /// Replaces time-window filtering with limit-based approach to avoid missing
  /// recent events when total event count exceeds window threshold.
  Stream<List<Event>> streamEventsForUrlPath(
    String urlPath, {
    String? recordId,
    bool shallow = false,
    int limit = 100,
  }) {
    // Cache streams using type-safe Dart record key to prevent:
    // 1. Duplicate Firestore subscriptions
    // 2. Cache key collisions (record keys are type-safe and unique)
    // StreamCache handles broadcast support and lazy subscription lifecycle
    final cacheKey = (
      urlPath: urlPath,
      recordId: recordId,
      shallow: shallow,
      limit: limit,
    );
    return _urlPathEventCache.getOrCreate(cacheKey, () {
      final upperBound = _incrementLastChar(urlPath);

      // CRITICAL: Must include organizationId filter to satisfy security rules
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      Query<Map<String, dynamic>> query = collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('urlPath', isGreaterThanOrEqualTo: urlPath)
          .where('urlPath', isLessThan: upperBound)
          .limit(limit);

      return _retryIndexStream(
        () => query.snapshots().map((snapshot) {
        var events = snapshot.docs
            .map(_parseEventSafe)
            .whereType<Event>()
            .toList();

        // Apply recordId filter client-side if specified
        if (recordId != null) {
          events = events.where((event) => event.recordId == recordId).toList();
        }

        // Apply shallow filter client-side (exclude nested children)
        if (shallow) {
          events = events.where((event) {
            if (event.urlPath == urlPath) return true;
            final remainder = event.urlPath.substring(urlPath.length);
            return !(remainder.startsWith('/') &&
                remainder.substring(1).contains('/'));
          }).toList();
        }

        // Sort by createdAt descending (in-memory instead of orderBy)
        events.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          return dateB.compareTo(dateA);
        });

        return events;
        }),
        debugLabel: 'streamEventsForUrlPath($urlPath)',
      );
    });
  }

  // ═══════════════════ SECTION: Mutations ═══════════════════

  Future<void> moveEvents({
    required List<Event> events,
    required InventoryRecord fromRecord,
    required InventoryRecord toRecord,
    required Transaction transaction,
  }) async {
    for (final event in events) {
      final newEventData = event.copyWith(
        urlPath: event.urlPath.replaceFirst(
          fromRecord.urlPath,
          toRecord.urlPath,
        ),
        internalPath: event.internalPath.replaceFirst(
          fromRecord.internalPath,
          toRecord.internalPath,
        ),
      );
      transaction.set(collectionRef.doc(event.id), newEventData.toJson());
    }
  }

  Future<CreateEvent> addCreateEvent<T extends InventoryRecord>(
    T record,
    InventoryRecord parent,
    WriteBatch batch, {
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final String eventId = generateId(firestore: db);
    LoggingService.instance.debug(
      'EventRepository.addCreateEvent: getting event slug...',
    );
    final String eventSlug = await nextSlugForModelType(ModelType.event);
    LoggingService.instance.debug(
      'EventRepository.addCreateEvent: event slug = $eventSlug',
    );

    // Debug: Log createdById for event creation - helps diagnose permission-denied issues
    // The Firestore rule requires createdById == request.auth.uid
    LoggingService.instance.debug(
      'EventRepository.addCreateEvent: creating event',
    );
    LoggingService.instance.debug('   - user.id (createdById): "${user.id}"');
    LoggingService.instance.debug('   - organization.id: "${organization.id}"');
    LoggingService.instance.debug(
      '   - record.modelType: ${record.modelType.name}',
    );
    LoggingService.instance.debug(
      '   - collectionRef.path: ${collectionRef.path}',
    );
    LoggingService.instance.debug(
      '   - event doc path: ${collectionRef.doc(eventId).path}',
    );

    var createEvent = CreateEvent(
      id: eventId,
      createdById: user.id,
      createdAt: _isoNow(),
      recordId: record.id,
      recordModelType: record.modelType,
      urlPath: '${record.urlPath}/$eventSlug',
      internalPath: '${record.internalPath}/$eventId',
      slug: eventSlug,
      updatedAt: _isoNow(),
      updatedById: user.id,
      organizationId: organization.id,
      snapshot: record,
      base: base,
    );

    createEvent = withOrganismMetadata(createEvent);
    batch.set(collectionRef.doc(eventId), createEvent.toJson());

    return createEvent;
  }

  Future<MoveInEvent> createMoveInEvent(
    InventoryRecord movedRecord,
    InventoryRecord fromParent,
    InventoryRecord toParent,
    Transaction transaction, {
    int? quantity,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final String moveInEventId = generateId(firestore: db);
    final String moveInSlug = await nextSlugForModelType(ModelType.event);

    var moveInEvent = MoveInEvent(
      id: moveInEventId,
      createdById: user.id,
      recordId: movedRecord.id,
      recordModelType: movedRecord.modelType,
      fromUrlPath: fromParent.urlPath,
      movedRecordId: movedRecord.id,
      quantity: quantity,
      createdAt: _isoNow(),
      updatedAt: _isoNow(),
      updatedById: user.id,
      organizationId: organization.id,
      slug: moveInSlug,
      urlPath: '${movedRecord.urlPath}/$moveInSlug',
      internalPath: '${movedRecord.internalPath}/$moveInEventId',
      fromParentId: fromParent.id,
      toParentId: toParent.id,
      // Legacy field - include both coral and organismRecord types
      movedCoralIds: _isOrganismType(movedRecord.modelType)
          ? [movedRecord.id]
          : [],
      reason: moveReason,
      base: base,
    );
    moveInEvent = withOrganismMetadata(moveInEvent);
    transaction.set(collectionRef.doc(moveInEvent.id), moveInEvent.toJson());

    return moveInEvent;
  }

  Future<MoveOutEvent> createMoveOutEvent(
    InventoryRecord record,
    InventoryRecord fromParent,
    InventoryRecord toParent,
    Transaction transaction, {
    int? quantity,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final String moveOutEventId = generateId(firestore: db);
    final String moveOutSlug = await nextSlugForModelType(ModelType.event);

    var moveOutEvent = MoveOutEvent(
      id: moveOutEventId,
      createdById: user.id,
      recordId: record.id,
      recordModelType: record.modelType,
      toUrlPath: toParent.urlPath,
      movedRecordId: record.id,
      quantity: quantity,
      createdAt: _isoNow(),
      updatedAt: _isoNow(),
      updatedById: user.id,
      organizationId: organization.id,
      slug: moveOutSlug,
      urlPath: '${record.urlPath}/$moveOutSlug',
      internalPath: '${record.internalPath}/$moveOutEventId',
      fromParentId: fromParent.id,
      toParentId: toParent.id,
      // Legacy field - include both coral and organismRecord types
      movedCoralIds: _isOrganismType(record.modelType) ? [record.id] : [],
      reason: moveReason,
      base: base,
    );
    moveOutEvent = withOrganismMetadata(moveOutEvent);
    transaction.set(collectionRef.doc(moveOutEvent.id), moveOutEvent.toJson());

    return moveOutEvent;
  }

  Future<ObservationEvent> createObservationEvent({
    required InventoryRecord forRecord,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    DateTime? createdAt,
    WriteBatch? batch,
  }) async {
    final String eventSlug = await nextSlugForModelType(ModelType.event);
    final String eventId = generateId(firestore: db);
    final createdAtIso = _isoNow(createdAt);
    final updatedAtIso = _isoNow(createdAt);

    var observationEvent = ObservationEvent(
      id: eventId,
      createdById: user.id,
      createdAt: createdAtIso,
      recordId: forRecord.id,
      urlPath: '${forRecord.urlPath}/$eventSlug',
      internalPath: '${forRecord.internalPath}/$eventId',
      slug: eventSlug,
      recordModelType: forRecord.modelType,
      comment: comment?.isNotEmpty == true ? comment : null,
      imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
      oldHealthStatus: oldHealthStatus,
      newHealthStatus: newHealthStatus,
      healthIssueTypeId: healthIssueTypeId,
      updatedAt: updatedAtIso,
      updatedById: user.id,
      organizationId: organization.id,
    );

    observationEvent = withOrganismMetadata(observationEvent);
    await createEvent(observationEvent, batch: batch);

    return observationEvent;
  }

  Future<OutplantEvent> createOutplantEvent({
    required Site site,
    required String name,
    required List<OutplantAllocation> allocations,
    String? comment,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    String? healthStatus,
    OutplantGeometry? geometry,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    String? deliverableId,
    String? attachmentMethodId,
    WriteBatch? batch,
  }) async {
    final String eventSlug = await nextSlugForModelType(ModelType.event);
    final String eventId = generateId(firestore: db);
    final String now = _isoNow();

    var outplantEvent = OutplantEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      recordId: site.id,
      recordModelType: ModelType.site,
      urlPath: '${site.urlPath}/$eventSlug',
      internalPath: '${site.internalPath}/$eventId',
      slug: eventSlug,
      name: name,
      siteId: site.id,
      allocations: allocations,
      comment: comment,
      percentCover: percentCover,
      percentBleaching: percentBleaching,
      percentDisease: percentDisease,
      healthStatus: healthStatus,
      geometry: geometry,
      permitMetadata: permitMetadata,
      deliverableId: deliverableId,
      attachmentMethodId: attachmentMethodId,
    );

    outplantEvent = withOrganismMetadata(outplantEvent);

    final docRef = collectionRef.doc(eventId);

    // Diagnostic logging for permission-denied debug
    LoggingService.instance.debug(
      'OUTPLANT EVENT CREATION DIAGNOSTIC:\n'
      '  - collectionRef.path: ${collectionRef.path}\n'
      '  - docRef.path: ${docRef.path}\n'
      '  - organizationId: ${outplantEvent.organizationId}\n'
      '  - createdById: ${outplantEvent.createdById}\n'
      '  - siteId: ${outplantEvent.siteId}\n'
      '  - allocationsCount: ${outplantEvent.allocations.length}',
    );

    if (batch != null) {
      batch.set(docRef, outplantEvent.toJson());
    } else {
      await docRef.set(outplantEvent.toJson());
    }

    return outplantEvent;
  }

  Future<OutplantEvent> updateOutplantGeometry({
    required OutplantEvent event,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    WriteBatch? batch,
  }) async {
    final now = _isoNow();
    final prepared = prepareOutplantGeometryUpdate(
      event: event,
      geometry: geometry,
      clearGeometry: clearGeometry,
      updatedAt: now,
      updatedById: user.id,
    );

    final docRef = collectionRef.doc(event.id);
    if (batch != null) {
      batch.update(docRef, prepared.payload);
    } else {
      await docRef.update(prepared.payload);
    }

    return prepared.updatedEvent;
  }

  Future<String> ensureUniqueOutplantName(String baseName) async {
    var candidate = baseName.trim();
    if (candidate.isEmpty) {
      candidate = 'Outplant ${_isoNow()}';
    }

    Future<bool> nameExists(String name) async {
      try {
        // Use a simpler query without orderBy to avoid composite index issues
        // CRITICAL: Must include organizationId filter for security rules
        final query = collectionRef
            .where('organizationId', isEqualTo: organization.id)
            .where('eventTypeId', isEqualTo: EventType.outplant.id)
            .where('name', isEqualTo: name)
            .limit(1);
        final snapshot = await query.get();
        return snapshot.docs.isNotEmpty;
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          // Fallback query MUST include organizationId for security rules
          final snapshot = await collectionRef
              .where('organizationId', isEqualTo: organization.id)
              .where('name', isEqualTo: name)
              .limit(1)
              .get();
          return snapshot.docs.isNotEmpty;
        }
        rethrow;
      }
    }

    if (!await nameExists(candidate)) {
      return candidate;
    }

    var suffix = 2;
    const maxSuffix = 100;
    while (suffix <= maxSuffix) {
      final nextCandidate = '$baseName #$suffix';
      if (!await nameExists(nextCandidate)) {
        return nextCandidate;
      }
      suffix++;
    }
    throw StateError(
      'Could not generate unique outplant name after $maxSuffix attempts. '
      'Base name: $baseName',
    );
  }

  Future<Event> createEvent(Event event, {WriteBatch? batch}) async {
    final enrichedEvent =
        event.metadata != null && event.metadata!.containsKey('organismKind')
        ? event
        : withOrganismMetadata(event);

    // Debug: Log event creation for permission debugging
    LoggingService.instance.debug(
      'EventRepository.createEvent: PERMISSION DEBUG',
    );
    LoggingService.instance.debug(
      '   collectionRef.path: ${collectionRef.path}',
    );
    LoggingService.instance.debug(
      '   event doc path: ${collectionRef.doc(enrichedEvent.id).path}',
    );
    LoggingService.instance.debug(
      '   event.createdById: "${enrichedEvent.createdById}"',
    );
    LoggingService.instance.debug(
      '   event.organizationId: "${enrichedEvent.organizationId}"',
    );
    LoggingService.instance.debug(
      '   Rule check: createdById must equal auth uid',
    );

    if (batch != null) {
      batch.set(collectionRef.doc(enrichedEvent.id), enrichedEvent.toJson());
    } else {
      await collectionRef.doc(enrichedEvent.id).set(enrichedEvent.toJson());
    }
    return EventFactory.eventFromJson(enrichedEvent.toJson());
  }

  /// Create a correction event for an inventory record update
  ///
  /// This creates a CorrectionEvent that references the original record ID
  /// rather than original event ID, since inventory record corrections
  /// are about the record itself, not a specific event.
  Future<CorrectionEvent> createInventoryRecordCorrectionEvent({
    required InventoryRecord originalRecord,
    required InventoryRecord updatedRecord,
    required Map<String, dynamic> changes,
    String? notes,
  }) async {
    final correctionId = generateId(firestore: db);
    final correctionSlug = await nextSlugForModelType(ModelType.event);
    final now = _isoNow();

    // For inventory record corrections, we create synthetic event IDs
    // The "original event" represents the record state before correction
    // The "corrected event" represents the record state after correction
    // This allows us to reuse the CorrectionEvent structure designed for event-to-event corrections
    final String syntheticOriginalEventId = '${originalRecord.id}_original';
    final String syntheticCorrectedEventId = '${updatedRecord.id}_corrected';

    // Create the correction event
    var correctionEvent = CorrectionEvent(
      id: correctionId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '${updatedRecord.urlPath}/$correctionSlug',
      internalPath: '${updatedRecord.internalPath}/$correctionId',
      slug: correctionSlug,
      recordId: updatedRecord.id,
      recordModelType: updatedRecord.modelType,
      originalEventId: syntheticOriginalEventId,
      correctedEventId: syntheticCorrectedEventId,
      notes: notes,
      eventTypeId: EventType.inventoryRecordCorrection.id,
    );

    correctionEvent = withOrganismMetadata(correctionEvent);
    await createEvent(correctionEvent);
    return correctionEvent;
  }

  Future<LifeStageTransitionEvent> createLifeStageTransitionEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required LifeStage oldLifeStage,
    required LifeStage newLifeStage,
    String? oldSubtype,
    String? newSubtype,
    String? transitionReason,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  }) async {
    final slug = await nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = _isoNow();
    var event = LifeStageTransitionEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '$recordUrlPath/$slug',
      internalPath: '$recordInternalPath/$eventId',
      slug: slug,
      recordId: recordId,
      recordModelType: ModelType.organismRecord,
      organismRecordSnapshot: snapshot,
      oldLifeStage: oldLifeStage,
      newLifeStage: newLifeStage,
      oldSubtype: oldSubtype,
      newSubtype: newSubtype,
      transitionReason: transitionReason,
      metadata: metadata,
    );
    event = withOrganismMetadata(
      event,
      additionalMetadata: _organismRecordMetadata(recordId, snapshot),
    );
    await createEvent(event, batch: batch);
    return event;
  }

  Future<PhysicalFormChangeEvent> createPhysicalFormChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    String? oldFormId,
    String? newFormId,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  }) async {
    final slug = await nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = _isoNow();
    var event = PhysicalFormChangeEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '$recordUrlPath/$slug',
      internalPath: '$recordInternalPath/$eventId',
      slug: slug,
      recordId: recordId,
      recordModelType: ModelType.organismRecord,
      organismRecordSnapshot: snapshot,
      oldFormId: oldFormId,
      newFormId: newFormId,
      metadata: metadata,
    );
    event = withOrganismMetadata(
      event,
      additionalMetadata: _organismRecordMetadata(recordId, snapshot),
    );
    await createEvent(event, batch: batch);
    return event;
  }

  Future<SizeChangeEvent> createSizeChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required SizeSpec oldSize,
    required SizeSpec newSize,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  }) async {
    // Validate that size actually changed to avoid creating no-op events
    if (oldSize == newSize) {
      throw RepositoryError(
        message:
            'Cannot create size change event: old and new sizes are identical.',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Change the size before submitting.',
      );
    }
    final slug = await nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = _isoNow();
    var event = SizeChangeEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '$recordUrlPath/$slug',
      internalPath: '$recordInternalPath/$eventId',
      slug: slug,
      recordId: recordId,
      recordModelType: ModelType.organismRecord,
      organismRecordSnapshot: snapshot,
      oldSize: oldSize,
      newSize: newSize,
      metadata: metadata,
    );
    event = withOrganismMetadata(
      event,
      additionalMetadata: _organismRecordMetadata(recordId, snapshot),
    );
    await createEvent(event, batch: batch);
    return event;
  }

  Future<QuantityChangeEvent> createQuantityChangeEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required PopulationMeasurement oldMeasurement,
    required PopulationMeasurement newMeasurement,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  }) async {
    final slug = await nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = _isoNow();
    var event = QuantityChangeEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '$recordUrlPath/$slug',
      internalPath: '$recordInternalPath/$eventId',
      slug: slug,
      recordId: recordId,
      recordModelType: ModelType.organismRecord,
      organismRecordSnapshot: snapshot,
      oldMeasurement: oldMeasurement,
      newMeasurement: newMeasurement,
      metadata: metadata,
    );
    event = withOrganismMetadata(
      event,
      additionalMetadata: _organismRecordMetadata(recordId, snapshot),
    );
    await createEvent(event, batch: batch);
    return event;
  }

  // ═══════════════════ SECTION: Queries ═══════════════════

  Future<List<T>> fetchEventsByType<T extends Event>({
    required String eventTypeId,
    DateTime? start,
    DateTime? end,
    int? limit,
  }) async {
    try {
      // Always use collectionQuery to enforce organizationId filtering.
      Query<Map<String, dynamic>> query = (collectionQuery(collectionRef) as Query<Map<String, dynamic>>)
          .where('eventTypeId', isEqualTo: eventTypeId)
          .orderBy('createdAt', descending: true);

      if (start != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: start.toIso8601String(),
        );
      }
      if (end != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: end.toIso8601String(),
        );
      }

      // Apply default limit when no date range is specified
      if (start == null && end == null && limit == null) {
        query = query.limit(1000);
      }
      // Apply custom limit if provided
      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final results = <T>[];
      for (final doc in snapshot.docs) {
        try {
          final event = RecordFactory.eventFromJson(_injectDocId(doc));
          if (event is T) {
            results.add(event);
          }
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'Failed to parse event ${doc.id} of type $eventTypeId',
            error,
            stackTrace,
          );
        }
      }
      return results;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'fetchEventsByType($eventTypeId) failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Stream<List<OutplantEvent>> streamOutplantEvents({
    String? siteId,
    int limit = 50,
  }) {
    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    Query<Map<String, dynamic>> query =
        (collectionQuery(collectionRef) as Query<Map<String, dynamic>>).where(
          'eventTypeId',
          isEqualTo: EventType.outplant.id,
        );

    if (siteId != null) {
      query = query.where('siteId', isEqualTo: siteId);
    }

    if (limit > 0) {
      query = query.limit(limit);
    }

    return _guardStream(
      query.snapshots().map((snapshot) {
        final events = <OutplantEvent>[];
        for (final doc in snapshot.docs) {
          try {
            final event = RecordFactory.eventFromJson(_injectDocId(doc));
            if (event is OutplantEvent) {
              events.add(event);
            }
          } catch (e, stackTrace) {
            LoggingService.instance.error(
              'Failed to parse outplant event ${doc.id}',
              e,
              stackTrace,
            );
          }
        }
        // Sort in-memory by createdAt descending (newest first)
        events.sort((a, b) {
          final dateA =
              DateTime.tryParse(a.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.createdAt) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        return events;
      }),
      debugLabel: 'streamOutplantEvents(siteId: $siteId)',
    );
  }

  /// Stream pending/shipped transfers addressed to the organization.
  ///
  /// These events are created by the sender organization, so we filter on
  /// `toOrganizationId` instead of `organizationId` to surface inbound transfers.
  Stream<List<TransferEvent>> streamPendingTransfers({
    List<String>? eventTypeIds,
  }) {
    final queryIds = eventTypeIds ?? LoanEventType.queryIds;

    // CRITICAL: Filter by toOrganizationId for inbound transfers
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return _guardStream(
      collectionRef
          .where('toOrganizationId', isEqualTo: organization.id)
          .where('eventTypeId', whereIn: queryIds)
          .where(
            'status',
            whereIn: [
              TransferStatus.pending.value,
              TransferStatus.shipped.value,
            ],
          )
          .snapshots()
          .map((snapshot) {
            final transfers = <TransferEvent>[];
            for (final doc in snapshot.docs) {
              try {
                final transferEvent = TransferEvent.fromJson(_injectDocId(doc));
                transfers.add(transferEvent);
              } catch (e, stackTrace) {
                LoggingService.instance.error(
                  'Error parsing TransferEvent from doc ${doc.id}',
                  e,
                  stackTrace,
                );
              }
            }
            // Sort in-memory by createdAt descending (newest first)
            transfers.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
            return transfers;
          }),
      debugLabel: 'streamPendingTransfers(toOrganizationId: ${organization.id})',
    );
  }

  /// Stream pending/shipped transfers created by the organization.
  ///
  /// Filters by `organizationId` and narrows to pending/shipped statuses
  /// in-memory to avoid adding a composite index.
  Stream<List<TransferEvent>> streamOutboundPendingTransfers({
    List<String>? eventTypeIds,
  }) {
    final queryIds = eventTypeIds ?? LoanEventType.queryIds;

    // CRITICAL: Must include organizationId filter to satisfy security rules
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return _guardStream(
      (collectionQuery(collectionRef) as Query<Map<String, dynamic>>)
          .where('eventTypeId', whereIn: queryIds)
          .snapshots()
          .map((snapshot) {
            final transfers = <TransferEvent>[];
            for (final doc in snapshot.docs) {
              try {
                final transferEvent = TransferEvent.fromJson(_injectDocId(doc));
                final status = transferEvent.status;
                if (status != TransferStatus.pending.value &&
                    status != TransferStatus.shipped.value) {
                  continue;
                }
                transfers.add(transferEvent);
              } catch (e, stackTrace) {
                LoggingService.instance.error(
                  'Error parsing TransferEvent from doc ${doc.id}',
                  e,
                  stackTrace,
                );
              }
            }
            // Sort in-memory by createdAt descending (newest first)
            transfers.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  DateTime.tryParse(b.createdAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
            return transfers;
          }),
      debugLabel:
          'streamOutboundPendingTransfers(organizationId: ${organization.id})',
    );
  }
}
