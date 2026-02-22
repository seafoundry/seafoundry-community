// @tier: community
part of 'transfer_service.dart';

/// Manifest building and handling methods for [TransferService].
///
/// This part file contains methods for building, parsing, and validating
/// transfer manifests and QR payloads.
extension _TransferServiceManifest on TransferService {
  /// Builds the genet payload portion of a transfer manifest.
  ///
  /// This private method extracts the common genet serialization logic
  /// shared between [buildManifest] and [buildManifestForEmail].
  Map<String, dynamic> _buildGenetPayload(ProvenanceRecord genet) {
    final provenanceId = genet.provenanceId?.trim().isNotEmpty == true
        ? genet.provenanceId
        : null;
    final resolvedSpecies = SpeciesRegistry.globalById(
      genet.speciesId,
      allowFallback: false,
    );
    if (resolvedSpecies == null) {
      throw TransferWorkflowException(
        'Transfer manifest cannot be created: unknown species "${genet.speciesId}". '
        'Please ensure taxonomy data is loaded and the genet has a valid species.',
      );
    }
    final resolvedSpeciesId = resolvedSpecies.id;
    final speciesCode = resolvedSpecies.code.trim();
    if (speciesCode.isEmpty) {
      throw TransferWorkflowException(
        'Transfer manifest cannot be created: species code missing for '
        '"${resolvedSpecies.name}" (${resolvedSpecies.id}).',
      );
    }
    final genetPayload = <String, dynamic>{
      'id': genet.id,
      'name': genet.displayName,
      'speciesId': resolvedSpeciesId,
      'speciesCode': speciesCode,
      if (genet.localId != null) 'localId': genet.localId,
      'provenanceTypeId': genet.metadata['provenanceTypeId'],
      if (provenanceId != null && provenanceId.isNotEmpty)
        'provenanceId': provenanceId,
      if (genet.metadata['clonalId'] != null)
        'clonalId': genet.metadata['clonalId'],
      if (genet.metadata['accessionNumber'] != null)
        'accessionNumber': genet.metadata['accessionNumber'],
      if (genet.metadata['notes'] != null) 'notes': genet.metadata['notes'],
      if (genet.metadata['provenance'] != null)
        'provenance': genet.metadata['provenance'],
      if (genet.metadata['parentGameteIds'] != null &&
          (genet.metadata['parentGameteIds'] as List).isNotEmpty)
        'parentGameteIds': genet.metadata['parentGameteIds'],
      if (genet.metadata['parentCohortId'] != null)
        'parentCohortId': genet.metadata['parentCohortId'],
      if (genet.metadata['donorGenotypeId'] != null)
        'donorGenotypeId': genet.metadata['donorGenotypeId'],
      if (genet.metadata['damGameteIds'] != null &&
          (genet.metadata['damGameteIds'] as List).isNotEmpty)
        'damGameteIds': genet.metadata['damGameteIds'],
      if (genet.metadata['sireGameteIds'] != null &&
          (genet.metadata['sireGameteIds'] as List).isNotEmpty)
        'sireGameteIds': genet.metadata['sireGameteIds'],
      if (genet.metadata['crossDate'] != null)
        'crossDate': genet.metadata['crossDate'],
      'readyForOutplant': genet.metadata['readyForOutplant'] == true,
      'createdAt': genet.metadata['createdAt'],
      'updatedAt': genet.metadata['updatedAt'],
    };

    final canonicalAliases =
        (genet.metadata['aliases'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        genet.aliasLabels
            .map((label) => {'value': label, 'source': 'unknown'})
            .toList();
    if (canonicalAliases.isNotEmpty) {
      genetPayload['aliases'] = canonicalAliases;
    }

    final ownership = extractOwnershipMetadata(genet.metadata);
    if (ownership.isNotEmpty) {
      genetPayload['ownership'] = ownership;
    }
    if (genet.metadata.isNotEmpty) {
      genetPayload['metadata'] = genet.metadata;
    }

    return genetPayload;
  }

  /// Builds the canonical transfer manifest that accompanies every QR payload.
  TransferManifest buildManifest({
    required TransferEvent transferEvent,
    required ProvenanceRecord genet,
    required Organization fromOrganization,
    required Organization toOrganization,
    required int quantity,
    String? comment,
    String? sourceStructureUrlPath,
    required User initiatedBy,
    required ProvenanceLifeStageSelection selection,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) {
    final genetPayload = _buildGenetPayload(genet);

    final metadata = <String, dynamic>{
      'eventSlug': transferEvent.slug,
      'recordUrlPath': genet.metadata['urlPath'],
      'recordInternalPath': genet.metadata['internalPath'],
      'quantityUnits': 'fragments',
      'organismKind': genet.organismKind.name,
    };
    metadata.addAll(
      buildSelectionMetadata(
        selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
      ),
    );

    // Add ownership type encoding (default to fullTransfer if not specified)
    final resolvedOwnershipType =
        ownershipType ?? TransferOwnershipType.fullTransfer;
    metadata['ownershipType'] = resolvedOwnershipType.id;
    if (originalOwnerOrganizationId != null &&
        originalOwnerOrganizationId.isNotEmpty) {
      metadata['originalOwnerOrganizationId'] = originalOwnerOrganizationId;
    }

    return TransferManifest(
      transferId: transferEvent.id,
      generatedAt: DateTime.now().toUtc(),
      fromOrganization: OrganizationSnapshot(
        id: fromOrganization.id,
        name: fromOrganization.name,
        domain: fromOrganization.domain,
        urlPath: fromOrganization.urlPath,
      ),
      toOrganization: OrganizationSnapshot(
        id: toOrganization.id,
        name: toOrganization.name,
        domain: toOrganization.domain,
        urlPath: toOrganization.urlPath,
      ),
      genet: GenetSnapshot.fromJson(genetPayload),
      requestedBy: UserSnapshot(
        id: initiatedBy.id,
        name: initiatedBy.name,
        email: initiatedBy.email,
      ),
      quantity: quantity,
      comment: comment,
      sourceStructureUrlPath: sourceStructureUrlPath,
      metadata: metadata,
    );
  }

  /// Builds a manifest for email-based transfers where the recipient org
  /// is not yet known.
  TransferManifest buildManifestForEmail({
    required TransferEvent transferEvent,
    required ProvenanceRecord genet,
    required Organization fromOrganization,
    required String toEmail,
    required int quantity,
    String? comment,
    String? sourceStructureUrlPath,
    required User initiatedBy,
    required ProvenanceLifeStageSelection selection,
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
    TransferOwnershipType? ownershipType,
    String? originalOwnerOrganizationId,
  }) {
    final genetPayload = _buildGenetPayload(genet);

    final metadata = <String, dynamic>{
      'eventSlug': transferEvent.slug,
      'recordUrlPath': genet.metadata['urlPath'],
      'recordInternalPath': genet.metadata['internalPath'],
      'quantityUnits': 'fragments',
      'organismKind': genet.organismKind.name,
    };
    metadata.addAll(
      buildSelectionMetadata(
        selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
      ),
    );

    // Add ownership type encoding (default to fullTransfer if not specified)
    final resolvedOwnershipType =
        ownershipType ?? TransferOwnershipType.fullTransfer;
    metadata['ownershipType'] = resolvedOwnershipType.id;
    if (originalOwnerOrganizationId != null &&
        originalOwnerOrganizationId.isNotEmpty) {
      metadata['originalOwnerOrganizationId'] = originalOwnerOrganizationId;
    }

    // For email-based transfers, use email as primary identifier
    return TransferManifest(
      transferId: transferEvent.id,
      generatedAt: DateTime.now().toUtc(),
      fromOrganization: OrganizationSnapshot(
        id: fromOrganization.id,
        name: fromOrganization.name,
        domain: fromOrganization.domain,
        urlPath: fromOrganization.urlPath,
      ),
      toOrganization: OrganizationSnapshot(
        email: toEmail,
        // No id, name, domain, or urlPath for email-only recipients
      ),
      genet: GenetSnapshot.fromJson(genetPayload),
      requestedBy: UserSnapshot(
        id: initiatedBy.id,
        name: initiatedBy.name,
        email: initiatedBy.email,
      ),
      quantity: quantity,
      comment: comment,
      sourceStructureUrlPath: sourceStructureUrlPath,
      metadata: metadata,
    );
  }

  /// Builds a Genet model from the manifest payload.
  ProvenanceRecord createGenetFromManifest({
    required TransferManifest manifest,
    required String overrideName,
    String? localId,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) {
    final genet = manifest.genet;
    final rawSpeciesId = genet.speciesId ?? genet.speciesCode;
    final provenanceId = genet.provenanceId;
    final metadata = genet.metadata != null
        ? Map<String, dynamic>.from(genet.metadata!)
        : <String, dynamic>{};

    if (rawSpeciesId == null || rawSpeciesId.isEmpty) {
      throw TransferWorkflowException('Manifest missing speciesId');
    }
    final resolvedSpecies = SpeciesRegistry.globalById(
      rawSpeciesId,
      allowFallback: false,
    );
    if (resolvedSpecies == null) {
      throw TransferWorkflowException(
        'Transfer manifest contains unknown species "$rawSpeciesId". '
        'Please ensure taxonomy data is loaded and retry the transfer.',
      );
    }
    final speciesId = resolvedSpecies.id;
    if (provenanceId == null || provenanceId.isEmpty) {
      throw TransferWorkflowException('Manifest missing provenanceId');
    }

    final provenance = genet.provenance != null
        ? Map<String, dynamic>.from(genet.provenance!)
        : <String, dynamic>{};
    metadata['transfer'] = {
      'fromOrganizationId': manifest.fromOrganization.id,
      'toOrganizationId': manifest.toOrganization.id,
      'transferEventId': manifest.transferId,
      'manifestVersion': manifest.version,
      'receivedAt': manifest.receivedAt?.toIso8601String(),
      if (genet.localId != null) 'senderLocalId': genet.localId,
      if (genet.name != null) 'senderRecordName': genet.name,
    };
    if (ownerOrganizationId != null && ownerOrganizationId.trim().isNotEmpty) {
      metadata['ownerOrganizationId'] = ownerOrganizationId.trim();
    }
    if (managingOrganizationId != null &&
        managingOrganizationId.trim().isNotEmpty) {
      metadata['managingOrganizationId'] = managingOrganizationId.trim();
    }
    if (localId != null && localId.isNotEmpty) {
      provenance['localId'] = localId;
    }

    final crossDateRaw = genet.crossDate;
    final aliasPayload = genet.aliases;

    final selectionSources = <Map<String, dynamic>>[];
    if (manifest.metadata != null && manifest.metadata!.isNotEmpty) {
      selectionSources.add(Map<String, dynamic>.from(manifest.metadata!));
    }
    if (metadata.isNotEmpty) {
      selectionSources.add(Map<String, dynamic>.from(metadata));
    }
    final fallbackKind =
        manifest.metadata?['provenanceKind']?.toString() ??
        metadata['provenanceKind']?.toString();
    final legacyProvenanceTypeId = genet.provenanceTypeId;
    final fallbackType =
        provenanceTypeOverride ??
        ProvenanceTypeX.tryParse(
          manifest.metadata?['provenanceTypeId']?.toString(),
        ) ??
        ProvenanceTypeX.tryParse(metadata['provenanceTypeId']?.toString()) ??
        ProvenanceTypeX.tryParse(legacyProvenanceTypeId);

    var selection = selectionSources.isEmpty
        ? (fallbackType != null
              ? ProvenanceLifeStageSelection(
                  provenanceType: fallbackType,
                  lifeStage: fallbackType.defaultLifeStage,
                )
              : ProvenanceLifeStageSelection.fallback())
        : ProvenanceLifeStageSelection.fromCanonicalSources(
            sources: selectionSources,
            fallbackProvenanceKind: fallbackKind,
            fallbackProvenanceType: fallbackType,
          );

    var resolvedProvenanceType =
        provenanceTypeOverride ?? selection.provenanceType;
    var resolvedLifeStage = lifeStageOverride ?? selection.lifeStage;
    final allowedStages = resolvedProvenanceType.allowedLifeStages;
    if (allowedStages.isNotEmpty &&
        !allowedStages.contains(resolvedLifeStage)) {
      resolvedLifeStage =
          allowedStages.contains(resolvedProvenanceType.defaultLifeStage)
          ? resolvedProvenanceType.defaultLifeStage
          : allowedStages.first;
    }
    selection = ProvenanceLifeStageSelection(
      provenanceType: resolvedProvenanceType,
      lifeStage: resolvedLifeStage,
    );

    metadata['provenanceTypeId'] = selection.provenanceType.id;
    metadata['provenanceType'] = selection.provenanceType.name;
    metadata['provenanceTypeLabel'] =
        selection.provenanceType.metadata.displayName;
    metadata['lifeStageId'] = selection.lifeStage.id;
    metadata['lifeStage'] = selection.lifeStage.name;
    metadata['lifeStageLabel'] = selection.lifeStage.displayName;
    metadata['provenanceKind'] =
        selection.provenanceType.defaultProvenanceKind.name;
    final ownershipRaw = genet.ownership;
    if (ownershipRaw != null) {
      final ownerId = ownershipRaw['ownerOrganizationId']?.toString();
      final managingId = ownershipRaw['managingOrganizationId']?.toString();
      if (ownerId != null && ownerId.trim().isNotEmpty) {
        metadata['ownerOrganizationId'] = ownerId.trim();
      }
      if (managingId != null && managingId.trim().isNotEmpty) {
        metadata['managingOrganizationId'] = managingId.trim();
      }
    }

    final resolvedProvenanceTypeId =
        provenanceTypeOverride?.id ??
        legacyProvenanceTypeId ??
        selection.provenanceType.id;

    // Map legacy fields to metadata
    metadata['provenanceTypeId'] = resolvedProvenanceTypeId;
    // provenanceId is stored on the top-level genet record, not in metadata
    if (genet.clonalId != null) metadata['clonalId'] = genet.clonalId;
    if (genet.accessionNumber != null)
      metadata['accessionNumber'] = genet.accessionNumber;
    if (genet.notes != null) metadata['notes'] = genet.notes;
    if (provenance.isNotEmpty) metadata['provenance'] = provenance;
    if (genet.parentGameteIds != null)
      metadata['parentGameteIds'] = genet.parentGameteIds;
    if (genet.parentCohortId != null)
      metadata['parentCohortId'] = genet.parentCohortId;
    if (genet.donorGenotypeId != null)
      metadata['donorGenotypeId'] = genet.donorGenotypeId;
    if (genet.damGameteIds != null)
      metadata['damGameteIds'] = genet.damGameteIds;
    if (genet.sireGameteIds != null)
      metadata['sireGameteIds'] = genet.sireGameteIds;
    if (crossDateRaw != null) metadata['crossDate'] = crossDateRaw;
    metadata['readyForOutplant'] = genet.readyForOutplant;

    // Build comprehensive alias list including source org's local ID
    final transferAliases = <Map<String, dynamic>>[];

    // Include all aliases from the manifest
    if (aliasPayload != null && aliasPayload.isNotEmpty) {
      transferAliases.addAll(aliasPayload);
    }

    // Add alias for source organization's local ID (if different from PID)
    final sourceLocalId = genet.localId?.trim();
    final sourceOrgName = manifest.fromOrganization.name?.trim();
    if (sourceLocalId != null &&
        sourceLocalId.isNotEmpty &&
        sourceOrgName != null &&
        sourceOrgName.isNotEmpty &&
        sourceLocalId.toLowerCase() != provenanceId.toLowerCase()) {
      // Check if value already exists in any existing alias
      final valueExists =
          aliasPayload?.any(
            (alias) =>
                alias['value']?.toString().trim().toLowerCase() ==
                sourceLocalId.toLowerCase(),
          ) ??
          false;
      if (!valueExists) {
        transferAliases.add({
          'sourceSystem': sourceOrgName,
          'value': sourceLocalId,
          'label': '$sourceOrgName: $sourceLocalId',
        });
      }
    }

    // Store aliases in metadata
    if (transferAliases.isNotEmpty) {
      metadata['aliases'] = transferAliases;
    }

    // Build foreign keys to reference source genet (ForeignKeyReference format)
    metadata['foreignKeys'] = {
      'sourceGenet': {
        'id': genet.id,
        'metadata': {
          if (manifest.fromOrganization.id != null)
            'organizationId': manifest.fromOrganization.id,
          if (manifest.fromOrganization.email != null)
            'organizationEmail': manifest.fromOrganization.email,
          'transferId': manifest.transferId,
        },
      },
    };

    // Extract organismKind from manifest metadata, fallback to coral for legacy manifests
    final organismKindRaw =
        manifest.metadata?['organismKind']?.toString() ??
        OrganismKind.coral.name;
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name.toLowerCase() == organismKindRaw.toLowerCase(),
      orElse: () => OrganismKind.coral,
    );

    return ProvenanceRecord(
      id: _idGenerator(), // Generate a new ID for the received record
      organismKind: organismKind,
      provenanceKind: selection.provenanceType.defaultProvenanceKind,
      displayName: overrideName,
      localId: localId,
      provenanceId: provenanceId,
      speciesId: speciesId,
      metadata: metadata,
      aliasLabels: transferAliases
          .map((e) => e['value']?.toString())
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toList(),
    );
  }

  /// Loads the manifest embedded on a transfer.
  TransferManifest requireManifest(TransferEvent transfer) {
    final manifestData = transfer.manifest;
    if (manifestData == null) {
      throw TransferWorkflowException(
        'Transfer ${transfer.id} is missing manifest data',
      );
    }
    return TransferManifest.fromJson(manifestData);
  }

  /// Utility for rendering manifest payloads as QR codes.
  String? safeQrPayload(TransferManifest manifest) {
    String payload;
    try {
      payload = manifest.encodePayload();
    } catch (e, stackTrace) {
      LoggingService.instance.warning('QR payload encoding failed', {
        'error': e.toString(),
        'transferId': manifest.transferId,
        'stackTrace': stackTrace.toString(),
      });
      return null;
    }
    if (QrPayloadUtils.isPayloadTooLong(payload)) {
      LoggingService.instance.warning('QR payload too large to encode', {
        'payloadLength': payload.length,
        'transferId': manifest.transferId,
      });
      return null;
    }
    try {
      final validation = QrValidator.validate(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
      if (!validation.isValid || validation.qrCode == null) {
        LoggingService.instance.warning('QR payload too large to encode', {
          'status': validation.status.name,
          'error': validation.error?.toString(),
          'payloadLength': payload.length,
          'transferId': manifest.transferId,
        });
        return null;
      }
      return payload;
    } catch (e, stackTrace) {
      LoggingService.instance.warning('QR payload validation failed', {
        'error': e.toString(),
        'payloadLength': payload.length,
        'transferId': manifest.transferId,
        'stackTrace': stackTrace.toString(),
      });
      return null;
    }
  }

  Future<Uint8List> renderQrPayload(String payload, {double size = 280}) async {
    if (QrPayloadUtils.isPayloadTooLong(payload)) {
      LoggingService.instance.warning('QR payload too large to encode', {
        'payloadLength': payload.length,
      });
      throw TransferWorkflowException('QR payload is too large to encode.');
    }
    QrValidationResult validation;
    try {
      validation = QrValidator.validate(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
    } catch (e) {
      throw TransferWorkflowException('QR payload could not be encoded.');
    }
    if (!validation.isValid || validation.qrCode == null) {
      final message = switch (validation.status) {
        QrValidationStatus.contentTooLong =>
          'QR payload is too large to encode.',
        QrValidationStatus.error => 'QR payload could not be encoded.',
        _ => 'QR payload could not be encoded.',
      };
      LoggingService.instance.warning('QR payload validation failed', {
        'status': validation.status.name,
        'error': validation.error?.toString(),
        'payloadLength': payload.length,
      });
      throw TransferWorkflowException(message);
    }

    final painter = QrPainter.withQr(qr: validation.qrCode!, gapless: true);
    final image = await painter.toImage(size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw TransferWorkflowException('Failed to encode QR code payload');
    }
    return byteData.buffer.asUint8List();
  }

  /// Clones the transfer's state history and appends the provided transition
  /// metadata.
  List<Map<String, dynamic>> appendStateHistory(
    TransferEvent transfer,
    TransferStatus status,
    String actorId, {
    DateTime? timestamp,
  }) {
    final history = List<Map<String, dynamic>>.from(
      transfer.stateHistory ?? const [],
    );
    history.add({
      'status': status.value,
      'changedAt': (timestamp ?? DateTime.now().toUtc()).toIso8601String(),
      'changedById': actorId,
    });
    return history;
  }

  ProvenanceLifeStageSelection resolveProvenanceSelection({
    required ProvenanceRecord genet,
    TransferEvent? transfer,
    ProvenanceType? overrideProvenanceType,
    LifeStage? overrideLifeStage,
  }) {
    final sources = <Map<String, dynamic>>[];
    final transferMetadata = transfer?.metadata;
    if (transferMetadata != null && transferMetadata.isNotEmpty) {
      sources.add(Map<String, dynamic>.from(transferMetadata));
    }
    final manifestData = transfer?.manifest;
    if (manifestData != null) {
      final manifestMetadata = manifestData['metadata'];
      if (manifestMetadata is Map<String, dynamic> &&
          manifestMetadata.isNotEmpty) {
        sources.add(Map<String, dynamic>.from(manifestMetadata));
      }
    }
    final genetMetadata = genet.metadata;
    if (genetMetadata.isNotEmpty) {
      sources.add(Map<String, dynamic>.from(genetMetadata));
    }

    final baseSelection = sources.isEmpty
        ? ProvenanceLifeStageSelection.fromProvenanceRecord(genet)
        : ProvenanceLifeStageSelection.fromCanonicalSources(sources: sources);

    var provenanceType = overrideProvenanceType ?? baseSelection.provenanceType;
    var lifeStage = overrideLifeStage ?? baseSelection.lifeStage;

    final allowedStages = provenanceType.allowedLifeStages;
    if (allowedStages.isNotEmpty && !allowedStages.contains(lifeStage)) {
      final preferred = allowedStages.contains(provenanceType.defaultLifeStage)
          ? provenanceType.defaultLifeStage
          : allowedStages.first;
      lifeStage = preferred;
    }

    return ProvenanceLifeStageSelection(
      provenanceType: provenanceType,
      lifeStage: lifeStage,
    );
  }

  Map<String, dynamic> buildSelectionMetadata(
    ProvenanceLifeStageSelection selection, {
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
  }) {
    final metadata = <String, dynamic>{
      'provenanceTypeId': selection.provenanceType.id,
      'provenanceType': selection.provenanceType.name,
      'provenanceTypeLabel': selection.provenanceType.metadata.displayName,
      'lifeStageId': selection.lifeStage.id,
      'lifeStage': selection.lifeStage.name,
      'lifeStageLabel': selection.lifeStage.displayName,
      'provenanceKind': selection.provenanceType.defaultProvenanceKind.name,
    };
    if (physicalFormOverride != null) {
      metadata['physicalFormId'] = physicalFormOverride;
    }
    if (sizeSpecOverride != null && sizeSpecOverride.hasSize) {
      metadata['size'] = sizeSpecOverride.toJson();
    } else if (sizeSpecOverride != null && sizeSpecOverride.isEmpty) {
      metadata.remove('size');
    }
    return metadata;
  }

  Map<String, dynamic> mergeSelectionMetadata(
    Map<String, dynamic>? existing,
    ProvenanceLifeStageSelection selection, {
    String? physicalFormOverride,
    SizeSpec? sizeSpecOverride,
  }) {
    final metadata = existing == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existing);
    metadata.addAll(
      buildSelectionMetadata(
        selection,
        physicalFormOverride: physicalFormOverride,
        sizeSpecOverride: sizeSpecOverride,
      ),
    );
    if (sizeSpecOverride != null && sizeSpecOverride.isEmpty) {
      metadata.remove('size');
    }
    return metadata;
  }

  Map<String, dynamic>? extractManifestMetadata(TransferEvent transfer) {
    final manifestData = transfer.manifest;
    if (manifestData == null) {
      return null;
    }
    final metadata = manifestData['metadata'];
    if (metadata is Map<String, dynamic>) {
      return Map<String, dynamic>.from(metadata);
    }
    return null;
  }

  String? physicalFormFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    final raw = metadata['physicalFormId'];
    if (raw == null) return null;
    final normalized = raw.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, String> extractOwnershipMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return const {};
    final owner = metadata['ownerOrganizationId']?.toString().trim();
    final managing = metadata['managingOrganizationId']?.toString().trim();
    final result = <String, String>{};
    if (owner != null && owner.isNotEmpty) {
      result['ownerOrganizationId'] = owner;
    }
    if (managing != null && managing.isNotEmpty) {
      result['managingOrganizationId'] = managing;
    }
    return result;
  }

  /// Builds an OrganismRecord from the manifest payload for inventory tracking.
  ///
  /// This creates the inventory holding at the destination site/group when a
  /// transfer is accepted. The organism record will be linked to the newly
  /// created genet via [genetId].
  ///
  /// Unlike [createGenetFromManifest], this method creates the inventory record
  /// that appears in the receiving org's inventory views.
  OrganismRecord createOrganismRecordFromManifest({
    required TransferManifest manifest,
    required ProvenanceRecord createdGenet,
    required int quantity,
    required String recordName,
    String? localId,
    ProvenanceType? provenanceTypeOverride,
    LifeStage? lifeStageOverride,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) {
    final genet = manifest.genet;
    final rawSpeciesId = genet.speciesId ?? genet.speciesCode;

    if (rawSpeciesId == null || rawSpeciesId.isEmpty) {
      throw TransferWorkflowException('Manifest missing speciesId');
    }
    final resolvedSpecies = SpeciesRegistry.globalById(
      rawSpeciesId,
      allowFallback: false,
    );
    if (resolvedSpecies == null) {
      throw TransferWorkflowException(
        'Transfer manifest contains unknown species "$rawSpeciesId". '
        'Please ensure taxonomy data is loaded and retry the transfer.',
      );
    }
    final speciesId = resolvedSpecies.id;

    // Extract organismKind from manifest metadata, fallback to coral for legacy
    final organismKindRaw =
        manifest.metadata?['organismKind']?.toString() ??
        OrganismKind.coral.name;
    final organismKind = OrganismKind.values.firstWhere(
      (kind) => kind.name.toLowerCase() == organismKindRaw.toLowerCase(),
      orElse: () => OrganismKind.coral,
    );

    // Resolve provenance type and life stage from manifest
    final selectionSources = <Map<String, dynamic>>[];
    if (manifest.metadata != null && manifest.metadata!.isNotEmpty) {
      selectionSources.add(Map<String, dynamic>.from(manifest.metadata!));
    }
    final genetMetadata = genet.metadata;
    if (genetMetadata != null && genetMetadata.isNotEmpty) {
      selectionSources.add(Map<String, dynamic>.from(genetMetadata));
    }

    final legacyProvenanceTypeId = genet.provenanceTypeId;
    final fallbackType =
        provenanceTypeOverride ??
        ProvenanceTypeX.tryParse(
          manifest.metadata?['provenanceTypeId']?.toString(),
        ) ??
        ProvenanceTypeX.tryParse(
          genetMetadata?['provenanceTypeId']?.toString(),
        ) ??
        ProvenanceTypeX.tryParse(legacyProvenanceTypeId);

    var selection = selectionSources.isEmpty
        ? (fallbackType != null
              ? ProvenanceLifeStageSelection(
                  provenanceType: fallbackType,
                  lifeStage: fallbackType.defaultLifeStage,
                )
              : ProvenanceLifeStageSelection.fallback())
        : ProvenanceLifeStageSelection.fromCanonicalSources(
            sources: selectionSources,
          );

    var resolvedProvenanceType =
        provenanceTypeOverride ?? selection.provenanceType;
    var resolvedLifeStage = lifeStageOverride ?? selection.lifeStage;
    final allowedStages = resolvedProvenanceType.allowedLifeStages;
    if (allowedStages.isNotEmpty &&
        !allowedStages.contains(resolvedLifeStage)) {
      resolvedLifeStage =
          allowedStages.contains(resolvedProvenanceType.defaultLifeStage)
          ? resolvedProvenanceType.defaultLifeStage
          : allowedStages.first;
    }

    // Extract physical form from manifest if present
    final physicalFormId = physicalFormFromMetadata(manifest.metadata);
    // Also try to extract sizeBandId from manifest metadata
    final sizeBandId =
        manifest.metadata?['sizeBandId']?.toString() ??
        manifest.metadata?['size']?['sizeBandId']?.toString();

    // Extract size spec from manifest if present
    SizeSpec? sizeSpec;
    final sizeData = manifest.metadata?['size'];
    if (sizeData is Map<String, dynamic>) {
      sizeSpec = SizeSpec.fromJson(sizeData);
    }

    final organization = _provenanceRepository.organization;

    // Ownership defaults to receiving organization when not explicitly set.
    // Receiver's explicit input takes precedence, otherwise use receiving org.
    // Note: We intentionally do NOT fall back to sender's manifest ownership -
    // when accepting a transfer, ownership transfers to the receiving org.
    final ownership = <String, String>{
      'ownerOrganizationId': ownerOrganizationId?.trim().isNotEmpty == true
          ? ownerOrganizationId!.trim()
          : organization.id,
      'managingOrganizationId': managingOrganizationId?.trim().isNotEmpty == true
          ? managingOrganizationId!.trim()
          : organization.id,
    };

    // Build organism record metadata
    final metadata = <String, dynamic>{
      'transferEventId': manifest.transferId,
      'fromOrganizationId': manifest.fromOrganization.id,
      'manifestVersion': manifest.version,
      'receivedAt': manifest.receivedAt?.toIso8601String(),
    };

    // Add custody history entry for this transfer
    final ownershipTypeRaw = manifest.metadata?['ownershipType']?.toString();
    final ownershipType = TransferOwnershipTypeX.tryParse(ownershipTypeRaw) ??
        TransferOwnershipType.fullTransfer;

    // Resolve owner name based on ownership type
    String? resolveOwnerName() {
      final ownerId = ownership['ownerOrganizationId'];
      if (ownerId == organization.id) {
        return organization.name;
      }
      if (ownerId == manifest.fromOrganization.id) {
        return manifest.fromOrganization.name;
      }
      // For third-party, check if name was included in metadata
      final thirdPartyName =
          manifest.metadata?['originalOwnerOrganizationName']?.toString();
      if (thirdPartyName != null && thirdPartyName.isNotEmpty) {
        return thirdPartyName;
      }
      // Fallback to sender name (may be inaccurate for third-party)
      return manifest.fromOrganization.name;
    }

    final custodyEntry = CustodyHistoryService.instance.createTransferEntry(
      transferId: manifest.transferId,
      ownershipType: ownershipType,
      ownerOrganizationId: ownership['ownerOrganizationId']!,
      ownerOrganizationName: resolveOwnerName(),
      managingOrganizationId: ownership['managingOrganizationId']!,
      managingOrganizationName: organization.name,
      acceptedAt: manifest.receivedAt,
    );

    // Merge any existing custody history from manifest with the new entry
    final existingCustodyHistory = manifest.metadata?['custodyHistory'];
    final custodyHistory = CustodyHistoryService.instance.parseCustodyHistory(
      existingCustodyHistory,
    );
    final fullCustodyHistory = [...custodyHistory, custodyEntry];
    metadata['custodyHistory'] = CustodyHistoryService.instance
        .serializeCustodyHistory(fullCustodyHistory);

    final user = _provenanceRepository.user;

    return OrganismRecord.create(
      organismKind: organismKind,
      organizationId: organization.id,
      createdById: user.id,
      lifeStage: LifeStageSpec(stage: resolvedLifeStage),
      measurement: PopulationMeasurement(
        value: quantity.toDouble(),
        unit: MeasurementUnit.count,
      ),
      recordName: recordName,
      speciesId: speciesId,
      localId: localId ?? createdGenet.localId,
      provenanceType: resolvedProvenanceType,
      physicalForm: physicalFormId != null && sizeBandId != null
          ? PhysicalFormInstance(formId: physicalFormId, sizeBandId: sizeBandId)
          : null,
      sizeSpec: sizeSpec,
      genetId: createdGenet.id,
      ownerOrganizationId: ownership['ownerOrganizationId'],
      managingOrganizationId: ownership['managingOrganizationId'],
      metadata: metadata,
    );
  }
}
