// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/taxonomy/organism_classification.dart';
import 'package:seafoundry_app/models/taxonomy/propagation_mode.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Canonical species metadata stored in Firestore (taxonomy_species collection).
class SpeciesRecord extends Equatable {
  const SpeciesRecord({
    required this.id,
    required this.organismKind,
    required this.genus,
    required this.species,
    required this.code,
    this.commonNames = const <String>[],
    this.aliases = const <String>[],
    this.morphology,
    this.tags = const <String>[],
    this.classification,
    this.propagationModes = const <PropagationMode>[],
    this.imageUrl,
    this.thumbnailUrl,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final OrganismKind organismKind;
  final String genus;
  final String species;
  final String code;
  final List<String> commonNames;
  final List<String> aliases;
  final CoralMorphology? morphology;
  final List<String> tags;
  final OrganismClassification? classification;
  final List<PropagationMode> propagationModes;

  /// URL to full-size species reference image in shared Cloud Storage.
  final String? imageUrl;

  /// URL to thumbnail species image for lists/dropdowns.
  final String? thumbnailUrl;

  final Map<String, dynamic> metadata;

  String get scientificName => '$genus $species';

  SpeciesRecord copyWith({
    String? id,
    OrganismKind? organismKind,
    String? genus,
    String? species,
    String? code,
    List<String>? commonNames,
    List<String>? aliases,
    CoralMorphology? morphology,
    List<String>? tags,
    OrganismClassification? classification,
    List<PropagationMode>? propagationModes,
    String? imageUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) {
    return SpeciesRecord(
      id: id ?? this.id,
      organismKind: organismKind ?? this.organismKind,
      genus: genus ?? this.genus,
      species: species ?? this.species,
      code: code ?? this.code,
      commonNames: commonNames ?? this.commonNames,
      aliases: aliases ?? this.aliases,
      morphology: morphology ?? this.morphology,
      tags: tags ?? this.tags,
      classification: classification ?? this.classification,
      propagationModes: propagationModes ?? this.propagationModes,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  factory SpeciesRecord.fromJson(
    Map<String, dynamic> json, {
    required String id,
  }) {
    final rawKind = json['organismKind']?.toString().trim().toLowerCase();
    final kind = OrganismKind.values.firstWhere(
      (value) => value.name.toLowerCase() == rawKind,
      orElse: () {
        throw ArgumentError.value(
          rawKind,
          'organismKind',
          'Unknown organism kind for species "$id".',
        );
      },
    );
    final genus = json['genus']?.toString().trim() ?? '';
    final species = json['species']?.toString().trim() ?? '';
    final morphology =
        CoralMorphologyX.tryParse(
          json[taxonomySpeciesMorphologyField]?.toString(),
        ) ??
        CoralMorphologyResolver.resolve(genus: genus, species: species);
    return SpeciesRecord(
      id: id,
      organismKind: kind,
      genus: genus,
      species: species,
      code: (json['code'] ?? id).toString().trim(),
      commonNames: List<String>.from(json['commonNames'] ?? const []),
      aliases: List<String>.from(json['aliases'] ?? const []),
      morphology: morphology,
      tags: List<String>.from(json[taxonomySpeciesTagsField] ?? const []),
      classification: OrganismClassification.fromJson(
        safeMapCast(json['classification']),
      ),
      propagationModes: _parsePropagationModes(json['propagationModes']),
      imageUrl: json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organismKind': organismKind.name,
      'genus': genus,
      'species': species,
      'code': code,
      'commonNames': commonNames,
      'aliases': aliases,
      if (morphology != null) taxonomySpeciesMorphologyField: morphology!.id,
      if (tags.isNotEmpty) taxonomySpeciesTagsField: tags,
      if (classification != null) 'classification': classification!.toJson(),
      if (propagationModes.isNotEmpty)
        'propagationModes': propagationModes.map((mode) => mode.name).toList(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
    };
  }

  static List<PropagationMode> _parsePropagationModes(dynamic raw) {
    if (raw is List) {
      return raw
          .map((value) => PropagationModeX.tryParse(value?.toString()))
          .whereType<PropagationMode>()
          .toList(growable: false);
    }
    return const [];
  }

  @override
  List<Object?> get props => [
    id,
    organismKind,
    genus,
    species,
    code,
    commonNames,
    aliases,
    morphology,
    tags,
    classification,
    propagationModes,
    imageUrl,
    thumbnailUrl,
    metadata,
  ];
}
