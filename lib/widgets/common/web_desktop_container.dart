// @tier: community
import 'package:flutter/material.dart';

/// Provides centered, max-width layout for large desktop/web canvases while
/// retaining sensible padding on smaller screens.
class WebDesktopContainer extends StatelessWidget {
  const WebDesktopContainer({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.minHorizontalPadding = 16,
  });

  final Widget child;
  final double maxWidth;
  final double minHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final shouldCenter = availableWidth > maxWidth;
        final sidePadding = shouldCenter
            ? (availableWidth - maxWidth) / 2
            : minHorizontalPadding;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: shouldCenter ? maxWidth : double.infinity,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
