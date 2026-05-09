// @tier: community
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth show User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/navigation/deep_link_cubit.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/mixins/provenance_search_mixin.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';
import 'package:seafoundry_app/services/legal_documents_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/utils/extensions.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

part 'onboarding_state.dart';

enum OnboardingStep {
  initial,
  loading,
  organizationSetup,
  userProfile,
  legalAcceptance, // Moved after userProfile
  siteSetup,
  education, // 5-Axis model explanation - moved before first organism
  firstOrganismSetup, // Create first genet and organism
  complete,
}

class OnboardingCubit extends Cubit<OnboardingState>
    with CubitStreamSubscriptionMixin, ProvenanceSearchMixin<OnboardingState> {
  OnboardingCubit({
    required this.onComplete,
    required this.repository,
    required this.invitationRepository,
    this.provenanceLookupService,
  }) : super(OnboardingInitial());
  List<Organization>? _allOrganizations;
  bool _organizationsLoaded = false;
  final OnboardingRepository repository;
  final InvitationRepository invitationRepository;
  final List<TextEditingController> _managedControllers = [];
  @override
  final ProvenanceLookupService? provenanceLookupService;

  final void Function(String? targetPath) onComplete;
  Timer? _recordNameSuggestionTimer;
  int _recordNameSuggestionRequestId = 0;

  // ---------------------------------------------------------------------------
  // ProvenanceSearchMixin requirements (used during first-organism onboarding)
  // ---------------------------------------------------------------------------

  @override
  String? get currentSpeciesCode {
    final current = state;
    if (current is OnboardingFirstOrganismSetup) {
      return current.selectedSpecies?.code;
    }
    return null;
  }

  @override
  ProvenanceSearchState get currentProvenanceSearch {
    final current = state;
    if (current is OnboardingFirstOrganismSetup) {
      return current.provenanceSearch;
    }
    return const ProvenanceSearchState();
  }

  @override
  void emitProvenanceSearch(ProvenanceSearchState search) {
    final current = state;
    if (current is OnboardingFirstOrganismSetup) {
      emit(current.copyWith(provenanceSearch: search));
    }
  }

  void _ensureOrganizationSubscription() {
    // listenWithKey auto-cancels existing subscription for the same key
    listenWithKey<List<Organization>>(
      'allOrganizations',
      repository.allOrganizations,
      onData: (organizations) {
        if (isClosed) return;
        _allOrganizations = organizations;
        _organizationsLoaded = true;
      },
    );
  }

  TextEditingController _registerController(TextEditingController controller) {
    _managedControllers.add(controller);
    return controller;
  }

  void load({
    required auth.User authUser,
    User? user,
    InviteContext? inviteContext,
    String? displayName,
  }) {
    if (state is! OnboardingInitial) {
      return;
    }
    _ensureOrganizationSubscription();
    if (user != null) {
      _loadUser(user);
    } else {
      _loadAuthUser(
        authUser,
        inviteContext: inviteContext,
        displayName: displayName,
      );
    }
  }

  Future<void> _loadAuthUser(
    auth.User authUser, {
    InviteContext? inviteContext,
    String? displayName,
  }) async {
    if (state is OnboardingInitial) {
      // Debug: Log Firebase Auth user details for security rules debugging
      if (kDebugMode) {
        LoggingService.instance.debug(
          'OnboardingCubit._loadAuthUser: Firebase Auth user details - '
          'uid: ${authUser.uid}, email: ${authUser.email}, '
          'emailVerified: ${authUser.emailVerified}, '
          'providerData: ${authUser.providerData.map((p) => '${p.providerId}: ${p.email}').join(', ')}',
        );
      }

      final String userId = authUser.uid;
      final String? normalizedEmail = UserIdentity.normalizeEmail(
        authUser.email,
      );
      final String inviteLookupEmail =
          normalizedEmail ?? authUser.email?.trim() ?? '';
      final String resolvedEmail = inviteLookupEmail.isNotEmpty
          ? inviteLookupEmail
          : authUser.uid;
      final String? name = displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (authUser.displayName?.trim().isEmpty ?? true
                ? null
                : authUser.displayName!.trim());

      if (kDebugMode) {
        LoggingService.instance.debug(
          'OnboardingCubit: userId (user.id): $userId, '
          'inviteLookupEmail (user.email): $inviteLookupEmail',
        );
      }

      if (!communityInvitationsEnabled) {
        final user = User(
          id: userId,
          email: resolvedEmail,
          name: name ?? '',
          imageUrl: authUser.photoURL,
          role: UserRole.practitioner.id,
          createdById: userId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          updatedById: userId,
          organizationId: Missing.string,
        );
        // Start with user profile, then move to organization setup
        emit(
          OnboardingUserProfile(
            user: user,
            name: UserName.dirty(value: name ?? ''),
            tagline: '',
            isInviteFlow: false,
          ),
        );
        return;
      }

      // CRITICAL: Check for pending invitations BEFORE emitting any state
      // Invitation flow must bypass legal acceptance and go straight to userName
      // Priority: 1. Deep link invite ID, 2. Email-based lookup
      try {
        List<Invitation> invitations = [];

        // If we have a deep link invite context, try to fetch that invitation first
        if (inviteContext != null) {
          final directInvite = await invitationRepository.getInvitationById(
            inviteContext.invitationId,
          );
          if (directInvite != null &&
              directInvite.isPending &&
              directInvite.email.toLowerCase() ==
                  inviteLookupEmail.toLowerCase()) {
            invitations = [directInvite];
            LoggingService.instance.info(
              'OnboardingCubit: Using invitation from deep link: ${inviteContext.invitationId}',
            );
          } else if (directInvite != null &&
              directInvite.email.toLowerCase() !=
                  inviteLookupEmail.toLowerCase()) {
            // CRITICAL: When there's a direct invite ID but email mismatch, do NOT silently
            // fall back to a different invitation. This could cause user to accept wrong invitation.
            // Emit an error state that the UI can handle to show the mismatch.
            LoggingService.instance.warning(
              'OnboardingCubit: Invitation email mismatch. Invite: ${directInvite.email}, User: ${authUser.email}',
            );
            if (isClosed) return;
            emit(
              OnboardingInviteEmailMismatch(
                invitationEmail: directInvite.email,
                currentUserEmail: authUser.email ?? authUser.uid,
              ),
            );
            return;
          }
        }

        // Fallback to email-based lookup ONLY if no deep link invite was provided
        // (i.e., inviteContext was null). If a deep link was provided but didn't match,
        // we already returned above with an error state.
        if (invitations.isEmpty && inviteContext == null) {
          invitations = await invitationRepository
              .getPendingInvitationsForEmail(inviteLookupEmail);
        }

        if (isClosed) return;

        // Capture first invitation immediately to avoid race condition with concurrent state updates
        final Invitation? firstInvitation = invitations.isNotEmpty
            ? invitations.first
            : null;
        final bool isInviteFlow = firstInvitation != null;

        // If user has an invitation, use the organization from the invitation
        final String organizationId = isInviteFlow
            ? firstInvitation.organizationId
            : Missing.string;

        final user = User(
          id: userId,
          email: resolvedEmail,
          name: name ?? '',
          imageUrl: authUser.photoURL,
          role: UserRole.practitioner.id,
          createdById: userId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          updatedById: userId,
          organizationId: organizationId,
        );

        if (isInviteFlow) {
          // Invite flow: skip organization setup, go directly to userProfile
          emit(
            OnboardingUserProfile(
              user: user,
              name: name != null && name.isNotEmpty
                  ? UserName.dirty(value: name)
                  : const UserName.pure(),
              isInviteFlow: true,
            ),
          );
        } else {
          // New org flow: start with organization setup
          emit(
            OnboardingOrganizationSetup(
              user: user,
              name: OrganizationName.pure(isNameAvailable: _isNameAvailable),
              nameController: _registerController(TextEditingController()),
              slugController: _registerController(TextEditingController()),
              selectedOrganisms: [],
              selectedSiteTypes: [],
            ),
          );
        }
      } catch (error) {
        if (isClosed) return;
        // Fallback to organization setup if invitation check fails
        LoggingService.instance.error(
          'Failed to check invitations for ${authUser.email}',
          error,
        );
        final user = User(
          id: userId,
          email: resolvedEmail,
          name: name ?? '',
          imageUrl: authUser.photoURL,
          role: UserRole.practitioner.id,
          createdById: userId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
          updatedById: userId,
          organizationId: Missing.string,
        );
        emit(
          OnboardingOrganizationSetup(
            user: user,
            name: OrganizationName.pure(isNameAvailable: _isNameAvailable),
            nameController: _registerController(TextEditingController()),
            slugController: _registerController(TextEditingController()),
            selectedOrganisms: [],
            selectedSiteTypes: [],
          ),
        );
      }
    }
  }

  Future<void> _createUser() async {
    if (state is! OnboardingUserProfile) {
      throw Exception('createUser called with wrong state: $state');
    }
    final userProfileState = state as OnboardingUserProfile;
    emit(OnboardingLoading());

    // Accept pending invitation if in invite flow
    if (userProfileState.isInviteFlow && communityInvitationsEnabled) {
      // For invite flow, mark onboarding as complete when joining existing org
      // Use createUser() because user document doesn't exist yet in Firestore
      // (user was only created in memory during _loadAuthUser)
      final userWithOnboardingComplete = userProfileState.user.copyWith(
        onboardingCompletedAt: DateTime.now(),
        tagline: userProfileState.tagline.isNotEmpty
            ? userProfileState.tagline
            : null,
      );
      final User user = await repository.createUser(userWithOnboardingComplete);
      if (isClosed) return;
      await _acceptInvitation(user);
      if (isClosed) return;
      // Invite flow skips site setup and education (assuming joining existing org)
      emit(const OnboardingComplete());
    } else if (userProfileState.isInviteFlow) {
      final userWithTagline = userProfileState.user.copyWith(
        tagline: userProfileState.tagline.isNotEmpty
            ? userProfileState.tagline
            : null,
      );
      final User user = await repository.createUser(userWithTagline);
      if (isClosed) return;
      emit(
        OnboardingLegalAcceptance(
          user: user,
          tosAccepted: false,
          privacyAccepted: false,
          isInviteFlow: false,
        ),
      );
    } else {
      // New org flow: don't create user yet, go to organization setup
      // User + org will be created together in _createOrganization()
      final updatedUserData = userProfileState.user.copyWith(
        name: userProfileState.name.value,
        tagline: userProfileState.tagline.isNotEmpty
            ? userProfileState.tagline
            : null,
      );
      if (isClosed) return;
      emit(
        OnboardingOrganizationSetup(
          user: updatedUserData,
          name: OrganizationName.pure(isNameAvailable: _isNameAvailable),
          nameController: _registerController(TextEditingController()),
          slugController: _registerController(TextEditingController()),
          selectedOrganisms: [],
          selectedSiteTypes: [],
        ),
      );
    }
  }

  Future<void> _loadUser(User user) async {
    // CRITICAL: Check if this is an invite flow BEFORE emitting any state
    // Invite flow is true when an organizationId is already set on the user.
    final bool isInviteFlow =
        user.organizationId.isNotEmpty && !user.organizationId.isMissing;

    if (isInviteFlow) {
      // Invite flow: skip organization setup, go directly to userProfile
      emit(
        OnboardingUserProfile(
          user: user,
          name: user.name.isNotEmpty
              ? UserName.dirty(value: user.name)
              : const UserName.pure(),
          isInviteFlow: true,
        ),
      );
    } else {
      // New org flow: start with organization setup
      emit(
        OnboardingOrganizationSetup(
          user: user,
          name: OrganizationName.pure(isNameAvailable: _isNameAvailable),
          nameController: _registerController(TextEditingController()),
          slugController: _registerController(TextEditingController()),
          selectedOrganisms: [],
          selectedSiteTypes: [],
        ),
      );
    }
  }

  Future<void> _createOrganization(
    OnboardingOrganizationSetup setupState,
  ) async {
    LoggingService.instance.info(
      '🚀 Starting organization creation: ${setupState.name.value}',
    );

    emit(OnboardingLoading());

    try {
      // Use the user-configured slug as the domain
      final domain = setupState.slug;

      // Derive default activities from selected site types
      // Use the actual selected site types as activities
      final activities = setupState.selectedSiteTypes
          .map((siteType) => siteType.id)
          .toList();

      // Debug: Log user data for security rules debugging
      if (kDebugMode) {
        LoggingService.instance.debug(
          'OnboardingCubit._createOrganization: User data - '
          'id: ${setupState.user.id}, email: ${setupState.user.email}, '
          'createdById: ${setupState.user.createdById}',
        );
      }

      final (Organization organization, User user) = await repository
          .createOrganization(
            setupState.name.value,
            setupState.user,
            activities,
            [], // No species initially - can be added via admin panel
            domain,
            heroImageUrl: null,
            logoUrl: null,
            accentColor: null,
            supportedOrganismKinds:
                setupState.selectedOrganisms, // Pass organisms to organization
          );

      LoggingService.instance.info(
        '✅ Organization created: ${organization.id}',
      );

      if (isClosed) return;

      // After organization is created, go to legal acceptance
      // (userProfile already happened before org setup)
      emit(
        OnboardingLegalAcceptance(
          user: user,
          tosAccepted: false,
          privacyAccepted: false,
          isInviteFlow: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;

      LoggingService.instance.error(
        'Organization creation failed',
        error,
        stackTrace,
      );

      final domainError = domainErrors.ErrorHandler.transformError(
        error,
        stackTrace: stackTrace,
        context: 'create organization',
      );
      final errorMessage = domainErrors.ErrorHandler.getDisplayMessage(
        domainError,
        includeDetails: kDebugMode,
      );

      // Return to setup state with error - user can try again
      emit(setupState.copyWith(errorMessage: errorMessage));
    }
  }

  String? _lastCreatedSiteId;
  String? _lastCreatedGroupId;
  OrganismKind? _lastOrganismKind;

  Future<void> _createSiteAndStructure() async {
    if (state is! OnboardingSiteSetup) {
      throw Exception('createSiteAndStructure called with wrong state: $state');
    }
    final siteState = state as OnboardingSiteSetup;

    // Show submitting state (keeps siteState with loading indicator)
    emit(siteState.copyWith(isSubmitting: true, clearError: true));

    try {
      // Fetch organization to get site types (activities)
      final organization = await repository.getOrganization(
        siteState.user.organizationId,
      );
      if (isClosed) return;

      // Determine best site type for the first site
      // Priority: 1. Ex-Situ Nursery (classic), 2. First selected type, 3. Default
      String siteTypeId = SiteType.nursery.id;
      if (organization != null && organization.activities.isNotEmpty) {
        if (organization.activities.contains(SiteType.nursery.id)) {
          siteTypeId = SiteType.nursery.id;
        } else {
          siteTypeId = organization.activities.first;
        }
      }

      // Create Site
      final site = await repository.createSite(
        siteState.siteNameController.text,
        siteState.user.organizationId,
        siteState.user,
        siteTypeId: siteTypeId,
      );
      if (isClosed) return;

      // Determine structure type: use selected or default to first structure type for site
      final siteTypeObj = SiteType.fromId(siteTypeId);
      final structureTypeId =
          siteState.selectedStructureTypeId ??
          siteTypeObj.groupTypes
              .where((g) => g.isStructure)
              .map((g) => g.id)
              .firstOrNull ??
          GroupType.tank.id;

      // Create Structure
      final group = await repository.createStructure(
        siteState.structureNameController.text,
        site.id,
        siteState.user.organizationId,
        siteState.user,
        structureTypeId: structureTypeId,
      );
      if (isClosed) return;

      // Store IDs for the organism creation step (after education)
      _lastCreatedSiteId = site.id;
      _lastCreatedGroupId = group.id;

      // Get organism kind from organization
      // Note: We already fetched organization above, but ensuring consistency
      const organismKind = OrganismKind.coral;
      _lastOrganismKind = organismKind; // Store for back navigation

      // Proceed to Education (5-Axis model) BEFORE first organism creation
      emit(OnboardingEducation(user: siteState.user));
    } catch (e, stack) {
      if (isClosed) return;
      LoggingService.instance.error(
        'Site/structure creation failed',
        e,
        stack,
      );

      final domainError = domainErrors.ErrorHandler.transformError(
        e,
        stackTrace: stack,
        context: 'create site and structure',
      );
      final errorMessage = domainErrors.ErrorHandler.getDisplayMessage(
        domainError,
        includeDetails: kDebugMode,
      );

      emit(siteState.copyWith(errorMessage: errorMessage, isSubmitting: false));
    }
  }

  /// Proceed from education to first organism setup.
  /// Uses stored site/group IDs from _createSiteAndStructure.
  void _proceedToFirstOrganismSetup() {
    final educationState = state;
    if (educationState is! OnboardingEducation) {
      throw Exception(
        '_proceedToFirstOrganismSetup called with wrong state: $state',
      );
    }

    final siteId = _lastCreatedSiteId;
    final groupId = _lastCreatedGroupId;
    final organismKind = _lastOrganismKind ?? OrganismKind.coral;

    if (siteId == null || groupId == null) {
      // Fallback: if IDs not available, skip to complete
      emit(const OnboardingComplete());
      return;
    }

    final defaultLifeStage = _getDefaultLifeStage(organismKind);
    final defaultLocalId = _getDefaultLocalId(organismKind);

    // Create and register tagId controller with localGenetId as default.
    final recordNameCtrl = _registerController(
      TextEditingController(text: defaultLocalId),
    );

    emit(
      OnboardingFirstOrganismSetup(
        user: educationState.user,
        localIdController: _registerController(
          TextEditingController(text: defaultLocalId),
        ),
        quantityController: _registerController(
          TextEditingController(text: '1'),
        ),
        recordNameController: recordNameCtrl,
        isRecordNameManuallyEdited: false,
        selectedSpecies: null,
        siteId: siteId,
        groupId: groupId,
        organismKind: organismKind,
        selectedLifeStage: defaultLifeStage,
        initialQuantity: 1,
      ),
    );

    // Upgrade to a unique adjective suggestion once available.
    _scheduleRecordNameSuggestion(defaultLocalId, debounce: false);
  }

  /// Get a sensible default life stage for the organism type
  LifeStage _getDefaultLifeStage(OrganismKind kind) {
    // Most organisms start as juveniles in nursery settings
    return LifeStage.juvenile;
  }

  /// Get a default local ID based on organism kind
  String _getDefaultLocalId(OrganismKind kind) {
    switch (kind) {
      case OrganismKind.coral:
        return 'CORAL-001';
    }
  }

  Future<void> _createFirstOrganism() async {
    if (state is! OnboardingFirstOrganismSetup) {
      throw Exception('createFirstOrganism called with wrong state: $state');
    }
    final organismState = state as OnboardingFirstOrganismSetup;
    if (organismState.isSubmitting) {
      return;
    }
    emit(organismState.copyWith(isSubmitting: true, clearError: true));

    try {
      final organismUrlPath = await repository.createFirstGenetAndOrganism(
        localGenetId: organismState.localIdController.text.trim(),
        species: organismState.selectedSpecies!,
        siteId: organismState.siteId,
        groupId: organismState.groupId,
        user: organismState.user,
        organismKind: organismState.organismKind,
        lifeStage: organismState.selectedLifeStage!,
        quantity: organismState.initialQuantity,
        provenanceType: organismState.selectedProvenanceType,
        collectionMethod: organismState.collectionMethod,
        collectionDate: organismState.collectionDate,
        cohortName: organismState.cohortName,
        cohortDate: organismState.cohortDate,
        clonalId: organismState.clonalId,
        accessionNumber: organismState.accessionNumber,
        inheritedProvenanceId:
            organismState.provenanceSearch.resolvedProvenanceId,
        tagId:
            organismState.recordNameController?.text.trim().isNotEmpty == true
            ? organismState.recordNameController!.text.trim()
            : null,
      );
      if (isClosed) return;

      // Proceed to Complete with organism URL path for tour
      emit(OnboardingComplete(targetPath: organismUrlPath));
    } catch (e, stack) {
      if (isClosed) return;
      LoggingService.instance.error(
        'Failed to create first organism',
        e,
        stack,
      );
      final domainError = domainErrors.ErrorHandler.transformError(
        e,
        stackTrace: stack,
        context: 'create first genet and organism',
      );
      final errorMessage = domainErrors.ErrorHandler.getDisplayMessage(
        domainError,
        includeDetails: kDebugMode,
      );
      final currentState = state;
      if (currentState is OnboardingFirstOrganismSetup) {
        emit(
          currentState.copyWith(
            errorMessage: errorMessage,
            isSubmitting: false,
          ),
        );
      }
    }
  }

  void setSelectedSpecies(Species? species) {
    if (state is OnboardingFirstOrganismSetup) {
      // Do NOT synchronously write localIdController.text here.
      // The async DB-aware suggestion (suggestNextOrganismLocalId) should be
      // the sole source of the localID value. The isEmpty guard in the UI
      // (first_genet_page.dart) protects user edits. A synchronous write
      // here races with the async suggestion and breaks that guard.

      // Reset provenance search (species-scoped) and clear alias inputs
      onProvenanceSearchReset();
      final refreshed = state as OnboardingFirstOrganismSetup;
      emit(
        refreshed.copyWith(
          selectedSpecies: species,
          clonalId: '',
          accessionNumber: '',
          aliasId: '',
          provenanceId: '',
          clearError: true,
        ),
      );
    }
  }

  void setSelectedLifeStage(LifeStage? lifeStage) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          selectedLifeStage: lifeStage,
          clearError: true,
        ),
      );
    }
  }

  void setClonalId(String clonalId) {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;
    final normalized = clonalId.trim();
    emit(currentState.copyWith(clonalId: normalized, clearError: true));
    if (normalized.isNotEmpty) {
      onClonalIdSearchChanged(normalized);
    } else {
      onClonalIdSearchChanged('');
    }
  }

  void setAccessionNumber(String accessionNumber) {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;
    final normalized = accessionNumber.trim();
    emit(currentState.copyWith(accessionNumber: normalized, clearError: true));
    if (normalized.isNotEmpty) {
      onAccessionSearchChanged(normalized);
    } else {
      onAccessionSearchChanged('');
    }
  }

  void setAliasId(String aliasId) {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;
    final normalized = aliasId.trim();
    emit(currentState.copyWith(aliasId: normalized, clearError: true));
    if (normalized.isNotEmpty) {
      onAliasSearchChanged(normalized);
    } else {
      onAliasSearchChanged('');
    }
  }

  void setProvenanceId(String provenanceId) {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;
    final normalized = provenanceId.trim();
    emit(currentState.copyWith(provenanceId: normalized, clearError: true));
    if (normalized.isNotEmpty) {
      onProvenanceIdSearchChanged(normalized);
    } else {
      onProvenanceIdSearchChanged('');
    }
  }

  void clearProvenanceSelection() {
    if (state is! OnboardingFirstOrganismSetup) return;
    onProvenanceSearchReset();
    final currentState = state as OnboardingFirstOrganismSetup;
    emit(
      currentState.copyWith(
        clearClonalId: true,
        clearAccessionNumber: true,
        clearAliasId: true,
        clearProvenanceId: true,
        clearError: true,
      ),
    );
  }

  void setActiveProvenanceField(ProvenanceMatchField field) {
    emitProvenanceSearch(currentProvenanceSearch.copyWith(activeField: field));
  }

  Future<void> selectProvenanceSuggestion(
    ProvenanceSuggestion suggestion,
    ProvenanceMatchField field,
  ) async {
    if (state is! OnboardingFirstOrganismSetup) return;
    onProvenanceSuggestionSelected(suggestion, field);
    var currentState = state as OnboardingFirstOrganismSetup;

    // Auto-select species if provided by suggestion
    Species? newSpecies = currentState.selectedSpecies;
    bool speciesChanged = false;

    if (suggestion.speciesCode.isNotEmpty) {
      final allSpecies = SpeciesRegistry.globalAll();
      final match = allSpecies
          .where(
            (s) => s.code.toUpperCase() == suggestion.speciesCode.toUpperCase(),
          )
          .firstOrNull;

      if (match != null && match != currentState.selectedSpecies) {
        newSpecies = match;
        speciesChanged = true;
      }
    }

    // Update state with new values (and species if changed)
    emit(
      currentState.copyWith(
        selectedSpecies: newSpecies,
        clonalId: field == ProvenanceMatchField.clonalId
            ? ClonalIdDisplayService.resolveForSuggestion(suggestion)
            : currentState.clonalId,
        accessionNumber: field == ProvenanceMatchField.accessionNumber
            ? suggestion.aliasValue
            : currentState.accessionNumber,
        aliasId: field == ProvenanceMatchField.alias
            ? suggestion.aliasValue
            : currentState.aliasId,
        provenanceId: suggestion.provenanceId,
        clearError: true,
      ),
    );

    // If species changed, attempt to auto-suggest Local ID
    // (Mimics logic in OnboardingSpeciesSelector callback)
    if (speciesChanged && newSpecies != null) {
      // Refresh state reference
      currentState = state as OnboardingFirstOrganismSetup;

      // Only overwrite if generic/empty or purely auto-generated
      if (currentState.localIdController.text.isEmpty ||
          !currentState.isLocalIdManuallyEdited) {
        try {
          final suggestedId = await suggestNextOrganismLocalId(newSpecies);
          if (suggestedId != null && !isClosed) {
            currentState.localIdController.text = suggestedId;
            // We don't need to emit again just for controller text
            // unless we want to track 'lastSuggested'.
            // But let's follow the pattern:
            updateLocalIdFromAutoSuggestion(suggestedId);
          }
        } catch (e) {
          LoggingService.instance.debug(
            'Failed to auto-suggest ID on species switch: $e',
          );
        }
      }
    }
  }

  void setInitialQuantity(int quantity) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          initialQuantity: quantity,
          clearError: true,
        ),
      );
    }
  }

  void setSelectedProvenanceType(ProvenanceType type) {
    if (state is OnboardingFirstOrganismSetup) {
      final currentState = state as OnboardingFirstOrganismSetup;
      // Clear type-specific metadata when changing provenance type
      emit(
        currentState.copyWith(
          selectedProvenanceType: type,
          // Update life stage to the default for this provenance type
          selectedLifeStage: type.defaultLifeStage,
          // Clear metadata from other types
          clearCollectionMethod: true,
          clearCollectionDate: true,
          clearCohortName: true,
          clearCohortDate: true,
          clearError: true,
        ),
      );
    }
  }

  void setCollectionMethod(String? method) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          collectionMethod: method,
          clearError: true,
        ),
      );
    }
  }

  void setCollectionDate(DateTime? date) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          collectionDate: date,
          clearError: true,
        ),
      );
    }
  }

  void setCohortName(String? name) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          cohortName: name,
          clearError: true,
        ),
      );
    }
  }

  void setCohortDate(DateTime? date) {
    if (state is OnboardingFirstOrganismSetup) {
      emit(
        (state as OnboardingFirstOrganismSetup).copyWith(
          cohortDate: date,
          clearError: true,
        ),
      );
    }
  }

  /// Handle record name edits and lock out auto-suggestions while manual.
  void recordNameChanged(String value) {
    if (state is OnboardingFirstOrganismSetup) {
      final currentState = state as OnboardingFirstOrganismSetup;
      final isManual = value.trim().isNotEmpty;
      if (isManual) {
        _recordNameSuggestionTimer?.cancel();
        _recordNameSuggestionRequestId += 1;
      } else if (currentState.isRecordNameManuallyEdited) {
        final localGenetId = currentState.localIdController.text.trim();
        if (localGenetId.isNotEmpty) {
          _scheduleRecordNameSuggestion(localGenetId, debounce: false);
        }
      }
      if (currentState.isRecordNameManuallyEdited != isManual) {
        emit(
          currentState.copyWith(
            isRecordNameManuallyEdited: isManual,
            clearError: true,
          ),
        );
      }
    }
  }

  /// Handle local ID edits and keep tagId auto-suggested when allowed.
  void localIdChanged(String localGenetId) {
    if (state is! OnboardingFirstOrganismSetup) return;
    var currentState = state as OnboardingFirstOrganismSetup;

    // specific check to avoid unnecessary emits
    if (!currentState.isLocalIdManuallyEdited) {
      emit(currentState.copyWith(isLocalIdManuallyEdited: true));
    }
    _processLocalIdChange(localGenetId);
  }

  /// Update local ID from auto-suggestion (no manual edit flag).
  void updateLocalIdFromAutoSuggestion(String localGenetId) {
    _processLocalIdChange(localGenetId);
  }

  void _processLocalIdChange(String localGenetId) {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;

    if (currentState.isRecordNameManuallyEdited) return;
    final trimmed = localGenetId.trim();
    if (trimmed.isEmpty) return;
    if (currentState.recordNameController != null) {
      currentState.recordNameController!.text = trimmed;
    }
    _scheduleRecordNameSuggestion(trimmed);
  }

  void _scheduleRecordNameSuggestion(String localGenetId, {bool debounce = true}) {
    _recordNameSuggestionTimer?.cancel();
    if (!debounce) {
      _suggestRecordName(localGenetId);
      return;
    }
    _recordNameSuggestionTimer = Timer(
      const Duration(milliseconds: 300),
      () => _suggestRecordName(localGenetId),
    );
  }

  Future<void> _suggestRecordName(String localGenetId) async {
    if (state is! OnboardingFirstOrganismSetup) return;
    final currentState = state as OnboardingFirstOrganismSetup;
    if (currentState.isRecordNameManuallyEdited) return;
    final requestId = ++_recordNameSuggestionRequestId;
    final suggestion = await repository.suggestRecordName(
      organizationId: currentState.user.organizationId,
      localGenetId: localGenetId,
    );
    if (isClosed) return;
    if (requestId != _recordNameSuggestionRequestId) return;
    final latestState = state;
    if (latestState is! OnboardingFirstOrganismSetup) return;
    if (latestState.isRecordNameManuallyEdited) return;
    if (suggestion != null && latestState.recordNameController != null) {
      latestState.recordNameController!.text = suggestion;
    }
  }

  /// Suggest the next organism local ID based on the selected species.
  ///
  /// Uses the organization's existing organism records to find the next
  /// available ID in the format: {SpeciesCode}-{number} (e.g., Apal-001, Acer-023).
  Future<String?> suggestNextOrganismLocalId(Species species) async {
    if (state is! OnboardingFirstOrganismSetup) {
      return null;
    }
    final organismState = state as OnboardingFirstOrganismSetup;

    try {
      return await repository.suggestNextOrganismLocalId(
        speciesId: species.id,
        organizationId: organismState.user.organizationId,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to suggest organism local ID',
        e,
        stackTrace,
      );
      // Fallback to basic format
      return '${species.id.toLowerCase().capitalizeFirst()}-1';
    }
  }

  /// Skip organism creation and proceed directly to complete
  void skipFirstOrganism() {
    if (state is! OnboardingFirstOrganismSetup) {
      LoggingService.instance.error(
        'skipFirstOrganism called with wrong state: $state',
      );
      return;
    }
    final organismState = state as OnboardingFirstOrganismSetup;
    _disposeStateControllers(organismState);

    // Skip directly to complete without creating any organism records
    emit(const OnboardingComplete());
  }

  /// Skip site creation and proceed directly to complete
  void skipSiteSetup() {
    if (state is! OnboardingSiteSetup) {
      LoggingService.instance.error(
        'skipSiteSetup called with wrong state: $state',
      );
      return;
    }
    final siteState = state as OnboardingSiteSetup;
    _disposeStateControllers(siteState);

    // Skip directly to complete without creating site/structure.
    // No site was created, so education->organism path would just
    // fall through to complete anyway. Skip the pointless detour.
    emit(const OnboardingComplete());
  }


  // close() is defined at the end of this class to merge all disposal logic

  /// Accept legal documents by updating user's legalAcceptances list
  /// Returns the updated user with legal acceptances
  Future<User> _acceptLegalDocuments(User user) async {
    try {
      // Get current legal documents
      final tos = LegalDocumentsService.getTermsOfService();
      final privacy = LegalDocumentsService.getPrivacyPolicy();

      // Create acceptance records
      final now = DateTime.now();
      final acceptances = [
        LegalAcceptance(
          documentId: tos.id,
          documentType: tos.type,
          documentVersion: tos.version,
          acceptedAt: now,
          userIp: null, // Could be collected from request context if needed
        ),
        LegalAcceptance(
          documentId: privacy.id,
          documentType: privacy.type,
          documentVersion: privacy.version,
          acceptedAt: now,
          userIp: null,
        ),
      ];

      // Update user with legal acceptances
      final updatedUser = user.copyWith(legalAcceptances: acceptances);
      await repository.updateUser(updatedUser);
      return updatedUser; // Return the updated user
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to accept legal documents',
        e,
        stackTrace,
      );
      // Return original user if legal acceptance fails (don't block onboarding)
      return user;
    }
  }

  /// Accept pending invitation for the user and create membership document
  Future<void> _acceptInvitation(User user) async {
    if (!communityInvitationsEnabled) {
      LoggingService.instance.info(
        'Invitation acceptance skipped: disabled in open-source build.',
      );
      return;
    }
    try {
      final invitations = await invitationRepository
          .getPendingInvitationsForEmail(user.email);

      // Capture first invitation immediately with null safety
      final invitation = invitations.firstOrNull;
      if (invitation == null) {
        LoggingService.instance.warning(
          'No pending invitations for ${user.email}',
        );
        return;
      }

      // Use atomic acceptance with role assignment
      final assignedRole = await invitationRepository.acceptInvitationAtomic(
        invitationId: invitation.id,
        acceptingUserEmail: user.email,
        userId: user.id,
        roleId: invitation.role,
      );

      LoggingService.instance.info(
        'Accepted invitation ${invitation.id} for ${user.email}, assigned role: $assignedRole',
      );

      LoggingService.instance.info(
        'Accepted invitation and ensured membership for invited user ${user.email}',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to accept invitation',
        e,
        stackTrace,
      );
      // Don't block onboarding on invitation acceptance failure
    }
  }

  Future<void> nextStep() async {
    switch (state.step) {
      case OnboardingStep.initial:
      case OnboardingStep.loading:
        throw Exception('nextStep called with bad state: $state');
      case OnboardingStep.organizationSetup:
        final setupState = state;
        if (setupState is! OnboardingOrganizationSetup) {
          LoggingService.instance.error(
            'Expected OnboardingOrganizationSetup but got ${setupState.runtimeType}',
          );
          return;
        }
        if (setupState.isValid) {
          // Create organization and proceed to userProfile
          // IMPORTANT: Must await to ensure errors are properly caught and displayed
          await _createOrganization(setupState);
        } else {
          if (kDebugMode) {
            debugPrint('🚫 Organization setup state is not valid:');
            debugPrint('   - name.isValid: ${setupState.name.isValid}');
            debugPrint('   - slug.isNotEmpty: ${setupState.slug.isNotEmpty}');
            debugPrint(
              '   - selectedOrganisms.isNotEmpty: ${setupState.selectedOrganisms.isNotEmpty}',
            );
            debugPrint(
              '   - selectedSiteTypes.isNotEmpty: ${setupState.selectedSiteTypes.isNotEmpty}',
            );
          }
        }
        break;
      case OnboardingStep.userProfile:
        await _createUser();
        break;
      case OnboardingStep.legalAcceptance:
        final legalState = state;
        if (legalState is! OnboardingLegalAcceptance) {
          LoggingService.instance.error(
            'Expected OnboardingLegalAcceptance but got ${legalState.runtimeType}',
          );
          return;
        }
        // Accept legal documents and wait for completion
        final updatedUser = await _acceptLegalDocuments(legalState.user);
        if (isClosed) return;

        // Proceed to site setup
        emit(
          OnboardingSiteSetup(
            user: updatedUser, // Use updated user with legal acceptances
            siteNameController: _registerController(
              TextEditingController(text: 'Main Nursery'),
            ),
            structureNameController: _registerController(
              TextEditingController(text: 'Tank 1'),
            ),
          ),
        );
        break;
      case OnboardingStep.siteSetup:
        await _createSiteAndStructure();
        break;
      case OnboardingStep.education:
        // After education, proceed to first organism setup
        _proceedToFirstOrganismSetup();
        break;
      case OnboardingStep.firstOrganismSetup:
        await _createFirstOrganism();
        break;
      case OnboardingStep.complete:
        final completeState = state as OnboardingComplete;
        onComplete(completeState.targetPath);
        break;
    }
  }

  /// Returns true if there is a previous step that can be navigated to
  bool canGoBack() {
    switch (state.step) {
      case OnboardingStep.initial:
      case OnboardingStep.loading:
      case OnboardingStep.complete:
      case OnboardingStep.userProfile: // First step in new flow
        return false;

      case OnboardingStep.organizationSetup:
      case OnboardingStep.legalAcceptance:
      case OnboardingStep.siteSetup:
      case OnboardingStep.firstOrganismSetup:
        return true; // All user-facing steps allow back

      case OnboardingStep.education:
        // If a site was already created, prevent going back to avoid
        // orphaned site/structure documents on re-forward.
        return _lastCreatedSiteId == null;
    }
  }

  void previousStep() {
    // Log warnings when navigating back from steps with created entities
    if (state.step == OnboardingStep.legalAcceptance) {
      LoggingService.instance.warning(
        'User navigating back from legalAcceptance - organization and user may have been created',
      );
    }

    if (state.step == OnboardingStep.education && _lastCreatedSiteId != null) {
      LoggingService.instance.warning(
        'User navigating back from education with site already created: $_lastCreatedSiteId',
      );
    }

    switch (state.step) {
      case OnboardingStep.initial:
      case OnboardingStep.loading:
      case OnboardingStep.complete:
        // No back navigation from technical states
        break;
      case OnboardingStep.userProfile:
        // First step - nowhere to go back to
        break;
      case OnboardingStep.organizationSetup:
        // Go back to user profile (nothing created yet, safe to navigate)
        final currentState = state;
        if (currentState is! OnboardingOrganizationSetup) return;

        emit(
          OnboardingUserProfile(
            user: currentState.user,
            name: currentState.user.name.isNotEmpty
                ? UserName.dirty(value: currentState.user.name)
                : UserName.pure(),
            tagline: currentState.user.tagline ?? '',
            isInviteFlow: false,
          ),
        );
        break;
      case OnboardingStep.legalAcceptance:
        // Go back to organization setup
        // Note: Org + user were created together, so this may create orphaned records
        // if user goes back and changes things. Acceptable risk for better UX.
        final currentState = state;
        if (currentState is! OnboardingLegalAcceptance) return;

        emit(
          OnboardingOrganizationSetup(
            user: currentState.user,
            name: OrganizationName.pure(isNameAvailable: _isNameAvailable),
            nameController: _registerController(TextEditingController()),
            slugController: _registerController(TextEditingController()),
            selectedOrganisms: [],
            selectedSiteTypes: [],
          ),
        );
        break;
      case OnboardingStep.siteSetup:
        // Go back to legal acceptance
        final currentState = state;
        if (currentState is! OnboardingSiteSetup) return;
        _disposeStateControllers(currentState);

        emit(
          OnboardingLegalAcceptance(
            user: currentState.user,
            tosAccepted: true, // They already accepted
            privacyAccepted: true,
            isInviteFlow: false,
          ),
        );
        break;
      case OnboardingStep.education:
        // If a site was already created, do NOT allow going back.
        // This prevents orphaned site/structure documents from being
        // created on re-forward (would call _createSiteAndStructure() again).
        if (_lastCreatedSiteId != null) return;

        // Going back from education to site setup
        final educationState = state;
        if (educationState is! OnboardingEducation) return;

        emit(
          OnboardingSiteSetup(
            user: educationState.user,
            siteNameController: _registerController(
              TextEditingController(text: 'Main Nursery'),
            ),
            structureNameController: _registerController(
              TextEditingController(text: 'Tank 1'),
            ),
          ),
        );
        break;
      case OnboardingStep.firstOrganismSetup:
        // Going back from first organism setup to education
        final currentState = state;
        if (currentState is! OnboardingFirstOrganismSetup) return;
        _disposeStateControllers(currentState);

        emit(OnboardingEducation(user: currentState.user));
        break;
    }
  }

  /// Dispose TextEditingControllers from a specific state to prevent memory leaks
  ///
  /// Called when transitioning away from a state that owns controllers.
  /// Removes controllers from the managed list before disposal to avoid
  /// double-disposal in the cubit's close() method.
  ///
  /// Currently handles:
  /// - OnboardingOrganizationSetup: nameController, slugController
  /// - OnboardingSiteSetup: siteNameController, structureNameController
  /// - OnboardingFirstOrganismSetup: localIdController, quantityController, recordNameController
  void _disposeStateControllers(OnboardingState state) {
    if (state is OnboardingOrganizationSetup) {
      state.nameController.dispose();
      _managedControllers.remove(state.nameController);

      if (state.slugController != null) {
        state.slugController!.dispose();
        _managedControllers.remove(state.slugController);
      }
    } else if (state is OnboardingSiteSetup) {
      state.siteNameController.dispose();
      _managedControllers.remove(state.siteNameController);
      state.structureNameController.dispose();
      _managedControllers.remove(state.structureNameController);
    } else if (state is OnboardingFirstOrganismSetup) {
      state.localIdController.dispose();
      _managedControllers.remove(state.localIdController);
      if (state.quantityController != null) {
        state.quantityController!.dispose();
        _managedControllers.remove(state.quantityController);
      }
      if (state.recordNameController != null) {
        state.recordNameController!.dispose();
        _managedControllers.remove(state.recordNameController);
      }
    }
  }

  /// Generate a URL-friendly slug from organization name
  ///
  /// Rules:
  /// - Converts to lowercase
  /// - Replaces non-alphanumeric characters with hyphens
  /// - Removes leading/trailing hyphens
  /// - Limits to 20 characters maximum
  /// - Returns fallback if name contains only special characters
  String _generateSlugFromName(String name) {
    if (name.trim().isEmpty) return '';

    final processed = name
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        ) // Replace non-alphanumeric with hyphens
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Remove leading/trailing hyphens

    // If processed string is empty (name had only special characters),
    // generate a fallback slug
    if (processed.isEmpty) {
      return 'org-${DateTime.now().millisecondsSinceEpoch % 100000}';
    }

    // Use processed.length, not original name.length, to avoid bounds error
    return processed.substring(0, processed.length.clamp(0, 20));
  }

  void setName(String name) {
    if (state is OnboardingUserProfile) {
      emit((state as OnboardingUserProfile).copyWith(nameString: name));
    } else if (state is OnboardingOrganizationSetup) {
      _ensureOrganizationSubscription();
      final currentState = state as OnboardingOrganizationSetup;
      final slug = _generateSlugFromName(name);

      // Update the slug controller text to match the generated slug
      currentState.slugController?.text = slug;

      emit(currentState.copyWith(nameString: name, slug: slug));
    }
  }

  void setTagline(String tagline) {
    if (state is OnboardingUserProfile) {
      emit((state as OnboardingUserProfile).copyWith(taglineString: tagline));
    }
  }

  void setSlug(String slug) {
    if (state is OnboardingOrganizationSetup) {
      emit((state as OnboardingOrganizationSetup).copyWith(slug: slug));
    }
  }

  void setOrganismSelection(OrganismKind organism, bool selected) {
    if (state is OnboardingOrganizationSetup) {
      final currentState = state as OnboardingOrganizationSetup;
      final updatedOrganisms =
          selected && organism == OrganismKind.coral
          ? <OrganismKind>[OrganismKind.coral]
          : <OrganismKind>[];

      emit(
        currentState.copyWith(
          selectedOrganisms: updatedOrganisms,
        ),
      );
    }
  }

  void setSiteTypeSelection(SiteType siteType, bool selected) {
    if (state is OnboardingOrganizationSetup) {
      final currentState = state as OnboardingOrganizationSetup;
      final updatedSiteTypes = List<SiteType>.from(
        currentState.selectedSiteTypes,
      );

      if (selected && !updatedSiteTypes.contains(siteType)) {
        updatedSiteTypes.add(siteType);
      } else if (!selected) {
        updatedSiteTypes.remove(siteType);
      }

      emit(currentState.copyWith(selectedSiteTypes: updatedSiteTypes));
    }
  }

  /// Set the selected structure type for site setup.
  /// This determines what type of container (tank, tree, dome, etc.) to create.
  void setSelectedStructureType(String? structureTypeId) {
    if (state is OnboardingSiteSetup) {
      emit(
        (state as OnboardingSiteSetup).copyWith(
          selectedStructureTypeId: structureTypeId,
          // Clear substructure when structure changes (different structures have different substructures)
          clearSubstructure: true,
        ),
      );
    }
  }

  /// Set the selected substructure type for site setup.
  /// Substructures (trays, branches, tags) allow finer organization.
  void setSelectedSubstructureType(String? substructureTypeId) {
    if (state is OnboardingSiteSetup) {
      emit(
        (state as OnboardingSiteSetup).copyWith(
          selectedSubstructureTypeId: substructureTypeId,
        ),
      );
    }
  }

  bool _isNameAvailable(String name) {
    // If organizations haven't loaded yet, assume available (optimistic validation)
    // This prevents blocking the user while waiting for the stream to emit
    if (!_organizationsLoaded || _allOrganizations == null) {
      return true;
    }

    // Check if any organization already uses this name (case-insensitive)
    return !_allOrganizations!.any(
      (organization) => organization.name.toLowerCase() == name.toLowerCase(),
    );
  }

  void setTosAccepted(bool accepted) {
    if (state is OnboardingLegalAcceptance) {
      emit(
        (state as OnboardingLegalAcceptance).copyWithLegal(
          tosAccepted: accepted,
        ),
      );
    }
  }

  void setPrivacyAccepted(bool accepted) {
    if (state is OnboardingLegalAcceptance) {
      emit(
        (state as OnboardingLegalAcceptance).copyWithLegal(
          privacyAccepted: accepted,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    disposeProvenanceSearch();
    _recordNameSuggestionTimer?.cancel();
    for (final controller in _managedControllers) {
      controller.dispose();
    }
    _managedControllers.clear();
    // Stream subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
    return super.close();
  }
}
