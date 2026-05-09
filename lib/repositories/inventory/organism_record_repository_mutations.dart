part of 'organism_record_repository.dart';

/// Mutation methods for OrganismRecordRepository.
///
/// Contains create, update, and state-changing operations that modify
/// organism records and emit corresponding events.
mixin _OrganismRecordRepositoryMutations
    on
        _OrganismRecordRepositoryBase,
        _OrganismRecordRepositoryHelpers,
        _OrganismRecordRepositoryQueries {
  @override
  Future<OrganismRecord> createRecord(
    OrganismRecord partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  }) async {
    // Validate before creating
    validateOrganismRecord(partialRecord);

    // Validate capacity before creating (defense-in-depth against race conditions)
    if (partialRecord.groupId != null && parent is Group) {
      await validateGroupCapacity(
        partialRecord.groupId!,
        partialRecord,
        parent,
      );
    }

    // Generate a user-friendly slug based on localGenetId instead of generic "organismRecord"
    final slugBase = generateSlugBase(partialRecord);
    final recordSlug = await nextSlugForBase(slugBase);

    // Create the record with the custom slug
    final batch = db.batch();
    final String recordId = generateId(firestore: db);

    final urlPath = '${parent.urlPath}/$recordSlug';
    final internalPath = '${parent.internalPath}/$recordId';

    final createdAt = DateTime.now();
    final createdAtIso = createdAt.toIso8601String();

    // Add initial custody history if not already present (transfers add their own)
    var recordMetadata = partialRecord.metadata ?? <String, dynamic>{};
    if (recordMetadata[CustodyHistoryService.custodyHistoryKey] == null) {
      recordMetadata = CustodyHistoryService.createMetadataWithInitialCustody(
        existingMetadata: recordMetadata,
        organization: organization,
        ownerOrganizationId: partialRecord.ownerOrganizationId,
        managingOrganizationId: partialRecord.managingOrganizationId,
        createdAt: createdAt,
      );
    }

    OrganismRecord fullRecord = partialRecord.copyWith(
      id: recordId,
      slug: recordSlug,
      urlPath: urlPath,
      internalPath: internalPath,
      organizationId: organization.id,
      createdById: user.id,
      updatedById: user.id,
      createdAt: createdAtIso,
      updatedAt: createdAtIso,
      metadata: recordMetadata,
    );

    // Set siteId and groupId from parent
    if (parent is Group) {
      fullRecord = fullRecord.copyWith(
        siteId: parent.siteId,
        groupId: parent.id,
      );
    } else if (parent is Site) {
      fullRecord = fullRecord.copyWith(siteId: parent.id, groupId: null);
    }

    // Sync foreignKeys['genetRecordId'] from top-level genetRecordId at write time
    fullRecord = _syncGenetIdForeignKey(fullRecord);

    final createEvent = await eventRepository.addCreateEvent(
      fullRecord,
      parent,
      batch,
      base: base,
    );

    if (!fullRecord.validate()) {
      throw RepositoryError(
        message: 'Record is not valid: ${fullRecord.toJson()}',
      );
    }

    batch.set(collectionRef.doc(recordId), fullRecord.toJson());

    LoggingService.instance.debug(
      'OrganismRecordRepository.createRecord: about to commit batch',
    );
    LoggingService.instance.debug(
      '   - slug: $recordSlug (from base: $slugBase)',
    );
    LoggingService.instance.debug('   - recordId: $recordId');

    try {
      await batch.commit();
      LoggingService.instance.debug(
        'OrganismRecordRepository.createRecord: batch commit succeeded!',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OrganismRecordRepository.createRecord: batch commit FAILED!',
        e,
        stackTrace,
      );
      rethrow;
    }

    try {
      await snapshotService.createAfterSnapshot(
        record: fullRecord,
        eventId: createEvent.id,
      );
    } catch (e) {
      LoggingService.instance.warning(
        'After-snapshot failed for record ${fullRecord.id}',
        e,
      );
    }

    return fullRecord;
  }

  @override
  Future<void> updateRecord(OrganismRecord record, {WriteBatch? batch}) async {
    // Validate before updating
    validateOrganismRecord(record);

    // Sync foreignKeys['genetRecordId'] from top-level genetRecordId at write time
    final synced = _syncGenetIdForeignKey(record);

    await super.updateRecord(synced, batch: batch);
  }

  /// Update record and emit appropriate events for all detected changes.
  ///
  /// This method compares [originalRecord] with [updatedRecord], updates
  /// the record in Firestore, then emits individual events for each type
  /// of change detected (life stage, physical form, size, quantity).
  ///
  /// Use this for comprehensive property edits that may change multiple
  /// fields at once (e.g., from OrganismRecordEditDialog).
  Future<List<Event>> updateRecordWithEvents(
    OrganismRecord originalRecord,
    OrganismRecord updatedRecord, {
    Map<String, dynamic>? eventMetadata,
  }) async {
    final changeSet = changeService.detectChanges(
      previous: originalRecord,
      next: updatedRecord,
    );

    if (!changeSet.hasChanges) {
      return []; // No changes to save
    }

    final createdEvents = <Event>[];

    // Set update timestamps
    final now = DateTime.now().toIso8601String();
    var recordToSave = updatedRecord.copyWith(
      updatedAt: now,
      updatedById: user.id,
    );

    // Append to life stage history if life stage changed
    if (changeSet.lifeStageChange != null) {
      final updatedHistory = updatedRecord.appendLifeStageTransition(
        updatedRecord.lifecycleStageSpec,
        occurredAt: DateTime.parse(now),
        recordedBy: user.id,
        notes: eventMetadata?['lifeStageReason'] as String?,
        sizeSnapshot: updatedRecord.sizeSpec,
      );
      recordToSave = recordToSave.copyWith(lifeStageHistory: updatedHistory);
    }

    // Create before-snapshot for audit trail (best-effort, before the batch)
    final auditEventId = generateId(firestore: db);
    try {
      await snapshotService.createBeforeSnapshot(
        record: originalRecord,
        eventId: auditEventId,
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Before-snapshot failed for record ${originalRecord.id}',
        e,
      );
    }

    // Create a WriteBatch for atomic record + event writes
    final batch = db.batch();

    // Update record within the batch
    await updateRecord(recordToSave, batch: batch);

    // Emit life stage transition event
    if (changeSet.lifeStageChange != null) {
      final change = changeSet.lifeStageChange!;
      final event = await eventRepository.createLifeStageTransitionEvent(
        recordId: recordToSave.id,
        recordUrlPath: recordToSave.urlPath,
        recordInternalPath: recordToSave.internalPath,
        snapshot: recordToSave,
        oldLifeStage: change.oldStage,
        newLifeStage: change.newStage,
        transitionReason: eventMetadata?['lifeStageReason'] as String?,
        metadata: eventMetadata,
        batch: batch,
      );
      createdEvents.add(event);
    }

    // Emit physical form change event
    if (changeSet.physicalFormChange != null) {
      final change = changeSet.physicalFormChange!;
      final event = await eventRepository.createPhysicalFormChangeEvent(
        recordId: recordToSave.id,
        recordUrlPath: recordToSave.urlPath,
        recordInternalPath: recordToSave.internalPath,
        snapshot: recordToSave,
        oldFormId: change.oldFormId,
        newFormId: change.newFormId,
        metadata: eventMetadata,
        batch: batch,
      );
      createdEvents.add(event);
    }

    // Emit size change event
    if (changeSet.sizeSpecChange != null) {
      final change = changeSet.sizeSpecChange!;
      final event = await eventRepository.createSizeChangeEvent(
        recordId: recordToSave.id,
        recordUrlPath: recordToSave.urlPath,
        recordInternalPath: recordToSave.internalPath,
        snapshot: recordToSave,
        oldSize: change.oldSize,
        newSize: change.newSize,
        metadata: eventMetadata,
        batch: batch,
      );
      createdEvents.add(event);
    }

    // Emit quantity change event
    if (changeSet.quantityChange != null) {
      final change = changeSet.quantityChange!;
      final event = await eventRepository.createQuantityChangeEvent(
        recordId: recordToSave.id,
        recordUrlPath: recordToSave.urlPath,
        recordInternalPath: recordToSave.internalPath,
        snapshot: recordToSave,
        oldMeasurement: change.oldMeasurement,
        newMeasurement: change.newMeasurement,
        metadata: eventMetadata,
        batch: batch,
      );
      createdEvents.add(event);
    }

    // Note: Identity change events (tagId, localGenetId, ownership) are emitted
    // by the cubit's _emitIdentityChangeEvents() with proper EventType constants.
    // Do NOT create observation events for these changes here to avoid duplicates.

    // Emit alias change event (aliases are not identity - still use observation)
    if (changeSet.aliasesChanged) {
      final event = await eventRepository.createObservationEvent(
        forRecord: recordToSave,
        comment: 'Aliases updated',
        batch: batch,
      );
      createdEvents.add(event);
    }

    // Commit all record + event writes atomically
    await batch.commit();

    // Create snapshots OUTSIDE the batch (supplementary audit data, best-effort)
    for (final event in createdEvents) {
      try {
        await snapshotService.createAfterSnapshot(
          record: recordToSave,
          eventId: event.id,
        );
      } catch (e) {
        LoggingService.instance.warning(
          'After-snapshot failed for record ${recordToSave.id}',
          e,
        );
      }
    }

    return createdEvents;
  }

  /// Update size and create SizeChangeEvent.
  Future<OrganismSizeChangePayload> updateSize(
    OrganismRecord organism,
    SizeSpec newSize, {
    String? comment,
  }) async {
    LoggingService.instance.debug('OrganismRecordRepository.updateSize called');
    LoggingService.instance.debug('   - organism.id: ${organism.id}');
    LoggingService.instance.debug(
      '   - organism.organizationId: ${organism.organizationId}',
    );
    LoggingService.instance.debug('   - user.id (updatedById): ${user.id}');
    LoggingService.instance.debug('   - organization.id: ${organization.id}');

    final oldSize = organism.sizeSpec;
    final now = DateTime.now().toIso8601String();

    final updatedOrganism = organism.copyWith(
      sizeSpec: newSize,
      updatedAt: now,
      updatedById: user.id,
    );

    // Create a WriteBatch for atomic record + event writes
    final batch = db.batch();

    // Update record within the batch
    LoggingService.instance.debug('   - Step 1: Updating organism record...');
    await updateRecord(updatedOrganism, batch: batch);

    // Create SizeChangeEvent within the batch
    LoggingService.instance.debug('   - Step 2: Creating SizeChangeEvent...');
    final event = await eventRepository.createSizeChangeEvent(
      recordId: organism.id,
      recordUrlPath: organism.urlPath,
      recordInternalPath: organism.internalPath,
      snapshot: updatedOrganism,
      oldSize: oldSize,
      newSize: newSize,
      metadata: comment != null ? {'comment': comment} : null,
      batch: batch,
    );
    LoggingService.instance.debug('   SizeChangeEvent created: ${event.id}');

    // Commit all record + event writes atomically
    await batch.commit();

    // Create snapshot OUTSIDE the batch (supplementary audit data, best-effort)
    try {
      LoggingService.instance.debug('   - Step 3: Creating after snapshot...');
      await snapshotService.createAfterSnapshot(
        record: updatedOrganism,
        eventId: event.id,
      );
      LoggingService.instance.debug('   After snapshot created');
    } catch (e) {
      LoggingService.instance.warning(
        'After-snapshot failed for record ${updatedOrganism.id}',
        e,
      );
    }

    return OrganismSizeChangePayload(
      event: event,
      updatedRecord: updatedOrganism,
    );
  }

  /// Update population and return event with updated organism for propagation.
  Future<OrganismPopulationChangePayload> updatePopulation(
    OrganismRecord organism,
    int newQuantity, {
    PopulationLossReason? lossReason,
    PopulationLossReason? mortalityReason,
    String? diseaseTypeId,
    PopulationGainReason? gainReason,
    String? comment,
    WriteBatch? batch,
  }) async {
    if (newQuantity < 0) {
      throw RepositoryError(
        message: 'Organism cannot have a negative quantity',
      );
    }

    final currentQuantity = organism.measurement.value.toInt();
    if (newQuantity == currentQuantity) {
      throw RepositoryError(
        message: 'New quantity must be different from the current quantity',
      );
    }

    final isGain = newQuantity > currentQuantity;
    final eventId = generateId(firestore: db);
    final eventSlug = await nextSlugForModelType(ModelType.event);
    final now = DateTime.now().toIso8601String();

    InventoryEvent event;
    late OrganismRecord updatedOrganism;

    // Use provided batch or create a new one
    final ownsBatch = batch == null;
    final writeBatch = batch ?? db.batch();

    if (isGain) {
      if (gainReason == null) {
        throw RepositoryError(
          message: 'Gain reason is required for population increases',
        );
      }

      updatedOrganism = organism.copyWith(
        measurement: organism.measurement.copyWith(
          value: newQuantity.toDouble(),
        ),
        updatedAt: now,
        updatedById: user.id,
      );
      await updateRecord(updatedOrganism, batch: writeBatch);

      event = PopulationGainEvent(
        id: eventId,
        createdById: user.id,
        createdAt: now,
        recordId: organism.id,
        recordModelType: ModelType.organismRecord,
        urlPath: '${organism.urlPath}/$eventSlug',
        internalPath: '${organism.internalPath}/$eventId',
        slug: eventSlug,
        oldPopulation: currentQuantity,
        newPopulation: newQuantity,
        snapshot: organism,
        eventTypeId: InventoryEventType.populationGain.id,
        gainReasonId: gainReason.id,
        comment: comment,
        updatedAt: now,
        updatedById: user.id,
        organizationId: organization.id,
      );
    } else {
      if (lossReason == null) {
        throw RepositoryError(
          message: 'Loss reason is required for population decreases',
        );
      }

      // Create standard PopulationLossEvent
      InventoryEvent populationLossEvent = PopulationLossEvent(
        id: eventId,
        createdById: user.id,
        createdAt: now,
        recordId: organism.id,
        recordModelType: ModelType.organismRecord,
        urlPath: '${organism.urlPath}/$eventSlug',
        internalPath: '${organism.internalPath}/$eventId',
        slug: eventSlug,
        oldPopulation: currentQuantity,
        newPopulation: newQuantity,
        snapshot: organism,
        eventTypeId: InventoryEventType.populationLoss.id,
        lossReasonId: lossReason.id,
        comment: comment,
        updatedAt: now,
        updatedById: user.id,
        organizationId: organization.id,
      );

      // Wrap as MortalityEvent if mortality reason is provided (nursery mortalities)
      if (mortalityReason != null) {
        populationLossEvent = MortalityEvent.fromPopulationLossEvent(
          populationLossEvent as PopulationLossEvent,
          mortalityReasonId: mortalityReason.id,
          diseaseTypeId: diseaseTypeId,
        );
      }

      if (newQuantity == 0) {
        final archiveMetadata = _buildArchiveMetadata(
          archivedAt: now,
          archivedById: user.id,
          lossReason: mortalityReason ?? lossReason,
        );
        updatedOrganism = organism.copyWith(
          measurement: organism.measurement.copyWith(
            value: newQuantity.toDouble(),
          ),
          metadata: _mergeMetadata(organism.metadata, archiveMetadata),
          updatedAt: now,
          updatedById: user.id,
        );
        await updateRecord(updatedOrganism, batch: writeBatch);
      } else {
        updatedOrganism = organism.copyWith(
          measurement: organism.measurement.copyWith(
            value: newQuantity.toDouble(),
          ),
          updatedAt: now,
          updatedById: user.id,
        );
        await updateRecord(updatedOrganism, batch: writeBatch);
      }

      event = populationLossEvent;
    }

    await eventRepository.createEvent(event, batch: writeBatch);

    // Only commit if this method owns the batch
    if (ownsBatch) {
      await writeBatch.commit();
    }

    if (ownsBatch) {
      try {
        await snapshotService.createAfterSnapshot(
          record: updatedOrganism,
          eventId: eventId,
        );
      } catch (e) {
        LoggingService.instance.warning(
          'After-snapshot failed for record ${updatedOrganism.id}',
          e,
        );
      }
    }

    return OrganismPopulationChangePayload(
      event: event,
      updatedRecord: updatedOrganism,
    );
  }

  /// Update the measurement for an organism record and emit a quantity change event.
  ///
  /// This is the canonical entry point for management dialogs that record partial
  /// removals or measurement adjustments across organism kinds. It keeps event
  /// metadata in sync and appends measurement history snapshots for auditing.
  Future<OrganismQuantityChangePayload> updateMeasurement({
    required OrganismRecord organism,
    required PopulationMeasurement newMeasurement,
    PopulationLossReason? lossReason,
    PopulationGainReason? gainReason,
    String? comment,
    bool archiveWhenZero = true,
  }) async {
    if (newMeasurement.value < 0) {
      throw RepositoryError(message: 'Measurement cannot be negative.');
    }

    final oldMeasurement = organism.measurement;
    final unitsMatchCategory =
        newMeasurement.unit.category == oldMeasurement.unit.category;
    if (!unitsMatchCategory) {
      throw RepositoryError(
        message:
            'Cannot change measurement unit category from ${oldMeasurement.unit.label} to ${newMeasurement.unit.label}.',
        category: AppErrorCategory.validation,
      );
    }

    final shouldArchive = archiveWhenZero && newMeasurement.value <= 0;
    var updatedRecord = organism.copyWith(
      measurement: newMeasurement,
      measurementHistory: organism.appendMeasurementSnapshot(
        measurement: newMeasurement,
        notes: comment?.isNotEmpty == true ? comment : null,
        source: 'organism_management_dialog.remove',
      ),
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: user.id,
    );
    if (shouldArchive) {
      final archiveMetadata = _buildArchiveMetadata(
        archivedAt: updatedRecord.updatedAt,
        archivedById: user.id,
        lossReason: lossReason,
      );
      updatedRecord = updatedRecord.copyWith(
        metadata: _mergeMetadata(updatedRecord.metadata, archiveMetadata),
      );
    }

    changeService.assertImmutableFields(
      previous: organism,
      next: updatedRecord,
    );
    final changeSet = changeService.detectChanges(
      previous: organism,
      next: updatedRecord,
    );

    if (changeSet.quantityChange == null) {
      throw RepositoryError(message: 'No measurement change detected.');
    }

    // Create batch for atomic operations
    final batch = db.batch();

    // Update the organism record (archived records remain in the active collection)
    await updateRecord(updatedRecord, batch: batch);

    final metadata =
        <String, dynamic>{
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (lossReason != null) 'lossReasonId': lossReason.id,
          if (gainReason != null) 'gainReasonId': gainReason.id,
        }..removeWhere(
          (_, value) => value == null || (value is String && value.isEmpty),
        );

    // Create quantity change event within batch
    final slug = await eventRepository.nextSlugForModelType(ModelType.event);
    final eventId = generateId(firestore: db);
    final now = DateTime.now().toIso8601String();
    var quantityEvent = QuantityChangeEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: '${updatedRecord.urlPath}/$slug',
      internalPath: '${updatedRecord.internalPath}/$eventId',
      slug: slug,
      recordId: updatedRecord.id,
      recordModelType: ModelType.organismRecord,
      organismRecordSnapshot: updatedRecord,
      oldMeasurement: oldMeasurement,
      newMeasurement: newMeasurement,
      metadata: metadata.isEmpty ? null : metadata,
    );

    // Add organism metadata enrichment
    final resolvedGenetId = GenetIdResolver.resolve(updatedRecord);
    final enrichedMetadata = <String, dynamic>{
      ...quantityEvent.metadata ?? {},
      'organismKind': organismContext.kind.name,
      'speciesId': updatedRecord.speciesId,
      'siteId': updatedRecord.siteId,
      'groupId': updatedRecord.groupId,
      if (resolvedGenetId != null) 'genetRecordId': resolvedGenetId,
      if (updatedRecord.lifeStage.stage.id.isNotEmpty)
        'lifeStageId': updatedRecord.lifeStage.stage.id,
    };
    final enrichedJson = quantityEvent.toJson();
    enrichedJson['metadata'] = enrichedMetadata;
    quantityEvent = QuantityChangeEvent.fromJson(enrichedJson);

    await eventRepository.createEvent(quantityEvent, batch: batch);

    // Commit all operations atomically
    await batch.commit();

    // Create snapshot after successful commit (best-effort)
    try {
      await snapshotService.createAfterSnapshot(
        record: updatedRecord,
        eventId: quantityEvent.id,
      );
    } catch (e) {
      LoggingService.instance.warning(
        'After-snapshot failed for record ${updatedRecord.id}',
        e,
      );
    }

    return OrganismQuantityChangePayload(
      event: quantityEvent,
      updatedRecord: updatedRecord,
    );
  }

  Map<String, dynamic> _buildArchiveMetadata({
    required String archivedAt,
    required String archivedById,
    PopulationLossReason? lossReason,
  }) {
    final reasonType = _archiveReasonType(lossReason);
    final metadata = <String, dynamic>{
      kArchivedFlagKey: true,
      kArchivedAtKey: archivedAt,
      kArchivedByIdKey: archivedById,
      kArchivedReasonTypeKey: reasonType,
      if (lossReason != null) kArchivedReasonIdKey: lossReason.id,
    };
    return metadata;
  }

  Map<String, dynamic> _mergeMetadata(
    Map<String, dynamic>? existing,
    Map<String, dynamic> additions,
  ) {
    final merged = <String, dynamic>{...existing ?? const {}};
    merged.addAll(additions);
    return merged;
  }

  String _archiveReasonType(PopulationLossReason? reason) {
    if (_isMortalityReason(reason)) {
      return kArchiveReasonTypeMortality;
    }
    return kArchiveReasonTypeDeleted;
  }

  bool _isMortalityReason(PopulationLossReason? reason) {
    if (reason == null) return false;
    return reason.isMortality;
  }

  /// Ensures foreignKeys['genetRecordId'] is set with a ForeignKeyReference when
  /// the top-level genetRecordId is present. This is the single write-time sync
  /// point for genet ID consistency.
  OrganismRecord _syncGenetIdForeignKey(OrganismRecord record) {
    final topLevelGenetId = record.genetRecordId;
    if (topLevelGenetId == null || topLevelGenetId.isEmpty) {
      return record;
    }

    final existingRef = record.foreignKeys['genetRecordId'];
    // Already synced and matches
    if (existingRef != null && existingRef.id == topLevelGenetId) {
      return record;
    }

    // Build a ForeignKeyReference from the existing one (preserving metadata)
    // or create a minimal one with just the ID.
    final updatedForeignKeys = Map<String, ForeignKeyReference>.from(
      record.foreignKeys,
    );
    updatedForeignKeys['genetRecordId'] = ForeignKeyReference(
      id: topLevelGenetId,
      metadata: existingRef?.metadata ?? const <String, dynamic>{},
    );

    return record.copyWith(foreignKeys: updatedForeignKeys);
  }

  /// Update the localGenetId for all organism records sharing the same genet.
  ///
  /// Used when user chooses "All records" in the LocalID edit scope dialog.
  /// Returns the number of records updated.
  ///
  /// For datasets <= 500 records, uses a Firestore transaction for true
  /// atomicity. For larger datasets, uses batches with 500-operation chunks.
  Future<int> updateLocalIdGenetWide({
    required String genetRecordId,
    required String newLocalId,
    required String updatedById,
  }) async {
    final trimmedGenetId = genetRecordId.trim();
    final trimmedLocalId = newLocalId.trim();

    if (trimmedGenetId.isEmpty) {
      LoggingService.instance.warning(
        'updateLocalIdGenetWide called with empty genetRecordId',
      );
      return 0;
    }

    if (trimmedLocalId.isEmpty) {
      throw RepositoryError(
        message: 'Cannot update localGenetId to an empty value.',
        category: AppErrorCategory.validation,
      );
    }

    try {
      // Get all organism records with this genetRecordId
      final snapshot = await collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('genetRecordId', isEqualTo: trimmedGenetId)
          .get();

      if (snapshot.docs.isEmpty) {
        LoggingService.instance.warning(
          'No organism records found for genet: $trimmedGenetId',
        );
        return 0;
      }

      final now = DateTime.now().toIso8601String();
      final totalDocs = snapshot.docs.length;

      // Firestore transactions/batches have a 500 operation limit
      const transactionLimit = 500;

      // For small datasets, use a transaction for true atomicity
      if (totalDocs <= transactionLimit) {
        final updatedCount = await db.runTransaction<int>((transaction) async {
          for (final doc in snapshot.docs) {
            transaction.update(doc.reference, {
              'localGenetId': trimmedLocalId,
              'updatedAt': now,
              'updatedById': updatedById,
            });
          }
          return totalDocs;
        });

        LoggingService.instance.info(
          'Updated localGenetId to "$trimmedLocalId" for $updatedCount records '
          '(genetRecordId: $trimmedGenetId) using transaction',
        );

        return updatedCount;
      }

      // For larger datasets, use batches (atomic per batch but not across all)
      var updatedCount = 0;

      for (var i = 0; i < totalDocs; i += transactionLimit) {
        final batch = db.batch();
        final endIndex = (i + transactionLimit < totalDocs)
            ? i + transactionLimit
            : totalDocs;

        for (var j = i; j < endIndex; j++) {
          batch.update(snapshot.docs[j].reference, {
            'localGenetId': trimmedLocalId,
            'updatedAt': now,
            'updatedById': updatedById,
          });
        }

        await batch.commit();
        updatedCount += (endIndex - i);
      }

      LoggingService.instance.info(
        'Updated localGenetId to "$trimmedLocalId" for $updatedCount records '
        '(genetRecordId: $trimmedGenetId) using ${(totalDocs / transactionLimit).ceil()} batches',
      );

      return updatedCount;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error updating localGenetId genet-wide for genetRecordId: $trimmedGenetId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
