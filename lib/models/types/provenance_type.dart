// @tier: community
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

import 'provenance_kind.dart';

/// Canonical provenance taxonomy used by the five-axis OrganismRecord DTO.
///
/// * `wild` – stocks collected in the wild (permits required, keeps method).
///   Also used for fragments/clones derived from wild-collected organisms.
/// * `sexualCohort` – fertilised/settled cohorts that create new lineages.
/// * `graduatedIndividual` – individuals promoted out of a cohort (ties back
///   to the source cohort for traceability).
/// * `transfer` – organisms received from another facility or external source.
/// * `unknown` – provenance information is not available.
enum ProvenanceType {
  wild,
  sexualCohort,
  graduatedIndividual,
  transfer,
  unknown,
}

class ProvenanceTypeMetadata {
  const ProvenanceTypeMetadata({
    required this.id,
    required this.displayName,
    required this.defaultLifeStage,
    required this.defaultProvenanceKind,
    this.description,
    this.requiresParentIds = false,
    this.requiresSourceCohort = false,
    this.supportsWildMethod = false,
    this.isGamete = false,
    this.aliases = const <String>[],
    this.allowedLifeStages = const <LifeStage>[],
  });

  final String id;
  final String displayName;
  final LifeStage defaultLifeStage;
  final ProvenanceKind defaultProvenanceKind;
  final String? description;
  final bool requiresParentIds;
  final bool requiresSourceCohort;
  final bool supportsWildMethod;
  final bool isGamete;
  final List<String> aliases;
  final List<LifeStage> allowedLifeStages;
}

extension ProvenanceTypeX on ProvenanceType {
  static const Map<ProvenanceType, ProvenanceTypeMetadata> _metadata = {
    ProvenanceType.wild: ProvenanceTypeMetadata(
      id: 'provenance_type_wild',
      displayName: 'Wild Collection',
      defaultLifeStage: LifeStage.broodstock,
      defaultProvenanceKind: ProvenanceKind.broodstock,
      description:
          'Founder stock or corals-of-opportunity collected from the wild.',
      supportsWildMethod: true,
      aliases: [
        'wild',
        'founder',
        'founder_genotype', // legacy GenetType
        'founder genotype', // legacy GenetType
        'donormeadow',
        'donor meadow',
        'donor_meadow',
        'broodstock',
      ],
      allowedLifeStages: [
        LifeStage.gamete,
        LifeStage.juvenile,
        LifeStage.adult,
        LifeStage.broodstock,
        LifeStage.unknown,
      ],
    ),
    ProvenanceType.sexualCohort: ProvenanceTypeMetadata(
      id: 'provenance_type_sexual_cohort',
      displayName: 'Sexual Cohort',
      defaultLifeStage: LifeStage.juvenile,
      defaultProvenanceKind: ProvenanceKind.cohort,
      description: 'Larval/settled cohort created via sexual reproduction.',
      requiresParentIds: true,
      aliases: [
        'sexualcohort',
        'sexual_cohort',
        'hatcherylot',
        'hatchery_lot',
        'cohort',
      ],
      allowedLifeStages: [
        // Note: gamete removed - sexual cohorts are the RESULT of fertilization
        // Gametes themselves inherit their parent's provenance type
        LifeStage.embryo,
        LifeStage.larva,
        LifeStage.juvenile,
        LifeStage.unknown,
      ],
    ),
    ProvenanceType.graduatedIndividual: ProvenanceTypeMetadata(
      id: 'provenance_type_graduated_individual',
      displayName: 'Graduated Individual',
      defaultLifeStage: LifeStage.adult,
      defaultProvenanceKind: ProvenanceKind.cohort,
      description: 'Individual promoted from a cohort with its own lineage.',
      requiresSourceCohort: true,
      aliases: [
        'graduatedindividual',
        'graduated_individual',
        'promoted_individual',
        'promoted',
        'individual',
      ],
    ),
    ProvenanceType.transfer: ProvenanceTypeMetadata(
      id: 'provenance_type_transfer',
      displayName: 'Transfer / Import',
      defaultLifeStage: LifeStage.adult,
      defaultProvenanceKind: ProvenanceKind.genet,
      description:
          'Organism received from another facility or external source.',
      aliases: ['transfer', 'import', 'received'],
      allowedLifeStages: [
        LifeStage.gamete,
        LifeStage.juvenile,
        LifeStage.adult,
        LifeStage.broodstock,
        LifeStage.unknown,
      ],
    ),
    ProvenanceType.unknown: ProvenanceTypeMetadata(
      id: 'provenance_type_unknown',
      displayName: 'Unknown',
      defaultLifeStage: LifeStage.adult,
      defaultProvenanceKind: ProvenanceKind.genet,
      description: 'Provenance information is not available.',
      aliases: ['unknown', 'missing', 'n/a'],
      allowedLifeStages: [
        LifeStage.gamete,
        LifeStage.juvenile,
        LifeStage.adult,
        LifeStage.broodstock,
        LifeStage.unknown,
      ],
    ),
  };

  ProvenanceTypeMetadata get metadata => _metadata[this]!;

  String get id => metadata.id;

  String get displayName => metadata.displayName;

  LifeStage get defaultLifeStage => metadata.defaultLifeStage;

  ProvenanceKind get defaultProvenanceKind => metadata.defaultProvenanceKind;

  List<LifeStage> get allowedLifeStages => metadata.allowedLifeStages;

  static ProvenanceType? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    return ProvenanceType.values.firstWhereOrNull((type) {
      final metadata = type.metadata;
      if (type.name.toLowerCase() == normalized ||
          metadata.id.toLowerCase() == normalized) {
        return true;
      }
      return metadata.aliases.any(
        (alias) => alias.trim().toLowerCase() == normalized,
      );
    });
  }

  static ProvenanceType fromName(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unknown provenance type. Expected one of: '
            '${ProvenanceType.values.map((t) => t.name).join(', ')}',
      );
    }
    return parsed;
  }

  static ProvenanceType? fromLegacyKind(ProvenanceKind? kind) {
    if (kind == null) return null;
    switch (kind) {
      case ProvenanceKind.genet:
        return ProvenanceType.wild;
      case ProvenanceKind.broodstock:
        return ProvenanceType.wild;
      case ProvenanceKind.donorMeadow:
        return ProvenanceType.wild;
      case ProvenanceKind.hatcheryLot:
      case ProvenanceKind.cohort:
        return ProvenanceType.sexualCohort;
    }
  }
}

/// Additional metadata that travels with a provenance type inside the
/// OrganismRecord payload. This stores sire/dam references for sexual crosses,
/// source cohorts for promoted individuals, and collection metadata for wild
/// stocks.
class ProvenanceAttributes extends Equatable {
  const ProvenanceAttributes({
    this.gameteRole,
    this.sireProvenanceId,
    this.damProvenanceId,
    this.sourceCohortId,
    this.wildCollectionMethod,
    this.isAliquoted = false,
  });

  final ProvenanceGameteRole? gameteRole;
  final String? sireProvenanceId;
  final String? damProvenanceId;
  final String? sourceCohortId;
  final String? wildCollectionMethod;
  final bool isAliquoted;

  ProvenanceAttributes copyWith({
    ProvenanceGameteRole? gameteRole,
    String? sireProvenanceId,
    String? damProvenanceId,
    String? sourceCohortId,
    String? wildCollectionMethod,
    bool? isAliquoted,
  }) {
    return ProvenanceAttributes(
      gameteRole: gameteRole ?? this.gameteRole,
      sireProvenanceId: sireProvenanceId ?? this.sireProvenanceId,
      damProvenanceId: damProvenanceId ?? this.damProvenanceId,
      sourceCohortId: sourceCohortId ?? this.sourceCohortId,
      wildCollectionMethod: wildCollectionMethod ?? this.wildCollectionMethod,
      isAliquoted: isAliquoted ?? this.isAliquoted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (gameteRole != null) 'gameteRole': gameteRole!.name,
      if (sireProvenanceId != null) 'sireProvenanceId': sireProvenanceId,
      if (damProvenanceId != null) 'damProvenanceId': damProvenanceId,
      if (sourceCohortId != null) 'sourceCohortId': sourceCohortId,
      if (wildCollectionMethod != null)
        'wildCollectionMethod': wildCollectionMethod,
      if (isAliquoted) 'isAliquoted': true,
    };
  }

  factory ProvenanceAttributes.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProvenanceAttributes();
    }
    final roleValue = json['gameteRole']?.toString();
    return ProvenanceAttributes(
      gameteRole: ProvenanceGameteRoleX.tryParse(roleValue),
      sireProvenanceId: _asString(json['sireProvenanceId']),
      damProvenanceId: _asString(json['damProvenanceId']),
      sourceCohortId: _asString(json['sourceCohortId']),
      wildCollectionMethod: _asString(json['wildCollectionMethod']),
      isAliquoted: json['isAliquoted'] == true,
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [
    gameteRole,
    sireProvenanceId,
    damProvenanceId,
    sourceCohortId,
    wildCollectionMethod,
    isAliquoted,
  ];
}

/// Constants for provenance field values.
///
/// The provenance system uses two representations for missing data:
/// - `null` = field not applicable (e.g., wild provenance has no parents)
/// - `unknownParentId` = field applicable but value unknown (e.g., cohort with unknown parents)
///
/// Use [unknownParentId] when the field is semantically required but the actual
/// value is not known. This allows the UI to track incomplete provenance via
/// the genet's completenessScore.
abstract class ProvenanceConstants {
  /// Placeholder value for unknown parent/cohort IDs.
  /// Used when provenance type requires parent linkage but IDs are not known.
  static const String unknownParentId = 'unknown';

  /// Check if a value represents an unknown parent ID.
  static bool isUnknown(String? value) =>
      value == null || value.trim().isEmpty || value == unknownParentId;
}

enum ProvenanceGameteRole { egg, sperm }

extension ProvenanceGameteRoleX on ProvenanceGameteRole {
  static ProvenanceGameteRole? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    return ProvenanceGameteRole.values.firstWhereOrNull(
      (role) => role.name.toLowerCase() == normalized,
    );
  }
}
