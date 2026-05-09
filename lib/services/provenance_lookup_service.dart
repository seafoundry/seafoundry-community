// @tier: community
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/provenance_crosswalk_service.dart';

/// Facade service that searches the community crosswalk for alias prefix
/// matches and returns typed [ProvenanceSuggestion] results.
///
/// This sits between the UI (BLoC layer) and the raw
/// [ProvenanceCrosswalkService], handling normalization, deduplication,
/// and sorting so callers get a ready-to-display suggestion list.
///
/// Caching is delegated to [ProvenanceCrosswalkService] (LRU, max 1000).
/// This service is stateless and safe to share across BLoCs.
class ProvenanceLookupService {
  ProvenanceLookupService({
    required ProvenanceCrosswalkService crosswalkService,
    LoggingService? logger,
  })  : _crosswalkService = crosswalkService,
        _logger = logger ?? LoggingService.instance;

  final ProvenanceCrosswalkService _crosswalkService;
  final LoggingService _logger;

  static final _nonAlphanumeric = RegExp(r'[^A-Z0-9]');

  /// Search the crosswalk for aliases whose normalized form starts with
  /// [prefix]. Returns deduplicated, sorted [ProvenanceSuggestion] results.
  ///
  /// [aliasType] lets the BLoC override the suggestion's type based on
  /// which input field the user is typing in (e.g., clonalId vs accession).
  ///
  /// Note: [limit] caps the final output list. The crosswalk query may fetch
  /// more alias documents to ensure enough unique records are returned.
  Future<List<ProvenanceSuggestion>> searchAliases({
    required String prefix,
    required String speciesCode,
    int limit = 15,
    ProvenanceAliasType? aliasType,
  }) async {
    final normalizedPrefix = _normalize(prefix);
    try {
      _logger.info(
        'ProvenanceSearch: Searching prefix="$prefix" (norm="$normalizedPrefix"), '
        'speciesCode="$speciesCode"',
      );

      // Request more from crosswalk than our output limit to account for
      // multiple aliases per record expanding into many suggestions.
      final records = await _crosswalkService.searchByAliasPrefix(
        prefix,
        speciesCode: speciesCode, // Enforce species filtering
        limit: limit * 3,
      );
      
      _logger.info('ProvenanceSearch: Found ${records.length} records.');

      final suggestions = <ProvenanceSuggestion>[];
      final seen = <String>{};

      for (final record in records) {
        final matchingAliases = record.aliases.where((alias) {
          if (!_normalize(alias.id).startsWith(normalizedPrefix)) return false;
          final parsedType = ProvenanceAliasType.fromString(alias.orgType);
          if (!_matchesAliasType(parsedType, aliasType)) return false;
          final enforceHumanReadable =
              aliasType == null ||
              aliasType == ProvenanceAliasType.accessionNumber;
          if (enforceHumanReadable &&
              !ClonalIdDisplayService.isHumanReadable(alias.id)) {
            return false;
          }
          return true;
        });

        for (final alias in matchingAliases) {
          final effectiveType =
              aliasType ?? ProvenanceAliasType.fromString(alias.orgType);
          final dedupeKey =
              '${record.provenanceId}|${alias.id}|${effectiveType.name}';
          if (!seen.add(dedupeKey)) continue;

          // Collect up to 3 other aliases for context (excluding the one being suggested)
          final otherAliases = record.aliases
              .where((a) => a.id != alias.id)
              .map((a) => a.id)
              .take(3)
              .toList();

          // Extract resolved fields from the record's aliases
          final resolved = _extractResolvedFields(record);

          suggestions.add(
            ProvenanceSuggestion.fromRecordAlias(
              provenanceId: record.provenanceId,
              speciesCode: record.speciesCode,
              aliasId: alias.id,
              aliasOrg: alias.org,
              aliasOrgType: alias.orgType,
              aliasTypeOverride: aliasType,
              otherAliases: otherAliases,
              masterClonalId: record.masterClonalId,
              resolvedClonalId: resolved.clonalId,
              resolvedAccessionNumber: resolved.accessionNumber,
              resolvedAlias: resolved.alias,
            ),
          );
        }
      }

      suggestions.sort((a, b) {
        final aExact = _normalize(a.aliasValue) == normalizedPrefix;
        final bExact = _normalize(b.aliasValue) == normalizedPrefix;
        if (aExact != bExact) return aExact ? -1 : 1;
        return a.aliasValue.compareTo(b.aliasValue);
      });

      return suggestions.take(limit).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'ProvenanceLookupService.searchAliases failed for '
        'prefix="$prefix", speciesCode="$speciesCode"',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Pass-through to get the full provenance record (e.g., for finding complementary aliases).
  Future<CommunityProvenanceRecord?> getProvenanceRecord(String provenanceId) {
    return _crosswalkService.getProvenanceRecord(provenanceId);
  }

  /// Normalize a string for comparison: uppercase, alphanumeric only.
  /// Matches the crosswalk's `_normalizeAlias` normalization.
  static String _normalize(String input) {
    return input.trim().toUpperCase().replaceAll(_nonAlphanumeric, '');
  }

  static bool _matchesAliasType(
    ProvenanceAliasType parsedType,
    ProvenanceAliasType? requestedType,
  ) {
    if (requestedType == null) return true;
    if (parsedType == requestedType) return true;
    if (requestedType == ProvenanceAliasType.accessionNumber &&
        parsedType == ProvenanceAliasType.csr) {
      return true;
    }
    return false;
  }

  /// Extracts resolved fields (clonalId, accessionNumber, alias) from a record's
  /// aliases. Returns a record with the first match of each type.
  static ({String? clonalId, String? accessionNumber, String? alias})
      _extractResolvedFields(CommunityProvenanceRecord record) {
    String? clonalId;
    String? accessionNumber;
    String? alias;

    for (final a in record.aliases) {
      // Skip UUID-like values — they are database IDs, not human-readable
      if (ClonalIdDisplayService.isUuid(a.id)) continue;

      final type = ProvenanceAliasType.fromString(a.orgType);
      switch (type) {
        case ProvenanceAliasType.clonalId:
        case ProvenanceAliasType.internalId:
        case ProvenanceAliasType.local:
          clonalId ??= a.id;
          break;
        case ProvenanceAliasType.accessionNumber:
        case ProvenanceAliasType.csr:
          accessionNumber ??= a.id;
          break;
        case ProvenanceAliasType.universalId:
        case ProvenanceAliasType.partnerId:
        case ProvenanceAliasType.transfer:
        case ProvenanceAliasType.primary:
        case ProvenanceAliasType.legacy:
          alias ??= a.id;
          break;
        default:
          // Other types - use as alias fallback if we don't have one yet
          alias ??= a.id;
      }
    }

    // Fall back to masterClonalId if no clonalId found in aliases
    clonalId ??= record.masterClonalId;

    return (clonalId: clonalId, accessionNumber: accessionNumber, alias: alias);
  }

  /// Search the crosswalk for Provenance IDs (PIDs) by prefix.
  /// Returns [ProvenanceSuggestion] results with PID as the alias value.
  Future<List<ProvenanceSuggestion>> searchProvenanceIds({
    required String prefix,
    required String speciesCode,
    int limit = 15,
  }) async {
    final normalizedPrefix = prefix.trim().toUpperCase();

    try {
      _logger.info(
        'ProvenanceSearch: Searching PID prefix="$prefix" (norm="$normalizedPrefix"), '
        'speciesCode="$speciesCode"',
      );

      final records = await _crosswalkService.searchByProvenanceIdPrefix(
        normalizedPrefix,
        speciesCode: speciesCode,
        limit: limit,
      );

      if (records.isEmpty) return [];

      final suggestions = records.map((record) {
        final otherAliases = record.aliases
            .map((alias) => alias.id)
            .where((id) => id != record.provenanceId)
            .take(3)
            .toList();

        // Extract resolved fields from the record's aliases
        final resolved = _extractResolvedFields(record);

        return ProvenanceSuggestion(
          provenanceId: record.provenanceId,
          aliasValue: record.provenanceId,
          aliasType: ProvenanceAliasType.primary,
          speciesCode: record.speciesCode,
          organizationName: null,
          otherAliases: otherAliases,
          masterClonalId: record.masterClonalId,
          resolvedClonalId: resolved.clonalId,
          resolvedAccessionNumber: resolved.accessionNumber,
          resolvedAlias: resolved.alias,
        );
      }).toList();

      suggestions.sort((a, b) => a.aliasValue.compareTo(b.aliasValue));
      return suggestions.take(limit).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'ProvenanceLookupService.searchProvenanceIds failed for '
        'prefix="$prefix", speciesCode="$speciesCode"',
        e,
        stackTrace,
      );
      return [];
    }
  }
}
