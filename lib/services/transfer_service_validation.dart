// @tier: community
part of 'transfer_service.dart';

/// Validation and helper methods for [TransferService].
///
/// This part file contains validation, organism locking/unlocking,
/// inventory management, notification handling, and other helper methods.
extension _TransferServiceValidation on TransferService {
  OutplantGeometry? buildGeometryFromInput(OutplantGeometryInput? input) {
    if (input == null || !input.hasCoordinates) {
      return null;
    }
    try {
      return _geometryBuilder.build(input: input);
    } on ArgumentError catch (error) {
      throw TransferWorkflowException(error.message);
    }
  }

  /// Fetches a transfer event by id, surfacing a workflow exception if it does
  /// not exist.
  Future<TransferEvent> requireTransferEvent(String transferEventId) async {
    final transfer = await getTransferEventById(transferEventId);
    if (transfer == null) {
      throw TransferWorkflowException(
        'Transfer event not found: $transferEventId',
      );
    }
    return transfer;
  }

  Future<TransferEvent?> getTransferEventById(String transferEventId) async {
    try {
      final doc = await _db.collection('events').doc(transferEventId).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return null;
      }
      final currentOrgId = _provenanceRepository.organization.id;
      final ownerOrgId = data['organizationId'] as String?;
      final recipientOrgId = data['toOrganizationId'] as String?;
      // Allow sender OR recipient organizations to access the transfer event.
      if (ownerOrgId != currentOrgId && recipientOrgId != currentOrgId) {
        LoggingService.instance.warning(
          'Transfer event $transferEventId belongs to different organization: '
          '$ownerOrgId (owner) / $recipientOrgId (recipient) vs $currentOrgId',
        );
        return null;
      }
      return TransferEvent.fromJson(data);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load transfer event',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> updateTransferEvent(TransferEvent transfer) async {
    // Verify the event belongs to the current organization before updating
    if (transfer.organizationId != _provenanceRepository.organization.id) {
      throw domainErrors.RepositoryError(
        message: 'Cannot update transfer event from different organization',
        category: domainErrors.AppErrorCategory.validation,
        recoverySuggestion:
            'Ensure you are logged into the correct organization',
      );
    }
    final enriched = _eventRepository.withOrganismMetadata(transfer);
    await _db
        .collection('events')
        .doc(enriched.id)
        .set(enriched.toJson(), SetOptions(merge: true));
  }

  /// Updates a transfer event within a Firestore transaction for atomicity.
  Future<void> updateTransferEventInTransaction(
    Transaction transaction,
    TransferEvent transfer,
  ) async {
    // Verify the event belongs to the current organization before updating.
    // Accept/reject flows run under the recipient org; allow either sender or recipient.
    final currentOrgId = _provenanceRepository.organization.id;
    if (transfer.organizationId != currentOrgId &&
        transfer.toOrganizationId != currentOrgId) {
      throw domainErrors.RepositoryError(
        message: 'Cannot update transfer event from different organization',
        category: domainErrors.AppErrorCategory.validation,
        recoverySuggestion:
            'Ensure you are logged into the correct organization',
      );
    }
    final enriched = _eventRepository.withOrganismMetadata(transfer);
    final docRef = _db.collection('events').doc(enriched.id);
    transaction.set(docRef, enriched.toJson(), SetOptions(merge: true));
  }

  /// Resolves an organization by domain/id.
  Future<Organization> lookupOrganization(String identifier) async {
    final resolved = await _organizationRepository.resolveIdentifier(
      identifier,
    );
    if (resolved != null) {
      return resolved;
    }

    final fallback = await _recordRepository.findOrganizationByDomain(
      identifier,
    );
    if (fallback != null) {
      return fallback;
    }

    throw TransferWorkflowException('Organization not found for "$identifier"');
  }

  /// Ensure the receiving organization's species catalog includes the
  /// transferred species. Transfers can introduce new species; this is a
  /// best-effort update and should not block acceptance.
  Future<void> ensureOrganizationSpeciesCatalog({
    required Organization organization,
    required String speciesId,
  }) async {
    final normalizedSpeciesId = SpeciesRegistry.normalizeId(speciesId);
    if (normalizedSpeciesId == null || normalizedSpeciesId.isEmpty) {
      return;
    }

    final existing = SpeciesRegistry.normalizeIds(organization.speciesIds);
    if (existing.contains(normalizedSpeciesId)) {
      return;
    }

    try {
      await _db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .update({
            'speciesIds': FieldValue.arrayUnion([normalizedSpeciesId]),
          });
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to update organization species catalog for transfer',
        {
          'organizationId': organization.id,
          'speciesId': normalizedSpeciesId,
          'error': e.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  /// Validates that the receiving organization is authorized to work with the
  /// organism type of the genet being transferred.
  void validateOrganismTypeCompatibility({
    required Organization receivingOrganization,
    required OrganismKind organismKind,
    required String genetName,
  }) {
    if (organismKind != OrganismKind.coral) {
      throw TransferWorkflowException(
        'Organization "${receivingOrganization.name}" is not authorized to receive '
        '${organismKind.name} organisms. The genet "$genetName" is a ${organismKind.name}, '
        'which is not supported in this community deployment. '
        'Please contact your organization administrator to add this organism type before '
        'accepting the transfer.',
      );
    }
  }

  /// Best-effort validation that the source genet still exists at the source organization.
  Future<void> validateSourceGenetExists({
    required TransferEvent transfer,
    required TransferManifest manifest,
  }) async {
    try {
      final sourceGenetId = manifest.genet['id'] as String?;
      final sourceOrgId = transfer.fromOrganizationId;

      if (sourceGenetId == null || sourceOrgId == null) {
        LoggingService.instance.debug(
          'Source genet validation skipped: missing genetId or fromOrganizationId',
        );
        return;
      }

      // Attempt to fetch the source genet from the source organization's genets collection
      final doc = await _db
          .collection('organizations')
          .doc(sourceOrgId)
          .collection('genets')
          .doc(sourceGenetId)
          .get();

      if (!doc.exists) {
        LoggingService.instance.warning(
          'Source genet $sourceGenetId no longer exists at organization $sourceOrgId. '
          'Transfer ${transfer.id} will proceed using manifest data, but provenance '
          'chain may be incomplete. Consider verifying the source genet status.',
        );
      }
    } catch (e) {
      // Best-effort check - log but don't block the transfer
      LoggingService.instance.debug(
        'Source genet validation failed (non-blocking): $e',
      );
    }
  }

  /// Persists/updates the receiving organization's notification stream.
  Future<TransferNotificationOutcome> createTransferNotification({
    required Organization fromOrganization,
    required Organization toOrganization,
    required ProvenanceRecord genet,
    required TransferEvent transferEvent,
    required TransferStatus status,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now().toIso8601String();
    final notification = <String, dynamic>{
      'id': transferEvent.id,
      'notificationType': 'transfer_request',
      'status': status.value,
      'createdAt': now,
      'updatedAt': now,
      'transferEventId': transferEvent.id,
      'genetId': genet.id,
      'genetName': genet.displayName,
      'quantity': transferEvent.quantity,
      'fromOrganizationId': fromOrganization.id,
      'fromOrganizationName': fromOrganization.name,
      'toOrganizationId': toOrganization.id,
      'toOrganizationName': toOrganization.name,
      'message':
          '${fromOrganization.name} is requesting ${transferEvent.quantity} ${genet.displayName}',
      'read': false,
    };
    if (metadata != null && metadata.isNotEmpty) {
      notification['metadata'] = metadata;
    }

    try {
      await _db
          .collection(ModelType.organization.collectionPath)
          .doc(toOrganization.id)
          .collection('notifications')
          .doc(transferEvent.id)
          .set(notification, SetOptions(merge: true));
      return TransferNotificationOutcome.success;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to create transfer notification',
        e,
        stackTrace,
      );
      return TransferNotificationOutcome.failed;
    }
  }

  /// Notifies the sender organization that a transfer was rejected and they
  /// should restore their inventory.
  ///
  /// This is needed because the recipient organization cannot directly modify
  /// the sender's inventory. The sender must process this notification to
  /// restore quantities that were decremented at transfer initiation.
  Future<void> _notifySenderForInventoryRestoration({
    required TransferEvent transfer,
  }) async {
    final senderOrgId = transfer.fromOrganizationId ?? transfer.organizationId;
    if (senderOrgId.isEmpty) {
      LoggingService.instance.warning(
        'Cannot notify sender for inventory restoration: '
        'missing organization ID on transfer ${transfer.id}',
      );
      return;
    }

    // Check if inventory was actually adjusted (pre-decremented)
    final inventoryAdjusted = transfer.metadata?['inventoryAdjusted'] == true;
    if (!inventoryAdjusted) {
      LoggingService.instance.debug(
        'Skipping inventory restoration notification: '
        'transfer ${transfer.id} was not pre-decremented',
      );
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final rejectingOrgName = _provenanceRepository.organization.name;
    final genetName =
        transfer.manifest?['genet']?['name']?.toString() ?? 'Unknown';

    final notification = <String, dynamic>{
      'id': '${transfer.id}_inventory_restore',
      'notificationType': 'transfer_inventory_restore',
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'transferEventId': transfer.id,
      'genetId': transfer.genetId,
      'genetName': genetName,
      'quantity': transfer.quantity,
      'sourceStructureUrlPath': transfer.sourceUrlPath,
      'fromOrganizationId': _provenanceRepository.organization.id,
      'fromOrganizationName': rejectingOrgName,
      'message':
          'Transfer to $rejectingOrgName was rejected - inventory restoration required',
      'read': false,
      'metadata': {
        'transferId': transfer.id,
        'rejectedAt': now,
        'rejectedById': _provenanceRepository.user.id,
        'lockedSelection': transfer.metadata?['lockedSelection'],
      },
    };

    try {
      await _db
          .collection(ModelType.organization.collectionPath)
          .doc(senderOrgId)
          .collection('notifications')
          .doc('${transfer.id}_inventory_restore')
          .set(notification, SetOptions(merge: true));

      LoggingService.instance.info(
        'Notified sender organization $senderOrgId to restore inventory for rejected transfer ${transfer.id}',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to notify sender for inventory restoration',
        e,
        stackTrace,
      );
      // Don't throw - this is best-effort
    }
  }

  /// Marks an existing notification as resolved and optionally stores a note.
  Future<TransferNotificationOutcome> updateTransferNotificationStatus({
    required TransferEvent transferEvent,
    required String status,
    String? note,
  }) async {
    final toOrgId = transferEvent.toOrganizationId;
    if (toOrgId == null || toOrgId.isEmpty) {
      return TransferNotificationOutcome.notRequired;
    }

    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
      'resolvedAt': DateTime.now().toIso8601String(),
      'read': true,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    try {
      await _db
          .collection(ModelType.organization.collectionPath)
          .doc(toOrgId)
          .collection('notifications')
          .doc(transferEvent.id)
          .set(updates, SetOptions(merge: true));
      return TransferNotificationOutcome.success;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to update transfer notification',
        e,
        stackTrace,
      );
      return TransferNotificationOutcome.failed;
    }
  }

  /// Unlocks organisms locked by a transfer (best-effort).
  Future<void> unlockOrganismsForTransfer({
    required String transferId,
    required String organizationId,
  }) async {
    final currentOrgId = _provenanceRepository.organization.id;
    if (organizationId != currentOrgId) {
      LoggingService.instance.debug(
        'Skipping unlock for transfer $transferId: '
        'organization mismatch (current=$currentOrgId, target=$organizationId)',
      );
      return;
    }
    try {
      final collection = _db
          .collection(ModelType.organization.collectionPath)
          .doc(organizationId)
          .collection(ModelType.organismRecord.collectionPath);

      final snapshot = await collection
          .where('metadata.pendingTransferId', isEqualTo: transferId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      final now = DateTime.now().toIso8601String();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'metadata.pendingTransferId': FieldValue.delete(),
          'metadata.lockedTransferQuantity': FieldValue.delete(),
          'updatedAt': now,
        });
      }

      await batch.commit();
      LoggingService.instance.info(
        'Unlocked ${snapshot.docs.length} organisms for transfer $transferId',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to unlock organisms for transfer $transferId',
        e,
        stackTrace,
      );
    }
  }

  Future<TransferEvent> applyTransferInventoryDecrement({
    required TransferEvent transferEvent,
    required Map<String, int> lockedSelection,
  }) async {
    final organismRepository = _organismRecordRepository;
    if (organismRepository == null) {
      LoggingService.instance.warning(
        'OrganismRecordRepository not configured; skipping inventory decrement '
        'for transfer ${transferEvent.id}',
      );
      return transferEvent;
    }

    if (lockedSelection.isEmpty) {
      return transferEvent;
    }

    final lockedTotal = lockedSelection.values.fold<int>(
      0,
      (total, quantity) => total + quantity,
    );
    if (lockedTotal != transferEvent.quantity) {
      LoggingService.instance.warning(
        'Transfer ${transferEvent.id} locked quantity mismatch',
        {
          'lockedTotal': lockedTotal,
          'transferQuantity': transferEvent.quantity,
        },
      );
    }

    // Phase 1: Pre-validate all organisms before making any changes
    // This prevents partial decrements if validation fails partway through
    final validatedOrganisms = <String, (OrganismRecord, int)>{};
    final validationErrors = <String>[];

    for (final entry in lockedSelection.entries) {
      final organismId = entry.key;
      final quantity = entry.value;
      if (quantity <= 0) continue;

      try {
        final organism = await organismRepository.getRecordForId(organismId);
        if (organism == null) {
          validationErrors.add('Organism $organismId not found');
          continue;
        }

        final currentQuantity = organism.measurement.value.toInt();
        final nextQuantity = currentQuantity - quantity;
        if (nextQuantity < 0) {
          validationErrors.add(
            'Organism $organismId has insufficient quantity '
            '(current: $currentQuantity, requested: $quantity)',
          );
          continue;
        }

        validatedOrganisms[organismId] = (organism, nextQuantity);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to validate organism $organismId for transfer ${transferEvent.id}',
          e,
          stackTrace,
        );
        validationErrors.add('Organism $organismId validation failed: $e');
      }
    }

    // If any validation failed, abort the entire operation
    if (validationErrors.isNotEmpty) {
      LoggingService.instance.warning(
        'Transfer ${transferEvent.id} inventory decrement aborted due to validation errors',
        {'errors': validationErrors},
      );
      return transferEvent;
    }

    // Phase 2: Apply all decrements (now that we know all are valid)
    // Track successful decrements for potential rollback logging
    final successfulDecrements = <String, int>{};
    var hadApplyError = false;

    for (final entry in validatedOrganisms.entries) {
      final organismId = entry.key;
      final (organism, nextQuantity) = entry.value;
      final decrementAmount = organism.measurement.value.toInt() - nextQuantity;

      try {
        final payload = await organismRepository.updatePopulation(
          organism,
          nextQuantity,
          lossReason: PopulationLossReason.transferred,
          comment: transferInventoryComment(transferEvent),
        );

        final updatedRecord = payload.updatedRecord;
        successfulDecrements[organismId] = decrementAmount;
        await clearTransferLockForOrganism(
          organizationId: transferEvent.organizationId,
          organismId: updatedRecord.id,
        );
      } catch (e, stackTrace) {
        hadApplyError = true;
        LoggingService.instance.error(
          'Failed to decrement inventory for transfer ${transferEvent.id}',
          e,
          stackTrace,
        );
        // Log successful decrements for manual recovery if needed
        if (successfulDecrements.isNotEmpty) {
          LoggingService.instance.error(
            'PARTIAL INVENTORY DECREMENT: Transfer ${transferEvent.id} '
            'partially applied. Manual review required.',
            {
              'transferId': transferEvent.id,
              'successfulDecrements': successfulDecrements,
              'failedOrganism': organismId,
              'failedDecrement': decrementAmount,
            },
            stackTrace,
          );
        }
        break; // Stop on first error during apply phase
      }
    }

    if (hadApplyError) {
      return transferEvent;
    }

    return markTransferInventoryAdjusted(transferEvent);
  }

  Future<void> clearTransferLockForOrganism({
    required String organizationId,
    required String organismId,
  }) async {
    try {
      final docRef = _db
          .collection(ModelType.organization.collectionPath)
          .doc(organizationId)
          .collection(ModelType.organismRecord.collectionPath)
          .doc(organismId);
      await docRef.update({
        'metadata.pendingTransferId': FieldValue.delete(),
        'metadata.lockedTransferQuantity': FieldValue.delete(),
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedById': _provenanceRepository.user.id,
      });
    } catch (e, stackTrace) {
      LoggingService.instance
          .warning('Failed to clear transfer lock for $organismId', {
            'organismId': organismId,
            'error': e.toString(),
            'stackTrace': stackTrace.toString(),
          });
    }
  }

  Future<TransferEvent> markTransferInventoryAdjusted(
    TransferEvent transferEvent,
  ) async {
    final updatedMetadata = Map<String, dynamic>.from(
      transferEvent.metadata ?? const {},
    );
    updatedMetadata['inventoryAdjusted'] = true;
    final updatedTransfer = transferEvent.copyWith(
      metadata: updatedMetadata,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      updatedById: _provenanceRepository.user.id,
    );
    await updateTransferEvent(updatedTransfer);
    return updatedTransfer;
  }

  String? transferInventoryComment(TransferEvent transferEvent) {
    final comment = transferEvent.comment?.trim();
    if (comment == null || comment.isEmpty) {
      return 'Transfer ${transferEvent.id}';
    }
    return 'Transfer ${transferEvent.id}: $comment';
  }

  /// Stores the locked organism selection in transfer metadata for later restoration
  /// on reject/cancel operations.
  Future<TransferEvent> storeLockedSelectionInMetadata({
    required TransferEvent transferEvent,
    required Map<String, int> lockedSelection,
  }) async {
    if (lockedSelection.isEmpty) {
      return transferEvent;
    }

    final updatedMetadata = Map<String, dynamic>.from(
      transferEvent.metadata ?? const {},
    );
    // Store as list of {organismId, quantity} for JSON serialization
    updatedMetadata['lockedSelection'] = lockedSelection.entries
        .map((e) => {'organismId': e.key, 'quantity': e.value})
        .toList();

    final updatedTransfer = transferEvent.copyWith(
      metadata: updatedMetadata,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      updatedById: _provenanceRepository.user.id,
    );

    await updateTransferEvent(updatedTransfer);
    return updatedTransfer;
  }

  /// Extracts the locked selection map from transfer metadata.
  Map<String, int> extractLockedSelectionFromMetadata(TransferEvent transfer) {
    final metadata = transfer.metadata;
    if (metadata == null) return {};

    final lockedSelectionRaw = metadata['lockedSelection'];
    if (lockedSelectionRaw == null) return {};

    if (lockedSelectionRaw is! List) return {};

    final lockedSelection = <String, int>{};
    for (final entry in lockedSelectionRaw) {
      if (entry is Map) {
        final organismId = entry['organismId']?.toString();
        final quantity = entry['quantity'];
        if (organismId != null && quantity is int) {
          lockedSelection[organismId] = quantity;
        }
      }
    }
    return lockedSelection;
  }

  /// Restores inventory that was decremented at transfer initiation.
  ///
  /// This method reads the locked selection from transfer metadata and increments
  /// the quantities back to their original values. Called when a transfer is
  /// rejected or cancelled.
  Future<void> restoreTransferInventory(TransferEvent transfer) async {
    final organismRepository = _organismRecordRepository;
    if (organismRepository == null) {
      LoggingService.instance.warning(
        'OrganismRecordRepository not configured; skipping inventory restoration '
        'for transfer ${transfer.id}',
      );
      return;
    }

    // Check if inventory was actually adjusted
    final inventoryAdjusted = transfer.metadata?['inventoryAdjusted'] == true;
    if (!inventoryAdjusted) {
      LoggingService.instance.debug(
        'Transfer ${transfer.id} inventory was not adjusted; skipping restoration',
      );
      return;
    }

    // Extract the locked selection from metadata
    final lockedSelection = extractLockedSelectionFromMetadata(transfer);
    if (lockedSelection.isEmpty) {
      LoggingService.instance.warning(
        'Transfer ${transfer.id} has no locked selection in metadata; '
        'cannot restore inventory',
      );
      return;
    }

    LoggingService.instance
        .info('Restoring inventory for transfer ${transfer.id}', {
          'organismCount': lockedSelection.length,
          'totalQuantity': lockedSelection.values.fold<int>(
            0,
            (total, qty) => total + qty,
          ),
        });

    // Phase 1: Pre-validate all organisms before making any changes
    final validatedOrganisms = <String, (OrganismRecord, int)>{};
    final validationErrors = <String>[];

    for (final entry in lockedSelection.entries) {
      final organismId = entry.key;
      final quantityToRestore = entry.value;
      if (quantityToRestore <= 0) continue;

      try {
        final organism = await organismRepository.getRecordForId(organismId);
        if (organism == null) {
          validationErrors.add('Organism $organismId not found');
          continue;
        }

        final currentQuantity = organism.measurement.value.toInt();
        final nextQuantity = currentQuantity + quantityToRestore;

        validatedOrganisms[organismId] = (organism, nextQuantity);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to validate organism $organismId for inventory restoration',
          e,
          stackTrace,
        );
        validationErrors.add('Organism $organismId validation failed: $e');
      }
    }

    // Log validation errors but continue with valid organisms
    if (validationErrors.isNotEmpty) {
      LoggingService.instance.warning(
        'Transfer ${transfer.id} inventory restoration had validation errors',
        {'errors': validationErrors},
      );
    }

    if (validatedOrganisms.isEmpty) {
      LoggingService.instance.warning(
        'No valid organisms found to restore for transfer ${transfer.id}',
      );
      return;
    }

    // Phase 2: Apply all increments
    final successfulRestorations = <String, int>{};
    var hadApplyError = false;

    for (final entry in validatedOrganisms.entries) {
      final organismId = entry.key;
      final (organism, nextQuantity) = entry.value;
      final incrementAmount = nextQuantity - organism.measurement.value.toInt();

      try {
        await organismRepository.updatePopulation(
          organism,
          nextQuantity,
          comment:
              'Transfer ${transfer.id} rejected/cancelled - inventory restored',
        );

        successfulRestorations[organismId] = incrementAmount;
      } catch (e, stackTrace) {
        hadApplyError = true;
        LoggingService.instance.error(
          'Failed to restore inventory for organism $organismId in transfer ${transfer.id}',
          e,
          stackTrace,
        );
        // Log successful restorations for manual recovery if needed
        if (successfulRestorations.isNotEmpty) {
          LoggingService.instance.error(
            'PARTIAL INVENTORY RESTORATION: Transfer ${transfer.id} '
            'partially restored. Manual review required.',
            {
              'transferId': transfer.id,
              'successfulRestorations': successfulRestorations,
              'failedOrganism': organismId,
              'failedIncrement': incrementAmount,
            },
            stackTrace,
          );
        }
        break; // Stop on first error during apply phase
      }
    }

    if (hadApplyError) {
      return;
    }

    // Mark inventory restoration as complete in transfer metadata
    await markTransferInventoryRestored(transfer);

    LoggingService.instance
        .info('Inventory restored for transfer ${transfer.id}', {
          'restoredOrganisms': successfulRestorations.length,
          'totalRestored': successfulRestorations.values.fold<int>(
            0,
            (total, qty) => total + qty,
          ),
        });
  }

  /// Marks the transfer as having its inventory restored.
  Future<void> markTransferInventoryRestored(TransferEvent transfer) async {
    final updatedMetadata = Map<String, dynamic>.from(
      transfer.metadata ?? const {},
    );
    updatedMetadata['inventoryRestored'] = true;
    updatedMetadata['inventoryRestoredAt'] = DateTime.now()
        .toUtc()
        .toIso8601String();
    updatedMetadata['inventoryRestoredById'] = _provenanceRepository.user.id;

    try {
      await _db.collection('events').doc(transfer.id).update({
        'metadata.inventoryRestored': true,
        'metadata.inventoryRestoredAt': DateTime.now()
            .toUtc()
            .toIso8601String(),
        'metadata.inventoryRestoredById': _provenanceRepository.user.id,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'updatedById': _provenanceRepository.user.id,
      });
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to mark transfer ${transfer.id} as inventory restored',
        {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }

  /// Returns the current inventory count at the source structure for a genet.
  Future<int> getSourceInventoryCount({
    required String genetId,
    String? sourceStructureUrlPath,
  }) async {
    try {
      final organization = _provenanceRepository.organization;

      final collection = _db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection(ModelType.organismRecord.collectionPath);

      LoggingService.instance.debug(
        '🔍 Transfer inventory check: querying ${ModelType.organismRecord.collectionPath}',
        {
          'organizationId': organization.id,
          'genetId': genetId,
          'sourceStructureUrlPath': sourceStructureUrlPath,
          'collectionPath':
              'organizations/${organization.id}/${ModelType.organismRecord.collectionPath}',
        },
      );

      final genetDocs = await loadOrganismDocsForGenet(
        collection: collection,
        genetId: genetId,
      );

      LoggingService.instance.debug(
        '🔍 Transfer inventory check: found ${genetDocs.length} '
        '${ModelType.organismRecord.collectionPath} for genet',
      );

      int totalCount = 0;
      final matchingGenetCount = genetDocs.length;
      int matchingPathCount = 0;

      for (final doc in genetDocs) {
        final data = doc.data();

        // Filter by sourceStructureUrlPath if specified
        if (sourceStructureUrlPath != null) {
          final urlPath = data['urlPath'] as String?;
          if (urlPath == null ||
              !_matchesPathPrefix(urlPath, sourceStructureUrlPath)) {
            continue;
          }
        }
        matchingPathCount++;

        final measurement = data['measurement'];
        final quantity = resolveOrganismQuantity(data);
        if (quantity > 0) {
          totalCount += quantity;
          LoggingService.instance.debug(
            '🔍 Transfer inventory: found organism_record with measurement',
            {
              'docId': doc.id,
              'genetId': genetId,
              'urlPath': data['urlPath'],
              'measurementValue': quantity,
              'runningTotal': totalCount,
            },
          );
        } else {
          LoggingService.instance.debug(
            '🔍 Transfer inventory: organism_record has no measurement',
            {
              'docId': doc.id,
              'genetId': genetId,
              'urlPath': data['urlPath'],
              'measurement': measurement,
            },
          );
        }
      }

      LoggingService.instance.info('🔍 Transfer inventory result', {
        'genetId': genetId,
        'sourceStructureUrlPath': sourceStructureUrlPath,
        'totalOrganismRecords': genetDocs.length,
        'matchingGenetId': matchingGenetCount,
        'matchingPath': matchingPathCount,
        'totalInventoryCount': totalCount,
      });

      return totalCount;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get source inventory count',
        e,
        stackTrace,
      );
      // Return 0 on error to be conservative (will fail validation if quantity > 0)
      return 0;
    }
  }

  /// Returns the count of organisms in pending outbound transfers for a genet.
  Future<int> getPendingOutboundCount({
    required String genetId,
    String? sourceStructureUrlPath,
  }) async {
    try {
      final organization = _provenanceRepository.organization;

      LoggingService.instance.debug(
        '🔍 Transfer pending check: querying events for pending/shipped transfers',
        {
          'organizationId': organization.id,
          'genetId': genetId,
          'sourceStructureUrlPath': sourceStructureUrlPath,
        },
      );

      // Query transfer events for this genet that are pending or shipped
      final snapshot = await _db
          .collection('events')
          .where('organizationId', isEqualTo: organization.id)
          .where('genetId', isEqualTo: genetId)
          .get();

      LoggingService.instance.debug(
        '🔍 Transfer pending check: found ${snapshot.docs.length} events for this genet',
      );

      int totalPending = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Filter by eventTypeId and status in memory
        final eventTypeId = data['eventTypeId'];
        if (!LoanEventType.queryIds.contains(eventTypeId)) {
          continue;
        }

        final metadata = data['metadata'];
        if (metadata is Map && metadata['inventoryAdjusted'] == true) {
          continue;
        }

        final status = data['status'];
        if (status != TransferStatus.pending.value &&
            status != TransferStatus.shipped.value) {
          continue;
        }

        // If sourceStructureUrlPath is specified, only count transfers from that structure
        if (sourceStructureUrlPath != null) {
          final transferSourcePath = data['sourceUrlPath'] as String?;
          if (transferSourcePath == null ||
              !_matchesPathPrefix(transferSourcePath, sourceStructureUrlPath)) {
            continue;
          }
        }

        final quantity = data['quantity'];
        if (quantity is int) {
          totalPending += quantity;
          LoggingService.instance
              .debug('🔍 Transfer pending: found pending/shipped transfer', {
                'eventId': doc.id,
                'eventTypeId': eventTypeId,
                'status': status,
                'quantity': quantity,
                'runningTotal': totalPending,
              });
        }
      }

      LoggingService.instance.info('🔍 Transfer pending result', {
        'genetId': genetId,
        'sourceStructureUrlPath': sourceStructureUrlPath,
        'totalEvents': snapshot.docs.length,
        'totalPendingQuantity': totalPending,
      });

      return totalPending;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to get pending outbound count',
        e,
        stackTrace,
      );
      // Return a large number on error to be conservative (will likely fail validation)
      return 999999;
    }
  }

  /// Atomically locks organisms for a transfer within a transaction.
  Future<Map<String, int>> lockOrganismsInTransaction({
    required Transaction transaction,
    required String genetId,
    required String transferId,
    required int quantity,
    required String organizationId,
    String? sourceStructureUrlPath,
    Map<String, int>? inventorySelection,
  }) async {
    final lockedSelection = <String, int>{};

    final collection = _db
        .collection(ModelType.organization.collectionPath)
        .doc(organizationId)
        .collection(ModelType.organismRecord.collectionPath);

    final genetDocs = await loadOrganismDocsForGenet(
      collection: collection,
      genetId: genetId,
    );

    if (genetDocs.isEmpty) {
      LoggingService.instance.warning(
        'No organism records found for genet $genetId - skipping organism locking',
      );
      return {};
    }

    // Filter by sourceStructureUrlPath
    final eligibleDocs = genetDocs.where((doc) {
      final data = doc.data();
      if (sourceStructureUrlPath != null) {
        final urlPath = data['urlPath'] as String?;
        if (urlPath == null ||
            !_matchesPathPrefix(urlPath, sourceStructureUrlPath)) {
          return false;
        }
      }
      return true;
    }).toList();

    final now = DateTime.now().toIso8601String();

    if (inventorySelection != null && inventorySelection.isNotEmpty) {
      // Lock specific organisms from selection
      for (final entry in inventorySelection.entries) {
        final organismId = entry.key;
        final requestedQty = entry.value;
        if (requestedQty <= 0) continue;

        final doc = eligibleDocs.firstWhereOrNull((d) => d.id == organismId);
        if (doc == null) {
          throw TransferWorkflowException(
            'Selected organism $organismId could not be found in inventory.',
          );
        }

        final data = doc.data();

        // Check if organism is pending outplant
        final isPendingOutplant = data['metadata']?['pendingOutplant'] == true;
        if (isPendingOutplant) {
          final displayName =
              data['metadata']?['localId'] as String? ?? organismId;
          throw TransferWorkflowException(
            'Organism "$displayName" is allocated to a pending outplant batch and cannot be transferred. '
            'Remove it from the outplant batch first.',
          );
        }

        final existingLock = data['metadata']?['pendingTransferId'] as String?;
        if (existingLock != null && existingLock != transferId) {
          throw TransferWorkflowException(
            'Organism $organismId is already locked by transfer $existingLock',
          );
        }

        final organismQty = resolveOrganismQuantity(data, fallback: 0);
        if (requestedQty > organismQty) {
          final displayName =
              data['metadata']?['localId'] as String? ?? organismId;
          throw TransferWorkflowException(
            'Organism "$displayName" has only $organismQty available.',
          );
        }

        transaction.update(doc.reference, {
          'metadata.pendingTransferId': transferId,
          'metadata.lockedTransferQuantity': requestedQty,
          'updatedAt': now,
        });
        lockedSelection[organismId] = requestedQty;
      }
    } else {
      // Auto-select organisms up to quantity
      var remaining = quantity;
      for (final doc in eligibleDocs) {
        if (remaining <= 0) break;

        final data = doc.data();
        final existingLock = data['metadata']?['pendingTransferId'] as String?;
        if (existingLock != null) continue; // Skip locked organisms

        // Skip organisms pending outplant
        final isPendingOutplant = data['metadata']?['pendingOutplant'] == true;
        if (isPendingOutplant) continue;

        final organismQty = resolveOrganismQuantity(data, fallback: 1);
        final toLock = organismQty < remaining ? organismQty : remaining;

        transaction.update(doc.reference, {
          'metadata.pendingTransferId': transferId,
          'metadata.lockedTransferQuantity': toLock,
          'updatedAt': now,
        });
        lockedSelection[doc.id] = toLock;
        remaining -= toLock;
      }
    }

    return lockedSelection;
  }

  String? resolveOrganismGenetId(Map<String, dynamic> data) {
    return GenetIdResolver.resolveFromJson(data);
  }

  bool matchesGenetId(Map<String, dynamic> data, String genetId) {
    final resolved = resolveOrganismGenetId(data);
    return resolved != null && resolved == genetId;
  }

  int resolveOrganismQuantity(Map<String, dynamic> data, {int fallback = 0}) {
    final measurement = data['measurement'];
    if (measurement is Map) {
      final value = measurement['value'];
      if (value is num) return value.toInt();
    } else if (measurement is num) {
      return measurement.toInt();
    }
    final inventoryCount = data['inventoryCount'];
    if (inventoryCount is num) return inventoryCount.toInt();
    return fallback;
  }

  bool _isArchivedOrganismData(Map<String, dynamic> data) {
    if (data['archived'] == true || data['isDeleted'] == true) {
      return true;
    }
    final metadata = data['metadata'];
    if (metadata is Map) {
      return metadata['archived'] == true || metadata['isDeleted'] == true;
    }
    return false;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  loadOrganismDocsForGenet({
    required CollectionReference<Map<String, dynamic>> collection,
    required String genetId,
  }) async {
    // Reject provenance-formatted IDs in doc-ID fields to prevent cross-type
    // confusion. Callers should use the top-level genetId (Firestore doc ID).
    if (RegExp(r'^(PID|SF)-').hasMatch(genetId)) {
      LoggingService.instance.warning(
        'loadOrganismDocsForGenet called with provenance-formatted ID: '
        '$genetId — expected a Firestore doc ID',
      );
    }

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    var hadQueryFailure = false;

    // Primary query: top-level genetId field (canonical after Team Alpha unification)
    try {
      final snapshot = await collection
          .where('genetId', isEqualTo: genetId)
          .get();
      for (final doc in snapshot.docs) {
        if (_isArchivedOrganismData(doc.data())) continue;
        docsById[doc.id] = doc;
      }
    } on FirebaseException catch (e) {
      hadQueryFailure = true;
      LoggingService.instance.debug(
        'Transfer inventory primary query failed; will use in-memory filter',
        {'genetId': genetId, 'code': e.code, 'message': e.message},
      );
    }

    if (docsById.isNotEmpty && !hadQueryFailure) {
      return docsById.values.toList();
    }

    // Fallback: scan all docs and match using resolveOrganismGenetId
    if (hadQueryFailure) {
      LoggingService.instance.debug(
        'Transfer inventory query incomplete; scanning for genet matches',
        {'genetId': genetId, 'seededMatches': docsById.length},
      );
    }

    final snapshot = await collection.get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (_isArchivedOrganismData(data)) continue;
      if (matchesGenetId(data, genetId)) {
        docsById[doc.id] = doc;
      }
    }

    return docsById.values.toList();
  }

  /// Registers the transfer mapping in the community Provenance ID crosswalk.
  ///
  /// When [transaction] is provided, the crosswalk update is performed within
  /// the transaction for atomicity with genet creation and transfer status
  /// update. When omitted, falls back to a standalone update (best-effort).
  ///
  /// [preResolvedProvenanceId] should be provided when using transactional mode
  /// to avoid queries inside the transaction. Use [_findCrosswalkProvenanceId]
  /// to resolve this value BEFORE starting the transaction.
  Future<void> registerCrosswalkMapping({
    required TransferEvent transfer,
    required TransferManifest manifest,
    required ProvenanceRecord createdGenet,
    Transaction? transaction,
    String? preResolvedProvenanceId,
  }) async {
    if (_crosswalkService == null) {
      LoggingService.instance.debug(
        'Crosswalk service not configured - skipping transfer mapping',
      );
      return;
    }

    String? sourceProvenanceId;
    String? sourceOrgId;
    String? provenanceId;
    String? localProvenanceId;
    String? receivingOrgId;

    try {
      // Extract the source provenanceId from the manifest
      sourceProvenanceId = manifest.genet['provenanceId'] as String?;
      if (sourceProvenanceId == null || sourceProvenanceId.isEmpty) {
        LoggingService.instance.debug(
          'No source provenanceId in manifest - skipping crosswalk mapping',
        );
        return;
      }

      sourceOrgId = transfer.fromOrganizationId;
      if (sourceOrgId == null || sourceOrgId.isEmpty) {
        return;
      }

      // Use pre-resolved ID if provided (transactional mode), otherwise query
      final crosswalk = _crosswalkService;
      if (preResolvedProvenanceId != null) {
        provenanceId = preResolvedProvenanceId;
      } else {
        // Try to find an existing community Provenance ID entry
        // Note: This should only be used in non-transactional mode
        provenanceId = await crosswalk.findExistingCrosswalkEntry(
          sourceProvenanceId: sourceProvenanceId,
          sourceOrganizationId: sourceOrgId,
          speciesCode: manifest.genet['speciesCode'] as String?,
        );
      }

      if (provenanceId == null) {
        LoggingService.instance.debug(
          'Source provenanceId "$sourceProvenanceId" not in community crosswalk - '
          'mapping not registered (this is normal for local-only genets)',
        );
        return;
      }

      // Register the receiving organization's local ID as a new alias.
      // The PID is the shared index; aliases are org-specific local IDs.
      localProvenanceId = createdGenet.localId?.trim();
      receivingOrgId = _provenanceRepository.organization.id;

      if (localProvenanceId == null || localProvenanceId.isEmpty) {
        LoggingService.instance.debug(
          'No receiving localId available - skipping crosswalk mapping',
        );
        return;
      }

      if (transaction != null) {
        // Transactional path: include crosswalk update in the same transaction
        // as genet creation and transfer status update
        final provenanceDocRef = crosswalk.getProvenanceDocRef(provenanceId);
        final provenanceDoc = await transaction.get(provenanceDocRef);

        crosswalk.registerTransferMappingInTransaction(
          transaction: transaction,
          provenanceDocRef: provenanceDocRef,
          provenanceDoc: provenanceDoc,
          provenanceId: provenanceId,
          localOrganizationId: receivingOrgId,
          localProvenanceId: localProvenanceId,
        );

        LoggingService.instance.info(
          'Queued crosswalk mapping in transaction: $localProvenanceId -> $provenanceId '
          '(from $sourceOrgId to $receivingOrgId)',
        );
      } else {
        // Non-transactional fallback (best-effort)
        await crosswalk.registerTransferMapping(
          provenanceId: provenanceId,
          localGenetId: createdGenet.id,
          localOrganizationId: receivingOrgId,
          localProvenanceId: localProvenanceId,
        );

        LoggingService.instance.info(
          'Registered crosswalk mapping: $localProvenanceId -> $provenanceId '
          '(from $sourceOrgId to $receivingOrgId)',
        );
      }
    } catch (e, stackTrace) {
      // In transactional mode, rethrow to roll back the entire transaction
      if (transaction != null) {
        LoggingService.instance.error(
          'Crosswalk registration failed in transaction - rolling back',
          e,
          stackTrace,
        );
        rethrow;
      }

      // Best-effort mode - don't fail the transfer if crosswalk update fails
      LoggingService.instance.warning(
        'Failed to register crosswalk mapping (non-fatal): $e',
      );
      LoggingService.instance.debug('Crosswalk error details: $stackTrace');

      // Persist the failure for audit trail and later retry
      await recordCrosswalkRegistrationFailure(
        transferEventId: transfer.id,
        createdGenetId: createdGenet.id,
        sourceProvenanceId: sourceProvenanceId,
        sourceOrganizationId: sourceOrgId,
        provenanceId: provenanceId,
        localProvenanceId: localProvenanceId,
        receivingOrganizationId: receivingOrgId,
        errorMessage: e.toString(),
      );
    }
  }

  /// Pre-fetches the community crosswalk Provenance ID for use in transactions.
  ///
  /// This should be called BEFORE starting the transaction to avoid queries
  /// inside the transaction. Returns null if the source genet is not in the
  /// community crosswalk (which is normal for local-only genets).
  Future<String?> _findCrosswalkProvenanceId({
    required TransferEvent transfer,
    required TransferManifest manifest,
  }) async {
    if (_crosswalkService == null) {
      return null;
    }

    final sourceProvenanceId = manifest.genet['provenanceId'] as String?;
    if (sourceProvenanceId == null || sourceProvenanceId.isEmpty) {
      return null;
    }

    final sourceOrgId = transfer.fromOrganizationId;
    if (sourceOrgId == null || sourceOrgId.isEmpty) {
      return null;
    }

    try {
      return await _crosswalkService.findExistingCrosswalkEntry(
        sourceProvenanceId: sourceProvenanceId,
        sourceOrganizationId: sourceOrgId,
        speciesCode: manifest.genet['speciesCode'] as String?,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to pre-fetch crosswalk provenance ID (will skip registration): $e',
      );
      LoggingService.instance.debug('Pre-fetch error details: $stackTrace');
      return null;
    }
  }

  /// Records a failed crosswalk registration attempt for audit trail and retry.
  Future<void> recordCrosswalkRegistrationFailure({
    required String transferEventId,
    required String createdGenetId,
    String? sourceProvenanceId,
    String? sourceOrganizationId,
    String? provenanceId,
    String? localProvenanceId,
    String? receivingOrganizationId,
    required String errorMessage,
  }) async {
    try {
      final failureRecord = <String, dynamic>{
        'transferEventId': transferEventId,
        'createdGenetId': createdGenetId,
        'sourceProvenanceId': sourceProvenanceId,
        'sourceOrganizationId': sourceOrganizationId,
        'provenanceId': provenanceId,
        'localProvenanceId': localProvenanceId,
        'receivingOrganizationId': receivingOrganizationId,
        'errorMessage': errorMessage,
        'failedAt': DateTime.now().toUtc().toIso8601String(),
        'retryCount': 0,
        'status': 'pending_retry',
      };

      // Store the failure in the transfer event's metadata
      await _db.collection('events').doc(transferEventId).update({
        'crosswalkRegistrationFailure': failureRecord,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      LoggingService.instance.info(
        'Recorded crosswalk registration failure for transfer $transferEventId',
      );
    } catch (e, stackTrace) {
      // Don't fail silently - log the error but don't throw
      LoggingService.instance.error(
        'Failed to record crosswalk registration failure',
        e,
        stackTrace,
      );
    }
  }

  /// Checks if [path] matches [prefix] as a proper path prefix.
  ///
  /// Returns true if:
  /// - [path] equals [prefix] exactly, OR
  /// - [path] starts with [prefix] followed by "/"
  ///
  /// This prevents false positives where "/transfer" would incorrectly
  /// match "/transfer-history" when using simple startsWith().
  bool _matchesPathPrefix(String path, String prefix) {
    if (path == prefix) {
      return true;
    }
    // Ensure the prefix is followed by a path separator
    final normalizedPrefix = prefix.endsWith('/') ? prefix : '$prefix/';
    return path.startsWith(normalizedPrefix);
  }
}
