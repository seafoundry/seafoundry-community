// @tier: community

/// Unified severity scale for all observation types.
///
/// The superset enum covers every severity level used across biofouling, pest,
/// disease, and thermal stress observations. Each observation type uses a
/// subset of these values, exposed via the static subset constants.
enum ObservationSeverity {
  light,
  mild,
  moderate,
  heavy,
  severe,
  critical;

  String get displayName => switch (this) {
    ObservationSeverity.light => 'Light',
    ObservationSeverity.mild => 'Mild',
    ObservationSeverity.moderate => 'Moderate',
    ObservationSeverity.heavy => 'Heavy',
    ObservationSeverity.severe => 'Severe',
    ObservationSeverity.critical => 'Critical',
  };

  /// Biofouling and pest severity scale: light, moderate, heavy, severe.
  static const List<ObservationSeverity> environmentalScale = [
    light,
    moderate,
    heavy,
    severe,
  ];

  /// Disease severity scale: mild, moderate, severe, critical.
  static const List<ObservationSeverity> clinicalScale = [
    mild,
    moderate,
    severe,
    critical,
  ];

  /// Thermal stress severity scale: mild, moderate, severe.
  static const List<ObservationSeverity> thermalScale = [
    mild,
    moderate,
    severe,
  ];

  /// Parse a severity from a string, returning null if not found.
  static ObservationSeverity? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final severity in ObservationSeverity.values) {
      if (severity.name == normalized) return severity;
    }
    return null;
  }
}
