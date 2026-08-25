import 'package:collection/collection.dart';

/// Canonical coral morphology categories used for taxonomy + monitoring.
enum CoralMorphology {
  branching('branching', 'Branching'),
  plating('plating', 'Plating'),
  massive('massive', 'Bouldering'),
  columnar('columnar', 'Columnar'),
  digitate('digitate', 'Digitate'),
  foliose('foliose', 'Foliose');

  const CoralMorphology(this.id, this.label);
  final String id;
  final String label;
}

extension CoralMorphologyX on CoralMorphology {
  static CoralMorphology? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'bouldering') {
      return CoralMorphology.massive;
    }
    return CoralMorphology.values.firstWhereOrNull(
      (entry) =>
          entry.id == normalized || entry.name.toLowerCase() == normalized,
    );
  }
}

/// Resolves a default morphology for coral taxonomy entries when missing.
class CoralMorphologyResolver {
  static CoralMorphology? resolve({
    required String genus,
    required String species,
  }) {
    final normalizedGenus = genus.trim().toLowerCase();
    final normalizedSpecies = species.trim().toLowerCase();
    if (normalizedGenus.isEmpty || normalizedSpecies.isEmpty) {
      return null;
    }
    final speciesKey = '$normalizedGenus $normalizedSpecies';
    final override = _speciesOverrides[speciesKey];
    if (override != null) {
      return override;
    }
    return _genusDefaults[normalizedGenus];
  }

  static const Map<String, CoralMorphology> _speciesOverrides = {};

  static const Map<String, CoralMorphology> _genusDefaults = {
    'acropora': CoralMorphology.branching,
    'agaricia': CoralMorphology.foliose,
    'colpophyllia': CoralMorphology.massive,
    'dendrogyra': CoralMorphology.columnar,
    'dichocoenia': CoralMorphology.massive,
    'diploria': CoralMorphology.massive,
    'eusmilia': CoralMorphology.branching,
    'favia': CoralMorphology.massive,
    'isophyllia': CoralMorphology.massive,
    'madracis': CoralMorphology.branching,
    'meandrina': CoralMorphology.massive,
    'montastraea': CoralMorphology.massive,
    'mycetophyllia': CoralMorphology.foliose,
    'orbicella': CoralMorphology.massive,
    'porites': CoralMorphology.digitate,
    'pseudodiploria': CoralMorphology.massive,
    'scolymia': CoralMorphology.massive,
    'siderastrea': CoralMorphology.massive,
    'solenastrea': CoralMorphology.massive,
  };
}
