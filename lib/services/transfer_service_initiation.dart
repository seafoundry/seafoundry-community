part of 'transfer_service.dart';

/// Transfer initiation methods for [TransferService].
///
/// This part file contains methods for initiating transfers to organizations
/// and email recipients.
extension _TransferServiceInitiation on TransferService {
  Future<TransferEvent> performInitiateTransfer({
    required String genetRecordId,
    required String toOrganizationId,
    required int quantity,
    String? sourceStructureUrlPath,
    String? comment,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
    Map<String, int>? inventorySelection,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) async {
    try {
      final sourceOrgId = _provenanceRepository.organization.id;
      if (sourceOrgId == toOrganizationId) {
        throw TransferWorkflowException(
          'Transfers must be sent to a different organization.',
        );
      }
      final genet = await _provenanceRepository.getRecordForId(genetRecordId);
      if (genet == null) {
        throw TransferWorkflowException('Genet not found: $genetRecordId');
      }

      // Pre-fetch data needed for transfer creation
      // (actual inventory validation happens atomically inside transaction)
      final targetOrganization = await lookupOrganization(toOrganizationId);
      final organization = _provenanceRepository.organization;
      final user = _provenanceRepository.user;

      final transferId = _idGenerator();
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final slug = await _eventRepository.nextSlugForModelType(ModelType.event);

      final sourcePath = sourceStructureUrlPath;
      final selection = resolveProvenanceSelection(
        genet: genet,
        overrideProvenanceType: provenanceTypeOverride,
        overrideLifeStage: lifeStageOverride,
      );
      final selectionMetadata = buildSelectionMetadata(
        selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
      );

      final geometry = buildGeometryFromInput(geometryInput);

      final draft = TransferEvent.initiate(
        id: transferId,
        genetRecordId: genetRecordId,
        recordId: genetRecordId,
        createdById: user.id,
        createdAt: nowIso,
        updatedAt: nowIso,
        updatedById: user.id,
        organizationId: organization.id,
        urlPath: '${genet.metadata['urlPath']}/$slug',
        internalPath: '${genet.metadata['internalPath']}/$transferId',
        slug: slug,
        toOrganizationId: targetOrganization.id,
        sourceStructureUrlPath: sourcePath,
        quantity: quantity,
        comment: comment,
        permitMetadata: permitMetadata,
        metadata: selectionMetadata.isEmpty ? null : selectionMetadata,
        geometry: geometry,
      );

      final manifestDraft = buildManifest(
        transferEvent: draft,
        genet: genet,
        fromOrganization: organization,
        toOrganization: targetOrganization,
        quantity: quantity,
        comment: comment,
        sourceStructureUrlPath: sourcePath,
        initiatedBy: user,
        selection: selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
        ownershipType: ownershipType,
        originalOwnerOrganizationId: originalOwnerOrganizationId,
      );

      final manifest = manifestDraft.updateStatus(
        TransferStatus.pending,
        timestamp: now,
        actorId: user.id,
      );

      final pendingHistory = appendStateHistory(
        draft,
        TransferStatus.pending,
        user.id,
        timestamp: now,
      );

      final pendingEvent = draft.copyWith(
        status: TransferStatus.pending.value,
        updatedAt: nowIso,
        updatedById: user.id,
        manifest: manifest.toJson(),
        manifestVersion: manifest.version,
        stateHistory: pendingHistory,
      );

      // Validate inventory before creating transfer
      // Note: Reads are done outside transaction to avoid async issues inside transaction callbacks
      final sourceInventory = await getSourceInventoryCount(
        genetRecordId: genetRecordId,
        sourceStructureUrlPath: sourceStructureUrlPath,
      );

      final pendingOutbound = await getPendingOutboundCount(
        genetRecordId: genetRecordId,
        sourceStructureUrlPath: sourceStructureUrlPath,
      );

      final availableQuantity = sourceInventory - pendingOutbound;
      LoggingService.instance.info(
        '🔍 Transfer validation: inventory calculation',
        {
          'genetRecordId': genetRecordId,
          'sourceInventory': sourceInventory,
          'pendingOutbound': pendingOutbound,
          'availableQuantity': availableQuantity,
          'requestedQuantity': quantity,
          'willPass': quantity <= availableQuantity,
        },
      );
      if (quantity > availableQuantity) {
        throw TransferWorkflowException(
          'Insufficient inventory. Available: $availableQuantity, Requested: $quantity',
        );
      }

      // Create the transfer event with atomic organism locking
      final enriched = _eventRepository.withOrganismMetadata(pendingEvent);
      final docRef = _db.collection('events').doc(enriched.id);

      LoggingService.instance.debug(
        'Creating transfer event',
        {
          'genetRecordId': genetRecordId,
          'transferId': transferId,
          'organizationId': organization.id,
          'toOrganizationId': targetOrganization.id,
          'createdById': user.id,
          'userEmail': user.email,
          'sourceStructureUrlPath': sourcePath,
          'inventorySelectionCount': inventorySelection?.length ?? 0,
          'collectionPath': docRef.path,
        },
      );
      _logTransferPayloadDiagnostics(
        transferId: transferId,
        event: enriched,
        manifest: manifest,
      );

      // Atomically create transfer and lock organisms in a transaction
      final lockedSelection = await _db.runTransaction<Map<String, int>>((
        transaction,
      ) async {
        LoggingService.instance.debug(
          'Transfer transaction started',
          {
            'transferId': transferId,
            'genetRecordId': genetRecordId,
            'organizationId': organization.id,
            'collectionPath': docRef.path,
          },
        );
        try {
          final locked = await lockOrganismsInTransaction(
            transaction: transaction,
            genetRecordId: genetRecordId,
            transferId: transferId,
            quantity: quantity,
            organizationId: organization.id,
            sourceStructureUrlPath: sourcePath,
            inventorySelection: inventorySelection,
          );
          LoggingService.instance.debug(
            'Transfer transaction locked organisms',
            {
              'transferId': transferId,
              'lockedCount': locked.length,
              'lockedTotal': locked.values.fold<int>(
                0,
                (total, value) => total + value,
              ),
            },
          );
          transaction.set(docRef, enriched.toJson());
          LoggingService.instance.debug(
            'Transfer transaction wrote event',
            {
              'transferId': transferId,
              'eventId': enriched.id,
            },
          );
          return locked;
        } catch (e, stackTrace) {
          final jsDescription = describeJsError(e) ?? e.toString();
          LoggingService.instance.error(
            'Transfer transaction failed: $jsDescription',
            e,
            stackTrace,
          );
          rethrow;
        }
      });

      LoggingService.instance.debug(
        'Transfer created with ${lockedSelection.length} organisms locked',
      );

      final notificationOutcome = await createTransferNotification(
        fromOrganization: organization,
        toOrganization: targetOrganization,
        genet: genet,
        transferEvent: pendingEvent,
        status: TransferStatus.pending,
        metadata: selectionMetadata,
      );
      if (notificationOutcome == TransferNotificationOutcome.failed) {
        LoggingService.instance.warning(
          'Transfer notification creation failed for transfer ${pendingEvent.id}',
        );
      }

      // Store locked selection in metadata for potential restoration on reject/cancel
      final transferWithSelection = await storeLockedSelectionInMetadata(
        transferEvent: pendingEvent,
        lockedSelection: lockedSelection,
      );

      final adjustedTransfer = await applyTransferInventoryDecrement(
        transferEvent: transferWithSelection,
        lockedSelection: lockedSelection,
      );

      LoggingService.instance.info(
        'Transfer initiated: ${genet.displayName} from ${organization.name} to ${targetOrganization.name}',
      );

      return adjustedTransfer;
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error(
        'Firebase error initiating transfer: code=${e.code}, message=${e.message}',
        e,
        stackTrace,
      );
      // Rethrow with more helpful message for UI
      throw TransferWorkflowException(
        'Transfer failed: ${e.message ?? e.code} (${e.code})',
      );
    } catch (e, stackTrace) {
      final jsDescription = describeJsError(e);
      if (jsDescription != null && jsDescription.isNotEmpty) {
        LoggingService.instance.error(
          'Failed to initiate transfer: $jsDescription',
          e,
          stackTrace,
        );
        throw TransferWorkflowException(jsDescription);
      }
      LoggingService.instance.error(
        'Failed to initiate transfer',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  void _logTransferPayloadDiagnostics({
    required String transferId,
    required TransferEvent event,
    required TransferManifest manifest,
  }) {
    try {
      final manifestPayload = jsonEncode(manifest.toJson());
      LoggingService.instance.debug(
        'Transfer manifest payload size',
        {
          'transferId': transferId,
          'bytes': utf8.encode(manifestPayload).length,
        },
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to encode transfer manifest payload for diagnostics',
        {
          'transferId': transferId,
          'error': e.toString(),
        },
      );
    }

    final eventJson = event.toJson();
    try {
      final eventPayload = jsonEncode(eventJson);
      LoggingService.instance.debug(
        'Transfer event payload size',
        {
          'transferId': transferId,
          'bytes': utf8.encode(eventPayload).length,
        },
      );
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to encode transfer event payload (raw)',
        {
          'transferId': transferId,
          'error': e.toString(),
        },
      );
      try {
        final fallback = jsonEncode(
          eventJson,
          toEncodable: (value) => value.toString(),
        );
        LoggingService.instance.debug(
          'Transfer event payload size (stringified)',
          {
            'transferId': transferId,
            'bytes': utf8.encode(fallback).length,
          },
        );
      } catch (fallbackError) {
        LoggingService.instance.warning(
          'Failed to encode transfer event payload (fallback)',
          {
            'transferId': transferId,
            'error': fallbackError.toString(),
          },
        );
      }
    }
  }

  Future<TransferEvent> performInitiateTransferToEmail({
    required String genetRecordId,
    required String toOrganizationEmail,
    required int quantity,
    String? sourceStructureUrlPath,
    String? comment,
    EventPermitMetadata permitMetadata = const EventPermitMetadata.empty(),
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    OutplantGeometryInput? geometryInput,
    Map<String, int>? inventorySelection,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) async {
    try {
      // Validate email format
      final trimmedEmail = toOrganizationEmail.trim().toLowerCase();
      if (!ValidationUtils.isValidEmail(trimmedEmail)) {
        throw TransferWorkflowException(
          'Invalid recipient email address: $toOrganizationEmail',
        );
      }

      final genet = await _provenanceRepository.getRecordForId(genetRecordId);
      if (genet == null) {
        throw TransferWorkflowException('Genet not found: $genetRecordId');
      }

      final organization = _provenanceRepository.organization;
      final user = _provenanceRepository.user;

      final transferId = _idGenerator();
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      final slug = await _eventRepository.nextSlugForModelType(ModelType.event);

      final sourcePath = sourceStructureUrlPath;
      final selection = resolveProvenanceSelection(
        genet: genet,
        overrideProvenanceType: provenanceTypeOverride,
        overrideLifeStage: lifeStageOverride,
      );
      final selectionMetadata = buildSelectionMetadata(
        selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
      );

      final geometry = buildGeometryFromInput(geometryInput);

      // Create draft with email instead of organization ID
      final draft = TransferEvent.initiate(
        id: transferId,
        genetRecordId: genetRecordId,
        recordId: genetRecordId,
        createdById: user.id,
        createdAt: nowIso,
        updatedAt: nowIso,
        updatedById: user.id,
        organizationId: organization.id,
        urlPath: '${genet.metadata['urlPath']}/$slug',
        internalPath: '${genet.metadata['internalPath']}/$transferId',
        slug: slug,
        toOrganizationId: null, // No org ID for email-based transfers
        toOrganizationEmail: trimmedEmail,
        sourceStructureUrlPath: sourcePath,
        quantity: quantity,
        comment: comment,
        permitMetadata: permitMetadata,
        metadata: selectionMetadata.isEmpty ? null : selectionMetadata,
        geometry: geometry,
      );

      // Build manifest with email-only recipient info
      final manifestDraft = buildManifestForEmail(
        transferEvent: draft,
        genet: genet,
        fromOrganization: organization,
        toEmail: trimmedEmail,
        quantity: quantity,
        comment: comment,
        sourceStructureUrlPath: sourcePath,
        initiatedBy: user,
        selection: selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
        ownershipType: ownershipType,
        originalOwnerOrganizationId: originalOwnerOrganizationId,
      );

      final manifest = manifestDraft.updateStatus(
        TransferStatus.pending,
        timestamp: now,
        actorId: user.id,
      );

      final pendingHistory = appendStateHistory(
        draft,
        TransferStatus.pending,
        user.id,
        timestamp: now,
      );

      final pendingEvent = draft.copyWith(
        status: TransferStatus.pending.value,
        updatedAt: nowIso,
        updatedById: user.id,
        manifest: manifest.toJson(),
        manifestVersion: manifest.version,
        stateHistory: pendingHistory,
      );

      // Validate inventory before creating transfer
      final sourceInventory = await getSourceInventoryCount(
        genetRecordId: genetRecordId,
        sourceStructureUrlPath: sourceStructureUrlPath,
      );

      final pendingOutbound = await getPendingOutboundCount(
        genetRecordId: genetRecordId,
        sourceStructureUrlPath: sourceStructureUrlPath,
      );

      final availableQuantity = sourceInventory - pendingOutbound;
      LoggingService.instance.info(
        '🔍 Transfer validation: inventory calculation',
        {
          'genetRecordId': genetRecordId,
          'sourceInventory': sourceInventory,
          'pendingOutbound': pendingOutbound,
          'availableQuantity': availableQuantity,
          'requestedQuantity': quantity,
          'willPass': quantity <= availableQuantity,
        },
      );
      if (quantity > availableQuantity) {
        throw TransferWorkflowException(
          'Insufficient inventory. Available: $availableQuantity, Requested: $quantity',
        );
      }

      // Create the transfer event with atomic organism locking
      final enriched = _eventRepository.withOrganismMetadata(pendingEvent);
      final docRef = _db.collection('events').doc(enriched.id);

      LoggingService.instance.debug(
        'Creating email-based transfer event',
        {
          'genetRecordId': genetRecordId,
          'transferId': transferId,
          'organizationId': organization.id,
          'toOrganizationEmail': trimmedEmail,
          'createdById': user.id,
          'userEmail': user.email,
          'collectionPath': docRef.path,
        },
      );

      // Atomically create transfer and lock organisms in a transaction
      final lockedSelection = await _db.runTransaction<Map<String, int>>((
        transaction,
      ) async {
        final locked = await lockOrganismsInTransaction(
          transaction: transaction,
          genetRecordId: genetRecordId,
          transferId: transferId,
          quantity: quantity,
          organizationId: organization.id,
          sourceStructureUrlPath: sourcePath,
          inventorySelection: inventorySelection,
        );

        transaction.set(docRef, enriched.toJson());
        return locked;
      });

      // Note: No notification created for email-based transfers
      // The recipient will receive the transfer via email/QR code

      // Store locked selection in metadata for potential restoration on reject/cancel
      final transferWithSelection = await storeLockedSelectionInMetadata(
        transferEvent: pendingEvent,
        lockedSelection: lockedSelection,
      );

      final adjustedTransfer = await applyTransferInventoryDecrement(
        transferEvent: transferWithSelection,
        lockedSelection: lockedSelection,
      );

      LoggingService.instance.info(
        'Email-based transfer initiated: ${genet.displayName} from ${organization.name} to $trimmedEmail',
      );

      return adjustedTransfer;
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error(
        'Firebase error initiating email transfer: code=${e.code}, message=${e.message}',
        e,
        stackTrace,
      );
      throw TransferWorkflowException(
        'Transfer failed: ${e.message ?? e.code} (${e.code})',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to initiate email transfer',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
