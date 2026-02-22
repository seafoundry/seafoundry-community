// @tier: community
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/local_id_matcher.dart';

/// Service for detecting conflicts during CSV import.
///
/// Validates import rows against existing data and other rows in the same file
/// to catch conflicts before committing changes.
class ConflictDetector {
  ConflictDetector._();

  /// Detects intra-file duplicate rows (B1 conflict).
  ///
  /// Returns conflicts for any rows that have the same normalized localId
  /// as another row in the file (second and subsequent occurrences are flagged).
  static List<ImportConflict> detectIntraFileDuplicates(
    List<Map<String, String>> rows,
    String localIdKey,
  ) {
    final conflicts = <ImportConflict>[];
    final seenIds = <String, int>{}; // normalized ID -> first row number

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2; // Account for header row
      final localId = row[localIdKey]?.trim() ?? '';

      if (localId.isEmpty) continue;

      final normalized = LocalIdMatcher.normalize(localId);
      if (seenIds.containsKey(normalized)) {
        conflicts.add(
          ImportConflict(
            type: ConflictType.intraFileDuplicate,
            rowNumber: rowNum,
            localId: localId,
            message:
                'Duplicate local ID "$localId" - first occurrence at row ${seenIds[normalized]}',
          ),
        );
      } else {
        seenIds[normalized] = rowNum;
      }
    }

    return conflicts;
  }

  /// Detects conflicts between import rows and existing records.
  ///
  /// [rows] - Import rows to check
  /// [localIdKey] - Key in the row map for the local ID
  /// [speciesIdKey] - Key in the row map for the species ID (optional)
  /// [provenanceIdKey] - Key in the row map for the provenance ID (optional)
  /// [existingRecords] - List of existing records to check against
  /// [getLocalId] - Function to extract localId from an existing record
  /// [getSpeciesId] - Function to extract speciesId from an existing record
  /// [getProvenanceId] - Function to extract provenanceId from an existing record
  static List<ImportConflict> detectDatabaseConflicts<T>({
    required List<Map<String, String>> rows,
    required String localIdKey,
    String? speciesIdKey,
    String? provenanceIdKey,
    required List<T> existingRecords,
    required String Function(T) getLocalId,
    String Function(T)? getSpeciesId,
    String Function(T)? getProvenanceId,
  }) {
    final conflicts = <ImportConflict>[];

    // Build lookup map of existing records by normalized localId
    final existingByLocalId = LocalIdMatcher.buildLookupMap(
      existingRecords,
      getLocalId,
    );

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2; // Account for header row
      final localId = row[localIdKey]?.trim() ?? '';

      if (localId.isEmpty) continue;

      final normalized = LocalIdMatcher.normalize(localId);
      final existing = existingByLocalId[normalized];

      if (existing == null) continue; // No conflict - new record

      // Check for species mismatch (A1)
      if (speciesIdKey != null && getSpeciesId != null) {
        final importSpeciesId = row[speciesIdKey]?.trim() ?? '';
        final existingSpeciesId = getSpeciesId(existing);

        if (importSpeciesId.isNotEmpty &&
            existingSpeciesId.isNotEmpty &&
            LocalIdMatcher.normalize(importSpeciesId) !=
                LocalIdMatcher.normalize(existingSpeciesId)) {
          conflicts.add(
            ImportConflict(
              type: ConflictType.speciesMismatch,
              rowNumber: rowNum,
              localId: localId,
              message:
                  'Species mismatch: import has "$importSpeciesId" but existing record has "$existingSpeciesId"',
              existingValue: existingSpeciesId,
              importValue: importSpeciesId,
            ),
          );
          continue; // Don't check for other conflicts on this row
        }
      }

      // Check for provenance mismatch (A2)
      if (provenanceIdKey != null && getProvenanceId != null) {
        final importProvenanceId = row[provenanceIdKey]?.trim() ?? '';
        final existingProvenanceId = getProvenanceId(existing);

        if (importProvenanceId.isNotEmpty &&
            existingProvenanceId.isNotEmpty &&
            LocalIdMatcher.normalize(importProvenanceId) !=
                LocalIdMatcher.normalize(existingProvenanceId)) {
          conflicts.add(
            ImportConflict(
              type: ConflictType.provenanceMismatch,
              rowNumber: rowNum,
              localId: localId,
              message:
                  'Provenance mismatch: import has "$importProvenanceId" but existing record has "$existingProvenanceId"',
              existingValue: existingProvenanceId,
              importValue: importProvenanceId,
            ),
          );
          continue;
        }
      }

      // If we get here with matching species/provenance, it's a duplicate (A3)
      // This is a skip, not an error
      conflicts.add(
        ImportConflict(
          type: ConflictType.duplicate,
          rowNumber: rowNum,
          localId: localId,
          message: 'Record with local ID "$localId" already exists - skipping',
        ),
      );
    }

    return conflicts;
  }

  /// Validates parent references exist (C1 conflict).
  ///
  /// Returns conflicts for any rows that reference a parent ID that doesn't exist.
  static List<ImportConflict> detectMissingParents<T>({
    required List<Map<String, String>> rows,
    required String parentIdKey,
    required List<T> existingParents,
    required String Function(T) getParentId,
    String fieldName = 'parentId',
  }) {
    final conflicts = <ImportConflict>[];

    // Build lookup map of existing parents by normalized ID
    final existingParentIds = <String>{};
    for (final parent in existingParents) {
      final id = getParentId(parent);
      if (id.isNotEmpty) {
        existingParentIds.add(LocalIdMatcher.normalize(id));
      }
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2; // Account for header row
      final parentId = row[parentIdKey]?.trim() ?? '';

      if (parentId.isEmpty) continue; // No parent reference

      final normalized = LocalIdMatcher.normalize(parentId);
      if (!existingParentIds.contains(normalized)) {
        conflicts.add(
          ImportConflict(
            type: ConflictType.missingParent,
            rowNumber: rowNum,
            localId: parentId,
            message: 'Referenced $fieldName "$parentId" does not exist',
          ),
        );
      }
    }

    return conflicts;
  }

  /// Converts a list of conflicts to CSVImportErrors.
  static List<CSVImportError> conflictsToErrors(List<ImportConflict> conflicts) {
    return conflicts.map((c) => c.toImportError()).toList(growable: false);
  }

  /// Filters conflicts to only blocking ones.
  static List<ImportConflict> blockingConflicts(List<ImportConflict> conflicts) {
    return conflicts.where((c) => c.type.isBlocking).toList(growable: false);
  }

  /// Counts conflicts by type.
  static Map<ConflictType, int> countByType(List<ImportConflict> conflicts) {
    final counts = <ConflictType, int>{};
    for (final conflict in conflicts) {
      counts[conflict.type] = (counts[conflict.type] ?? 0) + 1;
    }
    return counts;
  }
}
