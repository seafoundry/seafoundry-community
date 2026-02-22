// @tier: community
import 'package:meta/meta.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/provenance_formatter.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';

/// Provides taxonomy-backed provenance rows for genetics exports.
class ProvenanceExportRowSource {
  static final Map<_CacheKey, List<Map<String, dynamic>>> _rowCache = {};

  static Future<List<Map<String, dynamic>>> loadRows({
    required TaxonomyService taxonomyService,
    required OrganismKind organismKind,
    String? speciesId,
    bool forceRefresh = false,
  }) async {
    final key = _CacheKey(
      taxonomyService,
      organismKind,
      (speciesId ?? '').trim().toLowerCase(),
    );

    if (!forceRefresh) {
      final cached = _rowCache[key];
      if (cached != null) {
        return cached;
      }
    }

    final records = await taxonomyService.listProvenances(
      organismKind: organismKind,
      speciesId: speciesId,
    );

    final rows = records
        .map((record) {
          final metadataSummary = ProvenanceFormatter.summarizeMetadata(
            record.metadata,
          );
          return <String, dynamic>{
            'provenanceId': record.id,
            'displayName': record.displayName,
            'speciesId': record.speciesId,
            'provenanceKind': record.provenanceKind.name,
            'siteId': record.siteId ?? '',
            'parentProvenanceId': record.parentProvenanceId ?? '',
            'aliases': record.aliasLabels.join('; '),
            'metadata': metadataSummary,
            'metadataRaw': record.metadata,
          };
        })
        .toList(growable: false);

    _rowCache[key] = rows;
    return rows;
  }

  @visibleForTesting
  static void clearCache() => _rowCache.clear();
}

class _CacheKey {
  _CacheKey(TaxonomyService service, this.organismKind, this.speciesId)
    : _serviceHash = identityHashCode(service);

  final int _serviceHash;
  final OrganismKind organismKind;
  final String speciesId;

  @override
  bool operator ==(Object other) {
    return other is _CacheKey &&
        other._serviceHash == _serviceHash &&
        other.organismKind == organismKind &&
        other.speciesId == speciesId;
  }

  @override
  int get hashCode => Object.hash(_serviceHash, organismKind, speciesId);
}
