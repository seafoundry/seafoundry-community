// @tier: community
part of 'organism_record_repository.dart';

/// Status update methods for OrganismRecordRepository.
///
/// Contains methods for updating organism status fields like health,
/// propagation readiness, archive state, outplant status, and transfer locks.
mixin _OrganismRecordRepositoryStatus
    on
        _OrganismRecordRepositoryBase,
        _OrganismRecordRepositoryHelpers,
        _OrganismRecordRepositoryMutations {
  /// Update health status and create observation event.
  @override
  Future<OrganismHealthStatusPayload> updateHealthStatus(
    OrganismRecord organism,
    String newStatusId, {
    required String updatedById,
    String? comment,
    String? imageUrl,
  }) async {
    LoggingService.instance.info(
      'Updating health status for organism ${organism.id} from ${organism.healthStatus.id} to $newStatusId',
    );
    final oldStatusId = organism.healthStatus.id;

    if (oldStatusId == newStatusId) {
      // No change, create a simple observation event
      final observationEvent = await eventRepository.createObservationEvent(
        forRecord: organism,
        comment: comment,
        imageUrl: imageUrl,
        oldHealthStatus: oldStatusId,
        newHealthStatus: newStatusId,
      );

      return OrganismHealthStatusPayload(
        event: observationEvent,
        updatedRecord: organism,
      );
    }

    final now = DateTime.now().toIso8601String();
    final updatedHealthStatus = HealthStatus.fromId(newStatusId);

    // Clear readyForPropagation and readyForOutplant flags if health becomes unhealthy
    final shouldClearFlags = !updatedHealthStatus.isHealthy;
    final updatedMetadata = {
      ...organism.metadata ?? {},
      'healthStatus': newStatusId,
      if (shouldClearFlags) ...{
        'readyForPropagation': false,
        'readyForOutplant': false,
      },
    };

    final updatedOrganism = organism.copyWith(
      metadata: updatedMetadata,
      updatedAt: now,
      updatedById: updatedById,
    );

    // Update record first
    await updateRecord(updatedOrganism);

    // Create observation event
    final observationEvent = await eventRepository.createObservationEvent(
      forRecord: updatedOrganism,
      comment: comment,
      imageUrl: imageUrl,
      oldHealthStatus: oldStatusId,
      newHealthStatus: newStatusId,
    );

    await snapshotService.createAfterSnapshot(
      record: updatedOrganism,
      eventId: observationEvent.id,
    );

    return OrganismHealthStatusPayload(
      event: observationEvent,
      updatedRecord: updatedOrganism,
    );
  }

  /// Update health status without creating an observation event.
  ///
  /// Uses optimistic concurrency control to prevent race conditions when
  /// multiple users update the same organism simultaneously. If the record
  /// was modified since it was last read, throws [ConcurrentModificationException].
  @override
  Future<OrganismRecord> updateHealthStatusWithoutEvent(
    OrganismRecord organism,
    String newStatusId, {
    required String updatedById,
  }) async {
    LoggingService.instance.info(
      'Updating health status (no event) for organism ${organism.id} '
      'from ${organism.healthStatus.id} to $newStatusId',
    );
    final oldStatusId = organism.healthStatus.id;
    if (oldStatusId == newStatusId) {
      return organism;
    }

    // Optimistic concurrency check: verify record hasn't been modified
    final currentDoc = await collectionRef.doc(organism.id).get();
    if (currentDoc.exists) {
      final currentData = currentDoc.data();
      final currentUpdatedAtRaw = currentData?['updatedAt'];
      if (currentUpdatedAtRaw != null && organism.updatedAt.isNotEmpty) {
        final currentUpdatedAt = DateTime.tryParse(currentUpdatedAtRaw.toString());
        final expectedUpdatedAt = DateTime.tryParse(organism.updatedAt);

        if (currentUpdatedAt != null &&
            expectedUpdatedAt != null &&
            currentUpdatedAt.isAfter(expectedUpdatedAt)) {
          throw ConcurrentModificationException(
            message:
                'Record was modified by another user. Please refresh and try again.',
            recordId: organism.id,
            expectedUpdatedAt: expectedUpdatedAt,
            actualUpdatedAt: currentUpdatedAt,
            context: {
              'organismId': organism.id,
              'expectedUpdatedAt': organism.updatedAt,
              'actualUpdatedAt': currentUpdatedAtRaw.toString(),
            },
          );
        }
      }
    }

    final now = DateTime.now().toIso8601String();
    final updatedHealthStatus = HealthStatus.fromId(newStatusId);
    final shouldClearFlags = !updatedHealthStatus.isHealthy;
    final updatedMetadata = {
      ...organism.metadata ?? {},
      'healthStatus': newStatusId,
      if (shouldClearFlags) ...{
        'readyForPropagation': false,
        'readyForOutplant': false,
      },
    };

    final updatedOrganism = organism.copyWith(
      metadata: updatedMetadata,
      updatedAt: now,
      updatedById: updatedById,
    );

    await updateRecord(updatedOrganism);
    return updatedOrganism;
  }

  /// Update propagation ready status and create PropagationReadyStatus event.
  @override
  Future<OrganismPropagationReadyPayload> updatePropagationReadyStatus(
    OrganismRecord organism,
    bool isReady, {
    String? comment,
  }) async {
    final now = DateTime.now().toIso8601String();
    final updatedMetadata = {
      ...organism.metadata ?? {},
      'readyForPropagation': isReady,
    };

    final updatedOrganism = organism.copyWith(
      metadata: updatedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    // Update record first
    await updateRecord(updatedOrganism);

    // Create PropagationReadyStatus event
    final eventId = generateId(firestore: db);
    final eventSlug = await nextSlugForModelType(ModelType.event);
    final genetId = GenetIdResolver.resolve(organism) ?? '';

    final event = PropagationReadyStatus(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      recordId: organism.id,
      recordModelType: ModelType.organismRecord,
      urlPath: '${organism.urlPath}/$eventSlug',
      internalPath: '${organism.internalPath}/$eventId',
      slug: eventSlug,
      genetId: genetId,
      subEventIds: [],
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      metadata: comment != null ? {'comment': comment} : null,
    );

    await eventRepository.createEvent(event);
    await snapshotService.createAfterSnapshot(
      record: updatedOrganism,
      eventId: eventId,
    );

    return OrganismPropagationReadyPayload(
      event: event,
      updatedRecord: updatedOrganism,
    );
  }

  /// Update propagation ready status without creating an event.
  @override
  Future<OrganismRecord> updatePropagationReadyStatusWithoutEvent(
    OrganismRecord organism,
    bool isReady, {
    required String updatedById,
  }) async {
    if (organism.readyForPropagation == isReady) {
      return organism;
    }

    final now = DateTime.now().toIso8601String();
    final updatedMetadata = {
      ...organism.metadata ?? {},
      'readyForPropagation': isReady,
    };

    final updatedOrganism = organism.copyWith(
      metadata: updatedMetadata,
      updatedAt: now,
      updatedById: updatedById,
    );

    await updateRecord(updatedOrganism);
    return updatedOrganism;
  }

  /// Archive an organism record.
  ///
  /// Marks the organism record as archived by setting the archived flag to true
  /// and recording the timestamp. Archived records will be filtered out from
  /// active inventory views but can be restored.
  @override
  Future<void> archiveOrganismRecord(String organismRecordId) async {
    final record = await getRecordForId(organismRecordId);
    if (record == null) {
      throw RepositoryError(
        message: 'Organism $organismRecordId not found for archival.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final metadata = <String, dynamic>{
      ...record.metadata ?? const {},
      kArchivedFlagKey: true,
      kArchivedAtKey: now,
      kArchivedByIdKey: user.id,
      kArchivedReasonTypeKey: kArchiveReasonTypeDeleted,
    };

    final archivedRecord = record.copyWith(
      metadata: metadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = db.batch();
    await updateRecord(archivedRecord, batch: batch);
    await batch.commit();
  }

  /// Restore an archived organism record.
  ///
  /// Removes the archived flag and timestamp, allowing the organism record
  /// to appear in active inventory views again.
  @override
  Future<void> restoreOrganismRecord(String organismRecordId) async {
    final archivedSnapshot =
        await archivedCollectionRef.doc(organismRecordId).get();
    OrganismRecord? record;
    if (archivedSnapshot.exists) {
      final data = archivedSnapshot.data();
      if (data != null) {
        data['id'] = archivedSnapshot.id;
        record = RecordFactory.recordFromJson<OrganismRecord>(data);
      }
    } else {
      record = await getRecordForId(organismRecordId);
    }

    if (record == null) {
      throw RepositoryError(
        message: 'Organism $organismRecordId not found for restore.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final cleanedMetadata = <String, dynamic>{
      ...record.metadata ?? const {},
    }
      ..remove(kArchivedFlagKey)
      ..remove(kArchivedAtKey)
      ..remove(kArchivedByIdKey)
      ..remove(kArchivedReasonTypeKey)
      ..remove(kArchivedReasonIdKey)
      ..remove('isDeleted');

    final restored = record.copyWith(
      metadata: cleanedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = db.batch();
    batch.set(collectionRef.doc(record.id), restored.toJson());
    batch.delete(archivedCollectionRef.doc(record.id));
    await batch.commit();
  }

  /// Update pending outplant status for an organism.
  ///
  /// Sets or clears the pending outplant metadata flags on an organism record.
  /// When [isPending] is true, the organism is marked as allocated to a pending batch.
  /// When [isPending] is false, the pending status is cleared.
  ///
  /// If [batch] is provided, the update is added to the batch for atomic commit.
  /// Otherwise, the update is committed immediately.
  ///
  /// Invariant: pendingOutplant=true requires readyForOutplant=true.
  /// This is enforced at the extension getter level via [canAddToPendingBatch].
  @override
  Future<OrganismRecord> updatePendingOutplantStatus({
    required String organismId,
    required bool isPending,
    String? pendingBatchId,
    Map<String, dynamic>? pendingAllocation,
    WriteBatch? batch,
  }) async {
    final organism = await getRecordForId(organismId);
    if (organism == null) {
      throw RepositoryError(
        message: 'Organism $organismId not found',
        category: AppErrorCategory.data,
      );
    }

    // Validate invariant: pendingOutplant requires readyForOutplant
    if (isPending && !organism.readyForOutplant) {
      throw RepositoryError(
        message:
            'Cannot mark organism as pending: must be ready for outplant first',
        category: AppErrorCategory.validation,
        recoverySuggestion: 'Mark the organism as ready for outplant first.',
      );
    }

    // Validate exclusive batch membership
    if (isPending && organism.isPendingOutplant) {
      final existingBatchId = organism.pendingBatchId;
      if (existingBatchId != null && existingBatchId != pendingBatchId) {
        throw RepositoryError(
          message:
              'Organism is already allocated to pending batch $existingBatchId',
          category: AppErrorCategory.validation,
          recoverySuggestion: 'Cancel the existing pending batch first.',
        );
      }
    }

    final now = DateTime.now().toIso8601String();
    final Map<String, dynamic> updatedMetadata;

    if (isPending) {
      // Set pending status
      updatedMetadata = {
        ...organism.metadata ?? {},
        'pendingOutplant': true,
        'pendingBatchId': pendingBatchId,
        'pendingAllocation': pendingAllocation,
      };
    } else {
      // Clear pending status
      updatedMetadata = {...organism.metadata ?? {}};
      updatedMetadata.remove('pendingOutplant');
      updatedMetadata.remove('pendingBatchId');
      updatedMetadata.remove('pendingAllocation');
    }

    final updatedOrganism = organism.copyWith(
      metadata: updatedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    await updateRecord(updatedOrganism, batch: batch);

    LoggingService.instance.info(
      'Updated pending outplant status for organism $organismId: isPending=$isPending',
    );

    return updatedOrganism;
  }

  /// Update transfer lock status for an organism.
  @override
  Future<OrganismRecord> updateTransferLockStatus({
    required String organismId,
    required bool isLocked,
    String? pendingTransferId,
    int? lockedQuantity,
    WriteBatch? batch,
  }) async {
    final record = await getRecordForId(organismId);
    if (record == null) {
      throw RepositoryError(message: 'Organism record not found: $organismId');
    }

    final updatedRecord = record.copyWith(
      metadata: {
        ...?record.metadata,
        'transferLocked': isLocked,
        if (pendingTransferId != null) 'pendingTransferId': pendingTransferId,
        if (lockedQuantity != null) 'lockedQuantity': lockedQuantity,
      },
    );

    final writeBatch = batch ?? firestore.batch();
    await updateRecord(updatedRecord, batch: writeBatch);

    if (batch == null) {
      await writeBatch.commit();
    }

    return updatedRecord;
  }
}
