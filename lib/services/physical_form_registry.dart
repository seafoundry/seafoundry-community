// @tier: community

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:yaml/yaml.dart';

/// Registry for loading and caching physical form configurations
/// Configurations are loaded from config/organism_physical_forms.yaml
/// and cached for performance.
class PhysicalFormRegistry {
  PhysicalFormRegistry._();

  static final PhysicalFormRegistry _instance = PhysicalFormRegistry._();
  static PhysicalFormRegistry get instance => _instance;

  // Cache: (organismKind, lifeStage) → List<PhysicalFormConfig>
  final Map<(OrganismKind, LifeStage), List<PhysicalFormConfig>> _cache = {};

  // Cache: version → full YAML content
  final Map<String, Map<String, dynamic>> _versionCache = {};

  // Current active version
  String? _currentVersion;

  /// Get available physical forms for an organism at a life stage
  Future<List<PhysicalFormConfig>> getAvailableForms(
    OrganismKind organism,
    LifeStage lifeStage, {
    String? version,
  }) async {
    final key = (organism, lifeStage);

    // If no version specified, use current version
    final targetVersion = version ?? await _getCurrentVersion();

    // Check cache (only if using current version)
    if (version == null && _cache.containsKey(key)) {
      return _cache[key]!;
    }

    // Load configuration
    final yamlContent = await _loadYamlContent(targetVersion);
    final configs = _parsePhysicalForms(yamlContent, organism, lifeStage);

    // Cache only if using current version
    if (version == null) {
      _cache[key] = configs;
    }

    return configs;
  }

  /// Get a specific physical form configuration
  Future<PhysicalFormConfig?> getFormConfig(
    OrganismKind organism,
    LifeStage lifeStage,
    String formId, {
    String? version,
  }) async {
    final forms = await getAvailableForms(
      organism,
      lifeStage,
      version: version,
    );
    try {
      return forms.firstWhere((form) => form.id == formId);
    } catch (_) {
      return null;
    }
  }

  /// Get current configuration version
  Future<String> _getCurrentVersion() async {
    if (_currentVersion != null) {
      return _currentVersion!;
    }

    final yamlContent = await _loadYamlContent(null);
    _currentVersion = yamlContent['version'] as String? ?? 'v1';
    return _currentVersion!;
  }

  /// Load YAML content for a specific version
  /// If version is null, loads the current version from assets
  Future<Map<String, dynamic>> _loadYamlContent(String? version) async {
    // Check version cache
    if (version != null && _versionCache.containsKey(version)) {
      return _versionCache[version]!;
    }

    // IMPORTANT: Always load from main config file.
    // Version-specific files don't exist yet in config/organism_physical_forms_versions/.
    // On web, missing asset fetches return index.html (SPA fallback) which causes
    // YAML parsing errors like "line 12, column 21: Mapping values are not allowed here"
    // because the HTML contains "For more details:" which looks like a YAML key.
    //
    // When version-specific files are created in the future, update this logic
    // to check if the version file exists before attempting to load it.
    final yamlString = await rootBundle.loadString(
      'config/organism_physical_forms.yaml',
    );

    final yaml = loadYaml(yamlString) as YamlMap;
    final Map<String, dynamic> content = _yamlToMap(yaml);

    // Cache version content
    if (version != null) {
      _versionCache[version] = content;
    }

    return content;
  }

  /// Parse physical forms for a specific organism and life stage
  List<PhysicalFormConfig> _parsePhysicalForms(
    Map<String, dynamic> yamlContent,
    OrganismKind organism,
    LifeStage lifeStage,
  ) {
    final organismKey = organism.name;
    final lifeStageKey = lifeStage.name;

    // Navigate: yamlContent[organismKey][lifeStageKey]['physical_forms']
    final organismData = yamlContent[organismKey] as Map<String, dynamic>?;
    if (organismData == null) {
      return [];
    }

    final lifeStageData = organismData[lifeStageKey] as Map<String, dynamic>?;
    if (lifeStageData == null) {
      return [];
    }

    final physicalFormsList = lifeStageData['physical_forms'] as List?;
    if (physicalFormsList == null || physicalFormsList.isEmpty) {
      return [];
    }

    return physicalFormsList
        .map(
          (formData) => PhysicalFormConfig.fromYaml(
            Map<String, dynamic>.from(formData as Map),
          ),
        )
        .toList();
  }

  /// Convert YamlMap to `Map<String, dynamic>` recursively
  Map<String, dynamic> _yamlToMap(YamlMap yaml) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is YamlMap) {
        result[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        result[key] = _yamlToList(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  /// Convert YamlList to `List<dynamic>` recursively
  List<dynamic> _yamlToList(YamlList yaml) {
    return yaml.map((item) {
      if (item is YamlMap) {
        return _yamlToMap(item);
      } else if (item is YamlList) {
        return _yamlToList(item);
      } else {
        return item;
      }
    }).toList();
  }

  /// Clear cache (useful for testing or after configuration updates)
  void clearCache() {
    _cache.clear();
    _versionCache.clear();
    _currentVersion = null;
  }

  /// Pre-populate the version cache from a YAML string.
  ///
  /// Avoids `rootBundle.loadString()` in test environments where
  /// Flutter assets are not available.
  @visibleForTesting
  void seedCacheForTesting(String yamlString) {
    final yaml = loadYaml(yamlString) as YamlMap;
    final content = _yamlToMap(yaml);
    final version = content['version'] as String? ?? 'v1';
    _versionCache[version] = content;
    _currentVersion = version;
  }

  /// Validate that a physical form is valid for an organism and life stage
  Future<bool> isValidForm(
    OrganismKind organism,
    LifeStage lifeStage,
    String formId, {
    String? version,
  }) async {
    final forms = await getAvailableForms(
      organism,
      lifeStage,
      version: version,
    );
    return forms.any((form) => form.id == formId);
  }

  /// Get all organisms defined in the configuration
  Future<List<OrganismKind>> getConfiguredOrganisms({String? version}) async {
    final yamlContent = await _loadYamlContent(version);
    final organisms = <OrganismKind>[];

    for (final organismKey in yamlContent.keys) {
      if (organismKey == 'version' ||
          organismKey == 'created_at' ||
          organismKey == 'created_by') {
        continue;
      }
      final organism = OrganismKindX.tryParse(organismKey);
      if (organism != null) {
        organisms.add(organism);
      }
    }

    return organisms;
  }

  /// Get all life stages configured for an organism
  Future<List<LifeStage>> getConfiguredLifeStages(
    OrganismKind organism, {
    String? version,
  }) async {
    final yamlContent = await _loadYamlContent(version);
    final organismData = yamlContent[organism.name] as Map<String, dynamic>?;

    if (organismData == null) {
      return [];
    }

    final lifeStages = <LifeStage>[];
    for (final lifeStageKey in organismData.keys) {
      final lifeStage = LifeStageX.tryParse(lifeStageKey);
      if (lifeStage != null) {
        lifeStages.add(lifeStage);
      }
    }

    return lifeStages;
  }
}
