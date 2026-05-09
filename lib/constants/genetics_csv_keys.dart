// @tier: community

/// Shared CSV column key aliases for the genetics import/export pipeline.
/// Both the GeneticsCsvTranslationAdapter and GeneticsCsvImporter reference
/// these lists to prevent key-list drift.
class GeneticsCsvKeys {
  GeneticsCsvKeys._();

  static const List<String> provenanceIdKeys = [
    'provenanceId',
    'Provenance ID',
    'pid',
  ];

  /// Local ID keys — human-readable label for the genet (NOT a Firestore doc ID).
  /// Note: 'Genet ID' was removed as an alias because it is ambiguous — it
  /// could be confused with a Firestore document ID. Use 'genetLocalId'
  /// instead. (Phase 2, Team Delta — 2D.4)
  static const List<String> localIdKeys = [
    'localGenetId',
    'Local ID',
    'genetLocalId',
  ];

  /// Firestore document ID for a Genet record.
  /// This is always a Firestore auto-generated ID, never a lineage/provenance ID.
  static const List<String> genetDocIdKeys = [
    'genetId',
    'Genet ID',
  ];

  static const List<String> nameKeys = [
    'name',
    'genetName',
    'Genet Name',
  ];

  static const List<String> speciesKeys = [
    'speciesId',
    'Species ID',
    'speciesCode',
    'Species Code',
  ];

  static const List<String> organismKindKeys = [
    'organismKind',
    'Organism Kind',
    'Organism',
  ];

  static const List<String> provenanceTypeKeys = [
    'provenanceTypeId',
    'Provenance Type ID',
    'provenanceType',
    'Provenance Type',
  ];

  static const List<String> clonalIdKeys = [
    'clonalId',
    'Clonal ID',
  ];

  static const List<String> accessionNumberKeys = [
    'accessionNumber',
    'Accession Number',
    'accessionId',
    'Accession #',
  ];

  /// Donor genotype keys. Note: `site_id` is intentionally excluded.
  /// Legacy CSVs using site_id for donor genotype should use a partner-specific adapter.
  static const List<String> donorGenotypeKeys = [
    'donorGenotypeId',
    'Donor Genotype ID',
    'donorGenotype',
    'gameteDonorGenotypeId',
  ];

  static const List<String> genetNotesKeys = [
    'notes',
    'genetNotes',
    'Genet Notes',
  ];

  static const List<String> archivedKeys = [
    'archived',
    'Archived',
  ];

  static const List<String> parentGameteKeys = [
    'parentGameteIds',
    'Parent Gamete IDs',
  ];
}
