// @tier: community
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for validating physical form compatibility with provenance types and life stages.
///
/// Constraint data is hardcoded as Dart constants (no YAML loading required).
///
/// Usage:
/// ```dart
/// final service = PhysicalFormConstraintService.instance;
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

  // ---------------------------------------------------------------------------
  // Hardcoded constraint data (previously loaded from physical_form_constraints.yaml)
  // ---------------------------------------------------------------------------

  static const _provenanceConstraints = <String, Map<String, dynamic>>{
    'sexualCohort': {
      'allowed_form_patterns': [
        '.*substrate.*',
        '.*bag.*',
        '.*container.*',
        '.*vial.*',
        '.*suspension.*',
        '.*tank.*',
        '.*tray.*',
        '.*cage.*',
        '.*rack.*',
        '.*line.*',
        '.*panel.*',
      ],
      'disallowed_form_patterns': [
        '.*fragment.*',
        '.*colony.*',
        '.*individual.*',
        r'^microfragment$',
        '.*plug.*',
      ],
      'error_message':
          'Sexual cohorts can only be associated with container or shared substrate physical forms. Individual physical forms (fragments, colonies, plugs) are not compatible with cohorts.',
    },
    'gameteEgg': {
      'allowed_form_patterns': [
        '.*vial.*',
        '.*aliquot.*',
        '.*liquid.*',
        '.*suspension.*',
        '.*container.*',
      ],
      'disallowed_form_patterns': [
        '.*substrate.*',
        '.*fragment.*',
        '.*colony.*',
        '.*individual.*',
        '.*bag.*',
      ],
      'error_message':
          'Gamete eggs can only be stored in liquid/volumetric containers (vials, aliquots). Solid substrates and individual forms are not compatible.',
    },
    'gameteSperm': {
      'allowed_form_patterns': [
        '.*vial.*',
        '.*aliquot.*',
        '.*liquid.*',
        '.*suspension.*',
        '.*container.*',
      ],
      'disallowed_form_patterns': [
        '.*substrate.*',
        '.*fragment.*',
        '.*colony.*',
        '.*individual.*',
        '.*bag.*',
      ],
      'error_message':
          'Gamete sperm can only be stored in liquid/volumetric containers (vials, aliquots). Solid substrates and individual forms are not compatible.',
    },
    // wild, transfer, graduatedIndividual: no constraints (empty maps)
    'wild': <String, dynamic>{},
    'transfer': <String, dynamic>{},
    'graduatedIndividual': <String, dynamic>{},
  };

  static const _lifeStageConstraints = <String, Map<String, dynamic>>{
    'gamete': {
      'allowed_form_patterns': [
        '.*vial.*',
        '.*aliquot.*',
        '.*liquid.*',
        '.*suspension.*',
        '.*container.*',
      ],
      'disallowed_form_patterns': [
        '.*substrate.*',
        '.*fragment.*',
        '.*colony.*',
        '.*individual.*',
        '.*bag.*',
        '.*tank.*',
      ],
      'error_message':
          'Gametes can only be stored in liquid/volumetric containers (vials, aliquots). Solid substrates and individual forms are not compatible with gamete life stage.',
    },
    'embryo': {
      'allowed_form_patterns': [
        '.*vial.*',
        '.*aliquot.*',
        '.*suspension.*',
        '.*container.*',
        '.*substrate.*',
        '.*tank.*',
      ],
      'disallowed_form_patterns': [
        '.*fragment.*',
        '.*colony.*',
      ],
      'error_message':
          'Embryos can be stored in liquid containers or settlement substrates, but not as fragments or colonies.',
    },
    'larva': {
      'allowed_form_patterns': [
        '.*tank.*',
        '.*suspension.*',
        '.*container.*',
        '.*vial.*',
        '.*substrate.*',
        '.*bag.*',
        '.*tray.*',
      ],
      'disallowed_form_patterns': [
        '.*fragment.*',
        '.*colony.*',
      ],
      'error_message':
          'Larvae can be reared in tanks, containers, or settlement substrates, but not as fragments or colonies.',
    },
    'broodstock': {
      'disallowed_form_patterns': [
        '.*container.*',
        '.*vial.*',
        '.*aliquot.*',
        '.*liquid.*',
        '.*suspension.*',
        '.*bag.*',
        '.*tank.*',
        '.*tray.*',
        r'^mounted_individual$',
      ],
      'error_message':
          'Container physical forms and mounted individuals (plugs) cannot be applied to broodstock life stage per 5-axis specification. Broodstock must be tracked as free-standing individuals, colonies, or shared substrates.',
    },
    // Other life stages: no constraints (empty maps)
    'juvenile': <String, dynamic>{},
    'adult': <String, dynamic>{},
    'spat': <String, dynamic>{},
    'settler': <String, dynamic>{},
    'recruit': <String, dynamic>{},
    'fragment': <String, dynamic>{},
    'colony': <String, dynamic>{},
    'sporophyte': <String, dynamic>{},
    'gametophyte': <String, dynamic>{},
  };

  /// Initialize the service. No-op since constraints are now hardcoded.
  /// Retained for API compatibility with callers that await initialization.
  Future<void> initialize() async {
    _initialized = true;
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
    if (!_initialized) {
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
    final provenanceKey = provenanceType.name;
    final provenanceConstraint = _provenanceConstraints[provenanceKey];
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
    final lifeStageKey = lifeStage.name;
    final lifeStageConstraint = _lifeStageConstraints[lifeStageKey];
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

  /// Extract pattern list from structure
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
    if (!_initialized) return null;
    return _provenanceConstraints[provenanceType.name];
  }

  /// Get all constraints for a specific life stage (for debugging/UI)
  Map<String, dynamic>? getLifeStageConstraints(LifeStage lifeStage) {
    if (!_initialized) return null;
    return _lifeStageConstraints[lifeStage.name];
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Reset service (primarily for testing)
  void reset() {
    _initialized = false;
  }
}
