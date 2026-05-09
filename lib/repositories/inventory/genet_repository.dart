// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/inventory_record_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/alias_uniqueness_service.dart';
import 'package:seafoundry_app/services/provenance_id_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/services/validation_service.dart';
class GenetRepository extends InventoryRecordRepository<Genet> {

  late final AliasUniquenessService _aliasService;
  late final ProvenanceIdService _provenanceIdService;
  late final _nameValidationService = UniqueNameValidationService(firestore: db);
  final RecordRepository _recordRepository;

  GenetRepository({
    required super.organization,
    required super.user,
    required super.eventRepository,
    super.snapshotService,
    OrganizationRepository? organizationRepository,
    required RecordRepository recordRepository,
    required super.firestore,
    OrganismContext? organismContext,
    AliasUniquenessService? aliasService,
    ProvenanceIdService? provenanceIdService,
    super.enforceAuth = true,
  }) : _recordRepository = recordRepository,
       super(
         modelType: ModelType.genet,
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       ) {
    _aliasService = aliasService ?? AliasUniquenessService(firestore: db);
    _provenanceIdService = provenanceIdService ?? ProvenanceIdService(firestore: db);

    // Override collectionRef to use organization subcollection
    // Genets are stored at organizations/{orgId}/genets, not root genets collection
    collectionRef = db
        .collection(ModelType.organization.collectionPath)
        .doc(organization.id)
        .collection(ModelType.genet.collectionPath);
    // Debug: Log the overridden collection path for demo mode troubleshooting
    LoggingService.instance.debug('GenetRepository: collectionRef.path=${collectionRef.path}');
    LoggingService.instance.debug('   - organization.id="${organization.id}"');
    LoggingService.instance.debug('   - organization.domain="${organization.domain}"');
  }

  CollectionReference<Map<String, dynamic>> get _archivedCollection =>
      db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection('archived_genets');

  /// Exposes the provenance ID service for external preview operations.
  ProvenanceIdService get provenanceIdService => _provenanceIdService;

  @override
  bool shouldIncludeRecord(Genet record) {
    return !record.archived;
  }

  /// Override to return all documents without organizationId filter.
  /// The subcollection is already scoped to the organization.
  @override
  Query<Object?> collectionQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    return collectionRef.orderBy('createdAt', descending: true);
  }

  /// Returns the first genet matching the provided name.
  /// Optionally include archived records.
  Future<Genet?> getRecordByName(
    String name, {
    bool includeArchived = false,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final snapshot = await collectionRef
        .where('nameLowercase', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    final record = RecordFactory.recordFromJson<Genet>(data);
    if (!includeArchived && record.archived) {
      return null;
    }
    return record;
  }

  /// Returns the first genet matching the provided provenance ID.
  /// Optionally include archived records.
  Future<Genet?> getRecordByProvenanceId(
    String provenanceId, {
    bool includeArchived = false,
  }) async {
    final trimmed = provenanceId.trim();
    if (trimmed.isEmpty) return null;
    final snapshot = await collectionRef
        .where('provenanceId', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    final record = RecordFactory.recordFromJson<Genet>(data);
    if (!includeArchived && record.archived) {
      return null;
    }
    return record;
  }

  Future<Genet> createGenet(
    Genet genet, {
    String? inheritedProvenanceId,
  }) async {
    String currentStep = 'initializing';
    try {
      currentStep = 'resolving provenance ID';
      final batch = db.batch();

      // Inherited PIDs (from crosswalk match) bypass generation and uniqueness
      // checks — they are intentionally shared cross-org.
      final effectiveInheritedPid = inheritedProvenanceId?.trim();
      final hasInheritedPid =
          effectiveInheritedPid != null && effectiveInheritedPid.isNotEmpty;
      
      String? provenanceId;
      
      if (hasInheritedPid) {
        provenanceId = effectiveInheritedPid;
        // Inherited PIDs bypass generation and uniqueness checks
      } else {
        final hasManualPid =
            genet.provenanceId.trim().isNotEmpty &&
            genet.provenanceId != Missing.string;

        if (hasManualPid) {
          provenanceId = genet.provenanceId.trim();
          final formatError = ValidationService.provenanceId(provenanceId);
          if (formatError != null) {
            throw domainErrors.RepositoryError(
              message: 'Provenance ID "$provenanceId" has invalid format. '
                  'Expected format: PID-XXXX-XXXX (e.g., PID-ACER-0001).',
              context: {'provenanceId': provenanceId},
            );
          }
          currentStep = 'validating provenance ID uniqueness (manual)';
          await _assertProvenanceIdUnique(provenanceId: provenanceId);
        } else {
          // Auto-generate with retries for collision handling (counter drift)
          int attempts = 0;
          const maxAttempts = 5;
          
          while (attempts < maxAttempts) {
            attempts++;
            try {
              provenanceId = await _provenanceIdService.nextProvenanceId(
                speciesId: genet.speciesId,
              );
              
              currentStep = 'validating provenance ID uniqueness (attempt $attempts)';
              await _assertProvenanceIdUnique(provenanceId: provenanceId);
              
              // If we get here, validation passed
              break;
            } catch (e) {
              // Use typed exception for reliable collision detection
              if (e is domainErrors.UniqueConstraintViolationError &&
                  e.fieldName == 'provenanceId' &&
                  attempts < maxAttempts) {
                LoggingService.instance.warning(
                  'Provenance ID collision for $provenanceId. Retrying ($attempts/$maxAttempts)...',
                );
                continue; // Retry generation
              }
              rethrow; // Ensure other errors propagate
            }
          }
          
          // Safety fallback if loop exhausted without success (unlikely)
          if (provenanceId == null) {
            throw domainErrors.RepositoryError(
              message: 'Failed to generate unique Provenance ID after $maxAttempts attempts.',
            );
          }
        }
      }

      final genetRecordId = generateId(firestore: db);
      final genetSlug = genet.slug.trim().isEmpty || genet.slug == Missing.string
          ? await nextSlugForModelType(ModelType.genet)
          : genet.slug.trim();
      final trimmedName = genet.name.trim();

      currentStep = 'validating name uniqueness';
      final isUnique = await _nameValidationService.isGenetNameUnique(
        name: trimmedName,
        organizationDomain: organization.domain,
        organizationId: organization.id,
      );
      if (!isUnique) {
        throw domainErrors.RepositoryError(
          message:
              'Local ID "$trimmedName" already exists in ${organization.name}. Please choose a different ID.',
        );
      }

      currentStep = 'validating alias uniqueness';
      genet = genet.copyWith(name: trimmedName);
      final aliasEntries = _aliasesForGenet(genet);
      await _assertAliasesUnique(aliases: aliasEntries);

      final now = DateTime.now().toIso8601String();
      genet = genet.copyWith(
        id: genetRecordId,
        provenanceId: provenanceId,
        slug: genetSlug,
        urlPath: '${organization.domain}/$genetSlug',
        internalPath: '${organization.internalPath}/$genetRecordId',
        organizationId: organization.id,
        createdById: user.id,
        updatedById: user.id,
        createdAt: now,
        updatedAt: now,
      );

      currentStep = 'creating before snapshot';
      await snapshotService.createBeforeSnapshot(record: genet, eventId: genetRecordId);

      currentStep = 'adding create event';
      await eventRepository.addCreateEvent(genet, organization, batch);

      // Validate before saving
      if (!genet.validate()) {
        throw domainErrors.RepositoryError(
          message: 'Genet is not valid: ${genet.toJson()}',
        );
      }

      currentStep = 'committing genet to Firestore';
      final genetRef = collectionRef.doc(genetRecordId);
      batch.set(genetRef, genet.toJson());
      final normalizedSpeciesId = SpeciesRegistry.normalizeId(genet.speciesId);
      if (normalizedSpeciesId != null && normalizedSpeciesId.isNotEmpty) {
        final normalizedOrgSpecies =
            SpeciesRegistry.normalizeIds(organization.speciesIds);
        if (!normalizedOrgSpecies.contains(normalizedSpeciesId)) {
          currentStep = 'updating organization species list';
          final updatedOrganization = organization.copyWith(
            speciesIds: [...organization.speciesIds, normalizedSpeciesId],
          );
          _recordRepository.updateRecord(updatedOrganization, batch: batch);
        }
      }

      currentStep = 'committing batch to Firestore';
      LoggingService.instance.info('createGenet: About to commit batch', {
        'genetRecordId': genetRecordId,
        'genetName': trimmedName,
        'organizationId': organization.id,
        'createdById': user.id,
        'aliasCount': aliasEntries.length,
      });
      await batch.commit();

      currentStep = 'creating after snapshot';
      await snapshotService.createAfterSnapshot(record: genet, eventId: genetRecordId);

      currentStep = 'upserting alias index';
      await _upsertAliasIndex(
        aliases: aliasEntries,
        record: genet,
        organizationId: organization.id,
      );

      // Invalidate the local ID suggestion cache for this species since we just
      // created a new genet. This ensures subsequent suggestions don't collide.
      _nameValidationService.invalidateOrganismSuggestionCache(
        speciesId: genet.speciesId,
        organizationId: organization.id,
      );

      return genet;
    } catch (e, stack) {
      LoggingService.instance.error(
        'createGenet failed at step: $currentStep',
        e,
        stack,
      );

      // Re-throw with step context
      if (e is domainErrors.RepositoryError) {
        rethrow;
      }

      throw domainErrors.RepositoryError(
        message: 'Failed to create genet at step: $currentStep',
        technicalDetails: e.toString(),
        originalError: e,
        stackTrace: stack,
        recoverySuggestion: 'Check if all required fields are filled correctly. '
            'If the problem persists, try signing out and back in.',
      );
    }
  }

  Future<Genet> updateGenet({
    required Genet original,
    required Genet updated,
    Map<String, dynamic> changes = const {},
  }) async {
    final now = DateTime.now().toIso8601String();
    final eventId = generateId(firestore: db);
    final eventSlug = await eventRepository.nextSlugForModelType(
      ModelType.event,
    );

    final updatedRecord = updated.copyWith(
      updatedAt: now,
      updatedById: user.id,
    );

    final trimmedName = updatedRecord.name.trim();
    if (trimmedName != original.name.trim()) {
      final isUnique = await _nameValidationService.isGenetNameUnique(
        name: trimmedName,
        organizationDomain: organization.domain,
        organizationId: organization.id,
        excludeRecordId: original.id,
      );
      if (!isUnique) {
        throw domainErrors.RepositoryError(
          message:
              'Local ID "$trimmedName" already exists in ${organization.name}. Please choose a different ID.',
        );
      }
    }

    final trimmedProvenanceId = updatedRecord.provenanceId.trim();
    if (trimmedProvenanceId.isNotEmpty && trimmedProvenanceId != Missing.string) {
      final formatError = ValidationService.provenanceId(trimmedProvenanceId);
      if (formatError != null) {
        throw domainErrors.RepositoryError(
          message: 'Provenance ID "$trimmedProvenanceId" has invalid format. '
              'Expected format: PID-XXXX-XXXX (e.g., PID-ACER-0001).',
          context: {'provenanceId': trimmedProvenanceId},
        );
      }
    }
    if (trimmedProvenanceId != original.provenanceId.trim()) {
      await _assertProvenanceIdUnique(
        provenanceId: trimmedProvenanceId,
        excludeRecordId: original.id,
      );
    }

    final originalAliases = _aliasesForGenet(original);
    final trimmedAliases = _aliasesForGenet(updatedRecord);
    final addedAliases = _aliasesDifference(trimmedAliases, originalAliases);
    await _assertAliasesUnique(
      aliases: addedAliases,
      excludeRecordId: original.id,
    );

    final modificationEvent = GenetModificationEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      recordId: updatedRecord.id,
      recordModelType: ModelType.genet,
      urlPath: '${updatedRecord.urlPath}/$eventSlug',
      internalPath: '${updatedRecord.internalPath}/$eventId',
      slug: eventSlug,
      changes: changes,
    );

    await snapshotService.createBeforeSnapshot(
      record: original,
      eventId: eventId,
    );

    final batch = db.batch();
    await updateRecord(updatedRecord, batch: batch);
    await eventRepository.createEvent(modificationEvent, batch: batch);
    await batch.commit();

    await snapshotService.createAfterSnapshot(
      record: updatedRecord,
      eventId: eventId,
    );
    final removedAliases = _aliasesDifference(originalAliases, trimmedAliases);
    await _removeAliasIndexEntries(
      aliases: removedAliases,
      recordId: updatedRecord.id,
    );
    await _upsertAliasIndex(
      aliases: trimmedAliases,
      record: updatedRecord,
      organizationId: organization.id,
    );

    return updatedRecord;
  }

  Future<void> _assertAliasesUnique({
    required List<OrganismAlias> aliases,
    String? excludeRecordId,
  }) async {
    if (aliases.isEmpty) return;
    try {
      await _aliasService.assertAliasesUnique(
        aliases: aliases,
        modelType: ModelType.genet,
        excludeRecordId: excludeRecordId,
      );
    } on AliasConflictException catch (error) {
      throw domainErrors.RepositoryError(message: error.toString());
    }
  }

  Future<void> _upsertAliasIndex({
    required List<OrganismAlias> aliases,
    required Genet record,
    required String organizationId,
  }) async {
    if (aliases.isEmpty) return;
    try {
      await _aliasService.upsertAliases(
        aliases: aliases,
        modelType: ModelType.genet,
        recordId: record.id,
        provenanceId: record.provenanceId,
        organizationId: organizationId,
        localGenetId: record.name,
      );
    } on AliasConflictException catch (error) {
      throw domainErrors.RepositoryError(message: error.toString());
    }
  }

  Future<void> _removeAliasIndexEntries({
    required List<OrganismAlias> aliases,
    required String recordId,
  }) async {
    if (aliases.isEmpty) return;
    await _aliasService.removeAliases(
      aliases: aliases,
      recordId: recordId,
      organizationId: organization.id,
    );
  }

  Future<void> _assertProvenanceIdUnique({
    required String provenanceId,
    String? excludeRecordId,
  }) async {
    final trimmed = provenanceId.trim();
    if (trimmed.isEmpty || trimmed == Missing.string) return;
    // Use collectionRef (scoped to current org) instead of collectionGroup
    // because Provenance IDs CAN be reused across different organizations
    // (representing the same genotype). Uniqueness is only enforced within the org.
    try {
      final snapshot = await collectionRef
          .where('provenanceId', isEqualTo: trimmed)
          .limit(2)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final recordId = data['id'] as String? ?? doc.id;
        if (excludeRecordId != null && recordId == excludeRecordId) {
          continue;
        }
        throw domainErrors.UniqueConstraintViolationError(
          message:
              'Provenance ID "$trimmed" already exists. Please choose a different Provenance ID.',
          fieldName: 'provenanceId',
          value: trimmed,
          existingRecordId: recordId,
          recoverySuggestion: 'Please choose a different Provenance ID.',
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
        throw domainErrors.RepositoryError(
          message: 'Unable to verify provenance ID uniqueness due to authentication error. Please sign in and try again.',
          originalError: error,
          stackTrace: stackTrace,
          category: domainErrors.AppErrorCategory.authentication,
          recoverySuggestion: 'Please sign out and sign back in, then try again.',
        );
      }
      rethrow;
    }
  }

  /// Intentionally links [aliases] to an existing record (identified by
  /// [existingRecordId]) so two organizations can reference the same Provenance ID.
  /// The caller must pass aliases that already belong to the existing record;
  /// this method simply adds the current organization as another reference and
  /// persists the aliases on [target].
  Future<Genet> shareAliasesWithExistingRecord({
    required Genet target,
    required String existingRecordId,
    required List<OrganismAlias> aliases,
  }) async {
    final deduped = _aliasService.deduplicateLocalAliases(aliases);
    if (deduped.isEmpty) {
      return target;
    }
    for (final alias in deduped) {
      await _aliasService.linkAliasToExistingRecord(
        alias: alias,
        existingRecordId: existingRecordId,
        modelType: ModelType.genet,
        provenanceId: target.provenanceId,
        organizationId: organization.id,
        localGenetId: target.name,
      );
    }

    final existingAliases = List<Map<String, dynamic>>.from(
      target.aliases ?? const <Map<String, dynamic>>[],
    );
    existingAliases.addAll(deduped.map((alias) => alias.toJson()));
    final updatedRecord = target.copyWith(aliases: existingAliases);
    await updateRecord(updatedRecord);
    return updatedRecord;
  }

  List<OrganismAlias> _aliasesForGenet(Genet genet) =>
      OrganismAlias.listFromJson(genet.aliases ?? const []);

  List<OrganismAlias> _aliasesDifference(
    List<OrganismAlias> lhs,
    List<OrganismAlias> rhs,
  ) {
    if (lhs.isEmpty) return const <OrganismAlias>[];
    if (rhs.isEmpty) return List<OrganismAlias>.from(lhs);
    final rhsKeys = rhs.map(_aliasKeyOf).toSet();
    return lhs.where((alias) => !rhsKeys.contains(_aliasKeyOf(alias))).toList();
  }

  String _aliasKeyOf(OrganismAlias alias) {
    return '${alias.sourceSystem.trim().toLowerCase()}::'
        '${alias.value.trim().toLowerCase()}';
  }



  Future<void> archiveGenet(
    String genetRecordId, {
    PopulationLossReason? lossReason,
    String? comment,
  }) async {
    final docRef = collectionRef.doc(genetRecordId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw domainErrors.RepositoryError(
        message: 'Genet $genetRecordId not found for archival.',
      );
    }

    final data = snapshot.data();
    if (data == null) {
      throw domainErrors.RepositoryError(
        message: 'Genet $genetRecordId exists but has null data.',
      );
    }

    final genet = Genet.fromJson(
      {
        ...data,
        'id': genetRecordId,
      },
    );

    final now = DateTime.now().toIso8601String();
    final eventId = generateId(firestore: db);
    final eventSlug = await eventRepository.nextSlugForModelType(
      ModelType.event,
    );
    final normalizedComment = comment?.trim();
    final metadata = <String, dynamic>{
      if (lossReason != null) 'lossReasonId': lossReason.id,
      if (normalizedComment != null && normalizedComment.isNotEmpty)
        'comment': normalizedComment,
    };
    final changes = <String, dynamic>{
      'archived': {'from': genet.archived, 'to': true},
      'archivedAt': {'from': genet.archivedAt?.toIso8601String(), 'to': now},
    };

    // Genet.metadata getter is guaranteed non-null (see Genet class override).
    final archiveMetadata = <String, dynamic>{
      ...genet.metadata,
      kArchivedFlagKey: true,
      kArchivedAtKey: now,
      kArchivedByIdKey: user.id,
      kArchivedReasonTypeKey: _archiveReasonType(lossReason),
      if (lossReason != null) kArchivedReasonIdKey: lossReason.id,
    };

    final archivedRecord = genet.copyWith(
      archived: true,
      archivedAt: DateTime.now(),
      metadata: archiveMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    await snapshotService.createBeforeSnapshot(
      record: genet,
      eventId: eventId,
    );

    final batch = db.batch();
    await updateRecord(archivedRecord, batch: batch);

    final modificationEvent = GenetModificationEvent(
      id: eventId,
      createdById: user.id,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      recordId: genet.id,
      recordModelType: ModelType.genet,
      urlPath: '${genet.urlPath}/$eventSlug',
      internalPath: '${genet.internalPath}/$eventId',
      slug: eventSlug,
      changes: changes,
      metadata: metadata.isEmpty ? null : metadata,
    );

    await eventRepository.createEvent(modificationEvent, batch: batch);
    await batch.commit();

    await snapshotService.createAfterSnapshot(
      record: archivedRecord,
      eventId: eventId,
    );
  }

  Future<void> restoreGenet(String genetRecordId) async {
    final archivedSnapshot = await _archivedCollection.doc(genetRecordId).get();
    Genet? genet;
    if (archivedSnapshot.exists) {
      final data = archivedSnapshot.data();
      if (data != null) {
        data['id'] = archivedSnapshot.id;
        genet = RecordFactory.recordFromJson<Genet>(data);
      }
    } else {
      genet = await getRecordForId(genetRecordId);
    }

    if (genet == null) {
      throw domainErrors.RepositoryError(
        message: 'Genet $genetRecordId not found for restore.',
      );
    }

    final now = DateTime.now().toIso8601String();
    // Genet.metadata getter is guaranteed non-null (see Genet class override).
    final cleanedMetadata = <String, dynamic>{
      ...genet.metadata,
    }
      ..remove(kArchivedFlagKey)
      ..remove(kArchivedAtKey)
      ..remove(kArchivedByIdKey)
      ..remove(kArchivedReasonTypeKey)
      ..remove(kArchivedReasonIdKey);

    final restored = genet.copyWith(
      archived: false,
      archivedAt: null,
      metadata: cleanedMetadata,
      updatedAt: now,
      updatedById: user.id,
    );

    final batch = db.batch();
    final restoredData = restored.toJson();
    restoredData['archived'] = false;
    restoredData.remove('archivedAt');
    batch.set(collectionRef.doc(genet.id), restoredData);
    batch.delete(_archivedCollection.doc(genet.id));
    await batch.commit();
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

  Future<String> suggestNextLocalId(String speciesId) async {
    return _nameValidationService.suggestNextOrganismLocalId(
      speciesId: speciesId,
      organizationId: organization.id,
    );
  }

  Future<bool> isGenetNameUnique({
    required String name,
    String? excludeRecordId,
  }) async {
    return _nameValidationService.isGenetNameUnique(
      name: name,
      organizationDomain: organization.domain,
      organizationId: organization.id,
      excludeRecordId: excludeRecordId,
    );
  }

  Future<String> suggestNextGenerationLocalId(String baseLocalId) async {
    return _nameValidationService.suggestNextGenerationLocalId(
      baseLocalId: baseLocalId,
      organizationId: organization.id,
    );
  }

  Future<int> countOrganismRecordsForGenet(String genetRecordId) async {
    if (genetRecordId.trim().isEmpty) return 0;

    try {
      final organismRecordCollection = db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection(ModelType.organismRecord.collectionPath);

      final snapshot = await organismRecordCollection
          .where('genetRecordId', isEqualTo: genetRecordId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      LoggingService.instance.error(
        'Error counting organism records for genet: $genetRecordId',
        e,
      );
      return 0;
    }
  }
}
