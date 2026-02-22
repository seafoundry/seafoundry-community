// @tier: community
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/models.dart';

class CoralSizeChanged extends RecordFormInputEvent<CoralSize?> {
  const CoralSizeChanged(super.value);
}

class CoralSizeSelection
    extends
        RecordFormInput<CoralSize?, RecordFormInputError, CoralSizeChanged> {
  const CoralSizeSelection.pure() : super.pure();
  const CoralSizeSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Size';

  @override
  String? get hintText => 'Select coral size';

  @override
  CoralSizeSelection copyWith({required CoralSize? value}) {
    if (value == this.value) return this;
    if (value == null) return CoralSizeSelection.pure();
    return CoralSizeSelection.dirty(value);
  }
}

class CoralLifeStageChanged extends RecordFormInputEvent<LifeStage?> {
  const CoralLifeStageChanged(super.value);
}

class CoralLifeStageSelectionError extends RecordFormInputError {
  static const CoralLifeStageSelectionError notSelected =
      CoralLifeStageSelectionError('Please select a life stage');
  const CoralLifeStageSelectionError(super.message);
}

class CoralLifeStageSelection
    extends
        RecordFormInput<
          LifeStage?,
          CoralLifeStageSelectionError,
          CoralLifeStageChanged
        > {
  const CoralLifeStageSelection.pure() : super.pure();
  const CoralLifeStageSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Life Stage';

  @override
  String? get hintText => 'Select canonical life stage';

  @override
  CoralLifeStageSelectionError? validator(LifeStage? value) {
    if (value == null) return CoralLifeStageSelectionError.notSelected;
    return null;
  }

  @override
  CoralLifeStageSelection copyWith({required LifeStage? value}) {
    if (value == this.value) return this;
    if (value == null) return const CoralLifeStageSelection.pure();
    return CoralLifeStageSelection.dirty(value);
  }
}

class CoralPhysicalFormChanged
    extends RecordFormInputEvent<PhysicalFormInstance?> {
  const CoralPhysicalFormChanged(super.value);
}

class CoralPhysicalFormSelectionError extends RecordFormInputError {
  static const CoralPhysicalFormSelectionError notSelected =
      CoralPhysicalFormSelectionError('Please select a physical form');
  const CoralPhysicalFormSelectionError(super.message);
}

class CoralPhysicalFormSelection
    extends
        RecordFormInput<
          PhysicalFormInstance?,
          CoralPhysicalFormSelectionError,
          CoralPhysicalFormChanged
        > {
  const CoralPhysicalFormSelection.pure() : super.pure();
  const CoralPhysicalFormSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Physical Form';

  @override
  String? get hintText => 'Select holding form';

  @override
  CoralPhysicalFormSelectionError? validator(PhysicalFormInstance? value) {
    if (value == null) return CoralPhysicalFormSelectionError.notSelected;
    return null;
  }

  @override
  CoralPhysicalFormSelection copyWith({required PhysicalFormInstance? value}) {
    if (value == this.value) return this;
    if (value == null) return const CoralPhysicalFormSelection.pure();
    return CoralPhysicalFormSelection.dirty(value);
  }
}

class CoralQuantityChanged extends RecordFormInputEvent<int?> {
  const CoralQuantityChanged(super.value);
}

class CoralQuantityError extends RequiredInputError {
  static const CoralQuantityError nonNegative = CoralQuantityError(
    'Quantity must be greater than zero',
  );
  static const CoralQuantityError tooLarge = CoralQuantityError(
    'Quantity must be less than 1000',
  );
  const CoralQuantityError(super.message);
}

class CoralQuantity
    extends RecordFormInput<int?, CoralQuantityError, CoralQuantityChanged> {
  const CoralQuantity.pure() : super.pure();
  const CoralQuantity.dirty(super.value) : super.dirty();

  @override
  String get label => 'Quantity';

  @override
  String? get hintText => 'Number of corals';

  @override
  CoralQuantityError? validator(int? value) {
    if (value == null) return CoralQuantityError('Quantity is required');
    if (value <= 0) return CoralQuantityError.nonNegative;
    if (value > 1000) return CoralQuantityError.tooLarge;
    return null;
  }

  @override
  CoralQuantity copyWith({required int? value}) {
    if (value == this.value) return this;
    if (value == null) return CoralQuantity.pure();
    return CoralQuantity.dirty(value);
  }
}

class CoralQuantityRequired extends CoralQuantity {
  const CoralQuantityRequired.pure() : super.pure();
  const CoralQuantityRequired.dirty(super.value) : super.dirty();

  @override
  CoralQuantityError? validator(int? value) {
    if (value == null) return CoralQuantityError.nonNegative;
    if (value <= 0) return CoralQuantityError.nonNegative;
    if (value > 1000) return CoralQuantityError.tooLarge;
    return null;
  }
}

class CoralGenetSelected extends RecordFormInputEvent<Genet?> {
  const CoralGenetSelected(super.value);
}

class CoralGenetSelection
    extends RecordFormInput<Genet?, RequiredInputError, CoralGenetSelected> {
  const CoralGenetSelection.pure() : super.pure();
  const CoralGenetSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Genet';

  @override
  String? get hintText => 'Select or create a genet';

  @override
  RequiredInputError? validator(Genet? value) {
    if (value == null) {
      return RequiredInputError('Please select or create a genet');
    }
    return null;
  }

  @override
  CoralGenetSelection copyWith({required Genet? value}) {
    if (value == this.value) return this;
    if (value == null) return CoralGenetSelection.pure();
    return CoralGenetSelection.dirty(value);
  }
}

class OrganismIsPropagatableChanged extends RecordFormInputEvent<bool> {
  const OrganismIsPropagatableChanged(super.value);
}

class OrganismPropagatableInput
    extends
        RecordFormInput<bool, RecordFormInputError, OrganismIsPropagatableChanged> {
  const OrganismPropagatableInput.pure() : super.pure();
  const OrganismPropagatableInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Ready for Propagation';

  @override
  String? get hintText => 'Is this organism ready for asexual propagation?';

  @override
  OrganismPropagatableInput copyWith({required bool? value}) {
    if (value == this.value) return this;
    return OrganismPropagatableInput.dirty(value ?? false);
  }
}

class CoralProvenanceTypeChanged extends RecordFormInputEvent<ProvenanceType?> {
  const CoralProvenanceTypeChanged(super.value);
}

class CoralProvenanceTypeSelection
    extends
        RecordFormInput<
          ProvenanceType?,
          RecordFormInputError,
          CoralProvenanceTypeChanged
        > {
  const CoralProvenanceTypeSelection.pure() : super.pure();
  const CoralProvenanceTypeSelection.dirty(super.value) : super.dirty();

  @override
  String get label => 'Provenance Type';

  @override
  String? get hintText => 'Canonical provenance classification';

  @override
  CoralProvenanceTypeSelection copyWith({required ProvenanceType? value}) {
    if (value == this.value) return this;
    if (value == null) return const CoralProvenanceTypeSelection.pure();
    return CoralProvenanceTypeSelection.dirty(value);
  }
}

class CoralSizeSpecChanged extends RecordFormInputEvent<SizeSpec?> {
  const CoralSizeSpecChanged(super.value);
}

class CoralSizeSpecInput
    extends
        RecordFormInput<SizeSpec?, RecordFormInputError, CoralSizeSpecChanged> {
  const CoralSizeSpecInput.pure() : super.pure();
  const CoralSizeSpecInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Canonical Size Specification';

  @override
  String? get hintText => 'Size class and optional measured value';

  @override
  CoralSizeSpecInput copyWith({required SizeSpec? value}) {
    if (value == this.value) return this;
    if (value == null) return const CoralSizeSpecInput.pure();
    return CoralSizeSpecInput.dirty(value);
  }
}

class CoralReadyForOutplantChanged extends RecordFormInputEvent<bool> {
  const CoralReadyForOutplantChanged(super.value);
}

class CoralReadyForOutplantInput
    extends
        RecordFormInput<
          bool,
          RecordFormInputError,
          CoralReadyForOutplantChanged
        > {
  const CoralReadyForOutplantInput.pure() : super.pure();
  const CoralReadyForOutplantInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Ready for Outplant';

  @override
  String? get hintText => 'Mark this coral as ready for outplanting';

  @override
  CoralReadyForOutplantInput copyWith({required bool? value}) {
    if (value == this.value) return this;
    return CoralReadyForOutplantInput.dirty(value ?? false);
  }
}

class CoralOwnerOrganizationChanged extends RecordFormInputEvent<String?> {
  const CoralOwnerOrganizationChanged(super.value);
}

class CoralOwnerOrganizationInput
    extends
        RecordFormInput<
          String?,
          RecordFormInputError,
          CoralOwnerOrganizationChanged
        > {
  const CoralOwnerOrganizationInput.pure() : super.pure();
  const CoralOwnerOrganizationInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Owner Organization ID';

  @override
  String? get hintText => 'Defaults to your organization';

  @override
  CoralOwnerOrganizationInput copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null || value.trim().isEmpty) {
      return const CoralOwnerOrganizationInput.pure();
    }
    return CoralOwnerOrganizationInput.dirty(value.trim());
  }
}

class CoralManagingOrganizationChanged extends RecordFormInputEvent<String?> {
  const CoralManagingOrganizationChanged(super.value);
}

class CoralManagingOrganizationInput
    extends
        RecordFormInput<
          String?,
          RecordFormInputError,
          CoralManagingOrganizationChanged
        > {
  const CoralManagingOrganizationInput.pure() : super.pure();
  const CoralManagingOrganizationInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Managing Organization ID';

  @override
  String? get hintText => 'Optional, defaults to owner';

  @override
  CoralManagingOrganizationInput copyWith({required String? value}) {
    if (value == this.value) return this;
    if (value == null || value.trim().isEmpty) {
      return const CoralManagingOrganizationInput.pure();
    }
    return CoralManagingOrganizationInput.dirty(value.trim());
  }
}

class CoralAliasListChanged
    extends RecordFormInputEvent<List<GenetAliasEntry>> {
  const CoralAliasListChanged(super.value);
}

class CoralAliasListInput
    extends
        RecordFormInput<
          List<GenetAliasEntry>,
          RecordFormInputError,
          CoralAliasListChanged
        > {
  const CoralAliasListInput.pure() : super.pure();
  const CoralAliasListInput.dirty(super.value) : super.dirty();

  @override
  String get label => 'Aliases';

  @override
  String? get hintText => 'Tracks, CSR IDs, Provenance IDs, etc.';

  @override
  RecordFormInputError? validator(List<GenetAliasEntry>? value) => null;

  @override
  CoralAliasListInput copyWith({required List<GenetAliasEntry>? value}) {
    if (value == null) return const CoralAliasListInput.pure();
    return CoralAliasListInput.dirty(List<GenetAliasEntry>.unmodifiable(value));
  }
}

bool coralSupportsReadyForOutplant({
  required LifeStage? lifeStage,
  required Genet? genet,
}) {
  if (lifeStage == null || genet == null) {
    return false;
  }

  const allowedStages = <LifeStage>{LifeStage.adult, LifeStage.broodstock};
  if (!allowedStages.contains(lifeStage)) {
    return false;
  }

  // Disallow sexual cohorts from ready-for-outplant
  final disallowedProvenanceTypes = <String>{
    'provenance_type_sexual_cohort',
  };
  if (disallowedProvenanceTypes.contains(genet.provenanceTypeId)) {
    return false;
  }

  return true;
}
