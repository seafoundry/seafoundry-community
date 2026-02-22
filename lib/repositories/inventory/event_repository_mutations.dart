// @tier: community
part of 'event_repository.dart';

mixin _EventRepositoryMutations on _EventRepositoryBase, _EventRepositoryHelpers {
  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<ObservationEvent> createObservationEvent({
    required InventoryRecord forRecord,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    bool createTask = false,
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
      createTask: createTask,
      updatedAt: updatedAtIso,
      updatedById: user.id,
      organizationId: organization.id,
    );

    observationEvent = withOrganismMetadata(observationEvent);
    await createEvent(observationEvent, batch: batch);

    return observationEvent;
  }

  @override
  Future<MonitoringEventRecord> createMonitoringEvent({
    required InventoryRecord forRecord,
    String? comment,
    String? imageUrl,
    String? oldHealthStatus,
    String? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? siteId,
    DateTime? monitoringDate,
    List<String>? organismIds,
    List<String>? coralIds,
    bool createTask = false,
    OutplantGeometry? outplantGeometry,
    List<MonitoringEntry> entries = const [],
    int? totalCount,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final String eventSlug = await nextSlugForModelType(ModelType.event);
    final String eventId = generateId(firestore: db);
    final now = _isoNow();

    var monitoringEvent = MonitoringEventRecord(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      recordId: forRecord.id,
      urlPath: '${forRecord.urlPath}/$eventSlug',
      internalPath: '${forRecord.internalPath}/$eventId',
      slug: eventSlug,
      recordModelType: forRecord.modelType,
      comment: comment,
      imageUrl: imageUrl,
      oldHealthStatus: oldHealthStatus,
      newHealthStatus: newHealthStatus,
      healthIssueTypeId: healthIssueTypeId,
      percentCover: percentCover,
      percentBleaching: percentBleaching,
      percentDisease: percentDisease,
      measurements: measurements,
      siteId: siteId,
      monitoringDate: monitoringDate,
      organismIds: organismIds ?? coralIds,
      createTask: createTask,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      outplantGeometry: outplantGeometry,
      entries: entries.isEmpty
          ? const []
          : List<MonitoringEntry>.from(entries, growable: false),
      totalCount: totalCount ?? entries.length,
      base: base,
    );

    monitoringEvent = withOrganismMetadata(monitoringEvent);
    await createEvent(monitoringEvent);

    return monitoringEvent;
  }

  @override
  Future<PropagationEvent> createPropagationEvent({
    required Site site,
    required List<OrganismRecord> inputOrganisms,
    required List<OrganismRecord> outputOrganisms,
    int? inputQuantityOverride,
    int? outputQuantityOverride,
    Map<String, dynamic>? additionalMetadata,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final batch = db.batch();
    final String eventSlug = await nextSlugForModelType(ModelType.event);
    final String eventId = generateId(firestore: db);

    final int resolvedInputQuantity = inputQuantityOverride ??
        inputOrganisms.fold(
          0,
          (total, organism) => total + organism.measurement.value.round(),
        );
    final int resolvedOutputQuantity = outputQuantityOverride ??
        outputOrganisms.fold(
          0,
          (total, organism) => total + organism.measurement.value.round(),
        );

    // Validate that input organisms have a genet ID
    final genetId = GenetIdResolver.resolve(inputOrganisms.first);
    if (genetId == null) {
      throw StateError('Input organism has no genet ID');
    }

    var propagationEvent = PropagationEvent(
      id: eventId,
      createdById: user.id,
      createdAt: _isoNow(),
      genetId: genetId,
      inputOrganismIds: inputOrganisms.map((organism) => organism.id).toList(),
      outputOrganismIds: outputOrganisms
          .map((organism) => organism.id)
          .toList(),
      inputQuantity: resolvedInputQuantity,
      outputQuantity: resolvedOutputQuantity,
      recordId: site.id,
      recordModelType: ModelType.site,
      urlPath: '${site.urlPath}/$eventSlug',
      internalPath: '${site.internalPath}/$eventId',
      slug: eventSlug,
      updatedAt: _isoNow(),
      updatedById: user.id,
      organizationId: organization.id,
      base: base,
    );
    final metadata = <String, dynamic>{
      if (inputOrganisms.isNotEmpty)
        ..._organismRecordMetadata(inputOrganisms.first.id, inputOrganisms.first),
      ...?additionalMetadata,
    };
    propagationEvent = withOrganismMetadata(
      propagationEvent,
      additionalMetadata: metadata.isEmpty ? null : metadata,
    );
    batch.set(collectionRef.doc(eventId), propagationEvent.toJson());

    for (final organism in outputOrganisms) {
      final String recentPropagationEventId = generateId(firestore: db);
      final String recentPropagationEventSlug = await nextSlugForModelType(
        ModelType.event,
      );
      var recentPropagationEvent = RecentPropagationStatus(
        id: recentPropagationEventId,
        createdById: user.id,
        createdAt: _isoNow(),
        recordId: organism.id,
        recordModelType: ModelType.organismRecord,
        urlPath: '${organism.urlPath}/$recentPropagationEventSlug',
        internalPath: '${organism.internalPath}/$recentPropagationEventId',
        slug: recentPropagationEventSlug,
        updatedAt: _isoNow(),
        updatedById: user.id,
        organizationId: organization.id,
        propagationEventId: eventId,
        subEventIds: [],
      );
      recentPropagationEvent = withOrganismMetadata(recentPropagationEvent);
      batch.set(
        collectionRef.doc(recentPropagationEvent.id),
        recentPropagationEvent.toJson(),
      );
    }

    await batch.commit();

    return propagationEvent;
  }

  @override
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
    String? funderId,
    String? attachmentMethodId,
    String? missionId,
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
      funderId: funderId,
      attachmentMethodId: attachmentMethodId,
      missionId: missionId,
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

  @override
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

  @override
  Future<void> updateEventPhotos({
    required String eventId,
    required List<String> photoUrls,
    String? imageUrl,
    WriteBatch? batch,
  }) async {
    final now = _isoNow();
    final payload = <String, Object?>{
      'photoUrls': photoUrls,
      'updatedAt': now,
      'updatedById': user.id,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    final docRef = collectionRef.doc(eventId);
    if (batch != null) {
      batch.update(docRef, payload);
    } else {
      await docRef.update(payload);
    }
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

  @override
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

  @override
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
      await _maybeIncrementHealthIssueSummary(enrichedEvent, batch: batch);
    } else {
      await collectionRef.doc(enrichedEvent.id).set(enrichedEvent.toJson());
      await _maybeIncrementHealthIssueSummary(enrichedEvent);
    }
    return EventFactory.eventFromJson(enrichedEvent.toJson());
  }

  Future<void> _maybeIncrementHealthIssueSummary(
    Event event, {
    WriteBatch? batch,
  }) async {
    if (!_shouldIncrementHealthIssueSummary(event)) return;

    final eventDate = _resolveEventDate(event);
    final summaryRef = _healthIssuesDailyDocRef(eventDate);
    final payload = <String, Object?>{
      'summaryType': _healthIssuesDailySummaryType,
      'date': DateTimeConverter.formatDate(eventDate),
      'count': FieldValue.increment(1),
      'updatedAt': _isoNow(),
      'organizationId': organization.id,
    };

    try {
      if (batch != null) {
        batch.set(summaryRef, payload, SetOptions(merge: true));
      } else {
        await summaryRef.set(payload, SetOptions(merge: true));
      }
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to update health issue summary',
        error,
        stackTrace,
      );
    }
  }

  bool _shouldIncrementHealthIssueSummary(Event event) {
    if (event is MonitoringEventRecord) {
      return event.newHealthStatusEnum != null &&
          event.newHealthStatusEnum != HealthStatus.healthy;
    }
    if (event is ObservationEvent) {
      return event.newHealthStatusEnum != null &&
          event.newHealthStatusEnum != HealthStatus.healthy;
    }
    return false;
  }

  DateTime _resolveEventDate(Event event) {
    return DateTimeConverter.fromIso8601String(event.createdAt) ??
        DateTime.now();
  }

  @override
  Future<CorrectionEvent> createCorrectionEvent({
    required Event originalEvent,
    required Event correctedEvent,
    required EventType correctionType,
    String? notes,
  }) async {
    final correctionId = generateId(firestore: db);
    final correctionSlug = await nextSlugForModelType(ModelType.event);
    final now = _isoNow();

    String deriveRecordUrl(String urlPath) {
      final segments = urlPath.split('/')..removeLast();
      return segments.join('/');
    }

    final recordUrlPath = deriveRecordUrl(correctedEvent.urlPath);
    final recordInternalPath = deriveRecordUrl(correctedEvent.internalPath);

    var correctionEvent = CorrectionEvent(
      id: correctionId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '$recordUrlPath/$correctionSlug',
      internalPath: '$recordInternalPath/$correctionId',
      slug: correctionSlug,
      recordId: correctedEvent.recordId,
      recordModelType: correctedEvent.recordModelType,
      originalEventId: originalEvent.id,
      correctedEventId: correctedEvent.id,
      notes: notes,
      eventTypeId: correctionType.id,
    );

    correctionEvent = withOrganismMetadata(correctionEvent);
    await createEvent(correctionEvent);
    return correctionEvent;
  }

  /// Create a correction event for an inventory record update
  ///
  /// This creates a CorrectionEvent that references the original record ID
  /// rather than original event ID, since inventory record corrections
  /// are about the record itself, not a specific event.
  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  Future<PopulationLossEvent> createPopulationLossEvent({
    required String recordId,
    required String recordUrlPath,
    required String recordInternalPath,
    required OrganismRecord snapshot,
    required int oldPopulation,
    required int newPopulation,
    required String lossReasonId,
    String? comment,
    Map<String, dynamic>? metadata,
    WriteBatch? batch,
  }) async {
    final slug = await nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = _isoNow();
    var event = PopulationLossEvent(
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
      snapshot: snapshot,
      oldPopulation: oldPopulation,
      newPopulation: newPopulation,
      lossReasonId: lossReasonId,
      comment: comment,
      metadata: metadata,
      eventTypeId: InventoryEventType.populationLoss.id,
    );
    event = withOrganismMetadata(
      event,
      additionalMetadata: _organismRecordMetadata(recordId, snapshot),
    );
    await createEvent(event, batch: batch);
    return event;
  }
}
