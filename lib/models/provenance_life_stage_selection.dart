import 'package:seafoundry_community/models/genet.dart';
import 'package:seafoundry_community/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_community/models/transfer_manifest.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/types/provenance_kind.dart';
import 'package:seafoundry_community/models/types/provenance_type.dart';

/// Tuple describing a provenance + life stage selection.
class ProvenanceLifeStageSelection {
  const ProvenanceLifeStageSelection({
    required this.provenanceType,
    required this.lifeStage,
  });

  final ProvenanceType provenanceType;
  final LifeStage lifeStage;

  ProvenanceLifeStageSelection copyWith({
    ProvenanceType? provenanceType,
    LifeStage? lifeStage,
  }) {
    return ProvenanceLifeStageSelection(
      provenanceType: provenanceType ?? this.provenanceType,
      lifeStage: lifeStage ?? this.lifeStage,
    );
  }

  static ProvenanceLifeStageSelection fallback() =>
      ProvenanceLifeStageSelection(
        provenanceType: ProvenanceType.unknown,
        lifeStage: ProvenanceType.unknown.defaultLifeStage,
      );

  factory ProvenanceLifeStageSelection.fromGenet(Genet? genet) {
    if (genet == null) {
      return fallback();
    }
    final sources = <Map<String, dynamic>>[];
    final metadata = genet.metadata;
    if (metadata.isNotEmpty) {
      sources.add(Map<String, dynamic>.from(metadata));
    }

    // Only use provenanceKind as fallback if metadata doesn't contain provenanceTypeId
    final hasExplicitType = metadata['provenanceTypeId'] != null ||
                            metadata['provenanceType'] != null;

    return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: sources,
      fallbackProvenanceKind: hasExplicitType ? null : genet.provenanceKind.name,
    );
  }

  factory ProvenanceLifeStageSelection.fromProvenanceRecord(ProvenanceRecord? record) {
    if (record == null) {
      return fallback();
    }
    final sources = <Map<String, dynamic>>[];
    final metadata = record.metadata;
    if (metadata.isNotEmpty) {
      sources.add(Map<String, dynamic>.from(metadata));
    }
    return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: sources,
      fallbackProvenanceKind: record.provenanceKind.name,
    );
  }

  factory ProvenanceLifeStageSelection.fromManifest(TransferManifest manifest) {
    final sources = <Map<String, dynamic>>[];
    final genetMetadata = manifest.genet['metadata'];
    if (genetMetadata is Map<String, dynamic>) {
      sources.add(Map<String, dynamic>.from(genetMetadata));
    }
    if (manifest.metadata != null) {
      sources.add(Map<String, dynamic>.from(manifest.metadata!));
    }
    return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: sources,
      fallbackProvenanceKind: manifest.genet['provenanceKind']?.toString(),
    );
  }


  factory ProvenanceLifeStageSelection.fromCanonicalSources({
    List<Map<String, dynamic>> sources = const [],
    String? fallbackProvenanceKind,
    ProvenanceType? fallbackProvenanceType,
  }) {
    final provenanceTypeId = _readFirstNonEmpty(
      sources,
      const ['provenanceTypeId', 'provenanceType'],
    );
    final lifeStageId = _readFirstNonEmpty(
      sources,
      const ['lifeStageId', 'lifeStage'],
    );
    final resolvedKind = _readFirstNonEmpty(
          sources,
          const ['provenanceKind'],
        ) ??
        fallbackProvenanceKind;

    final provenanceType =
        ProvenanceTypeX.tryParse(provenanceTypeId) ??
        (resolvedKind != null
            ? ProvenanceTypeX.fromLegacyKind(
                ProvenanceKindX.tryParse(resolvedKind),
              )
            : null) ??
        fallbackProvenanceType ??
        ProvenanceType.unknown;

    final allowedStages = provenanceType.allowedLifeStages;
    var lifeStage =
        LifeStageX.tryParse(lifeStageId) ?? provenanceType.defaultLifeStage;
    if (allowedStages.isNotEmpty && !allowedStages.contains(lifeStage)) {
      lifeStage = allowedStages.first;
    }

    return ProvenanceLifeStageSelection(
      provenanceType: provenanceType,
      lifeStage: lifeStage,
    );
  }
}

String? _readFirstNonEmpty(List<Map<String, dynamic>> sources, List<String> keys) {
  for (final key in keys) {
    for (final source in sources) {
      final value = source[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}
