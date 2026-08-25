
/// Nomenclature systems available for viewing genotype identifiers.
///
/// Allows users to view genotype IDs in different naming conventions:
/// - Provenance ID (PID): Universal format (PID-APAL-001)
/// - Org A through Org J: Organization-specific naming systems
enum NomenclatureSystem {
  /// Universal Provenance ID format (PID-APAL-001)
  provenanceId,

  /// Organization A
  orgA,

  /// Organization B
  orgB,

  /// Organization C
  orgC,

  /// Organization D
  orgD,

  /// Organization E
  orgE,

  /// Organization F
  orgF,

  /// Organization G
  orgG,

  /// Organization H
  orgH,

  /// Organization I
  orgI,

  /// Organization J
  orgJ;

  /// Display name for UI
  String get displayName => switch (this) {
        provenanceId => 'Provenance ID',
        orgA => 'Org A',
        orgB => 'Org B',
        orgC => 'Org C',
        orgD => 'Org D',
        orgE => 'Org E',
        orgF => 'Org F',
        orgG => 'Org G',
        orgH => 'Org H',
        orgI => 'Org I',
        orgJ => 'Org J',
      };

  /// Full organization name (for tooltips/details)
  String get fullName => switch (this) {
        provenanceId => 'Universal Provenance ID',
        orgA => 'Organization A',
        orgB => 'Organization B',
        orgC => 'Organization C',
        orgD => 'Organization D',
        orgE => 'Organization E',
        orgF => 'Organization F',
        orgG => 'Organization G',
        orgH => 'Organization H',
        orgI => 'Organization I',
        orgJ => 'Organization J',
      };

  /// Key used in the aliases map.
  /// For organizations, this matches the enum name (orgA, orgB, etc.).
  /// For provenanceId, returns 'pid'.
  String get aliasKey => this == provenanceId ? 'pid' : name;

  /// Parse from string (case-insensitive)
  static NomenclatureSystem? tryParse(String? value) {
    if (value == null) return null;
    final lower = value.toLowerCase();
    for (final system in values) {
      if (system.name.toLowerCase() == lower ||
          system.aliasKey.toLowerCase() == lower) {
        return system;
      }
    }
    return null;
  }

  /// All organization systems (excludes provenanceId)
  static List<NomenclatureSystem> get organizations => values
      .where((s) => s != provenanceId)
      .toList(growable: false);
}
