// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/population_gain_reason.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/measurement_metrics_service.dart';

enum OrganismCreationStep {
  identity, // Step 0: Species + Local ID + mode toggle
  provenance, // Step 1a: NEW mode - provenance type + parent selection
  gainReason, // Step 1b: EXISTING mode - PopulationGainReason
  biometrics, // Step 2: Life stage
  measurements, // Step 3: Physical form + Quantity + metrics
  review, // Step 4: Review and submit
}

/// Step metadata for display
extension OrganismCreationStepX on OrganismCreationStep {
  String get displayName => switch (this) {
    OrganismCreationStep.identity => 'Identity',
    OrganismCreationStep.provenance => 'Provenance',
    OrganismCreationStep.gainReason => 'Gain Reason',
    OrganismCreationStep.biometrics => 'Biometrics',
    OrganismCreationStep.measurements => 'Measurements',
    OrganismCreationStep.review => 'Review',
  };
}

/// Sentinel class used to distinguish between "not provided" and "explicitly null"
/// in copyWith methods. This allows nullable fields to be set to null.
class _Undefined {
  const _Undefined();
}

const _undefined = _Undefined();

class OrganismCreationState extends Equatable {
  const OrganismCreationState({
    this.organismKind,
    this.species,
    this.lifeStage,
    this.physicalForm,
    this.availablePhysicalForms = const [],
    this.measurement = const PopulationMeasurement(
      value: 1.0,
      unit: MeasurementUnit.count,
    ),
    this.sizeSpec = const SizeSpec(),
    this.physicalFormLabel,
    this.isNewGenet = true,
    this.provenanceType,
    this.gainReason,
    this.sourceCohortId,
    this.wildCollectionMethod,
    this.collectionReefOrigin,
    this.collectionDate,
    this.collectionDepth,
    this.collectionHabitatType,
    this.collectionInstitution,
    this.collectionLatitude,
    this.collectionLongitude,
    this.flRegion,
    this.flFounderType,
    this.flHabitatCollectionType,
    this.sireProvenanceId,
    this.damProvenanceId,
    this.transferOrgId,
    this.transferEmail,
    this.aliases = const <OrganismAlias>[],
    this.localId,
    this.recordName,
    this.ownerOrganizationId,
    this.managingOrganizationId,
    this.selectedGenet,
    this.selectedPermitId,
    this.permitId = '',
    this.permitType = '',
    this.permitIssuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.editingCount,
    this.measurementFieldConfig,
    this.suggestedLocalId,
    this.clonalId,
    this.accessionNumber,
    this.aliasId,
    this.provenanceId,
    this.provenanceSearch = const ProvenanceSearchState(),
    this.currentStep = OrganismCreationStep.identity,
    this.completedSteps = const {},
    this.isLoading = false,
    this.error,
  });

  final OrganismKind? organismKind;
  final Species? species;
  final LifeStage? lifeStage;
  final PhysicalFormInstance? physicalForm;
  final List<PhysicalFormConfig> availablePhysicalForms;
  final PopulationMeasurement measurement;
  final SizeSpec sizeSpec;
  final String? physicalFormLabel;
  final ProvenanceType? provenanceType;
  final String? sourceCohortId;
  final String? wildCollectionMethod;
  final String? collectionReefOrigin;
  final DateTime? collectionDate;
  final String? collectionDepth;
  final String? collectionHabitatType;
  final String? collectionInstitution;
  final String? collectionLatitude;
  final String? collectionLongitude;

  /// Florida-specific founder metadata
  final String? flRegion;
  final String? flFounderType;
  final String? flHabitatCollectionType;

  final String? sireProvenanceId;
  final String? damProvenanceId;
  final String? transferOrgId;
  final String? transferEmail;
  final List<OrganismAlias> aliases;
  final String? localId;

  /// Required name for the individual record instance.
  /// This is separate from localId which is the genet's identifier.
  final String? recordName;

  /// Optional owner organization ID.
  final String? ownerOrganizationId;

  /// Optional managing organization ID.
  final String? managingOrganizationId;

  final Genet? selectedGenet;
  final String? selectedPermitId;
  final String permitId;
  final String permitType;
  final String permitIssuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final int? editingCount;
  final MeasurementFieldConfig? measurementFieldConfig;

  /// Suggested local ID based on species (e.g., "Apal-1", "Acer-2")
  final String? suggestedLocalId;

  /// Clonal ID text typed by the user (for provenance search).
  final String? clonalId;

  /// Accession number text typed by the user (for provenance search).
  final String? accessionNumber;

  /// Alias text typed by the user (for provenance search).
  final String? aliasId;

  /// Provenance ID (PID) text typed by the user (for provenance search).
  final String? provenanceId;

  /// Provenance search state tracking crosswalk matches.
  final ProvenanceSearchState provenanceSearch;

  /// Mode toggle: creating new genet lineage vs adding to existing inventory
  final bool isNewGenet;

  /// Population gain reason for existing inventory mode (when isNewGenet = false)
  final PopulationGainReason? gainReason;

  /// Current wizard step
  final OrganismCreationStep currentStep;

  /// Set of completed steps
  final Set<OrganismCreationStep> completedSteps;

  final bool isLoading;
  final String? error;

  static const Set<LifeStage> fragmentationDisallowedLifeStages = {
    LifeStage.gamete,
    LifeStage.embryo,
    LifeStage.juvenile,
  };

  bool get isFragmentationGain =>
      !isNewGenet && gainReason == PopulationGainReason.fragmentation;

  List<LifeStage> get availableLifeStages {
    if (!isFragmentationGain) {
      return LifeStage.values;
    }
    return LifeStage.values
        .where((stage) => !fragmentationDisallowedLifeStages.contains(stage))
        .toList();
  }

  /// Returns the effective local ID (selected genet name, explicit local ID,
  /// or suggested local ID).
  String? get effectiveLocalId {
    final genetName = selectedGenet?.name.trim();
    if (genetName != null && genetName.isNotEmpty) {
      return genetName;
    }
    final explicit = localId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final suggested = suggestedLocalId?.trim();
    if (suggested != null && suggested.isNotEmpty) {
      return suggested;
    }
    return null;
  }

  bool get hasEffectiveLocalId => effectiveLocalId != null;

  bool get hasPermitMetadata =>
      permitId.trim().isNotEmpty ||
      permitType.trim().isNotEmpty ||
      permitIssuingAuthority.trim().isNotEmpty ||
      permitAttachmentUrls.trim().isNotEmpty ||
      permitValidFrom != null ||
      permitValidTo != null;

  /// Auto-derives creation reason from provenance type.
  /// Returns null when linking to existing inventory (selectedGenet != null).
  String? get creationReason {
    if (selectedGenet != null) return null; // Existing inventory mode
    return switch (provenanceType) {
      ProvenanceType.wild => 'collection',
      ProvenanceType.cohort => 'cohort',
      ProvenanceType.graduatedIndividual => 'graduation',
      ProvenanceType.transfer => 'transfer',
      ProvenanceType.unknown => 'unknown',
      null => null,
    };
  }

  /// Returns a list of validation issues, or empty list if form is valid.
  /// Single source of truth for both canSubmit, hasValidationIssues, and missingFieldsDebug.
  /// Note: isLoading is checked separately in canSubmit, not included here
  /// since it's not a "missing field" but a transient state.
  List<String> get validationIssues {
    final issues = <String>[];

    if (species == null) issues.add('Species');
    if (!hasEffectiveLocalId) issues.add('Local ID');

    if (!isNewGenet && selectedGenet == null) {
      issues.add('Existing Genet');
    }

    // Block submit when clonalId and accessionNumber matched different PIDs
    if (isNewGenet && provenanceSearch.hasConflict) {
      issues.add('Conflicting provenance matches');
    }
    if (measurement.value <= 0) {
      issues.add('Quantity must be greater than 0');
    }
    if (measurement.unit == MeasurementUnit.count &&
        measurement.value > OrganismRecord.maxReasonableCount) {
      issues.add(
        'Quantity exceeds maximum (${OrganismRecord.maxReasonableCount})',
      );
    }

    if (isFragmentationGain &&
        lifeStage != null &&
        fragmentationDisallowedLifeStages.contains(lifeStage)) {
      issues.add('Life stage ${lifeStage!.displayName} cannot be fragmented');
    }

    return issues;
  }

  /// Whether form can be submitted - combines validation issues with loading state
  bool get canSubmit => !isLoading && validationIssues.isEmpty;

  /// Whether the form has validation errors (ignoring loading state)
  bool get hasValidationErrors => validationIssues.isNotEmpty;

  /// Returns a user-friendly string showing which required fields are missing.
  /// Used to guide users to complete the form.
  String get missingFieldsDebug {
    final missing = validationIssues;
    if (missing.isEmpty) return 'All required fields are complete';
    if (missing.length == 1) return 'Required: ${missing.first}';
    return 'Required: ${missing.join(' • ')}';
  }

  /// Returns the first missing required field name for focusing.
  /// Derives from validationIssues to maintain single source of truth.
  String? get firstMissingField {
    if (species == null) return 'species';
    if (!hasEffectiveLocalId) return 'localId';
    if (measurement.value <= 0) return 'quantity';

    if (isFragmentationGain &&
        lifeStage != null &&
        fragmentationDisallowedLifeStages.contains(lifeStage)) {
      return 'lifeStage';
    }

    return null;
  }

  /// Step-specific validation getters
  List<String> get identityStepIssues => [
    if (species == null) 'Species',
    if (!hasEffectiveLocalId) 'Local ID',
  ];

  List<String> get provenanceStepIssues {
    return const <String>[];
  }

  List<String> get gainReasonStepIssues => const [];

  List<String> get biometricsStepIssues {
    final issues = <String>[];

    if (isFragmentationGain &&
        lifeStage != null &&
        fragmentationDisallowedLifeStages.contains(lifeStage)) {
      issues.add('Life stage ${lifeStage!.displayName} cannot be fragmented');
    }

    return issues;
  }

  List<String> get measurementsStepIssues {
    final issues = <String>[];

    if (measurement.value <= 0) {
      issues.add('Quantity must be greater than 0');
    }

    if (measurement.unit == MeasurementUnit.count &&
        measurement.value > OrganismRecord.maxReasonableCount) {
      issues.add(
        'Quantity exceeds maximum (${OrganismRecord.maxReasonableCount})',
      );
    }

    return issues;
  }

  bool get canAdvanceFromCurrentStep => switch (currentStep) {
    OrganismCreationStep.identity => identityStepIssues.isEmpty,
    OrganismCreationStep.provenance => provenanceStepIssues.isEmpty,
    OrganismCreationStep.gainReason => gainReasonStepIssues.isEmpty,
    OrganismCreationStep.biometrics => biometricsStepIssues.isEmpty,
    OrganismCreationStep.measurements => measurementsStepIssues.isEmpty,
    OrganismCreationStep.review => canSubmit,
  };

  List<String> get currentStepIssues => switch (currentStep) {
    OrganismCreationStep.identity => identityStepIssues,
    OrganismCreationStep.provenance => provenanceStepIssues,
    OrganismCreationStep.gainReason => gainReasonStepIssues,
    OrganismCreationStep.biometrics => biometricsStepIssues,
    OrganismCreationStep.measurements => measurementsStepIssues,
    OrganismCreationStep.review => validationIssues,
  };

  /// Active steps based on current mode (new vs existing)
  List<OrganismCreationStep> get activeSteps => isNewGenet
      ? [
          OrganismCreationStep.identity,
          OrganismCreationStep.provenance,
          OrganismCreationStep.biometrics,
          OrganismCreationStep.measurements,
          OrganismCreationStep.review,
        ]
      : [
          OrganismCreationStep.identity,
          OrganismCreationStep.gainReason,
          OrganismCreationStep.biometrics,
          OrganismCreationStep.measurements,
          OrganismCreationStep.review,
        ];

  /// Creates a copy with the given fields replaced.
  ///
  /// Nullable fields use [Object?] type with [_undefined] sentinel to support
  /// explicitly setting them to null (e.g., `copyWith(species: null)` will
  /// clear the species field).
  OrganismCreationState copyWith({
    OrganismKind? organismKind,
    Object? species = _undefined,
    Object? lifeStage = _undefined,
    Object? physicalForm = _undefined,
    List<PhysicalFormConfig>? availablePhysicalForms,
    PopulationMeasurement? measurement,
    SizeSpec? sizeSpec,
    Object? physicalFormLabel = _undefined,
    Object? provenanceType = _undefined,
    Object? sourceCohortId = _undefined,
    Object? wildCollectionMethod = _undefined,
    Object? collectionReefOrigin = _undefined,
    Object? collectionDate = _undefined,
    Object? collectionDepth = _undefined,
    Object? collectionHabitatType = _undefined,
    Object? collectionInstitution = _undefined,
    Object? collectionLatitude = _undefined,
    Object? collectionLongitude = _undefined,
    Object? flRegion = _undefined,
    Object? flFounderType = _undefined,
    Object? flHabitatCollectionType = _undefined,
    Object? sireProvenanceId = _undefined,
    Object? damProvenanceId = _undefined,
    Object? transferOrgId = _undefined,
    Object? transferEmail = _undefined,
    List<OrganismAlias>? aliases,
    Object? localId = _undefined,
    Object? recordName = _undefined,
    Object? ownerOrganizationId = _undefined,
    Object? managingOrganizationId = _undefined,
    Object? selectedGenet = _undefined,
    Object? selectedPermitId = _undefined,
    String? permitId,
    String? permitType,
    String? permitIssuingAuthority,
    String? permitAttachmentUrls,
    Object? permitValidFrom = _undefined,
    Object? permitValidTo = _undefined,
    Object? editingCount = _undefined,
    Object? measurementFieldConfig = _undefined,
    Object? suggestedLocalId = _undefined,
    Object? clonalId = _undefined,
    Object? accessionNumber = _undefined,
    Object? aliasId = _undefined,
    Object? provenanceId = _undefined,
    ProvenanceSearchState? provenanceSearch,
    bool? isNewGenet,
    Object? gainReason = _undefined,
    OrganismCreationStep? currentStep,
    Set<OrganismCreationStep>? completedSteps,
    bool? isLoading,
    String? error,
  }) {
    return OrganismCreationState(
      organismKind: organismKind ?? this.organismKind,
      species: species == _undefined ? this.species : species as Species?,
      lifeStage: lifeStage == _undefined
          ? this.lifeStage
          : lifeStage as LifeStage?,
      physicalForm: physicalForm == _undefined
          ? this.physicalForm
          : physicalForm as PhysicalFormInstance?,
      availablePhysicalForms:
          availablePhysicalForms ?? this.availablePhysicalForms,
      measurement: measurement ?? this.measurement,
      sizeSpec: sizeSpec ?? this.sizeSpec,
      physicalFormLabel: physicalFormLabel == _undefined
          ? this.physicalFormLabel
          : physicalFormLabel as String?,
      provenanceType: provenanceType == _undefined
          ? this.provenanceType
          : provenanceType as ProvenanceType?,
      sourceCohortId: sourceCohortId == _undefined
          ? this.sourceCohortId
          : sourceCohortId as String?,
      wildCollectionMethod: wildCollectionMethod == _undefined
          ? this.wildCollectionMethod
          : wildCollectionMethod as String?,
      collectionReefOrigin: collectionReefOrigin == _undefined
          ? this.collectionReefOrigin
          : collectionReefOrigin as String?,
      collectionDate: collectionDate == _undefined
          ? this.collectionDate
          : collectionDate as DateTime?,
      collectionDepth: collectionDepth == _undefined
          ? this.collectionDepth
          : collectionDepth as String?,
      collectionHabitatType: collectionHabitatType == _undefined
          ? this.collectionHabitatType
          : collectionHabitatType as String?,
      collectionInstitution: collectionInstitution == _undefined
          ? this.collectionInstitution
          : collectionInstitution as String?,
      collectionLatitude: collectionLatitude == _undefined
          ? this.collectionLatitude
          : collectionLatitude as String?,
      collectionLongitude: collectionLongitude == _undefined
          ? this.collectionLongitude
          : collectionLongitude as String?,
      flRegion: flRegion == _undefined ? this.flRegion : flRegion as String?,
      flFounderType: flFounderType == _undefined
          ? this.flFounderType
          : flFounderType as String?,
      flHabitatCollectionType: flHabitatCollectionType == _undefined
          ? this.flHabitatCollectionType
          : flHabitatCollectionType as String?,
      sireProvenanceId: sireProvenanceId == _undefined
          ? this.sireProvenanceId
          : sireProvenanceId as String?,
      damProvenanceId: damProvenanceId == _undefined
          ? this.damProvenanceId
          : damProvenanceId as String?,
      transferOrgId: transferOrgId == _undefined
          ? this.transferOrgId
          : transferOrgId as String?,
      transferEmail: transferEmail == _undefined
          ? this.transferEmail
          : transferEmail as String?,
      aliases: aliases ?? this.aliases,
      localId: localId == _undefined ? this.localId : localId as String?,
      recordName: recordName == _undefined
          ? this.recordName
          : recordName as String?,
      ownerOrganizationId: ownerOrganizationId == _undefined
          ? this.ownerOrganizationId
          : ownerOrganizationId as String?,
      managingOrganizationId: managingOrganizationId == _undefined
          ? this.managingOrganizationId
          : managingOrganizationId as String?,
      selectedGenet: selectedGenet == _undefined
          ? this.selectedGenet
          : selectedGenet as Genet?,
      selectedPermitId: selectedPermitId == _undefined
          ? this.selectedPermitId
          : selectedPermitId as String?,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      permitIssuingAuthority:
          permitIssuingAuthority ?? this.permitIssuingAuthority,
      permitAttachmentUrls: permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom == _undefined
          ? this.permitValidFrom
          : permitValidFrom as DateTime?,
      permitValidTo: permitValidTo == _undefined
          ? this.permitValidTo
          : permitValidTo as DateTime?,
      editingCount: editingCount == _undefined
          ? this.editingCount
          : editingCount as int?,
      measurementFieldConfig: measurementFieldConfig == _undefined
          ? this.measurementFieldConfig
          : measurementFieldConfig as MeasurementFieldConfig?,
      suggestedLocalId: suggestedLocalId == _undefined
          ? this.suggestedLocalId
          : suggestedLocalId as String?,
      clonalId: clonalId == _undefined ? this.clonalId : clonalId as String?,
      accessionNumber: accessionNumber == _undefined
          ? this.accessionNumber
          : accessionNumber as String?,
      aliasId: aliasId == _undefined ? this.aliasId : aliasId as String?,
      provenanceId: provenanceId == _undefined
          ? this.provenanceId
          : provenanceId as String?,
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
      isNewGenet: isNewGenet ?? this.isNewGenet,
      gainReason: gainReason == _undefined
          ? this.gainReason
          : gainReason as PopulationGainReason?,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    organismKind,
    species,
    lifeStage,
    physicalForm,
    availablePhysicalForms,
    measurement,
    sizeSpec,
    physicalFormLabel,
    provenanceType,
    sourceCohortId,
    wildCollectionMethod,
    collectionReefOrigin,
    collectionDate,
    collectionDepth,
    collectionHabitatType,
    collectionInstitution,
    collectionLatitude,
    collectionLongitude,
    flRegion,
    flFounderType,
    flHabitatCollectionType,
    sireProvenanceId,
    damProvenanceId,
    transferOrgId,
    transferEmail,
    aliases,
    localId,
    recordName,
    ownerOrganizationId,
    managingOrganizationId,
    selectedGenet,
    selectedPermitId,
    permitId,
    permitType,
    permitIssuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    editingCount,
    measurementFieldConfig,
    suggestedLocalId,
    clonalId,
    accessionNumber,
    aliasId,
    provenanceId,
    provenanceSearch,
    isNewGenet,
    gainReason,
    currentStep,
    completedSteps,
    isLoading,
    error,
  ];

  // _coerceDouble removed in coral-only simplification
}
