// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/provenance_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Result of a genet merge operation.
class GenetMergeResult {
  const GenetMergeResult({
    required this.persistedTarget,
    required this.archivedSourceId,
    required this.reassignedCoralCount,
  });

  final ProvenanceRecord persistedTarget;
  final String archivedSourceId;
  final int reassignedCoralCount;
}

/// Service encapsulating genet merge business logic.
///
/// Handles:
/// - Loading coral counts for a genet
/// - Calculating merged alias counts
/// - Executing the merge operation (alias transfer, coral reassignment, archival)
class GenetMergeService {
  const GenetMergeService({
    required ProvenanceRepository provenanceRepository,
    required OrganismRecordRepository organismRecordRepository,
  })  : _provenanceRepository = provenanceRepository,
        _organismRecordRepository = organismRecordRepository;

  final ProvenanceRepository _provenanceRepository;
  final OrganismRecordRepository _organismRecordRepository;

  /// Loads the count of corals linked to the given genet ID.
  Future<int> loadCoralCount(String genetId) async {
    try {
      final organisms = await _organismRecordRepository.getAll();
      return organisms
          .where(
            (o) =>
                o.organismKind == OrganismKind.coral &&
                GenetIdResolver.resolve(o) == genetId,
          )
          .length;
    } catch (error) {
      LoggingService.instance.error('Failed to load coral count', error);
      return 0;
    }
  }

  /// Calculates the number of unique aliases after merging two genets.
  int calculateMergedAliasCount({
    required List<OrganismAlias> targetAliases,
    required List<OrganismAlias> sourceAliases,
  }) {
    final merged = _dedupeAliases([...targetAliases, ...sourceAliases]);
    return merged.length;
  }

  /// Executes the merge operation.
  ///
  /// 1. Clears aliases from source (to avoid uniqueness conflicts)
  /// 2. Merges aliases and optional fields into target
  /// 3. Reassigns corals from source to target (atomic batch write)
  /// 4. Archives the source genet
  ///
  /// Throws on failure. If alias clearing succeeded but later steps fail,
  /// the caller should attempt to restore source aliases.
  Future<GenetMergeResult> executeMerge({
    required ProvenanceRecord target,
    required ProvenanceRecord source,
  }) async {
    final sourceAliases = source.aliasEntries;
    final targetAliases = target.aliasEntries;
    final mergedAliases = _dedupeAliases([...targetAliases, ...sourceAliases]);

    // Step 1: Clear aliases from source to avoid uniqueness conflicts
    if (sourceAliases.isNotEmpty) {
      final clearedMetadata = Map<String, dynamic>.from(source.metadata);
      clearedMetadata['aliases'] = const <Map<String, dynamic>>[];
      final clearedSource = source.copyWith(
        aliasLabels: const [],
        metadata: clearedMetadata,
      );
      await _provenanceRepository.updateProvenanceRecord(clearedSource);
    }

    // Step 2: Merge aliases and optional fields into target
    final targetMetadata = Map<String, dynamic>.from(target.metadata);
    targetMetadata['aliases'] =
        mergedAliases.map((alias) => alias.toJson()).toList();

    // Merge optional fields - prefer target's non-empty values
    if ((target.clonalId?.isEmpty ?? true) &&
        source.clonalId?.isNotEmpty == true) {
      targetMetadata['clonalId'] = source.clonalId;
    }
    if ((target.accessionNumber?.isEmpty ?? true) &&
        source.accessionNumber?.isNotEmpty == true) {
      targetMetadata['accessionNumber'] = source.accessionNumber;
    }
    if ((target.notes?.isEmpty ?? true) && source.notes?.isNotEmpty == true) {
      targetMetadata['notes'] = source.notes;
    }

    final updatedTarget = target.copyWith(
      aliasLabels: mergedAliases.map((a) => a.label ?? a.value).toList(),
      metadata: targetMetadata,
    );
    final persistedTarget =
        await _provenanceRepository.updateProvenanceRecord(updatedTarget);

    // Step 3: Reassign corals from source to target (atomic batch write)
    final reassigned = await _reassignCorals(
      fromGenetId: source.id,
      toGenetId: persistedTarget.id,
    );

    // Step 4: Archive the source genet
    await _provenanceRepository.archiveGenet(
      source.id,
      comment: 'Merged into ${target.displayName}',
    );

    return GenetMergeResult(
      persistedTarget: persistedTarget,
      archivedSourceId: source.id,
      reassignedCoralCount: reassigned,
    );
  }

  /// Attempts to restore aliases on a source record after a failed merge.
  Future<void> restoreSourceAliases(ProvenanceRecord source) async {
    try {
      final restoredMetadata = Map<String, dynamic>.from(source.metadata);
      restoredMetadata['aliases'] =
          source.aliasEntries.map((a) => a.toJson()).toList();
      final restored = source.copyWith(
        aliasLabels:
            source.aliasEntries.map((a) => a.label ?? a.value).toList(),
        metadata: restoredMetadata,
      );
      await _provenanceRepository.updateProvenanceRecord(restored);
    } catch (_) {
      // Log but do not block UI; failure already surfaced.
    }
  }

  Future<int> _reassignCorals({
    required String fromGenetId,
    required String toGenetId,
  }) async {
    try {
      final organisms = await _organismRecordRepository.getAll();
      final coralsToReassign = organisms
          .where(
            (o) =>
                o.organismKind == OrganismKind.coral &&
                GenetIdResolver.resolve(o) == fromGenetId,
          )
          .toList();

      if (coralsToReassign.isEmpty) return 0;

      // Use batch write for atomicity - all corals reassigned or none
      final batch = _organismRecordRepository.firestore.batch();

      for (final organism in coralsToReassign) {
        final updatedForeignKeys = Map<String, ForeignKeyReference>.from(
          organism.foreignKeys,
        );
        updatedForeignKeys['genetId'] = ForeignKeyReference(id: toGenetId);

        final updated = organism.copyWith(foreignKeys: updatedForeignKeys);
        final docRef =
            _organismRecordRepository.collectionRef.doc(organism.id);
        batch.update(docRef, updated.toJson());
      }

      await batch.commit();
      return coralsToReassign.length;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to reassign corals during merge',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  List<OrganismAlias> _dedupeAliases(List<OrganismAlias> aliases) {
    final seen = <String>{};
    final result = <OrganismAlias>[];
    for (final alias in aliases) {
      final key =
          '${alias.sourceSystem.trim().toLowerCase()}::${alias.value.trim().toLowerCase()}';
      if (seen.add(key)) {
        result.add(alias);
      }
    }
    return result;
  }
}
