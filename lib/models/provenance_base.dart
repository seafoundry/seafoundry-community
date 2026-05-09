import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';

/// Shared interface for provenance-aware models (genets, broodstock lots, donor
/// meadows, etc.). Older code may still reference “lineage”; treat provenance
/// and lineage as synonyms while migrations complete.
abstract class ProvenanceBase {
  /// Record ID (distinct from provenance identifiers).
  String get id;
  /// Display label for the record (often the local ID).
  String get displayName;
  /// Organization-scoped identifier for the genet/provenance record (localID).
  String? get localGenetId;
  /// Canonical provenance identifier (PID) for cross-org comparisons.
  String? get provenanceId;
  /// High-level organism category for this provenance record.
  OrganismKind get organismKind;
  /// Coarse provenance bucket derived from provenance type.
  ProvenanceKind get provenanceKind;
  /// Species identifier for this provenance record.
  String get speciesId;
  /// Parent provenance ID for cohorts/gametes when applicable.
  String? get parentProvenanceId;
  /// Site context for wild collection records, when available.
  String? get siteId;
  /// Alternate identifiers (aliases) associated with this record.
  List<String> get aliasLabels;
  /// Raw metadata payload.
  Map<String, dynamic> get metadata;
}

extension ProvenanceBaseX on ProvenanceBase {
  String get provenanceKindId => provenanceKind.name;
}
