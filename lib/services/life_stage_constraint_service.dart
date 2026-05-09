import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';

/// Service for validating life stage compatibility with organism taxonomy.
///
/// Constraint data is hardcoded as Dart constants (no YAML loading required).
///
/// Per 5 Axis Overview: "Taxonomy determines which Life Stages are valid"
///
/// Usage:
/// ```dart
/// final service = LifeStageConstraintService.instance;
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

  // ---------------------------------------------------------------------------
  // Hardcoded constraint data (previously loaded from life_stage_constraints.yaml)
  // ---------------------------------------------------------------------------

  static const _organismConstraints = <String, Map<String, dynamic>>{
    'coral': {
      'allowed_stages': [
        'unknown',
        'gamete',
        'embryo',
        'larva',
        'juvenile',
        'adult',
        'broodstock',
      ],
      'error_message':
          "Life stage '{stage}' is not valid for coral. Valid stages: unknown, gamete, embryo, larva, juvenile, adult, broodstock",
    },
  };

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
    final organismConstraint = getOrganismConstraints(organismKind);
    if (organismConstraint == null || organismConstraint.isEmpty) {
      return null; // No constraints for this organism
    }

    final allowedStages = _extractStageList(organismConstraint['allowed_stages']);
    if (allowedStages.isEmpty) {
      return null; // No constraints defined
    }

    // Check if life stage is in allowed list
    final isAllowed = allowedStages.any(
      (allowedStage) => _matchesStage(lifeStage, allowedStage),
    );

    if (!isAllowed) {
      final errorTemplate = organismConstraint['error_message'] as String?;
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
    final organismConstraint = getOrganismConstraints(organismKind);
    if (organismConstraint == null || organismConstraint.isEmpty) {
      return LifeStage.values; // No constraints for this organism
    }

    final allowedStageNames = _extractStageList(organismConstraint['allowed_stages']);
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

  /// Extract stage list from structure
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
    return _organismConstraints[organismKind.name];
  }
}
