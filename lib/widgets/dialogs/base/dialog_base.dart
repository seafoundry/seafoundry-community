// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../../cubits/current_user/current_user.dart';
import '../../../models/organization.dart';
import '../../../models/user.dart';
import '../components/dialog_barrier.dart';

/// Utility class for showing dialogs with proper provider scope handling.
///
/// ## The Problem
/// `showDialog` creates a new overlay context that doesn't inherit providers from
/// the widget tree. Dialogs using `context.read<SomeProvider>()` will crash with
/// "Provider not found" errors.
///
/// ## The Solution
/// Capture required providers from the calling context BEFORE `showDialog`, then
/// wrap the dialog with providers to make them available.
///
/// ## Usage Pattern
/// ```dart
/// static Future<void> show(BuildContext context, {...}) {
///   // 1. Capture providers BEFORE showDialog
///   final repo = context.read<SomeRepository>();
///   final service = context.read<SomeService>();
///
///   // 2. Use showDialogWithProviders helper
///   return DialogBase.showDialogWithProviders(
///     context: context,
///     providers: [
///       RepositoryProvider<SomeRepository>.value(value: repo),
///       Provider<SomeService>.value(value: service),
///     ],
///     dialog: MyDialog(...),
///   );
/// }
/// ```
///
/// ## Migration Checklist
/// When migrating a dialog to use this pattern:
/// 1. Identify all `context.read<T>()` calls in the dialog
/// 2. Move those reads to the static `show()` method BEFORE `showDialog`
/// 3. Add corresponding providers to the `providers` list
/// 4. Use `DialogBase.showDialogWithProviders` instead of raw `showDialog`
sealed class DialogBase {
  const DialogBase._();

  /// Helper method to show a dialog with providers
  ///
  /// Accepts any [SingleChildWidget] (RepositoryProvider, BlocProvider, Provider, etc.)
  /// This allows mixing different provider types:
  /// ```dart
  /// providers: [
  ///   RepositoryProvider<MyRepo>.value(value: repo),
  ///   BlocProvider<MyCubit>.value(value: cubit),
  ///   Provider<MyService>.value(value: service),
  /// ]
  /// ```
  static Future<T?> showDialogWithProviders<T>({
    required BuildContext context,
    required List<SingleChildWidget> providers,
    required Widget dialog,
    bool barrierDismissible = false,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? dialogBarrierColor(context),
      builder: (_) => MultiProvider(providers: providers, child: dialog),
    );
  }

  /// Helper method to get current user and organization.
  /// Returns null if user is not logged in or data is unavailable.
  /// When non-null, both user and organization are guaranteed to be present.
  static (User, Organization)? getCurrentUserAndOrg(BuildContext context) {
    final currentUserState = context.read<CurrentUser>().state;

    if (currentUserState is CurrentUserLoaded) {
      return (currentUserState.user, currentUserState.organization);
    }

    return null;
  }
}

/// Base class for dialogs that need user and organization context
abstract class UserAwareDialogBase extends StatelessWidget {
  const UserAwareDialogBase({
    super.key,
    required this.user,
    required this.organization,
  });

  final User user;
  final Organization organization;

  /// Helper to safely show a user-aware dialog
  ///
  /// Accepts any [SingleChildWidget] providers (RepositoryProvider, BlocProvider, Provider, etc.)
  static Future<T?> showWithUser<T>({
    required BuildContext context,
    required List<SingleChildWidget> providers,
    required UserAwareDialogBase Function(User user, Organization organization)
        dialogBuilder,
    bool barrierDismissible = false,
  }) {
    final userAndOrg = DialogBase.getCurrentUserAndOrg(context);
    if (userAndOrg == null) {
      return Future.value(null);
    }

    final (user, organization) = userAndOrg;

    return DialogBase.showDialogWithProviders<T>(
      context: context,
      providers: providers,
      dialog: dialogBuilder(user, organization),
      barrierDismissible: barrierDismissible,
    );
  }
}

/// Example usage of DialogBase
class ExampleDialog extends StatelessWidget {
  const ExampleDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    // Read dependencies from parent context
    final repository1 = context
        .read<dynamic>(); // Replace with actual repository
    final service1 = context.read<dynamic>(); // Replace with actual service

    return DialogBase.showDialogWithProviders<bool>(
      context: context,
      providers: [
        RepositoryProvider.value(value: repository1),
        RepositoryProvider.value(value: service1),
      ],
      dialog: const ExampleDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Example Dialog'),
      content: const Text('This dialog has access to providers'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Example usage of UserAwareDialogBase
class ExampleUserDialog extends UserAwareDialogBase {
  const ExampleUserDialog({
    super.key,
    required super.user,
    required super.organization,
  });

  static Future<bool?> show(BuildContext context) {
    final repository1 = context
        .read<dynamic>(); // Replace with actual repository

    return UserAwareDialogBase.showWithUser<bool>(
      context: context,
      providers: [RepositoryProvider.value(value: repository1)],
      dialogBuilder: (user, organization) =>
          ExampleUserDialog(user: user, organization: organization),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Welcome ${user.name}'),
      content: Text('You are part of ${organization.name}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
