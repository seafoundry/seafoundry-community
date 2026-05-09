// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/brand_profile_repository.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

class OnboardingRepository {
  OnboardingRepository(
    this._recordRepository, {
    BrandProfileRepository? brandProfileRepository,
  }) : db = _recordRepository.db,
       _brandProfileRepository =
           brandProfileRepository ?? BrandProfileRepository();
  final RecordRepository _recordRepository;
  final FirebaseFirestore db;
  final BrandProfileRepository _brandProfileRepository;
  late final _nameValidationService = UniqueNameValidationService(
    firestore: db,
  );

  Stream<List<Organization>> get allOrganizations => _recordRepository
      .streamRecordsForModelType<Organization>(ModelType.organization);

  /// Get an organization by ID
  Future<Organization?> getOrganization(String organizationId) async {
    final doc = await db
        .collection(ModelType.organization.collectionPath)
        .doc(organizationId)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Organization.fromJson(data);
  }

  Future<User> createUser(User user) async {
    final newUser = user.copyWith(name: user.name.trim());
    await _recordRepository.createRecord(newUser);
    return newUser;
  }

  Future<User> updateUser(User user) async {
    final updatedUser = user.copyWith(name: user.name.trim());
    await _recordRepository.updateRecord(updatedUser);
    return updatedUser;
  }

  Future<(Organization, User)> createOrganization(
    String name,
    User owner,
    List<String> activityIds,
    List<String> speciesIds,
    String domain, {
    String? heroImageUrl,
    String? logoUrl,
    String? accentColor,
    List<OrganismKind>? supportedOrganismKinds,
  }) async {
    final String organizationId = generateId(firestore: db);
    final String eventId = generateId(firestore: db);
    // Keep the organization rooted at the domain; hang events beneath it.
    final String organizationUrlPath = domain;
    final String organizationSlug = domain;
    final String eventSlug = 'event-${DateTime.now().millisecondsSinceEpoch}';

    final Organization organization = Organization(
      id: organizationId,
      createdById: owner.id,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: owner.id,
      organizationId: organizationId,
      urlPath: organizationUrlPath,
      internalPath: '$organizationId/$eventId',
      slug: organizationSlug,
      name: name,
      domain: domain,
      siteTypeIds: activityIds,
      activities: activityIds,
      speciesIds: speciesIds,
    );

    final eventData = CreateEvent(
      id: eventId,
      createdById: owner.id,
      recordId: organizationId,
      recordModelType: ModelType.organization,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: owner.id,
      organizationId: organizationId,
      snapshot: organization,
      slug: eventSlug,
      urlPath: '$organizationUrlPath/$eventSlug',
      internalPath: '$organizationId/$eventId',
    );

    owner = owner.copyWith(
      organizationId: organizationId,
      onboardingCompletedAt: DateTime.now(),
      role: 'admin',
    );

    LoggingService.instance.debug(
      '🔵 OnboardingRepository.createOrganization: Starting batch write',
    );
    LoggingService.instance.debug('   - Organization ID: $organizationId');
    LoggingService.instance.debug('   - Organization name: $name');
    LoggingService.instance.debug('   - Organization domain: $domain');
    LoggingService.instance.debug('   - Owner ID: ${owner.id}');
    LoggingService.instance.debug('   - Owner email: ${owner.email}');

    // Log the exact JSON for debugging security rules
    final orgJson = organization.toJson();
    final eventJson = eventData.toJson();
    final userJson = owner.toJson();

    LoggingService.instance.debug('📦 Organization JSON (key fields):');
    LoggingService.instance.debug('   - id: ${organization.id}');
    LoggingService.instance.debug(
      '   - organizationId: ${orgJson['organizationId']}',
    );
    LoggingService.instance.debug(
      '   - createdById: ${orgJson['createdById']}',
    );

    LoggingService.instance.debug('📦 Event JSON (key fields):');
    LoggingService.instance.debug('   - id: ${eventData.id}');
    LoggingService.instance.debug(
      '   - organizationId: ${eventJson['organizationId']}',
    );
    LoggingService.instance.debug(
      '   - createdById: ${eventJson['createdById']}',
    );
    LoggingService.instance.debug(
      '   - recordModelType: ${eventJson['recordModelType']}',
    );

    LoggingService.instance.debug('📦 User JSON (key fields):');
    LoggingService.instance.debug('   - id (doc path): ${owner.id}');
    LoggingService.instance.debug('   - email: ${userJson['email']}');
    LoggingService.instance.debug(
      '   - organizationId: ${userJson['organizationId']}',
    );

    final WriteBatch batch = _recordRepository.db.batch();
    _recordRepository.createRecord(organization, batch: batch);
    _recordRepository.createRecord(eventData, batch: batch);
    _recordRepository.createRecord(owner, batch: batch);

    // Create membership document for UID-keyed access control.
    final normalizedEmail = UserIdentity.normalizeEmail(owner.email);
    final membershipRef = db
        .collection('organizations')
        .doc(organizationId)
        .collection('members')
        .doc(owner.id);
    LoggingService.instance.debug(
      'OnboardingRepository: Creating membership at ${membershipRef.path}',
    );
    batch.set(membershipRef, {
      'uid': owner.id,
      if (normalizedEmail != null && normalizedEmail.isNotEmpty)
        'email': normalizedEmail,
      'role': 'admin',
      'joinedAt': DateTime.now().toIso8601String(),
      'createdById': owner.id,
      'organizationId': organizationId,
    });

    // Initialize slugCounts atomically within the same batch so the org
    // is never left in a half-initialized state. (~10 ops total, well
    // within Firestore's 500-operation batch limit.)
    final slugCountsRef = db
        .collection(ModelType.organization.collectionPath)
        .doc(organizationId)
        .collection('slugCounts');
    for (final modelTypeName in [
      ModelType.site.name,
      ModelType.group.name,
      ModelType.organismRecord.name,
      ModelType.genet.name,
      ModelType.event.name,
      ModelType.cohort.name,
    ]) {
      batch.set(slugCountsRef.doc(modelTypeName), {'count': 0});
    }

    LoggingService.instance.debug(
      'OnboardingRepository.createOrganization: Committing batch...',
    );
    try {
      await batch.commit();
      LoggingService.instance.debug(
        'OnboardingRepository.createOrganization: Batch committed successfully!',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        '🔴 BATCH COMMIT FAILED in createOrganization',
        e,
        stackTrace,
      );
      // Re-throw with more context
      rethrow;
    }

    LoggingService.instance.debug(
      '✅ OnboardingRepository.createOrganization: SlugCounts initialized!',
    );

    // Create brand profile if any branding info was provided
    if (heroImageUrl != null || logoUrl != null || accentColor != null) {
      await _brandProfileRepository.upsertBrandProfile(
        organizationId: organizationId,
        brandName: name,
        heroImageUrl: heroImageUrl,
        logoUrl: logoUrl,
        accentColor: accentColor,
      );
    }

    return (organization, owner);
  }

  /// Persist a user's intro note/media under `/users/{userId}/intro/profile`.
  Future<void> saveUserIntro(String userId, UserIntro intro) async {
    final firestore = _recordRepository.db;
    final resolvedId = UserIdentity.normalizeUserDocId(userId);
    await firestore
        .collection('users')
        .doc(resolvedId)
        .collection('intro')
        .doc('profile')
        .set(intro.toMap(), SetOptions(merge: true));
  }

  Future<Site> createSite(
    String name,
    String organizationId,
    User user, {
    String? siteTypeId,
  }) async {
    LoggingService.instance.debug(
      'OnboardingRepository.createSite: Starting...',
    );
    LoggingService.instance.debug('   - name: $name');
    LoggingService.instance.debug('   - organizationId: $organizationId');
    LoggingService.instance.debug('   - user.id: ${user.id}');
    LoggingService.instance.debug(
      '   - user.organizationId: ${user.organizationId}',
    );

    try {
      final String siteId = generateId(firestore: db);
      final String eventId = generateId(firestore: db);
      LoggingService.instance.debug('   - Generated siteId: $siteId');
      LoggingService.instance.debug('   - Generated eventId: $eventId');

      // Fetch organization to get domain for urlPath
      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Fetching organization...',
      );
      final organization = await _recordRepository.getRecord<Organization>(
        ModelType.organization,
        organizationId,
      );
      if (organization == null) {
        LoggingService.instance.error(
          'OnboardingRepository.createSite: Organization not found!',
        );
        throw Exception('Organization not found: $organizationId');
      }
      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Organization fetched',
      );
      LoggingService.instance.debug(
        '   - organization.domain: ${organization.domain}',
      );

      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Generating unique slug...',
      );
      final String slug = await _generateUniqueSlug(
        organizationId: organizationId,
        parentUrlPath: organization.domain,
        base: ModelType.site.name,
        modelType: ModelType.site,
      );
      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Slug generated: $slug',
      );

      final String urlPath = '${organization.domain}/$slug';

      final Site site = Site(
        id: siteId,
        createdById: user.id,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: user.id,
        organizationId: organizationId,
        name: name,
        siteTypeId: siteTypeId ?? SiteType.nursery.id,
        groupIdHierarchy: SiteType.fromId(
          siteTypeId,
        ).groupTypes.map((t) => t.id).toList(),
        slug: slug,
        urlPath: urlPath,
        internalPath: '$organizationId/$siteId',
      );

      final eventData = CreateEvent(
        id: eventId,
        createdById: user.id,
        recordId: siteId,
        recordModelType: ModelType.site,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: user.id,
        organizationId: organizationId,
        snapshot: site,
        slug: slug,
        urlPath: urlPath,
        internalPath: '$organizationId/$siteId',
      );

      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Creating batch...',
      );
      LoggingService.instance.debug('   - site.id: ${site.id}');
      LoggingService.instance.debug(
        '   - site.organizationId: ${site.organizationId}',
      );
      LoggingService.instance.debug(
        '   - site.createdById: ${site.createdById}',
      );

      final WriteBatch batch = _recordRepository.db.batch();
      _recordRepository.createRecord(site, batch: batch);
      _recordRepository.createRecord(eventData, batch: batch);

      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Committing batch...',
      );
      await batch.commit();
      LoggingService.instance.debug(
        'OnboardingRepository.createSite: Batch committed successfully!',
      );

      // Synchronize slug counter with normal app flow
      await _updateSlugCount(
        organizationId: organizationId,
        modelType: ModelType.site,
        slug: slug,
      );

      return site;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OnboardingRepository.createSite: FAILED!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Group> createStructure(
    String name,
    String siteId,
    String organizationId,
    User user, {
    String structureTypeId = 'group_type_tank',
  }) async {
    LoggingService.instance.debug(
      'OnboardingRepository.createStructure: Starting...',
    );
    LoggingService.instance.debug('   - name: $name');
    LoggingService.instance.debug('   - siteId: $siteId');
    LoggingService.instance.debug('   - organizationId: $organizationId');
    LoggingService.instance.debug('   - user.id: ${user.id}');

    try {
      final String groupId = generateId(firestore: db);
      final String eventId = generateId(firestore: db);
      LoggingService.instance.debug('   - Generated groupId: $groupId');
      LoggingService.instance.debug('   - Generated eventId: $eventId');

      // Fetch site to get urlPath for hierarchy and slug scoping
      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Fetching site...',
      );
      final site = await _recordRepository.getRecord<Site>(
        ModelType.site,
        siteId,
      );
      if (site == null) {
        LoggingService.instance.error(
          'OnboardingRepository.createStructure: Site not found!',
        );
        throw Exception('Site not found: $siteId');
      }
      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Site fetched',
      );
      LoggingService.instance.debug('   - site.urlPath: ${site.urlPath}');

      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Generating unique slug...',
      );
      final String slug = await _generateUniqueSlug(
        organizationId: organizationId,
        parentUrlPath: site.urlPath,
        base: ModelType.group.name,
        modelType: ModelType.group,
      );
      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Slug generated: $slug',
      );

      final String urlPath = '${site.urlPath}/$slug';

      final Group group = Group(
        id: groupId,
        createdById: user.id,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: user.id,
        organizationId: organizationId,
        siteId: siteId,
        parentId: siteId,
        name: name,
        capacity: 100,
        groupTypeId: structureTypeId,
        slug: slug,
        urlPath: urlPath,
        internalPath: '$organizationId/$siteId/$groupId',
      );

      final eventData = CreateEvent(
        id: eventId,
        createdById: user.id,
        recordId: groupId,
        recordModelType: ModelType.group,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: user.id,
        organizationId: organizationId,
        snapshot: group,
        slug: slug,
        urlPath: urlPath,
        internalPath: '$organizationId/$siteId/$groupId',
      );

      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Creating batch...',
      );
      LoggingService.instance.debug(
        '   - groupRef path: organizations/$organizationId/groups/$groupId',
      );

      final WriteBatch batch = _recordRepository.db.batch();

      // Use nested collection for Group to match GroupRepository
      final groupRef = db
          .collection(ModelType.organization.collectionPath)
          .doc(organizationId)
          .collection(ModelType.group.collectionPath)
          .doc(groupId);

      batch.set(groupRef, group.toJson());
      _recordRepository.createRecord(eventData, batch: batch);

      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Committing batch...',
      );
      await batch.commit();
      LoggingService.instance.debug(
        'OnboardingRepository.createStructure: Batch committed successfully!',
      );

      // Synchronize slug counter with normal app flow
      await _updateSlugCount(
        organizationId: organizationId,
        modelType: ModelType.group,
        slug: slug,
      );

      return group;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OnboardingRepository.createStructure: FAILED!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Creates the first genet and organism record during onboarding
  ///
  /// Creates records using the five-axis data model:
  /// 1. Taxonomy - organismKind determines physical form defaults
  /// 2. Provenance - provenanceType with metadata (collection date, cohort info, etc.)
  /// 3. Location - siteId and groupId from previous onboarding step
  /// 4. Life Stage - user-selected life stage for the organism record
  /// 5. Measurement - quantity determines initial population count
  ///
  /// Returns the urlPath of the created organism for tour navigation
  Future<String> createFirstGenetAndOrganism({
    required String localId,
    required Species species,
    required String siteId,
    required String groupId,
    required User user,
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required int quantity,
    ProvenanceType provenanceType = ProvenanceType.wild,
    String? collectionMethod,
    DateTime? collectionDate,
    String? cohortName,
    DateTime? cohortDate,
    String? clonalId,
    String? accessionNumber,
    String? inheritedProvenanceId,
    String? recordName,
  }) async {
    final String organismId = generateId(firestore: db);
    final String organismEventId = generateId(firestore: db);
    final String now = DateTime.now().toIso8601String();

    // Fetch group to get urlPath for hierarchy
    final groupDoc = await db
        .collection(ModelType.organization.collectionPath)
        .doc(user.organizationId)
        .collection(ModelType.group.collectionPath)
        .doc(groupId)
        .get();

    final groupData = groupDoc.data();
    if (!groupDoc.exists || groupData == null) {
      throw domainErrors.RepositoryError(
        message: 'Group not found for first organism setup.',
        recoverySuggestion:
            'Go back and re-create the site setup step, then try again.',
        technicalDetails: 'Missing group document for groupId: $groupId',
      );
    }
    final groupUrlPath = groupData['urlPath'];
    if (groupUrlPath is! String || groupUrlPath.trim().isEmpty) {
      throw domainErrors.RepositoryError(
        message: 'Group location data is incomplete.',
        recoverySuggestion:
            'Go back and re-create the site setup step, then try again.',
        technicalDetails: 'Missing urlPath for groupId: $groupId',
      );
    }

    // Generate slugs
    final genetSlug = localId.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final organismSlug = '$genetSlug-1';

    // Build provenance metadata map
    final provenanceData = <String, dynamic>{'type': provenanceType.id};

    // Add provenance-specific metadata
    if (provenanceType == ProvenanceType.wild) {
      if (collectionMethod != null) {
        provenanceData['collectionMethod'] = collectionMethod;
      }
      if (collectionDate != null) {
        provenanceData['collectionDate'] = collectionDate.toIso8601String();
      }
    }

    final organization = await getOrganization(user.organizationId);
    if (organization == null) {
      throw domainErrors.RepositoryError(
        message: 'Organization not found for onboarding genet creation.',
        recoverySuggestion: 'Please sign out and sign back in, then try again.',
        technicalDetails: 'Missing organization for id: ${user.organizationId}',
      );
    }

    final eventRepository = EventRepository(
      organization: organization,
      user: user,
      firestore: db,
      organismContext: OrganismContext.forKind(organismKind),
    );
    final snapshotService = SnapshotService(firestore: db);
    final genetRepository = GenetRepository(
      organization: organization,
      user: user,
      eventRepository: eventRepository,
      snapshotService: snapshotService,
      recordRepository: _recordRepository,
      firestore: db,
      organismContext: OrganismContext.forKind(organismKind),
    );

    final normalizedClonalId = clonalId?.trim();
    final normalizedAccessionNumber = accessionNumber?.trim();

    final genetDraft = Genet.partial(
      name: localId,
      localId: localId,
      speciesId: species.id,
      provenanceTypeId: provenanceType.id,
      organismKind: organismKind,
      slug: genetSlug,
      clonalId: normalizedClonalId != null && normalizedClonalId.isNotEmpty
          ? normalizedClonalId
          : null,
      accessionNumber:
          normalizedAccessionNumber != null &&
              normalizedAccessionNumber.isNotEmpty
          ? normalizedAccessionNumber
          : null,
      provenance: provenanceData,
    );

    final genet = await genetRepository.createGenet(
      genetDraft,
      inheritedProvenanceId: inheritedProvenanceId,
    );

    // Synchronize genet slug counter with normal app flow
    await _updateSlugCount(
      organizationId: user.organizationId,
      modelType: ModelType.genet,
      slug: genetSlug,
    );

    // Resolve record name: use provided name, fall back to localId
    final resolvedRecordName = (recordName?.trim().isNotEmpty == true)
        ? recordName!.trim()
        : (localId.isNotEmpty ? localId : 'Unknown');

    // Resolve physical form from registry, fall back to hardcoded defaults
    final physicalForm = _getDefaultPhysicalForm(organismKind, lifeStage);

    // Create OrganismRecord with five-axis data
    final organismUrlPath = '$groupUrlPath/$organismSlug';
    final organism = OrganismRecord(
      id: organismId,
      createdAt: now,
      createdById: user.id,
      updatedAt: now,
      updatedById: user.id,
      organizationId: user.organizationId,
      urlPath: organismUrlPath,
      internalPath: '${user.organizationId}/$organismId',
      slug: organismSlug,
      organismKind: organismKind, // Taxonomy - Axis 1
      lifeStage: LifeStageSpec(stage: lifeStage), // Life Stage - Axis 4
      measurement: PopulationMeasurement(
        value: quantity.toDouble(),
        unit: MeasurementUnit.count,
      ), // Measurement - Axis 5
      recordName: resolvedRecordName,
      speciesId: species.id,
      localId: localId,
      siteId: siteId, // Location - Axis 3
      groupId: groupId, // Location - Axis 3
      provenanceType: provenanceType, // Provenance - Axis 2
      physicalForm: physicalForm, // Organism-aware default from registry
      foreignKeys: {
        'genetId': ForeignKeyReference(
          id: genet.id,
          metadata: {
            'localId': genet.localId,
            'provenanceId': genet.provenanceId,
            'displayName': genet.displayName,
          },
        ),
      },
    );

    final organismEvent = CreateEvent(
      id: organismEventId,
      createdById: user.id,
      recordId: organismId,
      recordModelType: ModelType.organismRecord,
      createdAt: now,
      updatedAt: now,
      updatedById: user.id,
      organizationId: user.organizationId,
      snapshot: organism,
      slug: organismSlug,
      urlPath: organismUrlPath,
      internalPath: '${user.organizationId}/$organismEventId',
    );

    final WriteBatch batch = db.batch();

    // Write organism to organization's organismRecords subcollection
    final organismRef = db
        .collection(ModelType.organization.collectionPath)
        .doc(user.organizationId)
        .collection(ModelType.organismRecord.collectionPath)
        .doc(organismId);
    batch.set(organismRef, organism.toJson());

    // Write events
    _recordRepository.createRecord(organismEvent, batch: batch);

    await batch.commit();

    // Synchronize organism slug counter with normal app flow
    await _updateSlugCount(
      organizationId: user.organizationId,
      modelType: ModelType.organismRecord,
      slug: organismSlug,
    );

    return organismUrlPath;
  }

  /// Get a sensible default physical form based on organism type and life stage.
  ///
  /// Queries [PhysicalFormRegistry] first for defaults, falling back to
  /// hardcoded values if the registry returns no results.
  PhysicalFormInstance _getDefaultPhysicalForm(
    OrganismKind kind,
    LifeStage lifeStage,
  ) {
    try {
      final forms = PhysicalFormRegistry.instance.getAvailableForms(
        kind,
        lifeStage,
      );
      if (forms.isNotEmpty) {
        final first = forms.first;
        final sizeBandId = first.defaultSizeBand?.id ?? 'small';
        return PhysicalFormInstance(formId: first.id, sizeBandId: sizeBandId);
      }
    } catch (e) {
      LoggingService.instance.debug(
        'PhysicalFormRegistry lookup failed during onboarding, '
        'using hardcoded default for ${kind.name}: $e',
      );
    }
    // Hardcoded fallback when registry returns empty or fails
    return _hardcodedDefaultPhysicalForm(kind);
  }

  /// Hardcoded fallback defaults for physical form when registry is unavailable.
  PhysicalFormInstance _hardcodedDefaultPhysicalForm(OrganismKind kind) {
    switch (kind) {
      case OrganismKind.coral:
        return const PhysicalFormInstance(
          formId: 'fragment',
          sizeBandId: 'small',
        );
    }
  }

  /// Suggest the next organism local ID for a species within an organization.
  ///
  /// Uses UniqueNameValidationService to find existing organism records and
  /// suggest the next available ID in the format: {SpeciesCode}-{number}
  /// (e.g., Apal-001, Acer-023).
  Future<String> suggestNextOrganismLocalId({
    required String speciesId,
    required String organizationId,
  }) async {
    return _nameValidationService.suggestNextOrganismLocalId(
      speciesId: speciesId,
      organizationId: organizationId,
    );
  }

  /// Suggest a record name for onboarding.
  /// Simply returns the localId as the default record name.
  Future<String?> suggestRecordName({
    required String organizationId,
    String? localId,
  }) async {
    final trimmed = localId?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  /// Generates a unique slug for a record during onboarding.
  ///
  /// Uses the same format as [InventoryRecordRepository.nextSlugForBase]:
  /// `{base}{counter}` (e.g., site1, site2, group1, group2).
  ///
  /// Unlike the counter-based approach in repositories, this queries for
  /// existing slugs to find the next available one. This is necessary during
  /// onboarding because we don't have access to the transaction-based counter.
  Future<String> _generateUniqueSlug({
    required String organizationId,
    required String base,
    required ModelType modelType,
    String? parentUrlPath,
  }) async {
    final normalizedBase = base.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    var counter = 1;
    var candidate = '$normalizedBase$counter';

    while (await _slugExists(
      organizationId: organizationId,
      modelType: modelType,
      slug: candidate,
      parentUrlPath: parentUrlPath,
    )) {
      counter += 1;
      candidate = '$normalizedBase$counter';
    }
    return candidate;
  }

  Future<bool> _slugExists({
    required String organizationId,
    required ModelType modelType,
    required String slug,
    String? parentUrlPath,
  }) async {
    final parentPath = parentUrlPath ?? '';
    final urlPath = parentPath.isEmpty ? slug : '$parentPath/$slug';

    // Check org-scoped collection (primary location)
    final orgScoped = await db
        .collection(ModelType.organization.collectionPath)
        .doc(organizationId)
        .collection(modelType.collectionPath)
        .where('urlPath', isEqualTo: urlPath)
        .limit(1)
        .get();
    return orgScoped.docs.isNotEmpty;
  }

  /// Update the slug counter after creating a record during onboarding.
  ///
  /// This synchronizes the query-based slug generation used in onboarding
  /// with the counter-based system used by the normal app flow, preventing
  /// duplicate slugs when users create additional records after onboarding.
  ///
  /// Extracts the counter from the generated slug (e.g., 'site1' -> 1) and
  /// updates the slugCounts document to that value.
  Future<void> _updateSlugCount({
    required String organizationId,
    required ModelType modelType,
    required String slug,
  }) async {
    // Extract counter from slug (e.g., 'site1' -> 1, 'group2' -> 2)
    final baseName = modelType.name.toLowerCase();
    final counterStr = slug.replaceFirst(baseName, '');
    final counter = int.tryParse(counterStr) ?? 1;

    final slugCountRef = db
        .collection(ModelType.organization.collectionPath)
        .doc(organizationId)
        .collection('slugCounts')
        .doc(modelType.name);

    // Update counter to the max of current value and new value
    // This handles the case where multiple records are created
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(slugCountRef);
      final currentCount = snapshot.exists ? (safeInt(snapshot.get('count')) ?? 0) : 0;
      if (counter > currentCount) {
        transaction.set(slugCountRef, {'count': counter});
      }
    });
  }
}
