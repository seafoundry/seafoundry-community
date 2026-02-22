// @tier: pro
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// RouterDelegate that syncs NavigationCubit state with browser history.
/// Enables browser back/forward buttons to work with the app's navigation.
///
/// This delegate can work with or without NavigationCubit:
/// - Without cubit (during auth/onboarding): Shows static page at '/'
/// - With cubit (after user loads): Syncs browser URL with graph navigation
class NavigationRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  NavigationCubit? _navigationCubit;
  final Widget child;
  StreamSubscription? _navigationSubscription;
  String _currentPath = '/';

  /// Stores navigation path requested before NavigationCubit was connected.
  /// Will be replayed when the cubit becomes available.
  String? _pendingNavigationPath;

  NavigationRouterDelegate({
    required this.child,
    NavigationCubit? navigationCubit,
  }) : _navigationCubit = navigationCubit {
    _connectToNavigationCubit();
  }

  /// Connect to NavigationCubit to sync browser URL with app navigation.
  /// Can be called multiple times - will disconnect from old cubit first.
  void _connectToNavigationCubit() {
    // Clean up existing subscription
    _navigationSubscription?.cancel();
    _navigationSubscription = null;

    // Listen to NavigationCubit state changes to update browser URL
    if (_navigationCubit != null) {
      _navigationSubscription = _navigationCubit!.stream.listen((state) {
        final newPath = state.currentNode?.urlPath ?? '/';
        if (newPath != _currentPath) {
          _currentPath = newPath;
          LoggingService.instance.debug(
            'NavigationRouterDelegate: Path changed to $_currentPath',
          );
          notifyListeners(); // Triggers browser URL update
        }
      });

      // Initialize current path from cubit's current state
      final currentNode = _navigationCubit!.state.currentNode;
      if (currentNode != null) {
        _currentPath = currentNode.urlPath;
      }
    }
  }

  /// Update the NavigationCubit after the delegate is created.
  /// Useful when the cubit becomes available later in the widget tree.
  ///
  /// When a new cubit is connected, this method handles two recovery scenarios:
  /// 1. Pending navigation: A path was requested before the cubit was available
  /// 2. Browser URL recovery: Cubit has empty stack but browser has valid path
  void updateNavigationCubit(NavigationCubit? cubit) {
    if (_navigationCubit != cubit) {
      LoggingService.instance.info(
        'NavigationRouterDelegate: Updating cubit '
        '(pendingPath: $_pendingNavigationPath, currentPath: $_currentPath)',
      );

      // Clear stale navigation state in two scenarios:
      // 1. Cubit disconnected (sign-out): Prevents stale paths from being restored
      // 2. Cubit replaced (user switch): Prevents new user from inheriting old user's path
      //    This handles the race condition where new user's connector connects before
      //    old user's connector disposes.
      final isDisconnecting = cubit == null && _navigationCubit != null;
      final isReplacing = cubit != null && _navigationCubit != null;

      if (isDisconnecting || isReplacing) {
        final reason = isDisconnecting ? 'sign-out' : 'user-switch';
        LoggingService.instance.info(
          'NavigationRouterDelegate: Clearing path state ($reason)',
        );
        _currentPath = '/';
        _pendingNavigationPath = null;
      }

      _navigationCubit = cubit;
      _connectToNavigationCubit();

      if (cubit != null) {
        // Priority 1: Replay pending navigation if exists.
        // This handles the case where setNewRoutePath was called before
        // the cubit was connected (e.g., deep link on initial load).
        if (_pendingNavigationPath != null &&
            _pendingNavigationPath!.isNotEmpty &&
            _pendingNavigationPath != '/') {
          final pendingPath = _pendingNavigationPath!;
          _pendingNavigationPath = null;
          LoggingService.instance.info(
            'NavigationRouterDelegate: Replaying pending navigation: $pendingPath',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!cubit.isClosed) {
              cubit.navigateToPath(pendingPath);
            }
          });
        }
        // Priority 2: Restore navigation state from browser URL if cubit has empty stack.
        // This handles the case where RepositoriesProvider rebuilds, disposing
        // the old NavigationCubit. The new cubit starts with an empty stack,
        // but the browser URL still has the user's previous location.
        else if (cubit.state.stack.isEmpty &&
            _currentPath.isNotEmpty &&
            _currentPath != '/') {
          LoggingService.instance.info(
            'NavigationRouterDelegate: Restoring navigation from browser URL: $_currentPath',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!cubit.isClosed) {
              cubit.navigateToPath(_currentPath);
            }
          });
        } else {
          LoggingService.instance.debug(
            'NavigationRouterDelegate: No navigation recovery needed '
            '(stack: ${cubit.state.stack.length}, path: $_currentPath)',
          );
        }
      }

      // Defer notifyListeners to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  @override
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  @override
  String? get currentConfiguration => _currentPath;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    // Browser URL changed (back/forward/manual edit)
    if (configuration != _currentPath) {
      LoggingService.instance.info(
        'NavigationRouterDelegate: setNewRoutePath called '
        '(path: $configuration, cubit: ${_navigationCubit != null ? "connected" : "null"})',
      );

      // Store pending navigation if cubit is not yet connected.
      // This will be replayed when updateNavigationCubit is called.
      final cubit = _navigationCubit;
      if (cubit == null || cubit.isClosed) {
        if (configuration.isNotEmpty && configuration != '/') {
          _pendingNavigationPath = configuration;
          _currentPath = configuration;
          LoggingService.instance.info(
            'NavigationRouterDelegate: Stored pending navigation: $configuration',
          );
        }
        return;
      }

      // When navigating to root '/', always accept it.
      // This is critical for sign-out: replaceHistoryState('/') must be honored
      // to prevent stale organization paths from persisting in the URL.
      // Previously, this code would restore the cubit's path, defeating sign-out URL clear.

      _currentPath = configuration;
      // Navigate the app to match the browser URL
      if (configuration.isNotEmpty && configuration != '/') {
        LoggingService.instance.debug(
          'NavigationRouterDelegate: Navigating cubit to: $configuration',
        );
        await cubit.navigateToPath(configuration);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in try-catch to ensure we always return something visible.
    // During sign-out transitions, various widgets may be in transitional states.
    try {
      return Navigator(
        key: navigatorKey,
        pages: [
          MaterialPage(
            key: const ValueKey('root_page'),
            child: child,
          ),
        ],
        onDidRemovePage: (page) {
          // Handle back navigation
          if (_navigationCubit?.canGoBack ?? false) {
            LoggingService.instance.debug(
              'NavigationRouterDelegate: Handling back navigation',
            );
            _navigationCubit?.navigateBack();
          }
        },
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        '🔴 NavigationRouterDelegate.build CAUGHT ERROR - showing fallback',
        e,
        stackTrace,
      );
      // Return the child directly without Navigator wrapper as emergency fallback
      return child;
    }
  }

  @override
  Future<bool> popRoute() async {
    // First check if the Navigator has routes to pop (e.g., pushed screens like Training, SOP)
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      LoggingService.instance.debug(
        'NavigationRouterDelegate: Popping Navigator route',
      );
      navigatorState.pop();
      return true;
    }

    // Then check NavigationCubit stack for graph navigation
    if (_navigationCubit?.canGoBack ?? false) {
      LoggingService.instance.debug(
        'NavigationRouterDelegate: Handling graph navigation back',
      );
      _navigationCubit?.navigateBack();
      return true;
    }

    // If we have a cubit but empty stack, and we're not at root,
    // navigate to home instead of allowing default behavior.
    // This prevents the browser from navigating away from the app
    // (which can trigger auth re-evaluation and show login screen).
    final cubit = _navigationCubit;
    if (cubit != null && _currentPath != '/' && _currentPath.isNotEmpty) {
      LoggingService.instance.debug(
        'NavigationRouterDelegate: Navigating to home from $_currentPath',
      );
      _currentPath = '/';
      cubit.navigateToHome();
      notifyListeners();
      return true;
    }

    // Allow default behavior (may close the app on mobile, do nothing on web)
    return false;
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }
}

