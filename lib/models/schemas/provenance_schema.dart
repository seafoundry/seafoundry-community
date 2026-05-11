import 'package:seafoundry_app/models/models.dart';

/// Typed facade for provenance metadata stored on [ProvenanceRecord].
/// Replaces legacy Genet-specific helpers with a neutral schema.
extension ProvenanceSchema on ProvenanceRecord {
  // Map these properties from ProvenanceRecord fields and metadata:
  String get name => displayName;

  String get urlPath => _str('urlPath').isNotEmpty ? _str('urlPath') : 'provenance/$id';
  String get internalPath => _str('internalPath').isNotEmpty ? _str('internalPath') : id;
  String get slug => _str('slug').isNotEmpty ? _str('slug') : id;
  String get provenanceTypeIdLegacy => _str('provenanceTypeId');
  String? get clonalId => _strOrNull('clonalId');
  String? get accessionNumber => _strOrNull('accessionNumber');
  String? get notes => _strOrNull('notes');
  Map<String, dynamic>? get provenance => metadata['provenance'] as Map<String, dynamic>?;
  List<String> get parentGameteIds => _strList('parentGameteIds');
  String? get parentCohortId => _strOrNull('parentCohortId');
  String? get donorGenotypeId => _strOrNull('donorGenotypeId');
  List<String> get damGameteIds => _strList('damGameteIds');
  List<String> get sireGameteIds => _strList('sireGameteIds');
  DateTime? get crossDate => _date('crossDate');
  bool get readyForOutplant => metadata['readyForOutplant'] == true;
  bool get heatTested => metadata['heatTested'] == true;
  bool get diseaseTested => metadata['diseaseTested'] == true;
  String? get heatTestingComment => _strOrNull('heatTestingComment');
  String? get diseaseTestingComment => _strOrNull('diseaseTestingComment');
  String get createdAt => _str('createdAt');
  String get updatedAt => _str('updatedAt');

  /// Whether the provenance record is archived
  bool get isArchived => metadata['archived'] == true;

  /// Timestamp when record was archived
  String? get archivedAt => _strOrNull('archivedAt');

  /// ID of user who created this record
  String? get createdById => _strOrNull('createdById');

  /// Life stage identifier
  String? get lifeStageId => _strOrNull('lifeStageId') ?? _strOrNull('lifeStage');

  /// Provenance type as raw string ID
  String? get provenanceTypeId => _strOrNull('provenanceTypeId') ?? _strOrNull('provenanceType');

  /// Get provenance type from metadata or derive from provenanceKind
  ProvenanceType get provenanceType {
    final typeId = _strOrNull('provenanceTypeId');
    if (typeId != null) {
      final parsed = ProvenanceTypeX.tryParse(typeId);
      if (parsed != null) return parsed;
    }
    // Fallback: derive from provenanceKind
    return ProvenanceTypeX.fromLegacyKind(provenanceKind) ?? ProvenanceType.wild;
  }

  // aliases support
  List<Map<String, dynamic>> get aliases {
    final raw = metadata['aliases'];
    if (raw is List) return List<Map<String, dynamic>>.from(raw.whereType<Map<String, dynamic>>());
    return const [];
  }

  List<OrganismAlias> get aliasEntries => OrganismAlias.listFromJson(aliases);

  // ---------------------------------------------------------------------------
  // Completeness Tracking
  // ---------------------------------------------------------------------------

  /// Completeness score from 0.0 to 1.0 for provenance/gamete metadata.
  double get completenessScore => _computeCompleteness().score;

  /// Returns list of incomplete provenance/gamete field names for display.
  List<String> get incompleteFields => _computeCompleteness().missingFields;

  /// Whether all provenance/gamete fields are filled.
  bool get isComplete => incompleteFields.isEmpty;

  // Helper methods
  String _str(String key) => (metadata[key]?.toString() ?? '').trim();
  String? _strOrNull(String key) {
    final v = metadata[key]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }
  List<String> _strList(String key) {
    final raw = metadata[key];
    if (raw is List) return List<String>.from(raw.whereType<String>());
    return const [];
  }
  DateTime? _date(String key) {
    final v = metadata[key];
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  _ProvenanceCompleteness _computeCompleteness() {
    final selection = ProvenanceLifeStageSelection.fromProvenanceRecord(this);
    final provenanceType = selection.provenanceType;
    final lifeStage = selection.lifeStage;
    final missing = <String>[];
    var total = 0;

    void requireField(String label, bool isComplete) {
      total += 1;
      if (!isComplete) {
        missing.add(label);
      }
    }

    if (lifeStage == LifeStage.gamete) {
      requireField('Donor genotype', _hasMeaningfulValue(donorGenotypeId));
      requireField(
        'Gamete sex',
        _hasProvenanceValue(const ['gamete_sex', 'gameteSex']),
      );
      requireField(
        'Spawn date',
        _hasProvenanceValue(const ['spawn_date', 'spawnDate']),
      );
      return _ProvenanceCompleteness(_score(total, missing.length), missing);
    }

    switch (provenanceType) {
      case ProvenanceType.wild:
        requireField(
          'Collection method',
          _hasProvenanceValue(
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
          _hasProvenanceValue(const ['collection_date', 'collectionDate']),
        );
        break;
      case ProvenanceType.transfer:
        requireField(
          'Source organization',
          _hasMetadataValue(
                const ['sourceOrganizationId', 'sourceOrganization'],
              ) ||
              _hasProvenanceValue(
                const [
                  'sending_organization',
                  'sendingOrganization',
                  'sourceOrganization',
                  'sourceOrganizationId',
                ],
              ),
        );
        requireField(
          'Source provenance ID',
          _hasMetadataValue(
                const ['sourceProvenanceId', 'provenanceId'],
              ) ||
              _hasProvenanceValue(const ['sourceProvenanceId']) ||
              _hasMeaningfulValue(donorGenotypeId),
        );
        break;
      case ProvenanceType.cohort:
      case ProvenanceType.graduatedIndividual:
        // Nursery-reared batches and graduated individuals use universal baseline.
        break;
      case ProvenanceType.unknown:
        requireField('Provenance type', false);
        break;
    }

    return _ProvenanceCompleteness(_score(total, missing.length), missing);
  }

  bool _hasProvenanceValue(List<String> keys) {
    final prov = provenance;
    if (prov == null || prov.isEmpty) return false;
    for (final key in keys) {
      if (_hasMeaningfulValue(prov[key])) return true;
    }
    return false;
  }

  bool _hasMetadataValue(List<String> keys) {
    if (metadata.isEmpty) return false;
    for (final key in keys) {
      if (_hasMeaningfulValue(metadata[key])) return true;
    }
    return false;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return false;
      final normalized = trimmed.toLowerCase();
      if (normalized == 'unknown' ||
          normalized == 'n/a' ||
          normalized == 'na') {
        return false;
      }
      return true;
    }
    if (value is Iterable) {
      for (final entry in value) {
        if (_hasMeaningfulValue(entry)) return true;
      }
      return false;
    }
    return true;
  }

  double _score(int total, int missingCount) {
    if (total <= 0) return 0.0;
    final completeCount = total - missingCount;
    return completeCount / total;
  }
}

class _ProvenanceCompleteness {
  const _ProvenanceCompleteness(this.score, this.missingFields);

  final double score;
  final List<String> missingFields;
}
