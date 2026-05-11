/// Organism kind enum. Simplified to coral-only for the community edition.
enum OrganismKind {
  coral,
}

/// Per-organism metadata for display names and defaults.
class OrganismKindMetadata {
  const OrganismKindMetadata({
    required this.displayName,
    required this.pluralDisplayName,
    required this.defaultMeasurementUnit,
    required this.lifeStages,
  });

  final String displayName;
  final String pluralDisplayName;
  final String defaultMeasurementUnit;
  final List<String> lifeStages;
}

extension OrganismKindX on OrganismKind {
  OrganismKindMetadata get metadata => _metadata[this]!;

  /// Parses an organism kind from a string value.
  /// Returns coral for any unknown value since this is a coral-only build.
  static OrganismKind? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    // Accept 'coral' or any legacy organism kind name — always return coral
    return OrganismKind.coral;
  }

  static const Map<OrganismKind, OrganismKindMetadata> _metadata = {
    OrganismKind.coral: OrganismKindMetadata(
      displayName: 'Coral',
      pluralDisplayName: 'corals',
      defaultMeasurementUnit: 'count',
      lifeStages: [
        'gamete',
        'larvae',
        'recruit',
        'juvenile',
        'colony',
        'fragment',
      ],
    ),
  };
}
