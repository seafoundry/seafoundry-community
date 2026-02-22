// @tier: community
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Model representing a community Provenance record with all known aliases
/// across organizations.
class CommunityProvenanceRecord {
  static final _nonAlphanumeric = RegExp(r'[^A-Z0-9]');

  const CommunityProvenanceRecord({
    required this.provenanceId,
    required this.species,
    required this.speciesCode,
    this.masterClonalId,
    required this.aliases,
    required this.hasGeneticData,
    required this.isFounder,
    required this.isSR,
    this.metadata,
    required this.sources,
    this.moteUniversalIds = const [],
  });

  final String provenanceId;
  final String species;
  final String speciesCode;
  final String? masterClonalId;
  final List<ProvenanceAlias> aliases;
  final bool hasGeneticData;
  final bool isFounder;
  final bool isSR;
  final Map<String, dynamic>? metadata;
  final List<String> sources;
  final List<String> moteUniversalIds;

  factory CommunityProvenanceRecord.fromJson(Map<String, dynamic> json) {
    return CommunityProvenanceRecord(
      provenanceId: json['provenanceId'] as String,
      species: json['species'] as String? ?? '',
      speciesCode: json['speciesCode'] as String? ?? '',
      masterClonalId: json['masterClonalId'] as String?,
      aliases:
          (json['aliases'] as List<dynamic>?)
              ?.map((a) => ProvenanceAlias.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      hasGeneticData: json['hasGeneticData'] as bool? ?? false,
      isFounder: json['isFounder'] as bool? ?? false,
      isSR: json['isSR'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
      moteUniversalIds:
          (json['moteUniversalIds'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'provenanceId': provenanceId,
    'species': species,
    'speciesCode': speciesCode,
    'masterClonalId': masterClonalId,
    'aliases': aliases.map((a) => a.toJson()).toList(),
    'hasGeneticData': hasGeneticData,
    'isFounder': isFounder,
    'isSR': isSR,
    'metadata': metadata,
    'sources': sources,
    'moteUniversalIds': moteUniversalIds,
  };

  /// Get all alias IDs as a flat list
  List<String> get allAliasIds => aliases.map((a) => a.id).toList();

  /// Get aliases filtered by organization
  List<ProvenanceAlias> aliasesForOrg(String org) =>
      aliases.where((a) => a.org == org).toList();

  /// Check if this record has an alias matching the given ID
  /// Normalizes by stripping all non-alphanumeric characters to match crosswalk keys.
  bool hasAlias(String aliasId) {
    final normalized = aliasId.trim().toUpperCase().replaceAll(
      _nonAlphanumeric,
      '',
    );
    return aliases.any(
      (a) =>
          a.id.trim().toUpperCase().replaceAll(_nonAlphanumeric, '') ==
          normalized,
    );
  }
}

/// Model representing a single alias for a Provenance ID
class ProvenanceAlias {
  const ProvenanceAlias({required this.id, required this.org, required this.orgType});

  final String id;
  final String org;
  final String orgType;

  factory ProvenanceAlias.fromJson(Map<String, dynamic> json) {
    return ProvenanceAlias(
      id: json['id'] as String,
      org: json['org'] as String? ?? '',
      orgType: json['orgType'] as String? ?? 'primary',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'org': org, 'orgType': orgType};
}

/// Result of an alias lookup
class AliasLookupResult {
  const AliasLookupResult({
    required this.provenanceId,
    required this.org,
    required this.orgType,
  });

  final String provenanceId;
  final String org;
  final String orgType;

  factory AliasLookupResult.fromJson(Map<String, dynamic> json) {
    return AliasLookupResult(
      provenanceId: json['provenanceId'] as String,
      org: json['org'] as String? ?? '',
      orgType: json['orgType'] as String? ?? 'primary',
    );
  }
}

/// Service for looking up community genetics Provenance IDs across organizations.
///
/// This service provides the "Community Genetics" toggle functionality,
/// allowing users to see which genotypes are shared across organizations
/// under a unified Provenance ID.
///
/// The crosswalk data is stored in Firestore:
/// - `community_genetics_provenances/{provenanceId}` - Full Provenance records
/// - `community_genetics_aliases/{speciesCode}_{aliasId}` - Quick alias lookups
///
/// ## Data Dependencies
///
/// This service queries `community_genetics_aliases` documents which must have:
/// - `normalizedAliasId`: Uppercase, alphanumeric-only version of aliasId
///   (populated by the crosswalk build scripts in `crc_db/`)
///
/// If `normalizedAliasId` is missing or inconsistent, case-insensitive lookups
/// may fail silently. See `crc_db/README.md` for crosswalk data population.
///
/// ## Usage
///
/// ```dart
/// final service = ProvenanceCrosswalkService(firestore: FirebaseFirestore.instance);
///
/// // Look up an alias
/// final results = await service.lookupAlias('Apal-025');
/// // Returns: [AliasLookupResult(provenanceId: 'PID-APAL-0007', org: 'CRF', ...)]
///
/// // Get full Provenance record
/// final record = await service.getProvenanceRecord('PID-APAL-0007');
/// // Returns CommunityProvenanceRecord with all aliases across orgs
/// ```
class ProvenanceCrosswalkService {
  ProvenanceCrosswalkService({
    required FirebaseFirestore firestore,
    FirestoreCollectionResolver? resolver,
    LoggingService? logger,
  }) : _firestore = firestore,
       _resolver = resolver ?? FirestoreCollectionResolver.instance,
       _logger = logger ?? LoggingService.instance;

  final FirebaseFirestore _firestore;
  final FirestoreCollectionResolver _resolver;
  final LoggingService _logger;

  static const String _provenanceCollection = 'community_genetics_provenances';
  static const String _aliasCollection = 'community_genetics_aliases';

  /// Maximum cache size to prevent unbounded memory growth.
  static const int _maxCacheSize = 1000;

  // In-memory LRU cache for performance using LinkedHashMap for O(1) eviction.
  // Access order is maintained by removing and re-inserting entries on access.
  final LinkedHashMap<String, _CacheEntry<List<AliasLookupResult>>> _aliasCache =
      LinkedHashMap<String, _CacheEntry<List<AliasLookupResult>>>();
  final LinkedHashMap<String, _CacheEntry<CommunityProvenanceRecord>> _provenanceCache =
      LinkedHashMap<String, _CacheEntry<CommunityProvenanceRecord>>();

  /// Look up an alias and return matching Provenance ID(s).
  ///
  /// The alias is normalized (uppercase, stripped of separators) before lookup.
  /// Returns a list because the same alias might map to multiple Provenance IDs in edge
  /// cases (though this should be rare with proper deduplication).
  Future<List<AliasLookupResult>> lookupAlias(
    String aliasId, {
    String? speciesCode,
  }) async {
    if (aliasId.isEmpty) return [];

    final normalizedAlias = _normalizeAlias(aliasId);
    final trimmedSpeciesCode = speciesCode?.trim();
    final normalizedSpeciesCode =
        trimmedSpeciesCode == null || trimmedSpeciesCode.isEmpty
            ? null
            : trimmedSpeciesCode.toUpperCase();
    final cacheKey = normalizedSpeciesCode != null
        ? '${normalizedSpeciesCode}_$normalizedAlias'
        : normalizedAlias;

    // Check cache first (LRU: remove and re-insert to move to end)
    final cached = _aliasCache.remove(cacheKey);
    if (cached != null) {
      cached.touch();
      _aliasCache[cacheKey] = cached;
      return cached.value;
    }

    try {
      // Get the collection reference for document access
      final collectionRef = _resolver.collection(_firestore, _aliasCollection);

      if (normalizedSpeciesCode != null) {
        // Direct document lookup if species known
        final docId = '${normalizedSpeciesCode}_$normalizedAlias';
        final doc = await collectionRef.doc(docId).get();
        if (doc.exists) {
          final data = doc.data();
          if (data == null) {
            _logger.warning(
              'Provenance alias $docId exists but has null data; skipping',
            );
          } else {
            final result = [AliasLookupResult.fromJson(data)];
            _cacheAlias(cacheKey, result);
            return result;
          }
        }
      } else {
        // Query by normalizedAliasId field for species-agnostic lookup.
        // The aliasId field stores the original (e.g., "APAL/123") while
        // normalizedAliasId stores the normalized version (e.g., "APAL123").
        _logger.warning(
          'Species-agnostic alias lookup for "$aliasId" - results may be ambiguous '
          'in multi-species contexts',
        );
        final snapshot = await collectionRef
            .where('normalizedAliasId', isEqualTo: normalizedAlias)
            .limit(10)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final results = snapshot.docs
              .map((doc) {
                final data = doc.data();
                return AliasLookupResult.fromJson(data);
              })
              .whereType<AliasLookupResult>()
              .toList();
          if (results.isNotEmpty) {
            _cacheAlias(cacheKey, results);
            return results;
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Provenance alias lookup failed for "$aliasId"', e, stackTrace);
    }

    return [];
  }

  /// Look up multiple aliases in batch.
  ///
  /// More efficient than calling [lookupAlias] multiple times.
  Future<Map<String, List<AliasLookupResult>>> lookupAliases(
    List<String> aliasIds, {
    String? speciesCode,
  }) async {
    final results = <String, List<AliasLookupResult>>{};

    for (final aliasId in aliasIds) {
      results[aliasId] = await lookupAlias(aliasId, speciesCode: speciesCode);
    }

    return results;
  }

  /// Get the full Provenance record by its ID.
  Future<CommunityProvenanceRecord?> getProvenanceRecord(String provenanceId) async {
    if (provenanceId.isEmpty) return null;

    // Check cache first (LRU: remove and re-insert to move to end)
    final cached = _provenanceCache.remove(provenanceId);
    if (cached != null) {
      cached.touch();
      _provenanceCache[provenanceId] = cached;
      return cached.value;
    }

    try {
      final doc = await _resolver
          .collection(_firestore, _provenanceCollection)
          .doc(provenanceId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          _logger.warning(
            'Provenance record $provenanceId exists but has null data; skipping',
          );
          return null;
        }
        final record = CommunityProvenanceRecord.fromJson(data);
        _cacheProvenance(provenanceId, record);
        return record;
      }
    } catch (e, stackTrace) {
      _logger.error('Provenance record lookup failed for "$provenanceId"', e, stackTrace);
    }

    return null;
  }

  /// Get all Provenance records for a species.
  ///
  /// Use with caution - can return large datasets.
  Future<List<CommunityProvenanceRecord>> getProvenanceRecordsForSpecies(
    String speciesCode, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _resolver
          .collection(_firestore, _provenanceCollection)
          .where('speciesCode', isEqualTo: speciesCode.toUpperCase())
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return CommunityProvenanceRecord.fromJson(data);
          })
          .whereType<CommunityProvenanceRecord>()
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get Provenance records for species "$speciesCode"',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Search for Provenance records by alias pattern.
  ///
  /// Supports prefix matching (e.g., "AP" matches "AP1", "AP10", etc.)
  Future<List<CommunityProvenanceRecord>> searchByAliasPrefix(
    String prefix, {
    String? speciesCode,
    int limit = 20,
  }) async {
    try {
      final normalizedPrefix = _normalizeAlias(prefix);

      // Query alias collection for prefix matches
      Query<Map<String, dynamic>> query = _resolver.collection(
        _firestore,
        _aliasCollection,
      );

      if (speciesCode != null && speciesCode.isNotEmpty) {
        query = query.where(
          'speciesCode',
          isEqualTo: speciesCode.toUpperCase(),
        );
      }

      var finalQuery = query;

      if (normalizedPrefix.isNotEmpty) {
        finalQuery = finalQuery.where(
          'normalizedAliasId',
          isGreaterThanOrEqualTo: normalizedPrefix,
        );
      }
      finalQuery = finalQuery.orderBy('normalizedAliasId');

      final snapshot = await finalQuery.limit(limit).get();
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          snapshot.docs;

      if (docs.isEmpty && normalizedPrefix.isNotEmpty && kDebugMode) {
        final fallbackSnapshot = await query.get();
        docs = fallbackSnapshot.docs;
      }
      if (snapshot.docs.isNotEmpty) {
         _logger.debug('CrosswalkSearch: Found ${snapshot.docs.length} matches for prefix $normalizedPrefix');
      } else {
         _logger.debug('CrosswalkSearch: Found 0 matches for prefix $normalizedPrefix');
      }

      // Collect unique Provenance IDs
      final provenanceIds = docs
          .where((doc) {
            if (normalizedPrefix.isEmpty) return true;
            final normalized = doc.data()['normalizedAliasId'];
            return normalized is String &&
                normalized.startsWith(normalizedPrefix);
          })
          .take(limit)
          .map((doc) => doc.data()['provenanceId'])
          .whereType<String>()
          .toSet();
      // Fetch full records in parallel
      final results = await Future.wait(
        provenanceIds.map((id) => getProvenanceRecord(id)),
      );

      final records = results.whereType<CommunityProvenanceRecord>().toList();

      return records;
    } catch (e, stackTrace) {
      _logger.error('Failed to search Provenance by prefix "$prefix"', e, stackTrace);
      return [];
    }
  }

  /// Search for Provenance records by PID prefix.
  ///
  /// Supports prefix matching (e.g., "PID-AP" matches "PID-APAL-0007").
  Future<List<CommunityProvenanceRecord>> searchByProvenanceIdPrefix(
    String prefix, {
    String? speciesCode,
    int limit = 20,
  }) async {
    try {
      final normalizedPrefix = prefix.trim().toUpperCase();

      Query<Map<String, dynamic>> query = _resolver.collection(
        _firestore,
        _provenanceCollection,
      );

      if (speciesCode != null && speciesCode.isNotEmpty) {
        query = query.where(
          'speciesCode',
          isEqualTo: speciesCode.toUpperCase(),
        );
      }

      query = query.orderBy('provenanceId');
      if (normalizedPrefix.isNotEmpty) {
        final endPrefix = '$normalizedPrefix\uf8ff';
        query = query.startAt([normalizedPrefix]).endAt([endPrefix]);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return CommunityProvenanceRecord.fromJson(data);
          })
          .whereType<CommunityProvenanceRecord>()
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to search Provenance IDs by prefix "$prefix"',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Find related genotypes that share the same community Provenance ID.
  ///
  /// Given a local genotype's source information (sourceProvenanceId, sourceOrganizationId),
  /// this finds the community Provenance record that links all related genotypes.
  Future<CommunityProvenanceRecord?> findRelatedGenotypes({
    required String aliasId,
    String? sourceOrganization,
    String? speciesCode,
  }) async {
    final lookupResults = await lookupAlias(aliasId, speciesCode: speciesCode);

    if (lookupResults.isEmpty) return null;

    // If source org specified, prefer that match
    if (sourceOrganization != null) {
      final orgMatch = lookupResults.firstWhere(
        (r) => r.org == sourceOrganization,
        orElse: () => lookupResults.first,
      );
      return getProvenanceRecord(orgMatch.provenanceId);
    }

    return getProvenanceRecord(lookupResults.first.provenanceId);
  }

  /// Register a new mapping when a transfer is accepted.
  ///
  /// This extends the crosswalk with organization-specific aliases that
  /// are discovered through transfers.
  Future<void> registerTransferMapping({
    required String provenanceId,
    required String localGenetId,
    required String localOrganizationId,
    String? localProvenanceId,
  }) async {
    if (localProvenanceId == null) return;

    try {
      final doc = _resolver
          .collection(_firestore, _provenanceCollection)
          .doc(provenanceId);

      // First check if doc exists (outside transaction for performance)
      final existsCheck = await doc.get();
      if (!existsCheck.exists) {
        _logger.info(
          'Transfer mapping skipped: "$provenanceId" is organization-local '
          '(not in community crosswalk)',
        );
        return;
      }

      // Use arrayUnion for atomic append (prevents race condition / lost updates)
      await doc.update({
        'aliases': FieldValue.arrayUnion([
          {'id': localProvenanceId, 'org': localOrganizationId, 'orgType': 'transfer'},
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Invalidate cache AFTER successful update to prevent stale reads
      // (a concurrent read during the update will cache the old data, but
      // invalidating after ensures subsequent reads get fresh data)
      _provenanceCache.remove(provenanceId);

      _logger.info('Registered transfer mapping: $localProvenanceId -> $provenanceId');
    } catch (e, stackTrace) {
      // Use error() for stack trace support, but at warning level conceptually
      // (registration is best-effort, not critical)
      _logger.error(
        'Failed to register transfer mapping for "$provenanceId" (best-effort)',
        e,
        stackTrace,
      );
      // Don't throw - registration is best-effort
    }
  }

  /// Register a new mapping within a Firestore transaction.
  ///
  /// This is the transactional version of [registerTransferMapping] that
  /// ensures atomicity with other transfer acceptance operations (genet
  /// creation, transfer status update). If crosswalk registration fails,
  /// the entire transaction rolls back.
  ///
  /// The [provenanceDoc] parameter must be fetched via `transaction.get()`
  /// BEFORE calling this method due to Firestore's read-before-write rule.
  void registerTransferMappingInTransaction({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> provenanceDocRef,
    required DocumentSnapshot<Map<String, dynamic>> provenanceDoc,
    required String provenanceId,
    required String localOrganizationId,
    required String localProvenanceId,
  }) {
    if (!provenanceDoc.exists) {
      _logger.info(
        'Transfer mapping skipped in transaction: "$provenanceId" is '
        'organization-local (not in community crosswalk)',
      );
      return;
    }

    // Use arrayUnion for atomic append within the transaction
    transaction.update(provenanceDocRef, {
      'aliases': FieldValue.arrayUnion([
        {
          'id': localProvenanceId,
          'org': localOrganizationId,
          'orgType': 'transfer',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Invalidate cache - transaction commit will make this visible
    _provenanceCache.remove(provenanceId);

    _logger.debug(
      'Queued crosswalk mapping in transaction: $localProvenanceId -> $provenanceId',
    );
  }

  /// Get a document reference for the provenance collection.
  ///
  /// Used by callers who need to fetch the document within a transaction
  /// before calling [registerTransferMappingInTransaction].
  DocumentReference<Map<String, dynamic>> getProvenanceDocRef(
    String provenanceId,
  ) {
    return _resolver
        .collection(_firestore, _provenanceCollection)
        .doc(provenanceId);
  }

  /// Check if community genetics data is available for a species.
  Future<bool> hasDataForSpecies(String speciesCode) async {
    try {
      final snapshot = await _resolver
          .collection(_firestore, _provenanceCollection)
          .where('speciesCode', isEqualTo: speciesCode.toUpperCase())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check data availability for species "$speciesCode"',
        e,
        stackTrace,
      );
      return false;
    }
  }

  /// Get available species codes that have community genetics data.
  Future<List<String>> getAvailableSpecies() async {
    try {
      // Query distinct species codes
      final snapshot = await _resolver
          .collection(_firestore, _provenanceCollection)
          .limit(1000)
          .get();

      final speciesCodes = <String>{};
      for (final doc in snapshot.docs) {
        final code = doc.data()['speciesCode'] as String?;
        if (code != null && code.isNotEmpty) {
          speciesCodes.add(code);
        }
      }

      return speciesCodes.toList()..sort();
    } catch (e, stackTrace) {
      _logger.error('Failed to get available species', e, stackTrace);
      return [];
    }
  }

  /// Clear the in-memory cache.
  void clearCache() {
    _aliasCache.clear();
    _provenanceCache.clear();
  }

  /// Get cache statistics for monitoring.
  Map<String, int> getCacheStats() => {
    'aliasCacheSize': _aliasCache.length,
    'provenanceCacheSize': _provenanceCache.length,
  };

  /// Normalize an alias for lookup.
  ///
  /// Uses UPPERCASE normalization to match the crosswalk build script's
  /// document key generation pattern. Trims whitespace and removes ALL
  /// non-alphanumeric characters (e.g., dashes, slashes, dots, underscores).
  /// This matches: scripts/build-species-crosswalk.js normalizedAliasId logic.
  String _normalizeAlias(String alias) {
    return alias.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Cache an alias lookup result with LRU eviction.
  void _cacheAlias(String key, List<AliasLookupResult> value) {
    _evictIfNeeded(_aliasCache);
    _aliasCache[key] = _CacheEntry(value);
  }

  /// Cache a Provenance record with LRU eviction.
  void _cacheProvenance(String key, CommunityProvenanceRecord value) {
    _evictIfNeeded(_provenanceCache);
    _provenanceCache[key] = _CacheEntry(value);
  }

  /// Evict oldest entries if cache is at capacity.
  /// Uses O(1) eviction by removing the first (oldest) entry from LinkedHashMap.
  void _evictIfNeeded<T>(LinkedHashMap<String, _CacheEntry<T>> cache) {
    while (cache.length >= _maxCacheSize) {
      // Remove the first (oldest) entry - O(1) operation
      cache.remove(cache.keys.first);
    }
  }
}

/// Cache entry with access tracking for LRU eviction.
class _CacheEntry<T> {
  _CacheEntry(this.value) : lastAccess = DateTime.now();

  final T value;
  DateTime lastAccess;

  void touch() {
    lastAccess = DateTime.now();
  }
}

/// Extension to integrate crosswalk service with transfer workflows.
extension ProvenanceCrosswalkTransferExtension on ProvenanceCrosswalkService {
  /// Called during transfer acceptance to check if the incoming genotype
  /// already exists in the community crosswalk.
  ///
  /// Returns the matching community Provenance ID if found, allowing the receiving
  /// organization to link rather than duplicate.
  Future<String?> findExistingCrosswalkEntry({
    required String sourceProvenanceId,
    required String sourceOrganizationId,
    String? speciesCode,
  }) async {
    final results = await lookupAlias(sourceProvenanceId, speciesCode: speciesCode);
    final normalizedSourceOrg = _normalizeAlias(sourceOrganizationId);

    for (final result in results) {
      if (_normalizeAlias(result.org) == normalizedSourceOrg) {
        return result.provenanceId;
      }
    }

    // Also try the full Provenance ID in case it's already a community ID
    final normalizedId = sourceProvenanceId.toUpperCase();
    if (normalizedId.startsWith('PID-')) {
      final record = await getProvenanceRecord(sourceProvenanceId);
      if (record != null) {
        return record.provenanceId;
      }
    }

    return null;
  }
}
