// @tier: community
part of 'onboarding_cubit.dart';

sealed class OnboardingState extends Equatable {
  const OnboardingState({required this.step, this.isInviteFlow = false});
  final OnboardingStep step;
  final bool isInviteFlow;

  String? validate();
  bool get isPure;

  @override
  List<Object?> get props;

  @override
  bool get stringify => false;
}

final class OnboardingInitial extends OnboardingState {
  const OnboardingInitial() : super(step: OnboardingStep.initial);
  @override
  String? validate() => null;
  @override
  bool get isPure => true;
  @override
  List<Object?> get props => [step];
}

final class OnboardingLoading extends OnboardingState {
  const OnboardingLoading() : super(step: OnboardingStep.loading);
  @override
  String? validate() => null;
  @override
  bool get isPure => true;
  @override
  List<Object?> get props => [step];
}

abstract class OnboardingUserState extends OnboardingState {
  const OnboardingUserState({
    required super.step,
    required this.user,
    super.isInviteFlow,
  });

  final User user;
}

final class OnboardingLegalAcceptance extends OnboardingUserState {
  const OnboardingLegalAcceptance({
    required super.user,
    required this.tosAccepted,
    required this.privacyAccepted,
    super.isInviteFlow,
    super.step = OnboardingStep.legalAcceptance,
  });

  final bool tosAccepted;
  final bool privacyAccepted;

  OnboardingLegalAcceptance copyWithLegal({
    bool? tosAccepted,
    bool? privacyAccepted,
  }) {
    return OnboardingLegalAcceptance(
      user: user,
      tosAccepted: tosAccepted ?? this.tosAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      isInviteFlow: isInviteFlow,
    );
  }

  @override
  String? validate() {
    if (!tosAccepted || !privacyAccepted) {
      return 'You must accept the Terms of Service and Privacy Policy to continue.';
    }
    return null;
  }

  @override
  bool get isPure => !tosAccepted && !privacyAccepted;

  @override
  List<Object?> get props => [
        step,
        user,
        tosAccepted,
        privacyAccepted,
        isInviteFlow,
      ];
}

final class OnboardingOrganizationSetup extends OnboardingUserState {
  const OnboardingOrganizationSetup({
    required super.user,
    required this.name,
    required this.nameController,
    required this.selectedOrganisms,
    required this.selectedSiteTypes,
    this.slug = '',
    this.slugController,
    this.errorMessage,
    super.step = OnboardingStep.organizationSetup,
  });

  final TextEditingController nameController;
  final TextEditingController? slugController;
  final OrganizationName name;
  final String slug; // Suggested slug auto-generated from name
  final List<OrganismKind> selectedOrganisms;
  final List<SiteType> selectedSiteTypes;
  final String? errorMessage;

  bool get isValid =>
      name.isValid &&
      slug.isNotEmpty &&
      selectedOrganisms.isNotEmpty &&
      selectedSiteTypes.isNotEmpty;

  OnboardingOrganizationSetup copyWith({
    String? nameString,
    String? slug,
    List<OrganismKind>? selectedOrganisms,
    List<SiteType>? selectedSiteTypes,
    String? errorMessage,
    bool clearError = false,
  }) {
    // Don't update controller text here - it's managed by the TextField's onChanged callback
    // Updating it here can cause conflicts with the TextField's internal state
    return OnboardingOrganizationSetup(
      user: user,
      name: nameString != null
          ? OrganizationName.dirty(
              value: nameString,
              isNameAvailable: name.isNameAvailable,
            )
          : name,
      nameController: nameController,
      slugController: slugController,
      slug: slug ?? this.slug,
      selectedOrganisms: selectedOrganisms ?? this.selectedOrganisms,
      selectedSiteTypes: selectedSiteTypes ?? this.selectedSiteTypes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String? validate() {
    if (!name.isValid) return name.displayError?.message;
    if (slug.isEmpty) return 'Organization domain is required';
    if (selectedOrganisms.isEmpty) {
      return 'Please select at least one organism type';
    }
    if (selectedSiteTypes.isEmpty) {
      return 'Please select at least one site type';
    }
    return null;
  }

  @override
  bool get isPure => name.isPure;

  @override
  List<Object?> get props => [
        step,
        user,
        name,
        slug,
        // Don't include nameController or slugController in props
        // Reason: TextEditingControllers are mutable objects managed by the cubit
        // Including them would cause unnecessary rebuilds on text changes
        // and violate Equatable's immutability principle
        selectedOrganisms,
        selectedSiteTypes,
        errorMessage,
      ];
}

final class OnboardingUserProfile extends OnboardingUserState {
  const OnboardingUserProfile({
    required super.user,
    required this.name,
    this.tagline = '',
    super.isInviteFlow,
  }) : super(step: OnboardingStep.userProfile);

  OnboardingUserProfile copyWith({
    String? nameString,
    String? taglineString,
    User? user,
  }) {
    return OnboardingUserProfile(
      user: user ?? (nameString != null ? this.user.copyWith(name: nameString) : this.user),
      name: nameString != null ? UserName.dirty(value: nameString) : name,
      tagline: taglineString ?? tagline,
      isInviteFlow: isInviteFlow,
    );
  }

  final UserName name;
  
  /// Optional user tagline/bio
  final String tagline;


  @override
  String? validate() {
    return name.displayError?.message;
  }

  @override
  bool get isPure => name.isPure;

  @override
  List<Object?> get props => [step, user, name.value, tagline, isInviteFlow];
}

final class OnboardingSiteSetup extends OnboardingUserState {
  const OnboardingSiteSetup({
    required super.user,
    required this.siteNameController,
    required this.structureNameController,
    this.selectedStructureTypeId,
    this.selectedSubstructureTypeId,
    this.errorMessage,
    this.isSubmitting = false,
    super.step = OnboardingStep.siteSetup,
  });

  final TextEditingController siteNameController;
  final TextEditingController structureNameController;

  /// Selected structure type ID (e.g., 'group_type_tank', 'group_type_tree')
  /// Defaults to first structure type for the site if not set
  final String? selectedStructureTypeId;

  /// Selected substructure type ID (e.g., 'group_type_tray', 'group_type_tree_branch')
  /// Allows subdividing structures
  final String? selectedSubstructureTypeId;

  final String? errorMessage;
  final bool isSubmitting;

  OnboardingSiteSetup copyWith({
    String? errorMessage,
    String? selectedStructureTypeId,
    String? selectedSubstructureTypeId,
    bool? isSubmitting,
    bool clearError = false,
    bool clearSubstructure = false,
  }) {
    return OnboardingSiteSetup(
      user: user,
      siteNameController: siteNameController,
      structureNameController: structureNameController,
      selectedStructureTypeId: selectedStructureTypeId ?? this.selectedStructureTypeId,
      selectedSubstructureTypeId: clearSubstructure ? null : (selectedSubstructureTypeId ?? this.selectedSubstructureTypeId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  String? validate() {
    if (siteNameController.text.trim().isEmpty) {
      return 'Site name is required';
    }
    if (structureNameController.text.trim().isEmpty) {
      return 'Structure name is required';
    }
    return null;
  }

  @override
  bool get isPure => true; // Controllers manage their own dirtiness visually

  @override
  List<Object?> get props => [
        step,
        user,
        selectedStructureTypeId,
        selectedSubstructureTypeId,
        errorMessage,
        isSubmitting,
      ];
}

final class OnboardingFirstOrganismSetup extends OnboardingUserState {
  const OnboardingFirstOrganismSetup({
    required super.user,
    required this.localIdController,
    required this.selectedSpecies,
    required this.siteId,
    required this.groupId,
    required this.organismKind,
    this.quantityController,
    this.recordNameController,
    this.isRecordNameManuallyEdited = false,
    this.selectedLifeStage,
    this.initialQuantity = 1,
    this.selectedProvenanceType = ProvenanceType.wild,
    this.collectionMethod,
    this.collectionDate,
    this.cohortName,
    this.cohortDate,
    this.clonalId = '',
    this.accessionNumber = '',
    this.aliasId = '',
    this.provenanceId = '',
    this.provenanceSearch = const ProvenanceSearchState(),
    this.errorMessage,
    this.isSubmitting = false,
    this.isLocalIdManuallyEdited = false,
    super.step = OnboardingStep.firstOrganismSetup,
  });

  final TextEditingController localIdController;
  final TextEditingController? quantityController;
  final TextEditingController? recordNameController;
  final bool isRecordNameManuallyEdited;
  final bool isLocalIdManuallyEdited;
  final Species? selectedSpecies;
  final String siteId;
  final String groupId;
  final OrganismKind organismKind;
  final LifeStage? selectedLifeStage;
  final int initialQuantity;

  // Provenance fields
  final ProvenanceType selectedProvenanceType;
  final String? collectionMethod; // For wild/founder
  final DateTime? collectionDate; // For wild/founder
  final String? cohortName; // For cohort
  final DateTime? cohortDate; // For cohort spawn/settlement date
  final String clonalId;
  final String accessionNumber;
  final String aliasId;
  final String provenanceId;
  final ProvenanceSearchState provenanceSearch;
  final String? errorMessage;
  final bool isSubmitting;

  OnboardingFirstOrganismSetup copyWith({
    Species? selectedSpecies,
    LifeStage? selectedLifeStage,
    int? initialQuantity,
    ProvenanceType? selectedProvenanceType,
    String? collectionMethod,
    DateTime? collectionDate,
    String? cohortName,
    DateTime? cohortDate,
    String? clonalId,
    String? accessionNumber,
    String? aliasId,
    String? provenanceId,
    ProvenanceSearchState? provenanceSearch,
    String? errorMessage,
    bool? isSubmitting,
    bool? isRecordNameManuallyEdited,
    bool? isLocalIdManuallyEdited,
    bool clearCollectionMethod = false,
    bool clearCollectionDate = false,
    bool clearCohortName = false,
    bool clearCohortDate = false,
    bool clearClonalId = false,
    bool clearAccessionNumber = false,
    bool clearAliasId = false,
    bool clearProvenanceId = false,
    bool clearError = false,
  }) {
    return OnboardingFirstOrganismSetup(
      user: user,
      localIdController: localIdController,
      quantityController: quantityController,
      recordNameController: recordNameController,
      isRecordNameManuallyEdited:
          isRecordNameManuallyEdited ?? this.isRecordNameManuallyEdited,
      isLocalIdManuallyEdited:
          isLocalIdManuallyEdited ?? this.isLocalIdManuallyEdited,
      selectedSpecies: selectedSpecies ?? this.selectedSpecies,
      siteId: siteId,
      groupId: groupId,
      organismKind: organismKind,
      selectedLifeStage: selectedLifeStage ?? this.selectedLifeStage,
      initialQuantity: initialQuantity ?? this.initialQuantity,
      selectedProvenanceType: selectedProvenanceType ?? this.selectedProvenanceType,
      collectionMethod: clearCollectionMethod ? null : (collectionMethod ?? this.collectionMethod),
      collectionDate: clearCollectionDate ? null : (collectionDate ?? this.collectionDate),
      cohortName: clearCohortName ? null : (cohortName ?? this.cohortName),
      cohortDate: clearCohortDate ? null : (cohortDate ?? this.cohortDate),
      clonalId: clearClonalId ? '' : (clonalId ?? this.clonalId),
      accessionNumber:
          clearAccessionNumber ? '' : (accessionNumber ?? this.accessionNumber),
      aliasId: clearAliasId ? '' : (aliasId ?? this.aliasId),
      provenanceId:
          clearProvenanceId ? '' : (provenanceId ?? this.provenanceId),
      provenanceSearch: provenanceSearch ?? this.provenanceSearch,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  String? validate() {
    if (localIdController.text.trim().isEmpty) {
      return 'Please enter a local ID for your first genet';
    }
    if (selectedSpecies == null) {
      return 'Please select a species';
    }
    if (selectedLifeStage == null) {
      return 'Please select a life stage';
    }
    if (initialQuantity < 1) {
      return 'Initial quantity must be at least 1';
    }
    if (provenanceSearch.hasConflict) {
      return provenanceSearch.conflictMessage ??
          'Conflicting provenance matches. Clear one field to resolve.';
    }
    return null;
  }

  @override
  bool get isPure =>
      localIdController.text.isEmpty &&
      selectedSpecies == null &&
      selectedLifeStage == null &&
      clonalId.isEmpty &&
      accessionNumber.isEmpty &&
      aliasId.isEmpty &&
      provenanceId.isEmpty;

  @override
  List<Object?> get props => [
        step,
        user,
        selectedSpecies,
        siteId,
        groupId,
        organismKind,
        selectedLifeStage,
        initialQuantity,
        isRecordNameManuallyEdited,
        isLocalIdManuallyEdited,
        selectedProvenanceType,
        collectionMethod,
        collectionDate,
        cohortName,
        cohortDate,
        clonalId,
        accessionNumber,
        aliasId,
        provenanceId,
        provenanceSearch,
        errorMessage,
        isSubmitting,
      ];
}

final class OnboardingEducation extends OnboardingUserState {
  const OnboardingEducation({
    required super.user,
    this.coralUrlPath,
    super.step = OnboardingStep.education,
  });

  /// URL path of the first coral created, used for tour navigation
  final String? coralUrlPath;

  @override
  String? validate() => null;

  @override
  bool get isPure => true;

  @override
  List<Object?> get props => [step, user, coralUrlPath];
}

final class OnboardingComplete extends OnboardingState {
  const OnboardingComplete({this.targetPath}) : super(step: OnboardingStep.complete);

  /// Optional path to navigate to after onboarding (e.g. created organism)
  final String? targetPath;

  @override
  String? validate() => null;

  @override
  bool get isPure => false;

  @override
  List<Object?> get props => [step, targetPath];
}

/// Error state emitted when a deep link invitation was sent to a different email
/// than the currently authenticated user. The UI should display this error and
/// prompt the user to sign in with the correct email address.
final class OnboardingInviteEmailMismatch extends OnboardingState {
  const OnboardingInviteEmailMismatch({
    required this.invitationEmail,
    required this.currentUserEmail,
  }) : super(step: OnboardingStep.initial);

  /// The email address the invitation was sent to
  final String invitationEmail;

  /// The email of the currently authenticated user
  final String currentUserEmail;

  @override
  String? validate() =>
      'This invitation was sent to $invitationEmail, but you are signed in as $currentUserEmail. '
      'Please sign in with $invitationEmail to accept this invitation.';

  @override
  bool get isPure => true;

  @override
  List<Object?> get props => [step, invitationEmail, currentUserEmail];
}
