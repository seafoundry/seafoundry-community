// @tier: pro
// NOTE: This file is a template for community builds - copied and patched during sync
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/auth/auth.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/onboarding/onboarding_cubit.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/repositories/brand_profile_repository.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/onboarding_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/screens/auth/community_auth_screen.dart';
import 'package:seafoundry_app/screens/error_screen.dart';
import 'package:seafoundry_app/screens/onboarding/onboarding_screen.dart';
import 'package:seafoundry_app/navigation/simple_navigation_widget.dart';
import 'package:seafoundry_app/services/provenance_crosswalk_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';

/// Community version of simple router
///
/// Removed Pro/Scale features:
/// - Public holdings map screens (PublicHoldingsMapScreen, PublicNodeScreen, PublicOrganizationScreen)
/// - Public route detection and handling
/// - Demo mode service and demo user cleanup
/// - Tour wrapper functionality
/// - All monitoring, training, and sebastian screen imports
///
/// Community version shows AuthScreen for unauthenticated users (no public map landing page)
class SimpleRouter extends StatelessWidget {
  const SimpleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserState = context.watch<CurrentUser>().state;

    // Handle authentication flow first
    // Show loading indicator while auth is in progress
    if (authState is AuthLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                authState.message,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Handle unauthenticated users - show auth screen
    // Community version: No public map landing page, just auth screen
    if (authState is! AuthAuthenticated) {
      return const CommunityAuthScreen();
    }

    // CRITICAL: Gate to prevent race condition between AuthAuthenticated and CurrentUserLoaded.
    // When AuthBloc emits AuthAuthenticated, the BlocListener in community_app.dart calls loadUser() async.
    // During this gap (before loadUser emits CurrentUserLoading), the CurrentUserState is still
    // CurrentUserInitial. We MUST show a loading indicator during this window to prevent:
    // 1. Flash of onboarding screen during the loading period
    // 2. Incorrect routing decisions based on stale state
    //
    // Show loading indicator when authenticated but CurrentUser hasn't reached a definitive state.
    // Definitive states are: CurrentUserLoaded, CurrentUserUninitialized,
    // CurrentUserOrganizationUninitialized, CurrentUserLoadedUser, CurrentUserError
    if (currentUserState is CurrentUserInitial ||
        currentUserState is CurrentUserLoading) {
      final message = switch (currentUserState) {
        CurrentUserLoading(:final message) => message,
        _ => null,
      };
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // At this point, we have a definitive CurrentUserState.
    // Handle user states that require onboarding vs main app.
    switch (currentUserState) {
      case CurrentUserInitial():
      case CurrentUserLoading():
        // These cases are already handled above, but Dart requires exhaustive switch.
        // This should never be reached due to the guard above.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case CurrentUserUninitialized(:final uuid):
        return _buildOnboardingFlow(
          context: context,
          authState: authState,
          fallbackUserId: uuid,
        );
      case CurrentUserOrganizationUninitialized(:final user):
        return _buildOnboardingFlow(
          context: context,
          authState: authState,
          existingUser: user,
        );

      case CurrentUserLoaded():
        // Community version: Navigate directly to community navigation widget
        // Wrapped in TourWrapper to enable onboarding tour
        return const SimpleNavigationWidget(
        );

      case CurrentUserLoadedUser(:final user):
        //! legacy onboarding step
        return _buildOnboardingFlow(
          context: context,
          authState: authState,
          existingUser: user,
        );

      case CurrentUserError():
        return ErrorScreen(
          message: currentUserState.message,
          stackTrace: null,
          json: null,
        );
    }
  }

  Widget _buildOnboardingFlow({
    required BuildContext context,
    required AuthAuthenticated authState,
    User? existingUser,
    String? fallbackUserId,
  }) {
    // Create repositories needed for onboarding
    final firestore = context.read<FirebaseService>().firestore;
    final recordRepository = context.read<RecordRepository>();
    final crosswalkService = ProvenanceCrosswalkService(firestore: firestore);
    final provenanceLookupService = ProvenanceLookupService(
      crosswalkService: crosswalkService,
    );

    return MultiRepositoryProvider(
      providers: [
        // Provide InvitationRepository for onboarding flow
        RepositoryProvider<InvitationRepository>(
          create: (_) => InvitationRepository(
            firestore: firestore,
            recordRepository: recordRepository,
          ),
        ),
        // Provide OrganizationRepository for activities management
        RepositoryProvider<OrganizationRepository>(
          create: (_) => OrganizationRepository(firestore: firestore),
        ),
        // Provide OnboardingRepository
        RepositoryProvider<OnboardingRepository>(
          create: (_) => OnboardingRepository(recordRepository),
        ),
        // Provide BrandProfileRepository for logo upload during onboarding
        RepositoryProvider<BrandProfileRepository>(
          create: (_) => BrandProfileRepository(),
        ),
      ],
      child: Builder(
        builder: (innerContext) {
          final currentUserCubit = context.read<CurrentUser>();
          final cubit = OnboardingCubit(
            repository: innerContext.read<OnboardingRepository>(),
            invitationRepository: innerContext.read<InvitationRepository>(),
            provenanceLookupService: provenanceLookupService,
            onComplete: (String? completedTargetPath) {
              final userId =
                  existingUser?.id ??
                  fallbackUserId ??
                  authState.authUser.uid;

              // Load user data - this will trigger navigation to main app
              currentUserCubit.loadUser(
                userId,
                targetPath: completedTargetPath,
              );

              // IMPORTANT: Clear any cached graph nodes to ensure fresh data loads
              // This is critical after onboarding because sites/structures were just created
              // Without this, the organization node will show cached (empty) data
              // Note: We can't access GraphRepository here since it's provided later in the widget tree
              // The GraphRepository will create a fresh root node on first access after cache clear
            },
          )..load(
              authUser: authState.authUser,
              user: existingUser,
              displayName: authState.displayName,
            );

          return BlocProvider<OnboardingCubit>(
            create: (_) => cubit,
            child: const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
