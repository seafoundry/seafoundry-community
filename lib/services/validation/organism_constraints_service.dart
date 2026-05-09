// @tier: community
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/physical_form_constraint_service.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';

class OrganismConstraintViolation {
  const OrganismConstraintViolation(this.message);
  final String message;
}

/// Lightweight service that centralises validation of organism-aware rules.
/// Additional constraints (size family enforcement, provenance requirements,
/// etc.) can be layered in here as the five-axis model matures.
class OrganismConstraintsService {
  const OrganismConstraintsService();

  /// Validate that a physical form (formId) is allowed for the given
  /// organism kind, life stage, and optional provenance type.
  ///
  /// Returns null if valid, or an [OrganismConstraintViolation] if invalid.
  OrganismConstraintViolation? validateLifeStagePhysicalForm({
    required OrganismKind organismKind,
    required LifeStage lifeStage,
    required String formId,
    ProvenanceType? provenanceType,
  }) {
    // First check if the formId is in the registry for this organism/lifeStage
    final isValidInRegistry = PhysicalFormRegistry.instance.isValidForm(
      organismKind,
      lifeStage,
      formId,
    );

    if (!isValidInRegistry) {
      return OrganismConstraintViolation(
        'Physical form "$formId" is not available for '
        '${lifeStage.displayName} in ${organismKind.metadata.displayName} workflows.',
      );
    }

    // Then validate constraints (provenance, life stage specific rules)
    final constraintError = PhysicalFormConstraintService.instance
        .validatePhysicalForm(provenanceType, lifeStage, formId);

    if (constraintError != null) {
      return OrganismConstraintViolation(constraintError);
    }

    return null;
  }

  /// Get the list of allowed physical form IDs for a given organism kind and life stage.
  ///
  /// Returns a list of formId strings that are valid for the specified combination.
  List<String> allowedFormIds({
    required OrganismKind organismKind,
    required LifeStage lifeStage,
  }) {
    final forms = PhysicalFormRegistry.instance.getAvailableForms(
      organismKind,
      lifeStage,
    );
    return forms.map((form) => form.id).toList();
  }
}
