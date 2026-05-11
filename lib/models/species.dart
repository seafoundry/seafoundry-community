import 'dart:collection';

import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/models/taxonomy/species_record.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

/// Runtime species metadata container.
///
/// Historically this file embedded a hard-coded list of coral species so that
/// the app could function before taxonomy data was seeded. Multi-organism
/// support now requires taxonomy collections (or explicit test seeds), so the
/// registry below simply mirrors whatever the [SpeciesRegistry] or tests load
/// at runtime.
class Species extends BuiltinRecordType implements Named {
  static const String pathBase = 'species';

  const Species({
    required super.id,
    required this.species,
    required this.genus,
    this.morphology,
    this.tags = const [],
    String? codeOverride,
  }) : _codeOverride = codeOverride,
       super(name: '$genus $species');

  final String species;
  final String genus;
  final CoralMorphology? morphology;
  final List<String> tags;
  final String? _codeOverride;

  String? get morphologyId => morphology?.id;
  String get morphologyLabel => morphology?.label ?? 'Unknown';
  bool get isEslListed => tags.contains(eslListedSpeciesTag);

  /// Returns the 4-letter species code (e.g., ACER for Acropora cervicornis).
  ///
  /// Format: First letter of genus + first 3 letters of species name.
  /// If a codeOverride was provided, uses that instead.
  String get code {
    if (_codeOverride != null && _codeOverride.isNotEmpty) {
      return _codeOverride.toUpperCase();
    }
    // Compute 4-letter code from genus + species
    // First letter of genus + first 3 letters of species
    final genusLetter = genus.isNotEmpty ? genus[0].toUpperCase() : 'X';
    final speciesPrefix = species.length >= 3
        ? species.substring(0, 3).toUpperCase()
        : species.toUpperCase().padRight(3, 'X');
    return '$genusLetter$speciesPrefix';
  }

  static Map<String, Species> _registry = _seedRegistryFromBuiltins();
  static final Map<String, Species> _fallbackCache = <String, Species>{};
  static const Species _unknownSpecies = Species(
    id: 'species_unknown',
    genus: 'Unknown',
    species: 'Species',
    codeOverride: 'UNKNOWN',
  );

  /// Current runtime registry. Callers should prefer consulting
  /// [SpeciesRegistry] directly, but a readonly map is exposed for legacy
  /// helpers that still depend on the previous singleton.
  static UnmodifiableMapView<String, Species> get registry =>
      UnmodifiableMapView(_registry);

  static Map<String, Species> get map => Map.unmodifiable(_registry);
  static int get length => _registry.length;
  static Species get single => _registry.values.single;

  /// Returns the Species for [id] if it exists in the runtime registry.
  static Species? lookupById(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return _registry[id.trim().toLowerCase()];
  }

  /// Creates a best-effort Species instance for ids that have not yet been
  /// hydrated into the runtime registry. This keeps legacy graph-node surfaces
  /// from crashing when taxonomy seeds are missing while still surfacing a
  /// human-friendly label.
  static Species fallback(String? rawId) {
    if (rawId == null || rawId.trim().isEmpty) {
      return _unknownSpecies;
    }
    final normalized = rawId.trim().toLowerCase();
    if (normalized == '__missing__' ||
        normalized == 'unknown' ||
        normalized == 'unknown_unknown') {
      return _unknownSpecies;
    }
    if (_registry.containsKey(normalized)) {
      return _registry[normalized]!;
    }
    if (_fallbackCache.containsKey(normalized)) {
      return _fallbackCache[normalized]!;
    }

    final tokens = normalized.split('_');
    final genusToken = tokens.length >= 2 ? tokens[1] : 'unknown';
    final speciesToken = tokens.length >= 3
        ? tokens.sublist(2).join(' ')
        : genusToken;
    // Scientific nomenclature: genus is capitalized, species epithet is lowercase
    final genus = _formatGenusToken(genusToken);
    final species = _formatSpeciesToken(speciesToken);
    final morphology = CoralMorphologyResolver.resolve(
      genus: genus,
      species: species,
    );
    final fallback = Species(
      id: normalized,
      genus: genus,
      species: species,
      morphology: morphology,
      tags: const [],
      codeOverride: _fallbackCodeFor(normalized),
    );
    _fallbackCache[normalized] = fallback;
    return fallback;
  }

  /// Replaces the registry with taxonomy-backed records.
  static void replaceAll(Iterable<SpeciesRecord> records) {
    final mapped = <String, Species>{};
    for (final record in records) {
      final normalizedId = record.id.trim().toLowerCase();
      if (normalizedId.isEmpty) continue;
      final code = record.code.trim();
      mapped[normalizedId] = Species(
        id: normalizedId,
        species: record.species,
        genus: record.genus,
        morphology: record.morphology,
        tags: record.tags,
        codeOverride: code.isEmpty ? null : code,
      );
    }

    if (mapped.isEmpty) {
      return;
    }

    _registry = mapped;
    _fallbackCache.clear();
  }

  /// Replaces the registry with the supplied species instances.
  static void replaceWithSeed(Iterable<Species> species) {
    final mapped = <String, Species>{};
    for (final entry in species) {
      mapped[entry.id.trim().toLowerCase()] = entry;
    }
    if (mapped.isEmpty) {
      return;
    }
    _registry = mapped;
    _fallbackCache.clear();
  }

  /// Resets the registry to the builtin fallback set used in legacy tests.
  static void reset() {
    _registry = _seedRegistryFromBuiltins();
    _fallbackCache.clear();
  }

  static Map<String, Species> _seedRegistryFromBuiltins() {
    return {for (final species in _builtinSpecies) species.id: species};
  }

  /// Formats a genus token with capitalization (scientific nomenclature).
  static String _formatGenusToken(String token) {
    if (token.isEmpty) return 'Unknown';
    final cleaned = token.replaceAll(RegExp(r'[^a-zA-Z]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Unknown';
    final lower = cleaned.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Formats a species epithet token in lowercase (scientific nomenclature).
  /// Species epithets should always be lowercase per taxonomic convention.
  static String _formatSpeciesToken(String token) {
    if (token.isEmpty) return 'unknown';
    final cleaned = token.replaceAll(RegExp(r'[^a-zA-Z]+'), ' ').trim();
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.toLowerCase();
  }

  /// Generates a 4-letter fallback code from a species ID.
  ///
  /// For IDs like "species_acropora_cervicornis", extracts genus and species
  /// to create a proper 4-letter code (e.g., ACER).
  static String _fallbackCodeFor(String id) {
    // Parse genus and species from typical ID patterns like "species_acropora_cervicornis"
    final normalized = id.toLowerCase().replaceAll('species_', '');
    final parts = normalized.split('_');

    if (parts.length >= 2) {
      // Format: genus_species -> first letter of genus + first 3 of species
      final genus = parts[0];
      final species = parts[1];
      final genusLetter = genus.isNotEmpty ? genus[0].toUpperCase() : 'X';
      final speciesPrefix = species.length >= 3
          ? species.substring(0, 3).toUpperCase()
          : species.toUpperCase().padRight(3, 'X');
      return '$genusLetter$speciesPrefix';
    } else if (normalized.length >= 4) {
      // Single word: take first 4 characters
      return normalized.substring(0, 4).toUpperCase();
    } else {
      return normalized.toUpperCase().padRight(4, 'X');
    }
  }

  static const Species acer = Species(
    id: 'acer',
    genus: 'Acropora',
    species: 'cervicornis',
    morphology: CoralMorphology.branching,
    tags: [eslListedSpeciesTag],
    codeOverride: 'ACER',
  );

  static const Species apal = Species(
    id: 'apal',
    genus: 'Acropora',
    species: 'palmata',
    morphology: CoralMorphology.branching,
    tags: [eslListedSpeciesTag],
    codeOverride: 'APAL',
  );

  static const Species ofav = Species(
    id: 'ofav',
    genus: 'Orbicella',
    species: 'faveolata',
    morphology: CoralMorphology.massive,
    tags: [eslListedSpeciesTag],
    codeOverride: 'OFAV',
  );

  static const Species past = Species(
    id: 'past',
    genus: 'Porites',
    species: 'astreoides',
    morphology: CoralMorphology.digitate,
    codeOverride: 'PAST',
  );

  static const Species ppor = Species(
    id: 'ppor',
    genus: 'Porites',
    species: 'porites',
    morphology: CoralMorphology.digitate,
    codeOverride: 'PPOR',
  );

  // Additional common coral species for onboarding
  static const Species mcav = Species(
    id: 'mcav',
    genus: 'Montastraea',
    species: 'cavernosa',
    morphology: CoralMorphology.massive,
    codeOverride: 'MCAV',
  );

  static const Species dlab = Species(
    id: 'dlab',
    genus: 'Diploria',
    species: 'labyrinthiformis',
    morphology: CoralMorphology.massive,
    codeOverride: 'DLAB',
  );

  static const Species ssid = Species(
    id: 'ssid',
    genus: 'Siderastrea',
    species: 'siderea',
    morphology: CoralMorphology.massive,
    codeOverride: 'SSID',
  );

  static const Species pstr = Species(
    id: 'pstr',
    genus: 'Pseudodiploria',
    species: 'strigosa',
    morphology: CoralMorphology.massive,
    codeOverride: 'PSTR',
  );

  static const Species cnat = Species(
    id: 'cnat',
    genus: 'Colpophyllia',
    species: 'natans',
    morphology: CoralMorphology.massive,
    codeOverride: 'CNAT',
  );

  static const Species dcyl = Species(
    id: 'dcyl',
    genus: 'Dendrogyra',
    species: 'cylindrus',
    morphology: CoralMorphology.columnar,
    tags: [eslListedSpeciesTag],
    codeOverride: 'DCYL',
  );

  static final List<Species> _builtinSpecies = <Species>[
    acer,
    apal,
    ofav,
    past,
    ppor,
    mcav,
    dlab,
    ssid,
    pstr,
    cnat,
    dcyl,
  ];
}
