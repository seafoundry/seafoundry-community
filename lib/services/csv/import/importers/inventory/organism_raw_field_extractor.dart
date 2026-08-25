
/// Extracted raw field values from a CSV row.
///
/// Contains all raw string values before type parsing and validation.
class OrganismRawFields {
  OrganismRawFields({
    required this.provenanceId,
    required this.organismId,
    required this.groupPath,
    required this.speciesIdRaw,
    required this.physicalFormIdRaw,
    required this.healthStatusIdRaw,
    required this.genetProvenanceId,
    required this.quantityStr,
    required this.populationValueRaw,
    required this.populationUnitRaw,
    required this.localGenetId,
    required this.notes,
    required this.lastEventAtRaw,
    required this.aliasesJson,
    required this.aliasesRaw,
    required this.genetProvenanceIdRaw,
    this.tagId,
  });

  final String provenanceId;
  final String organismId;
  final String groupPath;
  final String speciesIdRaw;
  final String physicalFormIdRaw;
  final String healthStatusIdRaw;
  final String genetProvenanceId;
  final String quantityStr;
  final String populationValueRaw;
  final String populationUnitRaw;
  final String localGenetId;
  final String? notes;
  final String lastEventAtRaw;
  final String? aliasesJson;
  final String? aliasesRaw;
  final String genetProvenanceIdRaw;
  String? tagId;

  /// Derives the record name from localGenetId if not already set.
  void deriveRecordNameIfEmpty() {
    if (tagId == null || tagId!.isEmpty) {
      tagId = localGenetId.isNotEmpty ? localGenetId : null;
    }
  }
}

/// Extracts raw field values from a CSV row map.
///
/// Pure function that handles column name variations and normalization.
class OrganismRawFieldExtractor {
  OrganismRawFieldExtractor._();

  /// Extracts all raw fields from a CSV row.
  static OrganismRawFields extract(Map<String, String> row) {
    final provenanceId = (row['provenanceId'] ?? '').trim();
    final organismId = (row['organismId'] ?? row['coralId'] ?? '').trim();
    final groupPath = (row['groupId'] ?? '').trim();
    final speciesIdRaw = (row['speciesId'] ?? '').trim();
    final physicalFormId =
        (row['physicalFormId'] ?? row['physicalForm'] ?? '').trim();
    final healthStatusIdRaw = (row['healthStatus'] ?? '').trim();
    // Read explicit genet provenance ID column.
    // Phase 2 (2D.3): Removed fallback that promoted provenanceId to
    // genet provenance ID. The genetProvenanceId column must be supplied
    // explicitly for genet lineage linking.
    final genetProvenanceIdRaw = (row['provenanceId'] ?? '').trim();
    final genetProvenanceId = genetProvenanceIdRaw;
    final quantityStr = (row['quantity'] ?? '').trim();
    final populationValueRaw = (row['quantityValue'] ?? '').trim();
    final populationUnitRaw = (row['measurementUnit'] ?? '').trim();
    final localGenetId = (row['localGenetId'] ?? '').trim();
    final rawRecordName = row['tagId'];
    final tagId =
        rawRecordName != null && rawRecordName.trim().isNotEmpty
            ? rawRecordName.trim()
            : null;
    final notes = row['notes'];
    final lastEventAtRaw = (row['lastEventAt'] ?? '').trim();
    final aliasesJson = row['aliasesJson'];
    final aliasesRaw = row['aliases'];

    return OrganismRawFields(
      provenanceId: provenanceId,
      organismId: organismId,
      groupPath: groupPath,
      speciesIdRaw: speciesIdRaw,
      physicalFormIdRaw: physicalFormId,
      healthStatusIdRaw: healthStatusIdRaw,
      genetProvenanceId: genetProvenanceId,
      quantityStr: quantityStr,
      populationValueRaw: populationValueRaw,
      populationUnitRaw: populationUnitRaw,
      localGenetId: localGenetId,
      tagId: tagId,
      notes: notes,
      lastEventAtRaw: lastEventAtRaw,
      aliasesJson: aliasesJson,
      aliasesRaw: aliasesRaw,
      genetProvenanceIdRaw: genetProvenanceIdRaw,
    );
  }
}
