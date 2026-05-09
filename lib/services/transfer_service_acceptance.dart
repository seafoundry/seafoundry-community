// @tier: community
part of 'transfer_service.dart';

/// Transfer acceptance, rejection, and cancellation methods for [TransferService].
///
/// This part file contains methods for accepting, rejecting, and canceling transfers,
/// as well as marking transfers as shipped.
extension _TransferServiceAcceptance on TransferService {
  /// Marks a pending transfer as shipped (pending -> shipped) after providing an
  /// optional tracking number/comment.
  Future<TransferEvent> performMarkTransferShipped({
    required String transferEventId,
    String? trackingNumber,
    String? comment,
  }) async {
    try {
      final transfer = await requireTransferEvent(transferEventId);
      final currentStatus = parseTransferStatus(
        transfer.status,
        fallback: TransferStatus.pending,
      );

      if (!TransferStateMachine.canTransition(
        currentStatus,
        TransferStatus.shipped,
      )) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} cannot transition from $currentStatus to shipped',
        );
      }

      final userId = _provenanceRepository.user.id;
      final now = DateTime.now().toUtc();
      final manifest = requireManifest(
        transfer,
      ).updateStatus(TransferStatus.shipped, timestamp: now, actorId: userId);

      final updatedHistory = appendStateHistory(
        transfer,
        TransferStatus.shipped,
        userId,
        timestamp: now,
      );

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.shipped.value,
        updatedAt: now.toIso8601String(),
        updatedById: userId,
        manifest: manifest.toJson(),
        trackingNumber: trackingNumber ?? transfer.trackingNumber,
        comment: comment ?? transfer.comment,
        shippedAt: manifest.shippedAt?.toIso8601String(),
        shippedById: manifest.shippedById,
        stateHistory: updatedHistory,
      );

      await updateTransferEvent(updatedTransfer);
      final notificationOutcome = await updateTransferNotificationStatus(
        transferEvent: updatedTransfer,
        status: TransferStatus.shipped.value,
        note: comment,
      );
      if (notificationOutcome == TransferNotificationOutcome.failed) {
        LoggingService.instance.warning(
          'Transfer notification update failed for transfer ${updatedTransfer.id}',
        );
      }

      LoggingService.instance.info(
        'Transfer shipped: ${transfer.id} with tracking ${trackingNumber ?? 'n/a'}',
      );

      return updatedTransfer;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to mark transfer as shipped',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Accepts an incoming transfer (pending/shipped -> received) and creates a
  /// genet record based on the manifest payload.
  Future<ProvenanceRecord> performAcceptTransfer({
    required String transferEventId,
    required String newGenetName,
    String? localId,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    OutplantGeometryInput? geometryInput,
    String? targetUrlPath,
    String? destinationSiteId,
    String? destinationGroupId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) async {
    try {
      final transfer = await requireTransferEvent(transferEventId);
      final organization = _provenanceRepository.organization;
      if (transfer.toOrganizationId != organization.id) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} is not addressed to ${organization.name}.',
        );
      }

      final currentStatus = parseTransferStatus(
        transfer.status,
        fallback: TransferStatus.pending,
      );
      if (!TransferStateMachine.canTransition(
        currentStatus,
        TransferStatus.received,
      )) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} is not ready to be received (status: ${transfer.status})',
        );
      }

      final resolvedTargetUrlPath = targetUrlPath?.trim();
      final resolvedDestinationSiteId = destinationSiteId?.trim();
      if (resolvedDestinationSiteId == null ||
          resolvedDestinationSiteId.isEmpty) {
        throw TransferWorkflowException(
          'Destination site is required to accept this transfer.',
        );
      }
      if (resolvedTargetUrlPath == null || resolvedTargetUrlPath.isEmpty) {
        throw TransferWorkflowException(
          'Destination location is required to accept this transfer.',
        );
      }

      final manifest = requireManifest(transfer);
      if (manifest.transferId != transfer.id) {
        LoggingService.instance.warning(
          'Manifest ${manifest.transferId} does not match transfer ${transfer.id}',
        );
        throw TransferWorkflowException('Manifest does not match transfer id');
      }

      // Extract and validate species compatibility BEFORE creating genet
      final rawSpecies =
          (manifest.genet['speciesId'] as String?)?.trim().isNotEmpty == true
          ? (manifest.genet['speciesId'] as String?)!.trim()
          : (manifest.genet['speciesCode'] as String?)?.trim();
      if (rawSpecies == null || rawSpecies.isEmpty) {
        throw TransferWorkflowException(
          'Transfer manifest is missing species information',
        );
      }
      final resolvedSpecies = SpeciesRegistry.globalById(
        rawSpecies,
        allowFallback: false,
      );
      if (resolvedSpecies == null) {
        throw TransferWorkflowException(
          'Transfer manifest contains unknown species "$rawSpecies". '
          'Please ensure taxonomy data is loaded and retry the transfer.',
        );
      }
      final speciesId = resolvedSpecies.id;

      // Community deployment is coral-only.
      const transferOrganismKind = OrganismKind.coral;

      validateOrganismTypeCompatibility(
        receivingOrganization: organization,
        organismKind: transferOrganismKind,
        genetName: manifest.genet['name']?.toString() ?? 'Unknown',
      );

      final now = DateTime.now().toUtc();
      final receiptedManifest = manifest.updateStatus(
        TransferStatus.received,
        timestamp: now,
        actorId: _provenanceRepository.user.id,
      );

      final ownershipType = _ownershipTypeFromMetadata(manifest.metadata);
      final resolvedOwnerOrgId = _resolvedTransferOwnerOrganizationId(
        ownershipType: ownershipType,
        manifest: manifest,
        receivingOrganization: organization,
        ownerOrganizationId: ownerOrganizationId,
      );
      final resolvedManagerOrgId = _resolvedManagingOrganizationId(
        receivingOrganizationId: organization.id,
        managingOrganizationId: managingOrganizationId,
      );

      final genetCandidate = createGenetFromManifest(
        manifest: receiptedManifest,
        overrideName: newGenetName,
        localId: localId,
        provenanceTypeOverride: provenanceTypeOverride,
        lifeStageOverride: lifeStageOverride,
        ownerOrganizationId: resolvedOwnerOrgId,
        managingOrganizationId: resolvedManagerOrgId,
      );
      final resolvedGenetCandidate = (resolvedDestinationSiteId.isNotEmpty)
          ? genetCandidate.copyWith(siteId: resolvedDestinationSiteId)
          : genetCandidate;

      final history = appendStateHistory(
        transfer,
        TransferStatus.received,
        _provenanceRepository.user.id,
        timestamp: now,
      );

      final geometry = buildGeometryFromInput(geometryInput);

      // Best-effort source genet validation (non-blocking)
      await validateSourceGenetExists(transfer: transfer, manifest: manifest);

      // Pre-fetch crosswalk data BEFORE transaction (lookup only, not transactional)
      // This finds the community Provenance ID if the source genet is in the crosswalk
      final crosswalkProvenanceId = await _findCrosswalkProvenanceId(
        transfer: transfer,
        manifest: receiptedManifest,
      );

      // Execute genet creation, transfer event update, and crosswalk registration atomically
      ProvenanceRecord createdGenet;
      TransferEvent updatedTransfer;
      OrganismRecord? createdOrganismRecord;
      try {
        final result = await _db
            .runTransaction<
              (ProvenanceRecord, TransferEvent, OrganismRecord?)
            >((transaction) async {
              // Re-check transfer status inside transaction to prevent accept/reject race
              final docRef = _db.collection('events').doc(transfer.id);
              final freshDoc = await transaction.get(docRef);

              if (!freshDoc.exists) {
                throw TransferWorkflowException(
                  'Transfer ${transfer.id} no longer exists',
                );
              }
              final freshData = freshDoc.data();
              if (freshData == null) {
                throw TransferWorkflowException(
                  'Transfer ${transfer.id} has no data',
                );
              }
              final freshStatus = parseTransferStatus(
                freshData['status'] as String?,
                fallback: TransferStatus.pending,
              );
              if (!TransferStateMachine.canTransition(
                freshStatus,
                TransferStatus.received,
              )) {
                throw TransferWorkflowException(
                  'Transfer ${transfer.id} status changed to ${freshStatus.value} - '
                  'cannot accept (possible concurrent reject)',
                );
              }

              // Create the genet within the transaction
              final genet = await _provenanceRepository.createProvenanceRecord(
                resolvedGenetCandidate,
                transaction: transaction,
              );

              // Create the organism record for inventory tracking
              final organismRecord = await _createOrganismRecordInTransaction(
                transaction: transaction,
                manifest: receiptedManifest,
                createdGenet: genet,
                quantity: transfer.quantity,
                targetUrlPath: resolvedTargetUrlPath,
                destinationSiteId: resolvedDestinationSiteId,
                destinationGroupId: destinationGroupId,
                localId: localId,
                provenanceTypeOverride: provenanceTypeOverride,
                lifeStageOverride: lifeStageOverride,
                ownerOrganizationId: resolvedOwnerOrgId,
                managingOrganizationId: resolvedManagerOrgId,
              );

              // Update the transfer event within the transaction
              final updated = transfer.copyWith(
                status: TransferStatus.received.value,
                updatedAt: now.toIso8601String(),
                updatedById: _provenanceRepository.user.id,
                manifest: receiptedManifest.toJson(),
                receivedAt: receiptedManifest.receivedAt?.toIso8601String(),
                receivedById: receiptedManifest.receivedById,
                targetUrlPath: resolvedTargetUrlPath,
                stateHistory: history,
                geometry: geometry ?? transfer.geometry,
              );

              await updateTransferEventInTransaction(transaction, updated);

              return (genet, updated, organismRecord);
            });
        createdGenet = result.$1;
        updatedTransfer = result.$2;
        createdOrganismRecord = result.$3;
      } on domainErrors.RepositoryError catch (e) {
        throw TransferWorkflowException(
          'Unable to accept transfer: ${e.message}',
        );
      }

      await ensureOrganizationSpeciesCatalog(
        organization: organization,
        speciesId: speciesId,
      );

      // Best-effort crosswalk mapping outside the transaction to avoid
      // permission failures blocking transfer acceptance.
      await registerCrosswalkMapping(
        transfer: transfer,
        manifest: receiptedManifest,
        createdGenet: createdGenet,
        preResolvedProvenanceId: crosswalkProvenanceId,
      );

      // Unlock organisms at the sender's organization (best-effort)
      await unlockOrganismsForTransfer(
        transferId: transferEventId,
        organizationId: transfer.organizationId,
      );

      LoggingService.instance.debug(
        'Transfer ${transfer.id} acceptance complete; '
        'source inventory is adjusted during initiation.',
      );

      if (_requiresExternalHoldingMirror(ownershipType)) {
        await _notifyOwnerOfExternalHolding(
          ownerOrganizationId: resolvedOwnerOrgId,
          holdingOrganizationId: organization.id,
          holdingOrganizationName: organization.name,
          holdingSiteId: resolvedDestinationSiteId,
          holdingGroupPath: destinationGroupId,
          transferId: transfer.id,
        );
      }

      // Best-effort operations outside transaction
      final notificationOutcome = await updateTransferNotificationStatus(
        transferEvent: updatedTransfer,
        status: TransferStatus.received.value,
        note: 'Accepted as ${createdGenet.displayName}',
      );
      if (notificationOutcome == TransferNotificationOutcome.failed) {
        LoggingService.instance.warning(
          'Transfer notification update failed for transfer ${updatedTransfer.id}',
        );
      }

      // NOTE: Crosswalk registration is now done INSIDE the transaction above
      // for atomicity with genet creation and transfer status update.

      await _createLocalTransferReceiptEvent(
        transfer: transfer,
        updatedTransfer: updatedTransfer,
        createdGenet: createdGenet,
        manifest: receiptedManifest,
        targetUrlPath: resolvedTargetUrlPath,
        destinationSiteId: resolvedDestinationSiteId,
        stateHistory: history,
      );
      await _createOrganismTransferReceiptEvent(
        transfer: transfer,
        updatedTransfer: updatedTransfer,
        createdGenet: createdGenet,
        organismRecord: createdOrganismRecord,
        manifest: receiptedManifest,
        stateHistory: history,
      );

      LoggingService.instance.info(
        'Transfer accepted: ${createdGenet.displayName} (${createdGenet.provenanceId ?? 'unknown'})',
      );

      return createdGenet;
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to accept transfer', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _createLocalTransferReceiptEvent({
    required TransferEvent transfer,
    required TransferEvent updatedTransfer,
    required ProvenanceRecord createdGenet,
    required TransferManifest manifest,
    required String targetUrlPath,
    required String destinationSiteId,
    required List<Map<String, dynamic>> stateHistory,
  }) async {
    try {
      final organization = _provenanceRepository.organization;
      final user = _provenanceRepository.user;
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final eventId = _idGenerator();
      final slug = await _eventRepository.nextSlugForModelType(ModelType.event);

      final metadata = <String, dynamic>{};
      final sourceMetadata = updatedTransfer.metadata;
      if (sourceMetadata != null) {
        metadata.addAll(Map<String, dynamic>.from(sourceMetadata));
      }
      metadata.addAll({
        'transferEventId': transfer.id,
        'transferReceipt': true,
        'sourceOrganizationId': transfer.fromOrganizationId,
        'destinationOrganizationId': organization.id,
      });

      final receiptEvent = TransferEvent(
        id: eventId,
        createdById: user.id,
        createdAt: nowIso,
        updatedAt: nowIso,
        updatedById: user.id,
        organizationId: organization.id,
        recordId: createdGenet.id,
        recordModelType: ModelType.genet,
        urlPath: '$targetUrlPath/$slug',
        internalPath:
            'organizations/${organization.id}/sites/$destinationSiteId/$eventId',
        slug: slug,
        genetId: createdGenet.id,
        fromOrganizationId: transfer.fromOrganizationId,
        toOrganizationId: organization.id,
        status: TransferStatus.received.value,
        comment: updatedTransfer.comment,
        quantity: updatedTransfer.quantity,
        sourceUrlPath: transfer.sourceUrlPath,
        targetUrlPath: targetUrlPath,
        manifest: manifest.toJson(),
        manifestVersion: manifest.version,
        receivedAt: manifest.receivedAt?.toIso8601String(),
        receivedById: manifest.receivedById,
        stateHistory: stateHistory,
        permitMetadata: updatedTransfer.permitMetadata,
        metadata: metadata,
        geometry: updatedTransfer.geometry,
      );

      await _eventRepository.createEvent(receiptEvent);
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to create local transfer receipt event (non-fatal): $e',
      );
      LoggingService.instance.debug(
        'Transfer receipt event error: $stackTrace',
      );
    }
  }

  Future<void> _createOrganismTransferReceiptEvent({
    required TransferEvent transfer,
    required TransferEvent updatedTransfer,
    required ProvenanceRecord createdGenet,
    required OrganismRecord? organismRecord,
    required TransferManifest manifest,
    required List<Map<String, dynamic>> stateHistory,
  }) async {
    if (organismRecord == null) {
      return;
    }
    try {
      final organization = _provenanceRepository.organization;
      final user = _provenanceRepository.user;
      final eventTimestamp =
          manifest.receivedAt?.toUtc() ?? DateTime.now().toUtc();
      final eventIso = eventTimestamp.toIso8601String();
      final eventId = _idGenerator();
      final slug = await _eventRepository.nextSlugForModelType(ModelType.event);

      final metadata = <String, dynamic>{};
      final sourceMetadata = updatedTransfer.metadata;
      if (sourceMetadata != null) {
        metadata.addAll(Map<String, dynamic>.from(sourceMetadata));
      }
      metadata.addAll({
        'transferEventId': transfer.id,
        'transferReceipt': true,
        'sourceOrganizationId': transfer.fromOrganizationId,
        'destinationOrganizationId': organization.id,
      });

      final receiptEvent = TransferEvent(
        id: eventId,
        createdById: user.id,
        createdAt: eventIso,
        updatedAt: eventIso,
        updatedById: user.id,
        organizationId: organization.id,
        recordId: organismRecord.id,
        recordModelType: ModelType.organismRecord,
        urlPath: '${organismRecord.urlPath}/$slug',
        internalPath: '${organismRecord.internalPath}/$eventId',
        slug: slug,
        genetId: createdGenet.id,
        fromOrganizationId: transfer.fromOrganizationId,
        toOrganizationId: organization.id,
        status: TransferStatus.received.value,
        comment: updatedTransfer.comment,
        quantity: updatedTransfer.quantity,
        sourceUrlPath: transfer.sourceUrlPath,
        targetUrlPath: updatedTransfer.targetUrlPath ?? transfer.targetUrlPath,
        manifest: manifest.toJson(),
        manifestVersion: manifest.version,
        receivedAt: manifest.receivedAt?.toIso8601String(),
        receivedById: manifest.receivedById,
        stateHistory: stateHistory,
        permitMetadata: updatedTransfer.permitMetadata,
        metadata: metadata,
        geometry: updatedTransfer.geometry,
      );

      await _eventRepository.createEvent(receiptEvent);
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to create organism transfer receipt event (non-fatal): $e',
      );
      LoggingService.instance.debug(
        'Organism transfer receipt event error: $stackTrace',
      );
    }
  }

  /// Rejects an incoming transfer (pending/shipped -> rejected) and appends the
  /// rejection note to both the manifest and notification for traceability.
  Future<void> performRejectTransfer({
    required String transferEventId,
    String? reason,
  }) async {
    try {
      final transfer = await requireTransferEvent(transferEventId);
      final organization = _provenanceRepository.organization;
      if (transfer.toOrganizationId != organization.id) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} is not addressed to ${organization.name}.',
        );
      }

      final currentStatus = parseTransferStatus(
        transfer.status,
        fallback: TransferStatus.pending,
      );
      if (currentStatus.isTerminal) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} is already resolved',
        );
      }

      final userId = _provenanceRepository.user.id;
      final now = DateTime.now().toUtc();
      final manifest = transfer.manifest != null
          ? TransferManifest.fromJson(transfer.manifest!)
          : null;
      final updatedManifest = manifest?.updateStatus(
        TransferStatus.rejected,
        timestamp: now,
        actorId: userId,
      );

      String? updatedComment = transfer.comment;
      final rejectionNote = reason?.trim();
      if (rejectionNote != null && rejectionNote.isNotEmpty) {
        final buffer = StringBuffer();
        if (updatedComment != null && updatedComment.isNotEmpty) {
          buffer.write(updatedComment);
          buffer.write('\n');
        }
        buffer.write('Rejection reason: $rejectionNote');
        updatedComment = buffer.toString();
      }

      final history = appendStateHistory(
        transfer,
        TransferStatus.rejected,
        userId,
        timestamp: now,
      );

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.rejected.value,
        updatedAt: now.toIso8601String(),
        updatedById: userId,
        comment: updatedComment,
        manifest: updatedManifest?.toJson(),
        stateHistory: history,
      );

      // Use transaction to prevent accept/reject race condition
      await _db.runTransaction<void>((transaction) async {
        final docRef = _db.collection('events').doc(transfer.id);
        final freshDoc = await transaction.get(docRef);
        if (!freshDoc.exists) {
          throw TransferWorkflowException(
            'Transfer ${transfer.id} no longer exists',
          );
        }
        final freshData = freshDoc.data();
        if (freshData == null) {
          throw TransferWorkflowException(
            'Transfer ${transfer.id} has no data',
          );
        }
        final freshStatus = parseTransferStatus(
          freshData['status'] as String?,
          fallback: TransferStatus.pending,
        );
        if (freshStatus.isTerminal) {
          throw TransferWorkflowException(
            'Transfer ${transfer.id} status changed to ${freshStatus.value} - '
            'cannot reject (possible concurrent accept)',
          );
        }

        // Update the transfer event within the transaction
        final enriched = _eventRepository.withOrganismMetadata(updatedTransfer);
        transaction.set(docRef, enriched.toJson(), SetOptions(merge: true));
      });

      // Restore inventory that was decremented at initiation (best-effort)
      // This must be done by the sender organization, so we need to notify them
      // if we're the recipient. For now, we just unlock organisms.
      // The inventory restoration happens at the sender's side.
      await unlockOrganismsForTransfer(
        transferId: transferEventId,
        organizationId: transfer.organizationId,
      );

      // Notify the sender organization to restore their inventory
      await _notifySenderForInventoryRestoration(transfer: transfer);

      final ownershipType = _ownershipTypeFromMetadata(transfer.metadata);
      final ownerOrganizationId = _ownerOrganizationIdForHoldingRemoval(
        ownershipType: ownershipType,
        senderOrganizationId: transfer.fromOrganizationId,
        originalOwnerOrganizationId: _originalOwnerOrganizationId(
          transfer.metadata,
        ),
      );
      if (ownerOrganizationId != null) {
        await _notifyOwnerOfHoldingRemoval(
          ownerOrganizationId: ownerOrganizationId,
          transferId: transfer.id,
        );
      }

      final notificationOutcome = await updateTransferNotificationStatus(
        transferEvent: updatedTransfer,
        status: TransferStatus.rejected.value,
        note: rejectionNote,
      );
      if (notificationOutcome == TransferNotificationOutcome.failed) {
        LoggingService.instance.warning(
          'Transfer notification update failed for transfer ${updatedTransfer.id}',
        );
      }

      LoggingService.instance.info('Transfer rejected: $transferEventId');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to reject transfer', e, stackTrace);
      rethrow;
    }
  }

  /// Cancels an outbound transfer (pending/shipped -> cancelled).
  ///
  /// Only the sender organization can cancel.
  Future<void> performCancelTransfer({
    required String transferEventId,
    String? reason,
  }) async {
    try {
      final transfer = await requireTransferEvent(transferEventId);
      final organization = _provenanceRepository.organization;

      // Only sender can cancel
      if (transfer.organizationId != organization.id) {
        throw TransferWorkflowException(
          'Only the sender organization can cancel this transfer.',
        );
      }

      final currentStatus = parseTransferStatus(transfer.status);

      if (currentStatus.isTerminal) {
        throw TransferWorkflowException(
          'Transfer is already ${currentStatus.value} and cannot be cancelled.',
        );
      }

      if (!currentStatus.canTransitionTo(TransferStatus.cancelled)) {
        throw TransferWorkflowException(
          'Cannot cancel transfer from ${currentStatus.value} state.',
        );
      }

      final userId = _provenanceRepository.user.id;
      final now = DateTime.now().toUtc();

      final history = appendStateHistory(
        transfer,
        TransferStatus.cancelled,
        userId,
        timestamp: now,
      );

      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.cancelled.value,
        updatedAt: now.toIso8601String(),
        updatedById: userId,
        stateHistory: history,
      );

      // Use transaction to prevent race with accept/reject
      await _db.runTransaction<void>((transaction) async {
        final docRef = _db.collection('events').doc(transfer.id);
        final freshDoc = await transaction.get(docRef);

        if (!freshDoc.exists) {
          throw TransferWorkflowException('Transfer no longer exists');
        }

        final freshData = freshDoc.data();
        final freshStatus = parseTransferStatus(freshData?['status']);

        if (freshStatus.isTerminal) {
          throw TransferWorkflowException(
            'Transfer status changed to ${freshStatus.value} - cannot cancel',
          );
        }

        final enriched = _eventRepository.withOrganismMetadata(updatedTransfer);
        transaction.set(docRef, enriched.toJson(), SetOptions(merge: true));
      });

      // Unlock organisms (best-effort, outside transaction)
      await unlockOrganismsForTransfer(
        transferId: transferEventId,
        organizationId: organization.id,
      );

      // Restore inventory that was decremented at initiation (best-effort)
      // Cancel is always done by the sender, so we can restore directly
      await restoreTransferInventory(transfer);

      final ownershipType = _ownershipTypeFromMetadata(transfer.metadata);
      final ownerOrganizationId = _ownerOrganizationIdForHoldingRemoval(
        ownershipType: ownershipType,
        senderOrganizationId: transfer.fromOrganizationId,
        originalOwnerOrganizationId: _originalOwnerOrganizationId(
          transfer.metadata,
        ),
        actingOrganizationId: organization.id,
        skipWhenActorIsOwner: true,
      );
      if (ownerOrganizationId != null) {
        await _notifyOwnerOfHoldingRemoval(
          ownerOrganizationId: ownerOrganizationId,
          transferId: transfer.id,
        );
      } else if (ownershipType == TransferOwnershipType.retainedOwnership) {
        LoggingService.instance.debug(
          'Transfer ${transfer.id} cancelled with retained ownership - '
          'no external holding notification needed (sender is owner)',
        );
      }

      // Notify recipient if exists
      if (transfer.toOrganizationId != null) {
        final notificationOutcome = await updateTransferNotificationStatus(
          transferEvent: updatedTransfer,
          status: TransferStatus.cancelled.value,
          note: reason,
        );
        if (notificationOutcome == TransferNotificationOutcome.failed) {
          LoggingService.instance.warning(
            'Transfer notification update failed for transfer ${updatedTransfer.id}',
          );
        }
      }

      LoggingService.instance.info('Transfer cancelled: $transferEventId');
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to cancel transfer', e, stackTrace);
      rethrow;
    }
  }

  /// Updates a pending transfer's quantity/comment while regenerating the
  /// manifest.
  Future<TransferEvent> performUpdatePendingTransfer({
    required String transferEventId,
    required int quantity,
    String? comment,
    EventPermitMetadata? permitMetadata,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
  }) async {
    try {
      final transfer = await requireTransferEvent(transferEventId);
      final currentStatus = parseTransferStatus(
        transfer.status,
        fallback: TransferStatus.pending,
      );

      if (currentStatus != TransferStatus.pending) {
        throw TransferWorkflowException(
          'Only pending transfers can be edited. Current status: ${transfer.status}',
        );
      }

      final organization = _provenanceRepository.organization;
      if (transfer.organizationId != organization.id) {
        throw TransferWorkflowException(
          'Transfer ${transfer.id} does not belong to ${organization.name}',
        );
      }

      final genet = await _provenanceRepository.getRecordForId(
        transfer.genetId!,
      );
      if (genet == null) {
        throw TransferWorkflowException('Genet not found: ${transfer.genetId}');
      }
      final selection = resolveProvenanceSelection(
        genet: genet,
        transfer: transfer,
        overrideProvenanceType: provenanceTypeOverride,
        overrideLifeStage: lifeStageOverride,
      );
      final manifestMetadata = extractManifestMetadata(transfer);
      final resolvedPhysicalForm =
          physicalFormOverride ??
          physicalFormFromMetadata(transfer.metadata) ??
          physicalFormFromMetadata(manifestMetadata) ??
          physicalFormFromMetadata(genet.metadata);
      final nextMetadata = mergeSelectionMetadata(
        transfer.metadata,
        selection,
        physicalFormOverride: resolvedPhysicalForm,
        sizeSpecOverride: sizeSpecOverride,
      );
      final geometry = buildGeometryFromInput(geometryInput);

      final toOrganization = await lookupOrganization(
        transfer.toOrganizationId!,
      );
      final user = _provenanceRepository.user;
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();

      // Rebuild manifest with updated quantity and comment
      final updatedManifest = buildManifest(
        transferEvent: transfer,
        genet: genet,
        fromOrganization: organization,
        toOrganization: toOrganization,
        quantity: quantity,
        comment: comment,
        sourceStructureUrlPath: transfer.sourceUrlPath,
        initiatedBy: user,
        selection: selection,
        physicalFormOverride: resolvedPhysicalForm,
        sizeSpecOverride: sizeSpecOverride,
      ).updateStatus(TransferStatus.pending, timestamp: now, actorId: user.id);

      // Update the transfer event
      final updatedTransfer = transfer.copyWith(
        quantity: quantity,
        comment: comment,
        updatedAt: nowIso,
        updatedById: user.id,
        manifest: updatedManifest.toJson(),
        manifestVersion: updatedManifest.version,
        permitMetadata: permitMetadata ?? transfer.permitMetadata,
        metadata: nextMetadata.isEmpty ? null : nextMetadata,
        geometry: geometry ?? transfer.geometry,
      );

      await updateTransferEvent(updatedTransfer);

      // Firestore merge:true deep-merges nested maps, so absent keys persist
      // from the existing document. Explicitly delete the nested 'size' key
      // when an empty SizeSpec is provided.
      if (sizeSpecOverride != null && sizeSpecOverride.isEmpty) {
        await _db.collection('events').doc(updatedTransfer.id).update({
          'metadata.size': FieldValue.delete(),
          'manifest.metadata.size': FieldValue.delete(),
        });
      }

      LoggingService.instance.info(
        'Transfer updated: ${transfer.id} (quantity: $quantity)',
      );

      return updatedTransfer;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update pending transfer',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Creates an OrganismRecord within a transaction for transfer acceptance.
  ///
  /// This method writes the organism record directly to Firestore within the
  /// transaction, ensuring atomicity with genet creation and transfer status
  /// update. The organism record represents the inventory holding at the
  /// destination site/group.
  Future<OrganismRecord?> _createOrganismRecordInTransaction({
    required Transaction transaction,
    required TransferManifest manifest,
    required ProvenanceRecord createdGenet,
    required int quantity,
    required String targetUrlPath,
    required String destinationSiteId,
    String? destinationGroupId,
    String? localId,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) async {
    if (_organismRecordRepository == null) {
      LoggingService.instance.warning(
        'OrganismRecordRepository not provided - skipping inventory creation '
        'for transfer acceptance. Organisms will not appear in inventory views.',
      );
      return null;
    }

    try {
      final organization = _provenanceRepository.organization;
      final user = _provenanceRepository.user;
      final now = DateTime.now();
      final nowIso = now.toIso8601String();

      // Generate unique identifiers for the organism record
      final recordId = _idGenerator();
      final slugBase = createdGenet.localId ?? 'organism';
      final recordSlug = await _organismRecordRepository.nextSlugForBase(
        slugBase,
      );

      // Check if we have a group destination
      final hasGroup =
          destinationGroupId != null && destinationGroupId.isNotEmpty;

      // Build the full paths for the organism record
      final urlPath = '$targetUrlPath/$recordSlug';
      final internalPath = hasGroup
          ? 'organizations/${organization.id}/sites/$destinationSiteId/groups/$destinationGroupId/$recordId'
          : 'organizations/${organization.id}/sites/$destinationSiteId/$recordId';

      // Create a partial organism record from the manifest
      var organismRecord = createOrganismRecordFromManifest(
        manifest: manifest,
        createdGenet: createdGenet,
        quantity: quantity,
        recordName: createdGenet.displayName,
        localId: localId ?? createdGenet.localId,
        provenanceTypeOverride: provenanceTypeOverride,
        lifeStageOverride: lifeStageOverride,
        ownerOrganizationId: ownerOrganizationId,
        managingOrganizationId: managingOrganizationId,
      );

      // Complete the record with paths and IDs
      organismRecord = organismRecord.copyWith(
        id: recordId,
        slug: recordSlug,
        urlPath: urlPath,
        internalPath: internalPath,
        organizationId: organization.id,
        createdById: user.id,
        updatedById: user.id,
        createdAt: nowIso,
        updatedAt: nowIso,
        siteId: destinationSiteId,
        groupId: hasGroup ? destinationGroupId : null,
      );

      // Sync foreignKeys['genetId'] from top-level genetId for consistency
      final foreignKeys = Map<String, ForeignKeyReference>.from(
        organismRecord.foreignKeys,
      );
      if (organismRecord.genetId != null) {
        foreignKeys['genetId'] = ForeignKeyReference(
          id: organismRecord.genetId!,
          metadata: {'source': 'transfer_acceptance', 'linkedAt': nowIso},
        );
      }

      // Write sourceGenet foreignKey for transfer lock detection
      // This enables IdentityEditService.checkTransferLock() to work from OrganismRecord context
      final sourceGenetId = manifest.genet['id'] as String?;
      if (sourceGenetId != null &&
          sourceGenetId.isNotEmpty &&
          manifest.fromOrganization.id != null) {
        foreignKeys['sourceGenet'] = ForeignKeyReference(
          id: sourceGenetId,
          metadata: {
            'organizationId': manifest.fromOrganization.id,
            'transferId': manifest.transferId,
          },
        );
      }

      organismRecord = organismRecord.copyWith(foreignKeys: foreignKeys);

      // Write the organism record to Firestore within the transaction.
      // Organism records are org-scoped under organizations/{orgId}/organismRecords.
      final docRef = _db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection(ModelType.organismRecord.collectionPath)
          .doc(recordId);
      transaction.set(docRef, organismRecord.toJson());

      LoggingService.instance.info(
        'Created organism record ${organismRecord.recordName} (${organismRecord.id}) '
        'for transfer acceptance at $urlPath',
      );
      return organismRecord;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create organism record during transfer acceptance',
        e,
        stackTrace,
      );
      // Re-throw to roll back the entire transaction (genet + transfer update)
      rethrow;
    }
  }

  TransferOwnershipType _ownershipTypeFromMetadata(
    Map<String, dynamic>? metadata, {
    TransferOwnershipType fallback = TransferOwnershipType.fullTransfer,
  }) {
    return TransferOwnershipTypeX.tryParse(
          metadata?['ownershipType']?.toString(),
        ) ??
        fallback;
  }

  String? _originalOwnerOrganizationId(Map<String, dynamic>? metadata) {
    final value = metadata?['originalOwnerOrganizationId']?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  bool _requiresExternalHoldingMirror(TransferOwnershipType ownershipType) {
    return ownershipType == TransferOwnershipType.retainedOwnership ||
        ownershipType == TransferOwnershipType.thirdPartyTransfer;
  }

  String _resolvedTransferOwnerOrganizationId({
    required TransferOwnershipType ownershipType,
    required TransferManifest manifest,
    required Organization receivingOrganization,
    String? ownerOrganizationId,
  }) {
    switch (ownershipType) {
      case TransferOwnershipType.fullTransfer:
        return ownerOrganizationId ?? receivingOrganization.id;
      case TransferOwnershipType.retainedOwnership:
        return manifest.fromOrganization.id ?? receivingOrganization.id;
      case TransferOwnershipType.thirdPartyTransfer:
        return _originalOwnerOrganizationId(manifest.metadata) ??
            manifest.fromOrganization.id ??
            receivingOrganization.id;
    }
  }

  String _resolvedManagingOrganizationId({
    required String receivingOrganizationId,
    String? managingOrganizationId,
  }) {
    return managingOrganizationId ?? receivingOrganizationId;
  }

  String? _ownerOrganizationIdForHoldingRemoval({
    required TransferOwnershipType ownershipType,
    required String? senderOrganizationId,
    required String? originalOwnerOrganizationId,
    String? actingOrganizationId,
    bool skipWhenActorIsOwner = false,
  }) {
    final ownerOrganizationId = switch (ownershipType) {
      TransferOwnershipType.fullTransfer => null,
      TransferOwnershipType.retainedOwnership => senderOrganizationId,
      TransferOwnershipType.thirdPartyTransfer => originalOwnerOrganizationId,
    };
    if (skipWhenActorIsOwner &&
        ownerOrganizationId != null &&
        ownerOrganizationId == actingOrganizationId) {
      return null;
    }
    return ownerOrganizationId;
  }

  /// Fetches the site name from Firestore for external holding notifications.
  Future<String> _getSiteName(String siteId) async {
    try {
      final doc = await _db.collection('sites').doc(siteId).get();
      final data = doc.data();
      if (data != null && data['name'] is String) {
        return data['name'] as String;
      }
      return 'Unknown Site';
    } catch (e) {
      LoggingService.instance.debug(
        'Failed to fetch site name for $siteId: $e',
      );
      return 'Unknown Site';
    }
  }

  /// Sends notification to owner org to create/update external holding mirror site.
  Future<void> _notifyOwnerOfExternalHolding({
    required String ownerOrganizationId,
    required String holdingOrganizationId,
    required String holdingOrganizationName,
    required String holdingSiteId,
    required String? holdingGroupPath,
    required String transferId,
  }) async {
    try {
      final holdingSiteName = await _getSiteName(holdingSiteId);

      final notificationRef = _db
          .collection('organizations')
          .doc(ownerOrganizationId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': 'externalHoldingCreated',
        'transferId': transferId,
        'holdingOrganizationId': holdingOrganizationId,
        'holdingOrganizationName': holdingOrganizationName,
        'holdingSiteId': holdingSiteId,
        'holdingSiteName': holdingSiteName,
        'holdingGroupPath': holdingGroupPath,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      LoggingService.instance.info(
        'Sent external holding notification to $ownerOrganizationId '
        'for transfer $transferId',
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to notify owner of external holding: $e',
      );
      // Best-effort - don't fail the transfer
    }
  }

  /// Sends notification to owner org to remove external holding entry.
  Future<void> _notifyOwnerOfHoldingRemoval({
    required String ownerOrganizationId,
    required String transferId,
  }) async {
    try {
      final notificationRef = _db
          .collection('organizations')
          .doc(ownerOrganizationId)
          .collection('notifications')
          .doc();

      await notificationRef.set({
        'type': 'externalHoldingRemoved',
        'transferId': transferId,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      LoggingService.instance.info(
        'Sent external holding removal notification to $ownerOrganizationId',
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to send external holding removal notification: $e',
      );
    }
  }
}
