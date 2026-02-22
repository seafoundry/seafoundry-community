// @tier: community

/// Type of validation rule.
enum ValidationRuleType {
  requiredField,
  measurementRange,
  sizeRange,
  allowedPhysicalForm,
  physicalFormTransition,
  custom;

  static const Map<ValidationRuleType, String> _displayNames = {
    ValidationRuleType.requiredField: 'Required Field',
    ValidationRuleType.measurementRange: 'Measurement Range',
    ValidationRuleType.sizeRange: 'Size Range',
    ValidationRuleType.allowedPhysicalForm: 'Allowed Physical Form',
    ValidationRuleType.physicalFormTransition: 'Physical Form Transition',
    ValidationRuleType.custom: 'Custom',
  };

  String get displayName => _displayNames[this]!;

  static ValidationRuleType? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in ValidationRuleType.values) {
      if (type.name.toLowerCase() == normalized) return type;
    }
    return null;
  }
}
