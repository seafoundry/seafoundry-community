import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/graph_node.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

import 'navigation_state.dart';

class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit({required GraphRepository graphRepository})
    : _graphRepository = graphRepository,
      super(NavigationState.initial(graphRepository.root));

  final GraphRepository _graphRepository;
  bool _isNavigating = false;
  String?
  _pendingNavigationPath; // Last-write-wins: stores path to navigate after current completes

  GraphNode? get currentNode => state.currentNode;
  List<GraphNode> get stack => state.stack;
  bool get canGoBack => stack.isNotEmpty;

  Future<void> initialize({String? initialPath}) async {
    final root = _graphRepository.root;
    emit(NavigationState.initial(root));
    await root.awaitLoaded();

    if (initialPath != null &&
        initialPath.isNotEmpty &&
        initialPath != root.currentUrlPath) {
      await navigateToPath(initialPath);
    }
  }

  /// Reinitialize navigation after critical data changes (e.g., post-onboarding)
  /// Forces a reload of the root organization node to pick up newly created sites
  Future<void> reinitialize({bool preserveCurrentPath = true}) async {
    final preservedPath = preserveCurrentPath
        ? state.currentNode?.currentUrlPath
        : null;
    LoggingService.instance.info(
      'NavigationCubit: Reinitializing after data changes (User Session Reset)',
      {'preserveCurrentPath': preserveCurrentPath, 'targetPath': preservedPath},
    );
    final root = _graphRepository.root;
    // Force reload to pick up any new sites/structures created during onboarding
    try {
      if (!root.isClosed) {
        root.add(GraphNodeLoadRequested());
        await root.awaitLoaded();
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'NavigationCubit: Failed to reload root during reinitialize',
        e,
        stackTrace,
      );
    }
    emit(NavigationState.initial(root));

    if (preserveCurrentPath &&
        preservedPath != null &&
        preservedPath.isNotEmpty &&
        preservedPath != root.currentUrlPath) {
      await navigateToPath(preservedPath);
    }
  }

  Future<void> navigateTo(GraphNode node) async {
    // Check navigation lock FIRST to prevent race conditions.
    // Two simultaneous calls could both pass the identical() check before
    // either sets _isNavigating, so we must acquire the lock first.
    if (_isNavigating) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit.navigateTo: Navigation already in progress, ignoring request to ${node.urlPath}',
        );
      }
      return;
    }
    _isNavigating = true;

    if (kDebugMode) {
      LoggingService.instance.debug(
        'NavigationCubit.navigateTo START - '
        'target: ${node.id} (${node.modelType.name}), urlPath: ${node.urlPath}, '
        'current: ${state.currentNode?.id} (${state.currentNode?.modelType.name}), '
        'identical: ${identical(state.currentNode, node)}, equal: ${state.currentNode == node}',
      );
    }

    // Use identical() to check for exact same instance, not just equality
    // GraphNode equality is based on initialRecord and parent, which could match
    // for different instances in some edge cases
    if (identical(state.currentNode, node)) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit.navigateTo: Already at this node (identical), skipping',
        );
      }
      _isNavigating = false;
      return;
    }

    try {
      // Capture the CURRENT state atomically before any async operations
      final currentNodeAtEntry = state.currentNode;
      final stackAtEntry = state.stack;

      final updatedStack = <GraphNode>[...stackAtEntry]; // Use captured stack
      if (currentNodeAtEntry != null) {
        updatedStack.add(currentNodeAtEntry);
      }

      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit.navigateTo: Emitting loading state, stack.length=${updatedStack.length}',
        );
      }

      final loadingState = state.copyWith(
        currentNode: node,
        stack: updatedStack,
        isLoading: true,
        errorMessage: null,
      );
      emit(loadingState);
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit.navigateTo: Emit completed, currentNode=${state.currentNode?.id}',
        );
      }

      try {
        await node.awaitLoaded();
        if (isClosed) return;

        // Check if we're still on the same navigation intent
        if (!identical(state.currentNode, node)) {
          if (kDebugMode) {
            LoggingService.instance.debug(
              'NavigationCubit.navigateTo: Navigation target changed during load, skipping final emit',
            );
          }
          return;
        }

        if (kDebugMode) {
          LoggingService.instance.debug(
            'NavigationCubit.navigateTo: Node loaded, emitting final state',
          );
        }
        // Final isClosed check before emit to prevent post-closure state updates
        if (isClosed) return;
        emit(
          state.copyWith(
            currentNode: node,
            stack: updatedStack,
            isLoading: false,
          ),
        );
      } catch (e, st) {
        LoggingService.instance.error('Failed to navigate', e, st);
        // Guard against emitting to closed cubit in error handler
        if (!isClosed) {
          emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
        }
      }
    } finally {
      // Reset navigation flag even if cubit is closed - safe since it's just a bool field
      // This ensures no lingering state if a new cubit is created later
      _isNavigating = false;

      // Process any pending navigation request (last-write-wins)
      // This handles browser back/forward during slow loads
      final pendingPath = _pendingNavigationPath;
      _pendingNavigationPath = null;
      if (pendingPath != null && !isClosed) {
        if (kDebugMode) {
          LoggingService.instance.debug(
            'NavigationCubit: Processing pending navigation to $pendingPath',
          );
        }
        // Use microtask to avoid stack overflow from recursive calls
        Future.microtask(() => navigateToPath(pendingPath));
      }
    }
  }

  Future<void> navigateToPath(String urlPath) async {
    if (kDebugMode) {
      LoggingService.instance.debug(
        'NavigationCubit.navigateToPath START - '
        'urlPath: "$urlPath", length: ${urlPath.length}, isEmpty: ${urlPath.isEmpty}',
      );
    }

    // Check navigation lock - use last-write-wins for concurrent requests
    // This ensures browser back/forward during slow loads will be processed
    if (_isNavigating) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit.navigateToPath: Navigation in progress, queuing $urlPath for after completion',
        );
      }
      _pendingNavigationPath = urlPath;
      return;
    }

    // Handle special non-graph routes
    if (urlPath.startsWith('/chat/')) {
      emit(state.copyWith(externalRoute: urlPath));
      // Clear it immediately so it doesn't persist
      emit(state.copyWith(externalRoute: null));
      return;
    }

    try {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit: About to call getNodeForUrlPath with: "$urlPath"',
        );
      }
      emit(state.copyWith(isLoading: true, errorMessage: null));
      final node = await _graphRepository.getNodeForUrlPath(urlPath);
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit: getNodeForUrlPath returned - '
          'found: ${node != null}, id: ${node?.id}, '
          'modelType: ${node?.modelType.name}, urlPath: ${node?.urlPath}',
        );
      }
      if (isClosed) {
        LoggingService.instance.warning(
          'NavigationCubit: Cubit is closed after getNodeForUrlPath',
        );
        return;
      }
      if (node == null) {
        LoggingService.instance.warning(
          'NavigationCubit: Node not found for path: $urlPath',
        );
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Node not found for $urlPath',
          ),
        );
        return;
      }
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit: Calling navigateTo for node at ${node.currentUrlPath}',
        );
      }
      await navigateTo(node);
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit: navigateTo completed successfully',
        );
      }
    } catch (e, st) {
      LoggingService.instance.error('Failed to navigate to path', e, st);
      // Guard against emitting to closed cubit
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
      }
    }
  }

  void navigateBack() {
    if (state.stack.isEmpty) return;
    final updatedStack = <GraphNode>[...state.stack];
    final previous = updatedStack.removeLast();
    emit(
      state.copyWith(
        currentNode: previous,
        stack: updatedStack,
        isLoading: false,
        errorMessage: null,
      ),
    );
  }

  void navigateToHome() {
    final root = _graphRepository.root;
    emit(
      NavigationState(
        currentNode: root,
        stack: const <GraphNode>[],
        isLoading: false,
      ),
    );
  }

  Future<void> navigateToParent() async {
    final current = state.currentNode;
    if (current == null) return;
    final parent = current.parent;
    if (parent != null) {
      await navigateTo(parent);
    }
  }

  Future<void> navigateToSearchResult(GraphNodeRecord record) async {
    if (kDebugMode) {
      LoggingService.instance.debug(
        'navigateToSearchResult: name=${record.name}, urlPath=${record.urlPath}, modelType=${record.modelType}',
      );
    }

    final node = await _graphRepository.getNodeForUrlPath(record.urlPath);

    if (isClosed) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'NavigationCubit is closed, aborting navigation',
        );
      }
      return;
    }

    if (node != null) {
      if (kDebugMode) {
        LoggingService.instance.debug(
          'Node found, navigating to ${node.modelType}:${node.name}, '
          'lineage.length=${node.lineage.length}, '
          'parent=${node.parent?.name ?? "null"}',
        );
      }

      // Verify lineage is valid before navigation
      if (node.lineage.isEmpty) {
        LoggingService.instance.warning(
          'navigateToSearchResult: Node has empty lineage, may cause breadcrumb issues. '
          'urlPath=${record.urlPath}',
        );
      }

      await navigateTo(node);

      // Verify navigation completed successfully
      if (kDebugMode && state.currentNode != null) {
        LoggingService.instance.debug(
          'navigateToSearchResult complete: currentNode=${state.currentNode?.name}, '
          'lineage.length=${state.currentNode?.lineage.length ?? 0}',
        );
      }
    } else {
      LoggingService.instance.warning('Node not found for ${record.urlPath}');
      emit(
        state.copyWith(
          errorMessage: 'Node not found for ${record.urlPath}',
          isLoading: false,
        ),
      );
    }
  }

  void removeFromHistory(GraphNode node) {
    if (state.stack.isEmpty) return;
    final updatedStack = state.stack.where((it) => it != node).toList();
    emit(state.copyWith(stack: updatedStack));
  }

  List<GraphNode> getBreadcrumbs() {
    final current = state.currentNode;
    if (current == null) return const <GraphNode>[];
    return current.lineage;
  }
}
