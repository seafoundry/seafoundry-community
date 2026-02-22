// @tier: community
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for validating physical form compatibility with provenance types and life stages.
///
/// This service loads constraints from `config/physical_form_constraints.yaml` and provides
/// validation methods to ensure data integrity across the 5-axis model.
///
/// Usage:
/// ```dart
/// final service = PhysicalFormConstraintService.instance;
/// await service.initialize();
///
/// final error = service.validatePhysicalForm(
///   ProvenanceType.sexualCohort,
///   LifeStage.juvenile,
///   'fragment_plug',
/// );
/// if (error != null) {
///   print('Invalid combination: $error');
/// }
/// ```
class PhysicalFormConstraintService {
  static final PhysicalFormConstraintService _instance =
      PhysicalFormConstraintService._internal();

  factory PhysicalFormConstraintService() => _instance;

  static PhysicalFormConstraintService get instance => _instance;

  PhysicalFormConstraintService._internal();

  bool _initialized = false;
  Map<String, dynamic>? _config;

  /// Initialize the service by loading the YAML configuration.
  /// Should be called during app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final yamlString = await rootBundle
          .loadString('config/physical_form_constraints.yaml');
      final yaml = loadYaml(yamlString);
      _config = _yamlToMap(yaml);
      _initialized = true;
    } catch (e) {
      // If config fails to load, log but don't crash
      // Fallback to hardcoded validation in OrganismRecord
      LoggingService.instance.warning(
        'Failed to load physical form constraints config. Using fallback validation.',
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

  /// Validate physical form compatibility with provenance type and life stage.
  ///
  /// Returns error message if invalid, null if valid or no constraints defined.
  ///
  /// Parameters:
  /// - [provenanceType]: The provenance type (optional, can be null for wild/unknown)
  /// - [lifeStage]: The life stage
  /// - [physicalFormId]: The physical form identifier to validate
  ///
  /// Returns:
  /// - `null` if valid or no constraints apply
  /// - Error message string if constraint violated
  String? validatePhysicalForm(
    ProvenanceType? provenanceType,
    LifeStage lifeStage,
    String physicalFormId,
  ) {
    if (!_initialized || _config == null) {
      return null; // Fallback to hardcoded validation
    }

    // Check provenance constraints first (higher priority)
    if (provenanceType != null) {
      final provenanceError =
          _validateProvenanceConstraint(provenanceType, physicalFormId);
      if (provenanceError != null) {
        return provenanceError;
      }
    }

    // Check life stage constraints
    final lifeStageError = _validateLifeStageConstraint(lifeStage, physicalFormId);
    if (lifeStageError != null) {
      return lifeStageError;
    }

    return null; // Valid
  }

  /// Validate provenance-specific constraints
  String? _validateProvenanceConstraint(
    ProvenanceType provenanceType,
    String physicalFormId,
  ) {
    final constraints = _config?['provenance_constraints'];
    if (constraints == null) return null;

    final provenanceKey = provenanceType.name;
    final provenanceConstraint = constraints[provenanceKey];
    if (provenanceConstraint == null || provenanceConstraint.isEmpty) {
      return null; // No constraints for this provenance type
    }

    return _checkPatternConstraints(
      physicalFormId,
      provenanceConstraint,
      'provenance type ${provenanceType.name}',
    );
  }

  /// Validate life stage-specific constraints
  String? _validateLifeStageConstraint(
    LifeStage lifeStage,
    String physicalFormId,
  ) {
    final constraints = _config?['life_stage_constraints'];
    if (constraints == null) return null;

    final lifeStageKey = lifeStage.name;
    final lifeStageConstraint = constraints[lifeStageKey];
    if (lifeStageConstraint == null || lifeStageConstraint.isEmpty) {
      return null; // No constraints for this life stage
    }

    return _checkPatternConstraints(
      physicalFormId,
      lifeStageConstraint,
      'life stage ${lifeStage.name}',
    );
  }

  /// Check if physical form matches allowed/disallowed patterns
  String? _checkPatternConstraints(
    String physicalFormId,
    Map<String, dynamic> constraint,
    String contextDescription,
  ) {
    final allowedPatterns = constraint['allowed_form_patterns'];
    final disallowedPatterns = constraint['disallowed_form_patterns'];
    final errorMessage = constraint['error_message'] as String?;

    // Check disallowed patterns first (explicit exclusion)
    if (disallowedPatterns != null) {
      final patterns = _extractPatternList(disallowedPatterns);
      for (final pattern in patterns) {
        if (_matchesPattern(physicalFormId, pattern)) {
          return errorMessage ??
              'Physical form "$physicalFormId" is not allowed for $contextDescription';
        }
      }
    }

    // Check allowed patterns (explicit inclusion)
    if (allowedPatterns != null) {
      final patterns = _extractPatternList(allowedPatterns);
      bool matchesAny = false;
      for (final pattern in patterns) {
        if (_matchesPattern(physicalFormId, pattern)) {
          matchesAny = true;
          break;
        }
      }
      if (!matchesAny) {
        return errorMessage ??
            'Physical form "$physicalFormId" is not in allowed list for $contextDescription';
      }
    }

    return null; // Valid
  }

  /// Extract pattern list from YAML structure
  List<String> _extractPatternList(dynamic patterns) {
    if (patterns is List) {
      return patterns.map((p) => p.toString()).toList();
    }
    return [];
  }

  /// Check if a physical form ID matches a regex pattern
  bool _matchesPattern(String physicalFormId, String pattern) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      return regex.hasMatch(physicalFormId);
    } catch (e) {
      LoggingService.instance.warning(
        'Invalid regex pattern in physical form constraints: "$pattern"',
        e,
      );
      return false;
    }
  }

  /// Get all constraints for a specific provenance type (for debugging/UI)
  Map<String, dynamic>? getProvenanceConstraints(ProvenanceType provenanceType) {
    if (!_initialized || _config == null) return null;
    final constraints = _config?['provenance_constraints'];
    return constraints?[provenanceType.name];
  }

  /// Get all constraints for a specific life stage (for debugging/UI)
  Map<String, dynamic>? getLifeStageConstraints(LifeStage lifeStage) {
    if (!_initialized || _config == null) return null;
    final constraints = _config?['life_stage_constraints'];
    return constraints?[lifeStage.name];
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Reset service (primarily for testing)
  void reset() {
    _initialized = false;
    _config = null;
  }
}
