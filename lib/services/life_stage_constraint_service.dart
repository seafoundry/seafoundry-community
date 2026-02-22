// @tier: community
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for validating life stage compatibility with organism taxonomy.
///
/// This service loads constraints from `config/life_stage_constraints.yaml` and provides
/// validation methods to ensure data integrity across the 5-axis model.
///
/// Per 5 Axis Overview: "Taxonomy determines which Life Stages are valid"
///
/// Usage:
/// ```dart
/// final service = LifeStageConstraintService.instance;
/// await service.initialize();
///
/// final error = service.validateLifeStage(
///   OrganismKind.coral,
///   LifeStage.gamete,
/// );
/// if (error != null) {
///   print('Invalid combination: $error');
/// }
/// ```
class LifeStageConstraintService {
  static final LifeStageConstraintService _instance =
      LifeStageConstraintService._internal();

  factory LifeStageConstraintService() => _instance;

  static LifeStageConstraintService get instance => _instance;

  LifeStageConstraintService._internal();

  bool _initialized = false;
  Map<String, dynamic>? _config;

  /// Initialize the service by loading the YAML configuration.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final yamlString =
          await rootBundle.loadString('config/life_stage_constraints.yaml');
      final yaml = loadYaml(yamlString);
      _config = _yamlToMap(yaml);
      _initialized = true;
    } catch (e) {
      // If config fails to load, log but don't crash
      // Fallback to no validation (allow all stages)
      LoggingService.instance.warning(
        'Failed to load life stage constraints config. All life stages will be allowed for all organisms.',
        e,
      );
      _config = null;
      _initialized = true; // Mark as initialized to avoid retry loops
    }
  }

  /// Convert YamlMap to regular Map for easier access
  dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((entry) => MapEntry(
              entry.key.toString(),
              _yamlToMap(entry.value),
            )),
      );
    } else if (yaml is YamlList) {
      return yaml.map((item) => _yamlToMap(item)).toList();
    } else {
      return yaml;
    }
  }

  /// Validate life stage compatibility with organism taxonomy.
  ///
  /// Returns error message if invalid, null if valid or no constraints defined.
  ///
  /// Parameters:
  /// - [organismKind]: The organism taxonomy
  /// - [lifeStage]: The life stage to validate
  ///
  /// Returns:
  /// - `null` if valid or no constraints apply
  /// - Error message string if constraint violated
  String? validateLifeStage(
    OrganismKind organismKind,
    LifeStage lifeStage,
  ) {
    if (!_initialized || _config == null) {
      return null; // No constraints loaded, allow all
    }

    final organismConstraints = getOrganismConstraints(organismKind);
    if (organismConstraints == null || organismConstraints.isEmpty) {
      return null; // No constraints for this organism
    }

    final allowedStages = _extractStageList(organismConstraints['allowed_stages']);
    if (allowedStages.isEmpty) {
      return null; // No constraints defined
    }

    // Check if life stage is in allowed list
    final isAllowed = allowedStages.any(
      (allowedStage) => _matchesStage(lifeStage, allowedStage),
    );

    if (!isAllowed) {
      final errorTemplate = organismConstraints['error_message'] as String?;
      if (errorTemplate != null) {
        return errorTemplate.replaceAll('{stage}', lifeStage.displayName);
      }
      return 'Life stage "${lifeStage.displayName}" is not valid for ${organismKind.metadata.displayName}. '
          'Valid stages: ${allowedStages.join(', ')}';
    }

    return null; // Valid
  }

  /// Get list of valid life stages for an organism kind
  List<LifeStage> getValidLifeStages(OrganismKind organismKind) {
    if (!_initialized || _config == null) {
      return LifeStage.values; // No constraints, all stages valid
    }

    final organismConstraints = getOrganismConstraints(organismKind);
    if (organismConstraints == null || organismConstraints.isEmpty) {
      return LifeStage.values; // No constraints for this organism
    }

    final allowedStageNames = _extractStageList(organismConstraints['allowed_stages']);
    if (allowedStageNames.isEmpty) {
      return LifeStage.values; // No constraints defined
    }

    // Convert allowed stage names to LifeStage enum values
    final validStages = <LifeStage>[];
    for (final stageName in allowedStageNames) {
      final stage = LifeStageX.tryParse(stageName);
      if (stage != null && !validStages.contains(stage)) {
        validStages.add(stage);
      }
    }

    return validStages.isEmpty ? LifeStage.values : validStages;
  }

  /// Extract stage list from YAML structure
  List<String> _extractStageList(dynamic stages) {
    if (stages is List) {
      return stages.map((s) => s.toString()).toList();
    }
    return [];
  }

  /// Check if a life stage matches an allowed stage name
  bool _matchesStage(LifeStage lifeStage, String allowedStageName) {
    // Try exact name match
    if (lifeStage.name.toLowerCase() == allowedStageName.toLowerCase()) {
      return true;
    }

    // Try ID match
    if (lifeStage.id.toLowerCase() == allowedStageName.toLowerCase()) {
      return true;
    }

    // Try display name match
    if (lifeStage.displayName.toLowerCase() == allowedStageName.toLowerCase()) {
      return true;
    }

    return false;
  }

  /// Get all constraints for a specific organism kind (for debugging/UI)
  Map<String, dynamic>? getOrganismConstraints(OrganismKind organismKind) {
    if (!_initialized || _config == null) return null;
    final constraints = _config?['organism_constraints'];
    return constraints?[organismKind.name];
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Reset service (primarily for testing)
  void reset() {
    _initialized = false;
    _config = null;
  }
}
