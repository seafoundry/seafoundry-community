// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/common/web_desktop_container.dart';

/// Shared scaffold that centers spreadsheet-heavy layouts on desktop widths
/// while preserving standard padding on smaller canvases.
class SpreadsheetPageScaffold extends StatelessWidget {
  const SpreadsheetPageScaffold({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.horizontalPadding = 16,
    this.verticalPadding = 0,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return WebDesktopContainer(
      maxWidth: maxWidth,
      minHorizontalPadding: horizontalPadding,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: child,
      ),
    );
  }
}
