// @tier: community
import 'package:flutter/material.dart';

/// Collapsible wrapper for spreadsheet filter toolbars on narrow screens.
///
/// When the available width drops below [compactBreakpoint], the filters are
/// placed inside an [ExpansionTile] to avoid consuming excessive vertical
/// space. On wider layouts, [child] is rendered directly.
class ResponsiveFilterSection extends StatelessWidget {
  const ResponsiveFilterSection({
    super.key,
    required this.child,
    this.label = 'Filters',
    this.compactBreakpoint = 600,
    this.initiallyExpanded = false,
    this.tilePadding,
    this.contentPadding,
    this.leading,
    this.trailing,
  });

  final Widget child;
  final String label;
  final double compactBreakpoint;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final isCompact = maxWidth < compactBreakpoint;
        if (!isCompact) {
          return child;
        }

        final theme = Theme.of(context);
        return ExpansionTile(
          leading: leading,
          trailing: trailing,
          title: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          tilePadding: tilePadding ?? const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding:
              contentPadding ?? const EdgeInsets.fromLTRB(4, 0, 4, 12),
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          children: [child],
        );
      },
    );
  }
}
