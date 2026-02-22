// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Result of the organism creation wizard.
///
/// Wraps the created [OrganismRecord] with an optional [inheritedProvenanceId]
/// when a crosswalk-matched PID was selected during creation. The caller must
/// pass [inheritedProvenanceId] to `GenetRepository.createGenet()` to inherit
/// the PID instead of auto-generating one.
class OrganismCreationResult {
  const OrganismCreationResult({
    required this.record,
    this.inheritedProvenanceId,
    this.clonalValue,
    this.accessionValue,
    this.provenanceMetadata,
  });

  final OrganismRecord record;

  /// The resolved PID from provenance search, if any.
  /// Pass to `GenetRepository.createGenet(inheritedProvenanceId:)`.
  final String? inheritedProvenanceId;

  /// Optional alias fields captured during creation for genet setup.
  final String? clonalValue;
  final String? accessionValue;

  /// Optional provenance metadata captured during creation (e.g. collection details).
  /// Used to seed genet provenance when creating a new genet.
  final Map<String, dynamic>? provenanceMetadata;
}
