import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/blocs/auth/auth_bloc.dart';
import 'package:seafoundry_app/blocs/auth/auth_state.dart';
import 'package:seafoundry_app/navigation/navigation_route_information_parser.dart';
import 'package:seafoundry_app/navigation/navigation_router_delegate.dart';
import 'package:seafoundry_app/navigation/simple_router.dart';
import 'package:seafoundry_app/repositories/auth/auth_repository.dart';
import 'package:seafoundry_app/repositories/current_user_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/widgets/repositories/repositories_provider.dart';

import 'cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/record_display_preferences/record_display_preferences_cubit.dart';
import 'package:seafoundry_app/cubits/spreadsheet_column_preferences/spreadsheet_column_preferences_cubit.dart';
import 'theme/theme.dart';

// App entry flow: main -> [CommunityApp] -> SimpleRouter
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide FirebaseService as the primary abstraction
        Provider<FirebaseService>(create: (_) => FirebaseService.instance),
        // Keep FirebaseFirestore for backward compatibility with existing code
        Provider<FirebaseFirestore>(
          create: (context) => context.read<FirebaseService>().firestore,
        ),
        // Repository layer - can depend on services
        RepositoryProvider<CurrentUserRepository>(
          create: (context) => CurrentUserRepository(
            firestore: context.read<FirebaseService>().firestore,
          ),
        )
      ],
      child: RepositoryProvider<RecordRepository>(
        create: (context) =>
            RecordRepository(db: context.read<FirebaseService>().firestore),
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) {
                return AuthBloc(
                  authRepository: AuthRepository(
                    firebaseService: context.read<FirebaseService>(),
                  ),
                  // GoogleSignInService is used internally by AuthBloc
                )..initialize();
              },
            ),
            BlocProvider(
              create: (context) =>
                  CurrentUser(repository: context.read<CurrentUserRepository>()),
            ),
            BlocProvider(
              create: (context) => RecordDisplayPreferencesCubit(),
            ),
            BlocProvider(
              create: (context) => SpreadsheetColumnPreferencesCubit(),
            ),
          ],
            child: BlocListener<AuthBloc, AuthState>(
            listener: (context, authState) {
              // When authenticated, load the current user
              if (authState is AuthAuthenticated) {
                context.read<CurrentUser>().loadUser(
                  authState.authUser.uid,
                );
              } else if (authState is AuthUnauthenticated) {
                // Reset current user when logged out
                context.read<CurrentUser>().reset();
              }
            },
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              routerDelegate: NavigationRouterDelegate(
                child: const RepositoriesProviderWrapper(child: SimpleRouter()),
                // NavigationCubit is not available here - will be set later
                navigationCubit: null,
              ),
              routeInformationParser: NavigationRouteInformationParser(),
            ),
          ),
        ),
      ),
    );
  }
}
