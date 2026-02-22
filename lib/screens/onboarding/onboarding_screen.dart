// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/auth/auth.dart';
import 'package:seafoundry_app/cubits/onboarding/onboarding_cubit.dart';
import 'package:seafoundry_app/screens/onboarding/onboarding_info_page.dart';
import 'package:seafoundry_app/screens/onboarding/organization_setup_page.dart';
import 'package:seafoundry_app/screens/onboarding/user_name_page.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'package:seafoundry_app/screens/onboarding/legal_acceptance_page.dart';
import 'package:seafoundry_app/screens/onboarding/first_site_setup_page.dart';
import 'package:seafoundry_app/screens/onboarding/first_genet_page.dart';
import 'package:seafoundry_app/screens/onboarding/education_page.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String stepName = context.read<OnboardingCubit>().state.step.name;
    return Navigator(
      initialRoute: stepName,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => _OnboardingScreen(stepName: settings.name!),
        );
      },
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  const _OnboardingScreen({required this.stepName});

  final String stepName;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          previous.step != current.step &&
          current.step.name != OnboardingStep.loading.name,
      listener: (context, state) =>
          Navigator.of(context).pushReplacementNamed(state.step.name),
      buildWhen: (previous, current) {
        return current.step.name == stepName;
      },
      builder: (context, state) {
        final OnboardingCubit cubit = context.read<OnboardingCubit>();

        // Handle invitation email mismatch error state
        if (state is OnboardingInviteEmailMismatch) {
          return _inviteEmailMismatchPage(context, state);
        }

        return switch (state.step) {
          OnboardingStep.initial => UI.loadingScreen,
          OnboardingStep.loading => UI.loadingScreen,
          OnboardingStep.legalAcceptance => _legalAcceptancePage(context, state, cubit),
          OnboardingStep.organizationSetup => const OrganizationSetupPage(),
          OnboardingStep.userProfile => _userProfilePage(state, cubit),
          OnboardingStep.siteSetup => _siteSetupPage(state, cubit),
          OnboardingStep.firstOrganismSetup => _firstOrganismPage(state, cubit),
          OnboardingStep.education => _educationPage(state, cubit),
          OnboardingStep.complete => _onboardingCompletePage(state, cubit),
        };
      },
    );
  }

  /// Displays an error when a deep link invitation was sent to a different email
  /// than the currently authenticated user.
  Widget _inviteEmailMismatchPage(
    BuildContext context,
    OnboardingInviteEmailMismatch state,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 64,
                        color: AppColors.warning,
                      ),
                      UI.spacingVerticalLg,
                      UIText.h4('Email Mismatch'),
                      UI.spacingVerticalMd,
                      UIText.bodyMedium(
                        'This invitation was sent to:',
                        color: AppColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                      UI.spacingVerticalSm,
                      Text(
                        state.invitationEmail,
                        style: UIText.bodyLargeStyle.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      UI.spacingVerticalMd,
                      UIText.bodyMedium(
                        'But you are signed in as:',
                        color: AppColors.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                      UI.spacingVerticalSm,
                      Text(
                        state.currentUserEmail,
                        style: UIText.bodyLargeStyle.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      UI.spacingVerticalXl,
                      UIText.bodySmall(
                        'Please sign out and sign in with the correct email address to accept this invitation.',
                        color: AppColors.textHint,
                        textAlign: TextAlign.center,
                      ),
                      UI.spacingVerticalXl,
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<AuthBloc>().signOut();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legalAcceptancePage(
    BuildContext context,
    OnboardingState state,
    OnboardingCubit onboardingCubit,
  ) {
    if (state is OnboardingLegalAcceptance) {
      return LegalAcceptancePage(
        isPure: state.isPure,
        tosAccepted: state.tosAccepted,
        privacyAccepted: state.privacyAccepted,
        onTosChanged: onboardingCubit.setTosAccepted,
        onPrivacyChanged: onboardingCubit.setPrivacyAccepted,
        onBack: onboardingCubit.canGoBack() ? onboardingCubit.previousStep : null,
        onNext: onboardingCubit.nextStep,
      );
    } else {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _userProfilePage(OnboardingState state, OnboardingCubit onboardingCubit) {
    if (state is OnboardingUserProfile) {
      return UserNamePage(
        isPure: state.isPure,
        nameValue: state.name.value,
        taglineValue: state.tagline,
        initialUserImageUrl: state.user.imageUrl,
        isInviteFlow: state.isInviteFlow,
        onChanged: (value) => onboardingCubit.setName(value),
        onTaglineChanged: (value) => onboardingCubit.setTagline(value),
        onBack: onboardingCubit.canGoBack() ? onboardingCubit.previousStep : null,
        onNext: onboardingCubit.nextStep,
      );
    } else {
      return UserNamePage.empty();
    }
  }

  Widget _siteSetupPage(OnboardingState state, OnboardingCubit onboardingCubit) {
    if (state is OnboardingSiteSetup) {
      return FirstSiteSetupPage(
        siteNameController: state.siteNameController,
        structureNameController: state.structureNameController,
        selectedStructureTypeId: state.selectedStructureTypeId,
        selectedSubstructureTypeId: state.selectedSubstructureTypeId,
        onStructureTypeChanged: onboardingCubit.setSelectedStructureType,
        onSubstructureTypeChanged: onboardingCubit.setSelectedSubstructureType,
        errorMessage: state.errorMessage,
        isSubmitting: state.isSubmitting,
        onNext: onboardingCubit.nextStep,
        onSkip: onboardingCubit.skipSiteSetup,
        onBack: onboardingCubit.canGoBack() ? onboardingCubit.previousStep : null,
      );
    } else {
      return FirstSiteSetupPage.empty();
    }
  }

  Widget _firstOrganismPage(OnboardingState state, OnboardingCubit onboardingCubit) {
    if (state is OnboardingFirstOrganismSetup) {
      return FirstGenetPage(
        localIdController: state.localIdController,
        recordNameController: state.recordNameController ?? TextEditingController(),
        quantityController: state.quantityController ?? TextEditingController(text: '1'),
        selectedSpecies: state.selectedSpecies,
        organismKind: state.organismKind,
        selectedLifeStage: state.selectedLifeStage,
        initialQuantity: state.initialQuantity,
        selectedProvenanceType: state.selectedProvenanceType,
        collectionMethod: state.collectionMethod,
        collectionDate: state.collectionDate,
        cohortName: state.cohortName,
        cohortDate: state.cohortDate,
        clonalId: state.clonalId,
        accessionNumber: state.accessionNumber,
        aliasId: state.aliasId,
        provenanceId: state.provenanceId,
        provenanceSearch: state.provenanceSearch,
        errorMessage: state.errorMessage,
        isSubmitting: state.isSubmitting,
        onSpeciesChanged: onboardingCubit.setSelectedSpecies,
        onLifeStageChanged: onboardingCubit.setSelectedLifeStage,
        onQuantityChanged: onboardingCubit.setInitialQuantity,
        onProvenanceTypeChanged: onboardingCubit.setSelectedProvenanceType,
        onCollectionMethodChanged: onboardingCubit.setCollectionMethod,
        onCollectionDateChanged: onboardingCubit.setCollectionDate,
        onCohortNameChanged: onboardingCubit.setCohortName,
        onCohortDateChanged: onboardingCubit.setCohortDate,
        onClonalIdChanged: onboardingCubit.setClonalId,
        onAccessionNumberChanged: onboardingCubit.setAccessionNumber,
        onAliasIdChanged: onboardingCubit.setAliasId,
        onProvenanceIdChanged: onboardingCubit.setProvenanceId,
        onProvenanceSuggestionSelected: onboardingCubit.selectProvenanceSuggestion,
        onSetActiveProvenanceField: onboardingCubit.setActiveProvenanceField,
        onClearProvenanceSelection: onboardingCubit.clearProvenanceSelection,
        onNext: onboardingCubit.nextStep,
        onBack: onboardingCubit.canGoBack() ? onboardingCubit.previousStep : null,
        onRecordNameChanged: onboardingCubit.recordNameChanged,
        onLocalIdChanged: onboardingCubit.localIdChanged,
        onAutoLocalIdChanged: onboardingCubit.updateLocalIdFromAutoSuggestion,
        isLocalIdManuallyEdited: state.isLocalIdManuallyEdited,
        onSkip: onboardingCubit.skipFirstOrganism, // Bypass creation entirely
        onSuggestLocalId: onboardingCubit.suggestNextOrganismLocalId, // Auto-suggest ID based on species
      );
    } else {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }

  Widget _educationPage(OnboardingState state, OnboardingCubit onboardingCubit) {
    if (state is OnboardingEducation) {
      return EducationPage(
        onNext: onboardingCubit.nextStep,
        onBack: onboardingCubit.canGoBack() ? onboardingCubit.previousStep : null,
      );
    } else {
      return EducationPage.empty();
    }
  }

  Widget _onboardingCompletePage(
    OnboardingState state,
    OnboardingCubit onboardingCubit,
  ) {
    if (state is OnboardingComplete) {
      return OnboardingInfoPage(
        title: 'Setup Complete!',
        description:
            'Your organization is ready! You can configure organism types, '
            'species, site types, and other settings in the admin panel.',
        onNext: onboardingCubit.nextStep,
        nextButtonText: 'Let\'s Go!',
      );
    } else {
      return UI.empty;
    }
  }
}
