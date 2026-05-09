// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_kind.dart';

/// Canonical provenance taxonomy used by the OrganismRecord DTO.
///
/// * `wild` -- stocks collected in the wild (permits required, keeps method).
/// * `cohort` -- organisms from a nursery-reared cohort (asexual propagation batch).
/// * `graduatedIndividual` -- individual promoted from a cohort to its own genet identity.
/// * `transfer` -- organisms received from another facility or external source.
/// * `unknown` -- provenance information is not available.
enum ProvenanceType {
  wild,
  cohort,
  graduatedIndividual,
  transfer,
  unknown,
}

extension ProvenanceTypeX on ProvenanceType {
  /// Legacy compatibility shim -- returns `this` so that existing
  /// `.metadata.displayName`, `.metadata.id`, etc. calls continue to work
  /// without a separate metadata class.
  ProvenanceType get metadata => this;

  /// Stable Firestore identifier for this provenance type.
  String get id => switch (this) {
    ProvenanceType.wild => 'provenance_type_wild',
    ProvenanceType.cohort => 'provenance_type_cohort',
    ProvenanceType.graduatedIndividual => 'provenance_type_graduated_individual',
    ProvenanceType.transfer => 'provenance_type_transfer',
    ProvenanceType.unknown => 'provenance_type_unknown',
  };

  String get displayName => switch (this) {
    ProvenanceType.wild => 'Wild Collection',
    ProvenanceType.cohort => 'Nursery Cohort',
    ProvenanceType.graduatedIndividual => 'Graduated Individual',
    ProvenanceType.transfer => 'Transfer / Import',
    ProvenanceType.unknown => 'Unknown',
  };

  /// Default provenance kind for this provenance type.
  /// All simplified provenance types map to genet.
  ProvenanceKind get defaultProvenanceKind => ProvenanceKind.genet;

  /// Allowed life stages for this provenance type.
  /// All provenance types now allow all life stages.
  List<LifeStage> get allowedLifeStages => LifeStage.values;

  /// Default life stage for this provenance type.
  LifeStage get defaultLifeStage => switch (this) {
    ProvenanceType.wild => LifeStage.broodstock,
    ProvenanceType.cohort => LifeStage.juvenile,
    ProvenanceType.graduatedIndividual => LifeStage.adult,
    ProvenanceType.transfer => LifeStage.adult,
    ProvenanceType.unknown => LifeStage.adult,
  };

  /// Parses a provenance type from a string value.
  ///
  /// Returns [ProvenanceType.unknown] for deleted values (sexualCohort,
  /// graduatedIndividual) to avoid crashes on existing Firestore data.
  static ProvenanceType? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    // Direct enum name matches
    for (final type in ProvenanceType.values) {
      if (type.name.toLowerCase() == normalized) return type;
    }

    // Legacy alias matching
    const aliases = <String, ProvenanceType>{
      'wild': ProvenanceType.wild,
      'founder': ProvenanceType.wild,
      'founder_genotype': ProvenanceType.wild,
      'founder genotype': ProvenanceType.wild,
      'donormeadow': ProvenanceType.wild,
      'donor meadow': ProvenanceType.wild,
      'donor_meadow': ProvenanceType.wild,
      'broodstock': ProvenanceType.wild,
      'provenance_type_wild': ProvenanceType.wild,
      'transfer': ProvenanceType.transfer,
      'import': ProvenanceType.transfer,
      'received': ProvenanceType.transfer,
      'provenance_type_transfer': ProvenanceType.transfer,
      'unknown': ProvenanceType.unknown,
      'missing': ProvenanceType.unknown,
      'n/a': ProvenanceType.unknown,
      'provenance_type_unknown': ProvenanceType.unknown,
      // Cohort aliases (nursery-reared batch)
      'cohort': ProvenanceType.cohort,
      'provenance_type_cohort': ProvenanceType.cohort,
      'sexualcohort': ProvenanceType.cohort,
      'sexual_cohort': ProvenanceType.cohort,
      'sexualCohort': ProvenanceType.cohort,
      'provenance_type_sexual_cohort': ProvenanceType.cohort,
      'hatcherylot': ProvenanceType.cohort,
      'hatchery_lot': ProvenanceType.cohort,
      // Graduated individual aliases
      'graduatedindividual': ProvenanceType.graduatedIndividual,
      'graduated_individual': ProvenanceType.graduatedIndividual,
      'provenance_type_graduated_individual': ProvenanceType.graduatedIndividual,
      'promoted_individual': ProvenanceType.graduatedIndividual,
      'promoted': ProvenanceType.graduatedIndividual,
      'individual': ProvenanceType.graduatedIndividual,
    };

    return aliases[normalized];
  }

  /// Maps a legacy [ProvenanceKind] to a [ProvenanceType].
  /// All kinds map to wild (founder-like) or unknown.
  static ProvenanceType? fromLegacyKind(ProvenanceKind? kind) {
    if (kind == null) return null;
    return switch (kind) {
      ProvenanceKind.genet => ProvenanceType.wild,
      ProvenanceKind.broodstock => ProvenanceType.wild,
      ProvenanceKind.donorMeadow => ProvenanceType.wild,
      ProvenanceKind.hatcheryLot => ProvenanceType.cohort,
      ProvenanceKind.cohort => ProvenanceType.cohort,
    };
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
}

/// Additional metadata that travels with a provenance type inside the
/// OrganismRecord payload. Stores collection metadata for wild stocks
/// and source organization for transfers.
///
/// The `gameteRole` field has been removed as part of the sexual propagation
/// workflow removal. Existing Firestore data with gameteRole is silently
/// ignored during parsing.
class ProvenanceAttributes extends Equatable {
  const ProvenanceAttributes({
    this.wildCollectionMethod,
  });

  final String? wildCollectionMethod;

  ProvenanceAttributes copyWith({
    String? wildCollectionMethod,
  }) {
    return ProvenanceAttributes(
      wildCollectionMethod: wildCollectionMethod ?? this.wildCollectionMethod,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (wildCollectionMethod != null)
        'wildCollectionMethod': wildCollectionMethod,
    };
  }

  factory ProvenanceAttributes.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ProvenanceAttributes();
    }
    // gameteRole is silently ignored for backward compat with existing data.
    return ProvenanceAttributes(
      wildCollectionMethod: _asString(json['wildCollectionMethod']),
    );
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [
    wildCollectionMethod,
  ];
}
