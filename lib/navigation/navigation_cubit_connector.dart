import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/navigation/navigation_router_delegate.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Connects NavigationCubit to NavigationRouterDelegate for browser history sync.
///
/// This widget should be placed in the widget tree where NavigationCubit is available
/// (typically in RepositoriesProvider) to enable browser back/forward navigation.
class NavigationCubitConnector extends StatefulWidget {
  const NavigationCubitConnector({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NavigationCubitConnector> createState() => _NavigationCubitConnectorState();
}

class _NavigationCubitConnectorState extends State<NavigationCubitConnector> {
  /// Tracks the currently connected cubit to detect recreation.
  NavigationCubit? _connectedCubit;
  NavigationRouterDelegate? _delegate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Try to find the RouterDelegate in the widget tree
    final router = Router.maybeOf(context);
    if (router != null && router.routerDelegate is NavigationRouterDelegate) {
      final delegate = router.routerDelegate as NavigationRouterDelegate;
      _delegate = delegate;
      final navigationCubit = context.read<NavigationCubit>();

      // Only reconnect if the cubit instance has changed
      if (_connectedCubit != navigationCubit) {
        final isReconnection = _connectedCubit != null;

        if (isReconnection) {
          LoggingService.instance.info(
            'NavigationCubitConnector: Detected cubit recreation '
            '(old: ${_connectedCubit.hashCode}, new: ${navigationCubit.hashCode})',
          );
        }

        // Connect the cubit to the delegate
        delegate.updateNavigationCubit(navigationCubit);
        _connectedCubit = navigationCubit;

        LoggingService.instance.info(
          'NavigationCubitConnector: Connected NavigationCubit to RouterDelegate '
          '(cubit: ${navigationCubit.hashCode})',
        );
      }
    }
  }

  @override
  void dispose() {
    // Disconnect cubit from delegate when this connector is disposed.
    // This is critical for sign-out: RepositoriesProvider disposes, which
    // disposes this connector and its NavigationCubit. We must notify the
    // delegate so it clears stale navigation state.
    if (_delegate != null) {
      LoggingService.instance.info(
        'NavigationCubitConnector: Disposing, disconnecting cubit from delegate',
      );
      _delegate!.updateNavigationCubit(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
