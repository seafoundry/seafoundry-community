// @tier: pro
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_state.dart';
import 'package:seafoundry_app/cubits/navigation_view_mode/navigation_view_mode.dart';
import 'package:seafoundry_app/screens/graph/community_graph_node_container.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Community version of SimpleNavigationWidget
///
/// This is identical to the Pro version as the actual screen filtering
/// happens in GraphNodeContainer and the app drawer. The navigation widget
/// itself just renders whatever node is current in the navigation stack.
///
/// All Pro/Scale screen restrictions are enforced at:
/// - AppDrawer level (which screens appear in menu)
/// - GraphNodeContainer level (which screens are rendered)
/// - Feature access service level (permission checks)
class SimpleNavigationWidget extends StatelessWidget {
  const SimpleNavigationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if NavigationCubit exists in the widget tree
    // This prevents errors during initialization when the cubit isn't provided yet
    try {
      context.read<NavigationCubit>();
    } on ProviderNotFoundException {
      // NavigationCubit not yet in tree - show loading
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if NavigationViewModeCubit exists in the widget tree
    try {
      context.read<NavigationViewModeCubit>();
    } on ProviderNotFoundException {
      // NavigationViewModeCubit not yet in tree - show loading
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BlocBuilder<NavigationViewModeCubit, NavigationViewModeState>(
      builder: (context, viewModeState) {
        if (viewModeState.mode == NavigationViewMode.community) {
          return const Center(child: Text('Community Feed - coming soon'));
        }

        // Existing organization view logic
        return BlocBuilder<NavigationCubit, NavigationState>(
          builder: (context, state) {
            final currentNode = state.currentNode;
            LoggingService.instance.debug('CommunitySimpleNavigationWidget: currentNode = ${currentNode?.id} (${currentNode?.modelType.name})');
            LoggingService.instance.debug('CommunitySimpleNavigationWidget: urlPath = ${currentNode?.urlPath}');
            LoggingService.instance.debug('CommunitySimpleNavigationWidget: stack.length = ${state.stack.length}');

            if (currentNode == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return KeyedSubtree(
              key: ValueKey(currentNode.urlPath),
              child: CommunityGraphNodeContainer(node: currentNode),
            );
          },
        );
      },
    );
  }
}
