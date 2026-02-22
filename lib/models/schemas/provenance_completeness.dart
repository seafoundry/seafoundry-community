// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Result of a provenance completeness calculation.
class ProvenanceCompletenessResult {
  const ProvenanceCompletenessResult(this.score, this.missingFields);

  final double score;
  final List<String> missingFields;
}

/// Shared completeness calculation for provenance records.
///
/// Both [Genet] and [ProvenanceSchema] delegate to this function.
/// Both callers resolve provenanceType and lifeStage via
/// [ProvenanceLifeStageSelection], which uses a unified resolution chain:
/// 1. Parse explicit provenanceTypeId
/// 2. Fall back via fromLegacyKind(provenanceKind)
/// 3. Fall back to [ProvenanceType.unknown]
ProvenanceCompletenessResult computeProvenanceCompleteness({
  required ProvenanceType provenanceType,
  required LifeStage lifeStage,
  required String? donorGenotypeId,
  required String? parentCohortId,
  required DateTime? crossDate,
  required List<String> damGameteIds,
  required List<String> sireGameteIds,
  required List<String> parentGameteIds,
  required Map<String, dynamic>? provenance,
  required Map<String, dynamic> metadata,
  String? provenanceId,
}) {
  final missing = <String>[];
  var total = 0;

  void requireField(String label, bool isComplete) {
    total += 1;
    if (!isComplete) {
      missing.add(label);
    }
  }

  // Universal baseline: is the provenance type identified?
  requireField(
    'Provenance type',
    provenanceType != ProvenanceType.unknown,
  );

  if (lifeStage == LifeStage.gamete) {
    requireField('Donor genotype', hasMeaningfulValue(donorGenotypeId));
    requireField(
      'Gamete sex',
      hasMapValue(provenance, const ['gamete_sex', 'gameteSex']),
    );
    requireField(
      'Spawn date',
      hasMapValue(provenance, const ['spawn_date', 'spawnDate']),
    );
    return ProvenanceCompletenessResult(
      _score(total, missing.length),
      missing,
    );
  }

  switch (provenanceType) {
    case ProvenanceType.wild:
      requireField(
        'Collection method',
        hasMapValue(
          provenance,
          const [
            'collection_method',
            'collectionMethod',
            'wild_method',
            'wildMethod',
          ],
        ),
      );
      requireField(
        'Collection date',
        hasMapValue(
          provenance,
          const ['collection_date', 'collectionDate'],
        ),
      );
      break;
    case ProvenanceType.sexualCohort:
      final parentCount =
          parentGameteIds.where(hasMeaningfulValue).length;
      final hasParentPair = parentCount >= 2;
      final hasDam = hasMeaningfulList(damGameteIds) || hasParentPair;
      final hasSire = hasMeaningfulList(sireGameteIds) || hasParentPair;
      requireField('Dam gamete linkage', hasDam);
      requireField('Sire gamete linkage', hasSire);
      requireField('Cross/spawn date', crossDate != null);
      break;
    case ProvenanceType.graduatedIndividual:
      requireField(
        'Parent cohort linkage',
        hasMeaningfulValue(parentCohortId),
      );
      break;
    case ProvenanceType.transfer:
      requireField(
        'Source organization',
        hasMapValue(
              metadata,
              const [
                'sourceOrganizationId',
                'sourceOrganization',
                'fromOrganizationId',
              ],
            ) ||
            hasMapValue(
              provenance,
              const [
                'sending_organization',
                'sendingOrganization',
                'sourceOrganization',
                'sourceOrganizationId',
                'fromOrganizationId',
              ],
            ),
      );
      requireField(
        'Source provenance ID',
        hasMeaningfulValue(provenanceId) ||
            hasMapValue(
              metadata,
              const ['sourceProvenanceId', 'provenanceId'],
            ) ||
            hasMapValue(
              provenance,
              const ['sourceProvenanceId'],
            ) ||
            hasMeaningfulValue(donorGenotypeId),
      );
      break;
    case ProvenanceType.unknown:
      // Handled by the universal baseline above.
      break;
  }

  return ProvenanceCompletenessResult(
    _score(total, missing.length),
    missing,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Whether [value] is non-null, non-empty, and not a placeholder.
bool hasMeaningfulValue(dynamic value) {
  if (value == null) return false;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final normalized = trimmed.toLowerCase();
    if (normalized == 'unknown' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        trimmed == Missing.string) {
      return false;
    }
    return true;
  }
  if (value is Iterable) {
    for (final entry in value) {
      if (hasMeaningfulValue(entry)) return true;
    }
    return false;
  }
  return true;
}

/// Whether any [keys] in the given [map] hold a meaningful value.
bool hasMapValue(Map<String, dynamic>? map, List<String> keys) {
  if (map == null || map.isEmpty) return false;
  for (final key in keys) {
    if (hasMeaningfulValue(map[key])) return true;
  }
  return false;
}

/// Whether [values] contains at least one meaningful entry.
bool hasMeaningfulList(List<String> values) {
  if (values.isEmpty) return false;
  return values.any(hasMeaningfulValue);
}

double _score(int total, int missingCount) {
  if (total <= 0) return 0.0;
  final completeCount = total - missingCount;
  return completeCount / total;
}
