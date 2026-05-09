// @tier: community

import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/physical_form_data.dart';

/// Registry for loading and caching physical form configurations.
///
/// Configurations are defined as hardcoded Dart constants in
/// `physical_form_data.dart` and cached for performance.
class PhysicalFormRegistry {
  PhysicalFormRegistry._();

  static final PhysicalFormRegistry _instance = PhysicalFormRegistry._();
  static PhysicalFormRegistry get instance => _instance;

  // Cache: (organismKind, lifeStage) -> List<PhysicalFormConfig>
  final Map<(OrganismKind, LifeStage), List<PhysicalFormConfig>> _cache = {};

  /// Get available physical forms for an organism at a life stage
  List<PhysicalFormConfig> getAvailableForms(
    OrganismKind organism,
    LifeStage lifeStage, {
    String? version,
  }) {
    final key = (organism, lifeStage);

    // Check cache
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Look up from hardcoded data
    final configs = _lookupForms(organism, lifeStage);
    _cache[key] = configs;
    return configs;
  }

  /// Get a specific physical form configuration
  PhysicalFormConfig? getFormConfig(
    OrganismKind organism,
    LifeStage lifeStage,
    String formId, {
    String? version,
  }) {
    final forms = getAvailableForms(organism, lifeStage, version: version);
    try {
      return forms.firstWhere((form) => form.id == formId);
    } catch (_) {
      return null;
    }
  }

  /// Look up physical forms from the hardcoded data
  List<PhysicalFormConfig> _lookupForms(
    OrganismKind organism,
    LifeStage lifeStage,
  ) {
    final organismData = physicalFormData[organism.name];
    if (organismData == null) return [];

    final lifeStageForms = organismData[lifeStage.name];
    if (lifeStageForms == null) return [];

    return lifeStageForms;
  }

  /// Clear cache (useful for testing or after configuration updates)
  void clearCache() {
    _cache.clear();
  }

  /// Validate that a physical form is valid for an organism and life stage
  bool isValidForm(
    OrganismKind organism,
    LifeStage lifeStage,
    String formId, {
    String? version,
  }) {
    final forms = getAvailableForms(organism, lifeStage, version: version);
    return forms.any((form) => form.id == formId);
  }

}
