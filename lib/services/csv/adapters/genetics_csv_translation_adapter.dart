// @tier: community
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/constants/genetics_csv_keys.dart';
import 'package:seafoundry_app/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_app/services/csv/genetics_row_normalizer.dart';

/// Adapter that canonicalizes legacy genetics CSV rows so the importer always
/// receives the v2 provenance columns (habitat, collection date, notes, etc.).
class GeneticsCsvTranslationAdapter extends CsvTranslationAdapter {
  const GeneticsCsvTranslationAdapter() : super(id: 'genetics_csv_translation');

  /// Keys to look for local ID in CSV files.
  /// Phase 2 (2D.4): Removed 'genetRecordId' alias — genetRecordId is a Firestore
  /// document ID column, not a local ID. Use 'genetLocalId' instead.
  static final List<String> _localIdKeys = [
    ...GeneticsCsvKeys.localIdKeys,
  ];

  @override
  bool supports(CsvTranslationContext context) {
    if (context.kind != CsvTemplateKind.genetics) {
      return false;
    }
    if (context.direction != CsvTranslationDirection.import) {
      // Export rows are already canonical; passthrough is fine.
      return false;
    }
    final template =
        _metadataValue(context.metadata, _templateKeys) ?? '';
    if (template.isEmpty) return true;
    return template.toLowerCase() == CsvTemplateKind.genetics.name ||
        template.contains('genetic');
  }

  @override
  CsvTranslationResult<String> translateImport(
    CsvTranslationContext context,
    List<Map<String, String>> rows,
  ) {
    final canonicalRows = <Map<String, String>>[];
    for (final row in rows) {
      canonicalRows.add(_canonicalizeRow(row));
    }
    return CsvTranslationResult<String>(rows: canonicalRows, adapterId: id);
  }

  Map<String, String> _canonicalizeRow(Map<String, String> row) {
    final canonical = Map<String, String>.from(row);

    void setIfPresent(String key, String? value) {
      if (value == null) return;
      canonical[key] = value;
    }

    setIfPresent('provenanceId', _firstValue(row, GeneticsCsvKeys.provenanceIdKeys));
    setIfPresent('localGenetId', _firstValue(row, _localIdKeys));
    setIfPresent('name', _firstValue(row, GeneticsCsvKeys.nameKeys));
    setIfPresent('speciesId', _firstValue(row, GeneticsCsvKeys.speciesKeys));
    setIfPresent(
      'organismKind',
      _firstValue(row, GeneticsCsvKeys.organismKindKeys)?.toLowerCase(),
    );
    setIfPresent('provenanceType', _firstValue(row, GeneticsCsvKeys.provenanceTypeKeys));
    setIfPresent('clonalId', _firstValue(row, GeneticsCsvKeys.clonalIdKeys));
    setIfPresent('accessionNumber', _firstValue(row, GeneticsCsvKeys.accessionNumberKeys));
    setIfPresent('donorGenotypeId', _firstValue(row, GeneticsCsvKeys.donorGenotypeKeys));

    final parentGametes = GeneticsRowNormalizer.collectParentGameteIds(row);
    if (parentGametes.isNotEmpty) {
      canonical['parentGameteIds'] = parentGametes;
    }

    final aliasString = GeneticsRowNormalizer.aliasStringFromRow(row);
    if (aliasString.isNotEmpty) {
      canonical['aliases'] = aliasString;
    }

    final metadata = GeneticsRowNormalizer.metadataFromRow(row);
    final habitat = GeneticsRowNormalizer.firstNonEmpty([
      row['provenance.habitatType'],
      row['habitatType'],
      GeneticsRowNormalizer.metadataString(metadata, const [
        'habitatType',
        'habitat',
      ]),
    ]);
    if (habitat.isNotEmpty) {
      canonical['provenance.habitatType'] = habitat;
    }

    final collectionDate = GeneticsRowNormalizer.firstNonEmpty([
      row['provenance.collectionDate'],
      row['collectionDate'],
      GeneticsRowNormalizer.metadataString(metadata, const [
        'collectionDate',
        'collectedOn',
      ]),
      row['crossDate'],
    ]);
    if (collectionDate.isNotEmpty) {
      canonical['provenance.collectionDate'] = collectionDate;
    }

    final provenanceNotes = GeneticsRowNormalizer.joinDistinctSegments([
      row['provenance.notes'],
      row['genotypeProvenance'],
      row['genetNotes'],
      GeneticsRowNormalizer.metadataString(metadata, const [
        'notes',
        'note',
        'description',
        'provenanceNotes',
      ]),
      row['metadata'],
      row['metadataSummary'],
    ]);
    if (provenanceNotes.isNotEmpty) {
      canonical['provenance.notes'] = provenanceNotes;
    }

    return canonical;
  }

  String? _firstValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static const List<String> _templateKeys = [
    'provenanceCsvTemplate',
    'sfCsvTemplate',
  ];

  String? _metadataValue(Map<String, String> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
