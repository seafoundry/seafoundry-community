// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';

class NavigationHelper {
  NavigationHelper._(this._cubit);

  final NavigationCubit _cubit;

  static NavigationHelper of(BuildContext context) {
    final cubit = context.read<NavigationCubit>();
    return NavigationHelper._(cubit);
  }

  GraphNode? get currentNode => _cubit.currentNode;
  bool get canGoBack => _cubit.canGoBack;
  List<GraphNode> get breadcrumbs => _cubit.getBreadcrumbs();

  Future<void> navigateTo(GraphNode node) => _cubit.navigateTo(node);
  void navigateBack() => _cubit.navigateBack();

  static NavigationCubit? maybeReadCubit(BuildContext context) {
    try {
      final cubit = context.read<NavigationCubit>();
      return cubit.isClosed ? null : cubit;
    } catch (_) {
      return null;
    }
  }
}

extension NavigationHelperExtension on BuildContext {
  NavigationHelper get navigation => NavigationHelper.of(this);

  NavigationCubit? maybeNavigationCubit() =>
      NavigationHelper.maybeReadCubit(this);
}
