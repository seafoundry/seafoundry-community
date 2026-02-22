// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Widget that displays the path to a GraphNode by traversing its parent chain
class NodePathWidget extends StatelessWidget {
  const NodePathWidget({
    super.key,
    required this.node,
    this.fontSize = 14,
    this.navigable = false,
  });

  final GraphNode node;
  final double fontSize;
  final bool navigable;

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgets = [];
    for (int i = 0; i < node.lineage.length; i++) {
      final ancestor = node.lineage[i];

      widgets.add(_buildNodeWidget(context, ancestor, i));

      if (i < node.lineage.length - 1) {
        widgets.add(
          Text(
            ' / ',
            style: TextStyle(
              fontSize: fontSize,
              color: AppColors.textSecondary,
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: widgets),
    );
  }

  /// Build the display widget for a node based on its type and position
  Widget _buildNodeWidget(BuildContext context, GraphNode ancestor, int depth) {
    final isCurrentNode = ancestor.id == node.id;

    // Determine text style
    TextStyle style = TextStyle(fontSize: fontSize);

    if (depth == 0 && ancestor is OrganizationNode) {
      // Organization: bold and uppercase
      style = style.copyWith(fontWeight: FontWeight.bold);
    } else if (ancestor is SiteNode) {
      // Site: semi-bold
      style = style.copyWith(fontWeight: FontWeight.w600);
    } else if (isCurrentNode) {
      // Current node: bold
      style = style.copyWith(fontWeight: FontWeight.bold);
    }

    String text = ancestor.name;
    if (ancestor is OrganizationNode) {
      text = ancestor.state.record.domain.toUpperCase();
    }

    // If navigable and not the current node, wrap in clickable widget
    if (navigable && !isCurrentNode) {
      return InkWell(
        onTap: () {
          context.read<NavigationCubit>().navigateTo(ancestor);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.xs,
            vertical: 2,
          ),
          child: Text(
            text,
            style: style.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    } else {
      // Non-navigable or current node
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: style.copyWith(
            color: isCurrentNode
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      );
    }
  }
}
