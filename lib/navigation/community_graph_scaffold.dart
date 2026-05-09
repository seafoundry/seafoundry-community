import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/graph_node_streams.dart';
import 'package:seafoundry_app/models/graph/graph_node_state.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_state.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/navigation/simple_search_integration.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/widgets/common/gesture_navigation.dart';
import 'package:seafoundry_app/widgets/navigation/bottom_action_bar.dart';
import 'package:seafoundry_app/widgets/visual/brand_logo.dart';
import 'package:seafoundry_app/widgets/navigation/community_app_drawer.dart';
import 'package:seafoundry_app/widgets/visual/rotating_gradient_background.dart';

/// Community version of NavigationBreadcrumbs
class CommunityNavigationBreadcrumbs extends StatelessWidget {
  const CommunityNavigationBreadcrumbs({
    super.key,
    this.showLogo = false,
    this.nodes,
  });

  final bool showLogo;
  final List<GraphNode>? nodes;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, NavigationState>(
      buildWhen: (previous, current) {
        // Always rebuild when currentNode changes
        return previous.currentNode != current.currentNode ||
            previous.isLoading != current.isLoading;
      },
      builder: (context, state) {
        List<GraphNode> resolvedNodes = nodes?.isNotEmpty == true
            ? nodes!
            : state.currentNode?.lineage ?? const [];

        // Defensive fallback: if lineage is empty but currentNode exists,
        // show at least the current node to prevent empty breadcrumbs
        if (resolvedNodes.isEmpty && state.currentNode != null) {
          resolvedNodes = [state.currentNode!];
        }

        // If still empty and loading, try to show something from the navigation stack
        if (resolvedNodes.isEmpty && state.stack.isNotEmpty) {
          final lastNode = state.stack.last;
          resolvedNodes = lastNode.lineage.isNotEmpty
              ? lastNode.lineage
              : [lastNode];
        }

        if (resolvedNodes.isEmpty) {
          return const SizedBox.shrink();
        }

        final children = <Widget>[];

        // Add logo at the start if requested
        if (showLogo) {
          final theme = BrandThemeProvider.of(context);
          if (theme.logoUrl != null && theme.logoUrl!.isNotEmpty) {
            children.add(
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: BrandLogo(height: 28),
              ),
            );
          }
        }

        for (var index = 0; index < resolvedNodes.length; index++) {
          final node = resolvedNodes[index];
          final isLast = index == resolvedNodes.length - 1;
          children.add(
            _BreadcrumbChip(
              node: node,
              isActive: isLast,
              onTap: isLast
                  ? null
                  : () async {
                      await context.read<NavigationCubit>().navigateTo(node);
                    },
            ),
          );
          if (!isLast) {
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            );
          }
        }

        return SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: children),
          ),
        );
      },
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.node,
    required this.isActive,
    this.onTap,
  });

  final GraphNode node;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String label = _nodeLabel(node);

    if (isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () async {
                    await HapticFeedback.selectionClick();
                    LoggingService.instance.info('breadcrumb.navigate', {
                      'target_name': label,
                      'target_type': node.runtimeType.toString(),
                      'target_id': _nodeId(node),
                    });
                    onTap?.call();
                  },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _nodeLabel(GraphNode node) {
    final state = node.state;
    if (state is GraphLoadedState) {
      final record = state.record;
      if (record is OrganismRecord) {
        return _organismLabel(record);
      }
      return record.name;
    }
    return '…';
  }

  String _nodeId(GraphNode node) {
    final state = node.state;
    if (state is GraphLoadedState) {
      return state.record.id;
    }
    return 'unknown';
  }

  String _organismLabel(OrganismRecord record) {
    return record.displayLabel;
  }
}

/// Community version of SimpleNavigationAppBar with end-drawer menu support
class CommunitySimpleNavigationAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CommunitySimpleNavigationAppBar({
    super.key,
    this.title,
    this.actions,
    this.showLogo = false,
  });

  final Widget? title;
  final List<Widget>? actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NavigationCubit, NavigationState>(
      builder: (context, state) {
        Widget? leading;
        final canGoBack = state.stack.isNotEmpty;

        if (canGoBack) {
          leading = IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: context.read<NavigationCubit>().navigateBack,
          );
        }

        final actionWidgets = <Widget>[
          if (actions != null) ...actions!,
          // Hamburger menu button to open end drawer
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            tooltip: 'Menu',
          ),
        ];

        return AppBar(
          automaticallyImplyLeading: false,
          leading: leading,
          titleSpacing: 4,
          centerTitle: false,
          title: title ?? CommunityNavigationBreadcrumbs(showLogo: showLogo),
          actions: actionWidgets,
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Community version of SimpleGraphScreenScaffold with end-drawer menu
class CommunitySimpleGraphScreenScaffold extends StatelessWidget {
  const CommunitySimpleGraphScreenScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.fab,
    this.bottomActions,
    this.showLogo = true,
  });

  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? fab;
  final List<BottomAction>? bottomActions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: CommunitySimpleNavigationAppBar(
        title: title,
        actions: actions,
        showLogo: showLogo,
      ),
      endDrawer: const CommunityAppDrawer(),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: RotatingGradientBackground()),
          Column(
            children: [
              const SimpleSearchBar(),
              Expanded(child: body),
              if (bottomActions != null && bottomActions!.isNotEmpty)
                BottomActionBar(
                  actions: bottomActions!,
                )
              else if (fab != null)
                fab!,
            ],
          ),
        ],
      ),
    );

    // Disable SwipeToNavigateWrapper on web - browser handles back/forward gestures,
    // and the wrapper interferes with horizontal scrolling in spreadsheets/lists,
    // causing false back navigation and "Session expired" errors.
    if (kIsWeb) {
      return scaffold;
    }

    return SwipeToNavigateWrapper(
      onBack: () => Navigator.of(context).maybePop(),
      child: scaffold,
    );
  }
}
