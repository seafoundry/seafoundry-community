import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for validating unique names for structures, sites, and genets.
class UniqueNameValidationService {
  UniqueNameValidationService({required FirebaseFirestore firestore})
    : _db = firestore;

  final FirebaseFirestore _db;
  final LoggingService _logger = LoggingService.instance;

  // Static TTL cache for genet name suggestions - shared across all instances
  // Key: "$organizationDomain:$speciesId"
  static final Map<String, _CachedSuggestion> _suggestionCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Check if a structure name is unique within its site and type
  ///
  /// Unique constraints:
  /// - Name must be unique within the site (all descendants of site)
  /// - Name must be unique within the same model type (e.g., all groups)
  /// - Can exclude a specific record ID (for edit operations)
  Future<bool> isStructureNameUnique({
    required String name,
    required ModelType modelType,
    required Site site,
    String? excludeRecordId,
  }) async {
    try {
      // Query nested collection (the only source of truth)
      // Root collections like /groups are blocked by Firestore rules
      final query = _db
          .collection(ModelType.organization.collectionPath)
          .doc(site.organizationId)
          .collection(modelType.collectionPath)
          .where('urlPath', isGreaterThanOrEqualTo: site.urlPath)
          .where('urlPath', isLessThanOrEqualTo: '${site.urlPath}\uf8ff');

      return _validateUniqueNameInQuery(
        query: query,
        name: name,
        contextLabel: '${modelType.name} under ${site.name}',
        excludeRecordId: excludeRecordId,
      );
    } catch (e) {
      _logger.error('Failed to validate unique name', e);
      rethrow;
    }
  }

  /// Check if a site name is unique within the organization
  Future<bool> isSiteNameUnique({
    required String name,
    required String organizationDomain,
    required String organizationId,
    String? excludeRecordId,
  }) async {
    try {
      final domainLabel =
          organizationDomain.trim().isEmpty ? organizationId : organizationDomain;
      // Query nested collection (the only source of truth for org-scoped queries)
      // Root /sites collection requires complex permission checks that fail with urlPath queries
      final query = _db
          .collection(ModelType.organization.collectionPath)
          .doc(organizationId)
          .collection(ModelType.site.collectionPath);

      return _validateUniqueNameInQuery(
        query: query,
        name: name,
        contextLabel: domainLabel,
        excludeRecordId: excludeRecordId,
      );
    } catch (e) {
      _logger.error('Failed to validate unique site name', e);
      rethrow;
    }
  }

  /// Helper to validate name uniqueness within a query.
  ///
  /// Iterates through the query snapshot and checks for case-insensitive
  /// name matches, excluding the specified [excludeRecordId].
  Future<bool> _validateUniqueNameInQuery({
    required Query query,
    required String name,
    required String contextLabel,
    String? excludeRecordId,
  }) async {
    final snapshot = await query.get();
    final lowerName = name.toLowerCase();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docName = data['name'] as String?;
      final docId = data['id'] as String?;

      // Skip if this is the record being edited
      if (excludeRecordId != null && docId == excludeRecordId) {
        continue;
      }

      // Check if name matches (case-insensitive)
      if (docName?.toLowerCase() == lowerName) {
        _logger.info(
          'Name conflict found: "$name" already exists in $contextLabel',
        );
        return false;
      }
    }
    return true;
  }

  /// Check if a genet name (local genet ID) is unique within the organization
  ///
  /// Unique constraints:
  /// - Name must be unique within the organization (all genets)
  /// - Case-insensitive comparison
  /// - Can exclude a specific record ID (for edit operations)
  Future<bool> isGenetNameUnique({
    required String name,
    required String organizationDomain,
    required String organizationId,
    String? excludeRecordId,
  }) async {
    try {
      final domainLabel =
          organizationDomain.trim().isEmpty ? organizationId : organizationDomain;
      // Query for genets under this organization with the same name
      final lowerName = name.toLowerCase();
      final scopedCollection = _db
          .collection('organizations')
          .doc(organizationId)
          .collection(ModelType.genet.collectionPath);

      final scopedExact = await scopedCollection
          .where('nameLowercase', isEqualTo: lowerName)
          .get();

      for (final doc in scopedExact.docs) {
        final docId = doc.id;
        if (excludeRecordId == null || docId != excludeRecordId) {
          _logger.info(
            'Genet name conflict found via indexed lookup: "$name" '
            'already exists for organization $domainLabel',
          );
          return false;
        }
      }

      // Query nested collection (the only source of truth)
      // Root /genets collection is blocked by Firestore rules
      final docs = (await scopedCollection.get()).docs;

      for (final doc in docs) {
        final data = doc.data();
        final docName = (data['displayName'] ?? data['name']) as String?;
        final docId = data['id'] as String?;

        // Skip if this is the record being edited
        if (excludeRecordId != null && docId == excludeRecordId) {
          continue;
        }

        // Check if name matches (case-insensitive)
        if (docName?.toLowerCase() == name.toLowerCase()) {
          _logger.info(
            'Genet name conflict found: "$name" already exists in $domainLabel',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.error('Failed to validate unique genet name', e);
      rethrow;
    }
  }

  /// Check if a genet local ID is unique within the organization.
  ///
  /// Local ID conflicts should block re-use even if the genet is archived.
  /// This mirrors the suggestion logic that never reuses archived IDs.
  Future<bool> isGenetLocalIdUnique({
    required String localGenetId,
    required String organizationId,
    String? excludeRecordId,
  }) async {
    try {
      final normalizedTarget = normalizeLocalId(localGenetId);
      if (normalizedTarget == null) {
        return true;
      }

      final scopedCollection = _db
          .collection('organizations')
          .doc(organizationId)
          .collection(ModelType.genet.collectionPath);

      // Fast path: exact localGenetId matches.
      final exactSnapshot = await scopedCollection
          .where('localGenetId', isEqualTo: localGenetId)
          .get();

      for (final doc in exactSnapshot.docs) {
        final docId = doc.data()['id'] as String? ?? doc.id;
        if (excludeRecordId == null || docId != excludeRecordId) {
          _logger.info(
            'Genet local ID conflict found via indexed lookup: "$localGenetId" '
            'already exists for organization $organizationId',
          );
          return false;
        }
      }

      // Fallback: scan for case-insensitive or legacy storage in name/displayName.
      final docs = (await scopedCollection.get()).docs;
      for (final doc in docs) {
        final data = doc.data();
        final docId = data['id'] as String? ?? doc.id;
        if (excludeRecordId != null && docId == excludeRecordId) {
          continue;
        }
        final candidate =
            data['localGenetId']?.toString().trim().isNotEmpty == true
                ? data['localGenetId']?.toString()
                : (data['name']?.toString() ?? data['displayName']?.toString());
        final normalizedCandidate = normalizeLocalId(candidate);
        if (normalizedCandidate == null) {
          continue;
        }
        if (normalizedCandidate == normalizedTarget) {
          _logger.info(
            'Genet local ID conflict found: "$localGenetId" already exists '
            'for organization $organizationId',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      _logger.error('Failed to validate unique genet local ID', e);
      rethrow;
    }
  }

  /// Get next suggested local ID for an organism within organization
  ///
  /// Format: {4-letter-code}-{3-digit-number} (e.g., Apal-001, Acer-023)
  /// Uses the species 4-letter code (genus first 1 letter + species first 3 letters)
  /// in mixed case format (first letter uppercase, rest lowercase)
  /// Finds the highest existing number for this species and suggests next one
  ///
  /// Queries organismRecords collection, not genets.
  Future<String> suggestNextOrganismLocalId({
    required String speciesId,
    required String organizationId,
  }) async {
    // Check cache first
    final cacheKey = 'organism:$organizationId:$speciesId';
    final cached = _suggestionCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      _logger.debug('Using cached organism local ID suggestion: ${cached.suggestedName}');
      return cached.suggestedName;
    }

    try {
      // Get the 4-letter species code from the Species registry
      final species = Species.lookupById(speciesId);
      final String formattedCode;

      if (species != null) {
        // Use the proper 4-letter code from Species, in mixed case (e.g., "Apal")
        final code = species.code;
        formattedCode = code.isNotEmpty
            ? code[0].toUpperCase() + code.substring(1).toLowerCase()
            : 'Unkn';
      } else {
        // Fallback: Try to extract a reasonable code from speciesId
        final normalized = speciesId.replaceAll('species_', '').replaceAll('_', ' ').trim();
        final parts = normalized.split(' ');

        if (parts.length >= 2) {
          // genus + species: take first letter of genus + first 3 of species
          final genus = parts[0];
          final speciesName = parts[1];
          final rawCode = (genus.isNotEmpty ? genus[0] : 'X') +
              (speciesName.length >= 3
                  ? speciesName.substring(0, 3)
                  : speciesName.padRight(3, 'x'));
          formattedCode = rawCode[0].toUpperCase() + rawCode.substring(1).toLowerCase();
        } else if (normalized.length >= 4) {
          final rawCode = normalized.substring(0, 4);
          formattedCode = rawCode[0].toUpperCase() + rawCode.substring(1).toLowerCase();
        } else {
          formattedCode = 'Unkn';
        }
      }

      // Query genets for this species in the organization
      // Using organization subcollection is more efficient and consistent with validation
      // which checks against the genets collection.
      final snapshot = await _db
          .collection('organizations')
          .doc(organizationId)
          .collection(ModelType.genet.collectionPath)
          .where('speciesId', isEqualTo: speciesId)
          .get();

      // Find the highest number used for this species code
      int maxNumber = 0;
      // Match patterns like "APAL-001", "Apal-23", "apal-1" (case-insensitive)
      final pattern = RegExp(
        '^[a-zA-Z]{4}[\\-](\\d+)',
        caseSensitive: false,
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Do not skip archived genets. If "Apal-001" is archived, we should NOT reuse it.
        // We want the next ID to be "Apal-002".

        // Genet Local ID is primarily stored in 'name', but check others for safety
        final localGenetId = (data['name'] ??
                         data['localGenetId'] ??
                         data['displayName']) as String?;

        if (localGenetId != null) {
          final match = pattern.firstMatch(localGenetId);
          if (match != null) {
            final number = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (number > maxNumber) {
              maxNumber = number;
            }
          }
        }
      }

      // Suggest next number with 3-digit zero-padding (e.g., 001, 023, 999)
      final nextNumber = (maxNumber + 1).toString().padLeft(3, '0');
      final suggestion = '$formattedCode-$nextNumber';

      // Cache the result
      _suggestionCache[cacheKey] = _CachedSuggestion(
        suggestion,
        DateTime.now().add(_cacheTtl),
      );

      return suggestion;
    } catch (e) {
      _logger.error('Failed to suggest next organism local ID', e);
      // Fallback to simple format with proper code extraction
      final species = Species.lookupById(speciesId);
      if (species != null) {
        final code = species.code;
        final formatted = code.isNotEmpty
            ? code[0].toUpperCase() + code.substring(1).toLowerCase()
            : 'Unkn';
        return '$formatted-001';
      }
      return 'Unkn-001';
    }
  }

  /// Invalidate cached suggestion for organism local ID when a new organism is created.
  void invalidateOrganismSuggestionCache({
    required String speciesId,
    required String organizationId,
  }) {
    final cacheKey = 'organism:$organizationId:$speciesId';
    _suggestionCache.remove(cacheKey);
    _logger.debug('Invalidated organism local ID suggestion cache for $cacheKey');
  }

  /// Suggests the next generation local ID for graduation/spawning workflows.
  ///
  /// Given a base local ID (e.g., `APAL-COH-001` for cohort graduation or
  /// `APAL-001` for spawning), finds all existing IDs matching the pattern
  /// `{baseLocalId}-F\d+` and returns the next available generation counter.
  ///
  /// Examples:
  /// - If `baseLocalId` is `APAL-COH-001` and no `-F1`, `-F2` exist, returns `APAL-COH-001-F1`
  /// - If `APAL-COH-001-F1` and `APAL-COH-001-F2` exist, returns `APAL-COH-001-F3`
  /// - If `APAL-001-F1` through `APAL-001-F5` exist, returns `APAL-001-F6`
  ///
  /// The generation counter represents lineage depth from the source organism/cohort.
  Future<String> suggestNextGenerationLocalId({
    required String baseLocalId,
    required String organizationId,
  }) async {
    final normalizedBase = baseLocalId.trim();
    if (normalizedBase.isEmpty) {
      return '$normalizedBase-F1';
    }

    try {
      // Query genets for this organization
      final snapshot = await _db
          .collection('organizations')
          .doc(organizationId)
          .collection(ModelType.genet.collectionPath)
          .get();

      // Find the highest generation number used for this base local ID
      int maxGeneration = 0;

      // Match patterns like "APAL-001-F1", "APAL-COH-001-F23" (case-insensitive)
      // The base is escaped to handle special regex characters
      final escapedBase = RegExp.escape(normalizedBase);
      final pattern = RegExp(
        '^$escapedBase-F(\\d+)\$',
        caseSensitive: false,
      );

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Do not skip archived genets - we never want to reuse generation IDs

        // Check all possible local ID storage locations
        final localGenetId = (data['localGenetId'] ??
                data['name'] ??
                data['displayName']) as String?;

        if (localGenetId != null) {
          final match = pattern.firstMatch(localGenetId.trim());
          if (match != null) {
            final generation = int.tryParse(match.group(1) ?? '0') ?? 0;
            if (generation > maxGeneration) {
              maxGeneration = generation;
            }
          }
        }
      }

      // Return next generation number
      final nextGeneration = maxGeneration + 1;
      return '$normalizedBase-F$nextGeneration';
    } catch (e) {
      _logger.error('Failed to suggest next generation local ID', e);
      // Fallback to F1 if query fails
      return '$normalizedBase-F1';
    }
  }

  static String? normalizeLocalId(String? localGenetId) {
    if (localGenetId == null) return null;
    final trimmed = localGenetId.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'\s+'), '-').toLowerCase();
  }
}

/// Cached suggestion with expiry timestamp
class _CachedSuggestion {
  _CachedSuggestion(this.suggestedName, this.expiresAt);

  final String suggestedName;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
