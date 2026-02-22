// @tier: community
part of 'organism_record_repository.dart';

/// Query and stream methods for OrganismRecordRepository.
///
/// Contains client-side filtered streams, server-side Firestore queries,
/// and search/retrieval operations.
mixin _OrganismRecordRepositoryQueries
    on _OrganismRecordRepositoryBase, _OrganismRecordRepositoryHelpers {
  // Threshold in ms for logging slow search warnings (Phase 2 server-side target)
  static const _slowSearchThresholdMs = 200;

  // ===========================================================================
  // FILTERED STREAMS
  //
  // These methods use client-side filtering of the cached streamAll for
  // consistency and to share the same Firestore subscription. For very large
  // organizations (>5000 organisms), consider using the server-side
  // queryBySite/queryByGroup methods instead.
  // ===========================================================================

  /// Stream organism records filtered by site.
  ///
  /// Uses client-side filtering of the cached stream for consistency.
  /// For large datasets, use [queryBySite] for server-side filtering.
  @override
  Stream<List<OrganismRecord>> streamBySite(String siteId) {
    return streamAll.map(
      (records) => records.where((record) => record.siteId == siteId).toList(),
    );
  }

  /// Stream organism records filtered by group (container).
  ///
  /// Uses client-side filtering of the cached stream for consistency.
  /// For large datasets, use [queryByGroup] for server-side filtering.
  @override
  Stream<List<OrganismRecord>> streamByGroup(String groupId) {
    return streamAll.map(
      (records) =>
          records.where((record) => record.groupId == groupId).toList(),
    );
  }

  /// Stream organism records filtered by organism type.
  ///
  /// Uses client-side filtering of the cached stream for consistency.
  /// For large datasets, use [queryByOrganismKind] for server-side filtering.
  @override
  Stream<List<OrganismRecord>> streamByOrganism(OrganismKind kind) {
    return streamAll.map(
      (records) =>
          records.where((record) => record.organismKind == kind).toList(),
    );
  }

  /// Stream organism records that are propagatable
  /// (organism-specific: ready for propagation and healthy).
  @override
  Stream<List<OrganismRecord>> streamPropagatable() {
    return streamAll.map(
      (records) => records.where((record) {
        final readyForPropagation = record.readyForPropagation;
        final healthStatus = record.healthStatus;
        final isHealthy = healthStatus.isHealthy;
        return readyForPropagation && isHealthy;
      }).toList(),
    );
  }

  /// Stream organism records that are ready for outplanting.
  @override
  Stream<List<OrganismRecord>> streamReadyForOutplant() {
    return streamAll.map(
      (records) => records.where((record) {
        final readyForOutplant = record.readyForOutplant;
        final healthStatus = record.healthStatus;
        final isHealthy = healthStatus.isHealthy;
        return readyForOutplant && isHealthy;
      }).toList(),
    );
  }

  // ===========================================================================
  // SERVER-SIDE FILTERED QUERIES
  //
  // These methods use Firestore server-side filtering for better scalability
  // with large datasets. They create separate Firestore subscriptions but
  // reduce network bandwidth and client memory usage.
  //
  // REQUIRED INDEXES (add to firestore.indexes.json):
  // - organizationId + siteId
  // - organizationId + groupId
  // - organizationId + organismKind
  // ===========================================================================

  /// Query organism records by site using server-side Firestore filtering.
  ///
  /// Creates a separate Firestore subscription with server-side siteId filter.
  /// More efficient for large organizations but doesn't share cache with [streamAll].
  @override
  Stream<List<OrganismRecord>> queryBySite(String siteId) {
    final query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('siteId', isEqualTo: siteId);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => parseOrganismSafe(doc.data()))
          .whereType<OrganismRecord>()
          .where(shouldIncludeRecord)
          .toList();
    });
  }

  /// Query organism records by group using server-side Firestore filtering.
  ///
  /// Creates a separate Firestore subscription with server-side groupId filter.
  /// More efficient for large organizations but doesn't share cache with [streamAll].
  @override
  Stream<List<OrganismRecord>> queryByGroup(String groupId) {
    final query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('groupId', isEqualTo: groupId);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => parseOrganismSafe(doc.data()))
          .whereType<OrganismRecord>()
          .where(shouldIncludeRecord)
          .toList();
    });
  }

  /// Query organism records by organism kind using server-side Firestore filtering.
  ///
  /// Creates a separate Firestore subscription with server-side organismKind filter.
  /// More efficient for large organizations but doesn't share cache with [streamAll].
  @override
  Stream<List<OrganismRecord>> queryByOrganismKind(OrganismKind kind) {
    final query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('organismKind', isEqualTo: kind.name);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => parseOrganismSafe(doc.data()))
          .whereType<OrganismRecord>()
          .where(shouldIncludeRecord)
          .toList();
    });
  }

  /// Query organism records by genet ID using server-side Firestore filtering.
  ///
  /// Creates a separate Firestore subscription with server-side genetId filter.
  Stream<List<OrganismRecord>> queryByGenet(String genetId) {
    final query = collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('genetId', isEqualTo: genetId);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => parseOrganismSafe(doc.data()))
          .whereType<OrganismRecord>()
          .where(shouldIncludeRecord)
          .toList();
    });
  }

  // ===========================================================================
  // SEARCH AND RETRIEVAL
  // ===========================================================================

  /// Search organism records by query string with optional filters.
  ///
  /// Uses client-side filtering over in-memory collection from [getAll].
  /// Searches across: recordName, localId, aliases, speciesId, provenance display name.
  /// Filters by: organismKind, lifeStage, physicalFormId, siteId, groupId.
  ///
  /// Results are returned in no guaranteed order when query is empty.
  ///
  /// **Performance Note:** This uses client-side filtering after fetching all
  /// records. For optimal performance with large datasets (>10k records),
  /// migrate to server-side Firestore queries with composite indexes:
  ///
  /// Required indexes for server-side search:
  /// - `organismRecords(organizationId, organismKind, __name__)`
  /// - `organismRecords(organizationId, siteId, __name__)`
  /// - `organismRecords(organizationId, groupId, __name__)`
  ///
  /// Text search would require a third-party search service (Algolia, Typesense).
  @override
  Future<List<OrganismRecord>> search(
    String query, {
    OrganismKind? organismKind,
    LifeStage? lifeStage,
    String? physicalFormId,
    String? siteId,
    String? groupId,
    int limit = 50,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final allRecords = await getAll();
      final normalizedQuery = query.trim().toLowerCase();

      final results = allRecords
          .where((record) {
            // Apply filters
            if (organismKind != null && record.organismKind != organismKind) {
              return false;
            }
            if (lifeStage != null && record.lifeStage.stage != lifeStage) {
              return false;
            }
            if (physicalFormId != null &&
                record.physicalForm?.formId != physicalFormId) {
              return false;
            }
            if (siteId != null && record.siteId != siteId) {
              return false;
            }
            if (groupId != null && record.groupId != groupId) {
              return false;
            }

            // If no query, return all filtered records
            if (normalizedQuery.isEmpty) return true;

            // Build searchable tokens
            final tokens = <String>[
              record.recordName,
              record.localId ?? '',
              record.alias ?? '',
              record.speciesId ?? '',
              record.provenanceType?.metadata.displayName ?? '',
              ...record.aliases.map((alias) => alias.value),
              (record.metadata?['localId'] as String?) ?? '',
            ];

            // Match any token (case-insensitive substring)
            return tokens.any(
              (token) => token.toLowerCase().contains(normalizedQuery),
            );
          })
          .take(limit)
          .toList(growable: false);

      stopwatch.stop();

      // Log slow searches for monitoring
      if (stopwatch.elapsedMilliseconds > _slowSearchThresholdMs) {
        LoggingService.instance.warning(
          'Slow organism search detected: ${stopwatch.elapsedMilliseconds}ms',
          {
            'query': query,
            'resultCount': results.length,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        );
      }

      return results;
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// Get recent organism records ordered by updatedAt descending.
  ///
  /// Used by search dialogs to show recent selections before user types.
  @override
  Future<List<OrganismRecord>> getRecent({
    int limit = 5,
    OrganismKind? organismKind,
  }) async {
    final allRecords = await getAll();

    var filtered = allRecords;
    if (organismKind != null) {
      filtered = filtered.where((r) => r.organismKind == organismKind).toList();
    }

    // Sort by updatedAt descending
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return filtered.take(limit).toList(growable: false);
  }

  /// Get organisms by species ID.
  ///
  /// Useful for species-specific searches and reports.
  @override
  Future<List<OrganismRecord>> getBySpecies(
    String speciesId, {
    OrganismKind? organismKind,
  }) async {
    final allRecords = await getAll();

    return allRecords
        .where((record) {
          if (record.speciesId != speciesId) return false;
          if (organismKind != null && record.organismKind != organismKind) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Get organisms by genet provenance ID (PID- format).
  ///
  /// Matches against Genet records with the provided provenanceId and returns
  /// organisms whose top-level genetId references those genets.
  ///
  /// Rejects input that does not match PID format to prevent
  /// accidental comparison against Firestore document IDs or legacy IDs.
  @override
  Future<List<OrganismRecord>> getByGenetProvenanceId(
    String provenanceId, {
    OrganismKind? organismKind,
  }) async {
    final normalized = provenanceId.trim().toUpperCase();
    if (ValidationService.provenanceId(normalized) != null) {
      LoggingService.instance.warning(
        'getByGenetProvenanceId called with non-provenance ID: $provenanceId',
      );
      return const [];
    }

    final genetCollection = FirestoreCollectionResolver.instance.subcollection(
      db,
      ModelType.organization.collectionPath,
      organization.id,
      ModelType.genet.collectionPath,
    );
    final genetSnapshot = await genetCollection
        .where('provenanceId', isEqualTo: normalized)
        .get();
    if (genetSnapshot.docs.isEmpty) {
      return const [];
    }
    final genetIds = genetSnapshot.docs
        .map((doc) => doc.id)
        .toSet();

    final allRecords = await getAll();
    return allRecords
        .where((record) {
          final recordGenetId = record.genetId;
          if (recordGenetId == null || recordGenetId.isEmpty) {
            return false;
          }
          final matchesProvenance = genetIds.contains(recordGenetId);

          if (!matchesProvenance) return false;
          if (organismKind != null && record.organismKind != organismKind) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Count organisms in a specific group.
  ///
  /// Returns the total count of organism records within the specified group.
  /// Used for capacity validation when creating new organisms.
  @override
  Future<int> countByGroup(String groupId) async {
    final records = await streamByGroup(groupId).first;
    return records.length;
  }

  /// Get all organisms that belong to a pending outplant batch.
  ///
  /// Returns organisms where pendingBatchId matches the given batch ID.
  /// Used for executing or cancelling a pending batch.
  @override
  Future<List<OrganismRecord>> getOrganismsForPendingBatch(
    String batchId,
  ) async {
    final allRecords = await getAll();

    return allRecords
        .where((record) => record.pendingBatchId == batchId)
        .toList(growable: false);
  }
}
