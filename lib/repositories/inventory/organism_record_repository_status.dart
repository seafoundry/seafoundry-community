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

  /// Archive an organism record.
  ///
  /// Marks the organism record as archived by setting the archived flag to true
  /// and recording the timestamp. Archived records will be filtered out from
  /// active inventory views but can be restored.
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

}
