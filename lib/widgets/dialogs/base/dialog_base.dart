import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../../cubits/current_user/current_user_cubit.dart';
import '../../../cubits/current_user/current_user_state.dart';
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

