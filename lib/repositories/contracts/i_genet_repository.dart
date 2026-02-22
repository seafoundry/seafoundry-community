// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';

/// Interface contract for GenetRepository.
///
/// This mirrors the concrete repository API used in production so concrete
/// repositories can implement it and tests can mock it.
abstract class IGenetRepository {
  /// Stream all genets for the organization.
  Stream<List<Genet>> get streamAll;

  /// Stream genets for a URL path using client-side filtering.
  Stream<List<Genet>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Stream a single genet for a URL path.
  Stream<Genet?> streamRecordForUrlPath(String urlPath);

  /// Get all genets.
  Future<List<Genet>> getAll();

  /// Get a single genet by ID.
  Future<Genet?> getRecordForId(String id);

  /// Searches for genets whose name starts with the given prefix.
  /// Returns up to [limit] matching genets sorted by name (case-insensitive).
  /// Excludes archived records by default.
  Future<List<Genet>> searchGenetsByNamePrefix(
    String prefix, {
    int limit = 10,
    bool includeArchived = false,
  });

  /// Get genets for a URL path.
  Future<List<Genet>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Create a genet via standard inventory workflow.
  Future<Genet> createRecord(
    Genet partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  });

  /// Move a genet between parents.
  Future<Genet> moveRecord({
    required Genet record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Update an existing genet.
  Future<void> updateRecord(Genet record, {WriteBatch? batch});

  /// Delete a genet.
  Future<void> deleteRecord(Genet record, {WriteBatch? batch});

  /// Create a genet with domain-specific logic.
  /// [inheritedProvenanceId] bypasses PID generation and uniqueness checks
  /// when the genet is linked to an existing crosswalk provenance record.
  Future<Genet> createGenet(Genet genet, {String? inheritedProvenanceId});

  /// Update a genet with correction events and alias handling.
  Future<Genet> updateGenet({
    required Genet original,
    required Genet updated,
    Map<String, dynamic> changes = const {},
  });

  /// Link aliases to an existing genet record.
  Future<Genet> shareAliasesWithExistingRecord({
    required Genet target,
    required String existingRecordId,
    required List<OrganismAlias> aliases,
  });

  /// Backfill provenance ID for a genet that currently has an auto-generated one.
  /// Returns the updated genet if backfill was applied, or the original if skipped.
  Future<Genet> backfillProvenanceId({
    required String genetId,
    required String provenanceId,
    bool force = false,
  });

  /// Archive a genet record.
  Future<void> archiveGenet(
    String genetId, {
    PopulationLossReason? lossReason,
    String? comment,
  });

  /// Restore a genet record.
  Future<void> restoreGenet(String genetId);

  /// Suggests the next available Local ID for a given species.
  Future<String> suggestNextLocalId(String speciesId);

  /// Check if a genet name (local ID) is unique within the organization.
  Future<bool> isGenetNameUnique({
    required String name,
    String? excludeRecordId,
  });

  /// Suggests the next generation local ID for graduation/spawning workflows.
  ///
  /// Given a base local ID (e.g., `APAL-COH-001` for a cohort or `APAL-001` for
  /// a parent organism), finds all existing IDs matching `{baseLocalId}-F\d+`
  /// and returns the next available generation counter.
  ///
  /// Use cases:
  /// - **Graduation**: When graduating an individual from cohort `APAL-COH-001`,
  ///   generates `APAL-COH-001-F1`, `APAL-COH-001-F2`, etc.
  /// - **Spawning**: When spawning gametes from parent `APAL-001`,
  ///   generates `APAL-001-F1`, `APAL-001-F2`, etc.
  ///
  /// The generation counter (`F1`, `F2`, etc.) represents lineage tree depth.
  Future<String> suggestNextGenerationLocalId(String baseLocalId);

  /// Counts how many organism records are linked to a specific genet.
  ///
  /// Returns 0 if the genet doesn't exist or has no linked organisms.
  /// Used by the LocalID edit scope dialog to determine if a genet-wide
  /// update should be offered.
  Future<int> countOrganismRecordsForGenet(String genetId);
}
