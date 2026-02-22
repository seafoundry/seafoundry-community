// @tier: community

import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Builder for constructing holding metadata from CSV row data.
class HoldingMetadataBuilder {
  HoldingMetadataBuilder._();

  /// Builds holding metadata from CSV row data.
  ///
  /// Extracts metadata fields from the row and constructs
  /// a map suitable for holding record metadata.
  static Map<String, dynamic> build(
    Map<String, String> row,
    String? sourceName,
  ) {
    final metadata = <String, dynamic>{'source': 'csv_v2'};
    if (sourceName != null) {
      metadata['sourceName'] = sourceName;
    }
    void addIfPresent(String key) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        metadata[key] = value.trim();
      }
    }

    for (final key in [
      'notes',
      'structureType',
      'siteId',
      'groupId',
      'provenanceKind',
      'lifeStageId',
      'lifeStageSubtype',
    ]) {
      addIfPresent(key);
    }

    final provenanceTypeValue = row['provenanceType'];
    final provenanceType = ProvenanceTypeX.tryParse(provenanceTypeValue);
    if (provenanceType != null) {
      metadata['provenanceType'] = provenanceType.id;
    }

    final lifeStageId = row['lifeStageId'] ?? row['lifeStage'];
    if (lifeStageId != null && lifeStageId.trim().isNotEmpty) {
      metadata['lifeStageId'] = lifeStageId.trim();
    }

    if ((row['lifeStageSubtype'] ?? '').trim().isNotEmpty) {
      metadata['lifeStageSubtype'] = row['lifeStageSubtype']!.trim();
    }
    return metadata;
  }
}
