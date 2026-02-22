// @tier: community
import 'package:flutter/material.dart';

/// Provides a consistent scaffold for spreadsheet views with scrollbars and headers.
class SpreadsheetScrollView extends StatelessWidget {
  const SpreadsheetScrollView({
    super.key,
    required this.header,
    required this.body,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final List<Widget> header;
  final Widget body;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain height to available space to prevent overflow
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;
        return Container(
          color: backgroundColor,
          constraints: maxHeight.isFinite
              ? BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxHeight: maxHeight,
                )
              : BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              Expanded(
                child: Padding(
                  padding: padding,
                  // Rely on the inner widget to manage scrolling; wrapping non-scrollable
                  // content with Scrollbar triggers ScrollController assertions at runtime.
                  child: ClipRect(child: body),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
