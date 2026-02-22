// @tier: community

/// Category of physical form that determines how size is interpreted.
///
/// Per the 5-Axis Overview specification, physical forms fall into three
/// categories that affect how size measurements work:
///
/// - **Individual**: Size represents actual physical dimensions (cm, mm, m).
///   Examples: fragment, colony, microfragment, plug
///
/// - **Shared Substrate**: Size represents density (# of organisms per substrate unit).
///   Examples: settlement_substrate, tile, dome, rope, panel
///
/// - **Container**: Size represents density (# of organisms per mL volume).
///   Examples: vial, tank, bag, cage, rack
enum PhysicalFormCategory {
  /// Individual organisms tracked by physical dimensions.
  /// Size = actual measurements (length, width, height in cm/mm/m).
  /// Used for: fragments, colonies, individual organisms.
  individual,

  /// Multiple organisms on a shared substrate.
  /// Size = density (# of organisms per substrate area).
  /// Used for: settlement substrates, tiles, domes, ropes, panels.
  sharedSubstrate,

  /// Multiple organisms in a container.
  /// Size = density (# of organisms per mL or L volume).
  /// Used for: vials, tanks, bags, cages, racks, aliquots.
  container;

  /// Returns true if this category uses density-based size interpretation.
  bool get usesDensity => this != individual;

  /// Returns true if this category uses dimension-based size interpretation.
  bool get usesDimension => this == individual;

  /// Canonical identifier for persistence and API payloads.
  String get id => name;

  /// Human-friendly label for UI presentation.
  String get label {
    switch (this) {
      case PhysicalFormCategory.individual:
        return 'Individual';
      case PhysicalFormCategory.sharedSubstrate:
        return 'Shared Substrate';
      case PhysicalFormCategory.container:
        return 'Container';
    }
  }

  /// Description of how size is interpreted for this category.
  String get sizeDescription {
    switch (this) {
      case PhysicalFormCategory.individual:
        return 'Size represents physical dimensions (cm, mm, m)';
      case PhysicalFormCategory.sharedSubstrate:
        return 'Size represents density (organisms per substrate unit)';
      case PhysicalFormCategory.container:
        return 'Size represents density (organisms per mL volume)';
    }
  }

  /// Infer category from a physical form ID using string-matching heuristics.
  ///
  /// This is the single source of truth for form-ID-based category inference,
  /// used by [PhysicalFormConfig.effectiveCategory] and
  /// [OutplantingAnalyticsService._resolveFormCategory].
  static PhysicalFormCategory inferFromFormId(String formId) {
    final lowerId = formId.toLowerCase();

    // Container patterns
    if (lowerId.contains('vial') ||
        lowerId.contains('tank') ||
        lowerId.contains('bag') ||
        lowerId.contains('aliquot') ||
        lowerId.contains('suspension') ||
        lowerId.contains('liquid') ||
        lowerId.contains('culture')) {
      return PhysicalFormCategory.container;
    }

    // Shared substrate patterns
    if (lowerId.contains('substrate') ||
        lowerId.contains('tile') ||
        lowerId.contains('dome') ||
        lowerId.contains('rope') ||
        lowerId.contains('panel') ||
        lowerId.contains('rack') ||
        lowerId.contains('line') ||
        lowerId.contains('cage') ||
        lowerId.contains('tray')) {
      return PhysicalFormCategory.sharedSubstrate;
    }

    // Individual forms (fragments, colonies, etc.)
    return PhysicalFormCategory.individual;
  }
}

extension PhysicalFormCategoryX on PhysicalFormCategory {
  /// Parse category from string identifier.
  static PhysicalFormCategory? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();

    for (final category in PhysicalFormCategory.values) {
      if (category.name.toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }

  /// Parse category from string, throwing if invalid.
  static PhysicalFormCategory fromString(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unknown physical form category. Expected one of: '
            '${PhysicalFormCategory.values.map((c) => c.name).join(', ')}',
      );
    }
    return parsed;
  }
}
