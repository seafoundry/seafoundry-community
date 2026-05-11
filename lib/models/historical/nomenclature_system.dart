
/// Nomenclature systems available for viewing genotype identifiers.
///
/// Allows users to view genotype IDs in different naming conventions:
/// - Provenance ID (PID): Universal format (PID-APAL-001)
/// - Org A through Org J: Organization-specific naming systems
enum NomenclatureSystem {
  /// Universal Provenance ID format (PID-APAL-001)
  provenanceId,

  /// Org A (Mote Marine Laboratory)
  orgA,

  /// Org B (Coral Restoration Foundation)
  orgB,

  /// Org C (Florida Aquarium)
  orgC,

  /// Org D (Reef Renewal)
  orgD,

  /// Org E (University of the Virgin Islands)
  orgE,

  /// Org F (The Nature Conservancy)
  orgF,

  /// Org G (UM-RSMAS)
  orgG,

  /// Org H (ISER Caribe)
  orgH,

  /// Org I (Nova Southeastern University)
  orgI,

  /// Org J (Sea Ventures MRU)
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
        orgA => 'Mote Marine Laboratory',
        orgB => 'Coral Restoration Foundation',
        orgC => 'Florida Aquarium',
        orgD => 'Reef Renewal',
        orgE => 'University of the Virgin Islands',
        orgF => 'The Nature Conservancy',
        orgG => 'UM-RSMAS',
        orgH => 'ISER Caribe',
        orgI => 'Nova Southeastern University',
        orgJ => 'Sea Ventures MRU',
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
