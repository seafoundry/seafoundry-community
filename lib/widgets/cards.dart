import 'package:flutter/material.dart';

import 'ui.dart';

/// Card widget library for consistent card styling
class AppCards {
  // Basic card
  static Widget basic({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    VoidCallback? onTap,
  }) {
    Widget card = Card(
      color: backgroundColor ?? UI.cardColor,
      elevation: elevation ?? UI.elevationSm,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius ?? UI.borderRadiusXl)),
      margin: margin ?? UI.marginSm,
      child: Padding(padding: padding ?? UI.paddingMd, child: child),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(borderRadius ?? UI.borderRadiusXl), child: card);
    }

    return card;
  }

  // Elevated card
  static Widget elevated({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    VoidCallback? onTap,
  }) {
    return basic(
      child: child,
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation ?? UI.elevationMd,
      borderRadius: borderRadius,
      onTap: onTap,
    );
  }

  // Outlined card
  static Widget outlined({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    double? borderRadius,
    VoidCallback? onTap,
  }) {
    Widget card = Card(
      color: backgroundColor ?? UI.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? UI.borderRadiusXl),
        side: BorderSide(color: borderColor ?? UI.dividerColor, width: borderWidth ?? 1.0),
      ),
      margin: margin ?? UI.marginSm,
      child: Padding(padding: padding ?? UI.paddingMd, child: child),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(borderRadius ?? UI.borderRadiusXl), child: card);
    }

    return card;
  }

  // List card
  static Widget list({
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    bool showDividers = true,
  }) {
    return basic(
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          if (showDividers && index < children.length - 1) {
            return Column(
              children: [
                child,
                const Divider(color: UI.dividerColor, height: 1.0),
              ],
            );
          }

          return child;
        }).toList(),
      ),
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
    );
  }

  // Header card
  static Widget header({
    required Widget header,
    required Widget content,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    Color? headerBackgroundColor,
    EdgeInsetsGeometry? headerPadding,
  }) {
    return basic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: headerPadding ?? UI.paddingMd,
            decoration: UI.roundedBox(color: headerBackgroundColor ?? UI.backgroundColor, borderRadius: borderRadius),
            child: header,
          ),
          Padding(padding: padding ?? UI.paddingMd, child: content),
        ],
      ),
      padding: EdgeInsets.zero,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
    );
  }

  // Action card
  static Widget action({
    required Widget content,
    required List<Widget> actions,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    MainAxisAlignment actionsAlignment = MainAxisAlignment.end,
  }) {
    return basic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          UI.spacingVerticalMd,
          Row(mainAxisAlignment: actionsAlignment, children: actions),
        ],
      ),
      padding: padding,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
    );
  }

  // Media card
  static Widget media({
    required Widget media,
    required Widget content,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    double? mediaHeight,
    BoxFit mediaFit = BoxFit.cover,
  }) {
    return basic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(borderRadius ?? UI.borderRadiusXl),
              topRight: Radius.circular(borderRadius ?? UI.borderRadiusXl),
            ),
            child: SizedBox(width: double.infinity, height: mediaHeight ?? 200.0, child: media),
          ),
          Padding(padding: padding ?? UI.paddingMd, child: content),
        ],
      ),
      padding: EdgeInsets.zero,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
    );
  }

  // Compact card
  static Widget compact({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    VoidCallback? onTap,
  }) {
    return basic(
      child: child,
      padding: padding ?? UI.paddingSm,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
      onTap: onTap,
    );
  }

  // Large card
  static Widget large({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? backgroundColor,
    double? elevation,
    double? borderRadius,
    VoidCallback? onTap,
  }) {
    return basic(
      child: child,
      padding: padding ?? UI.paddingLg,
      margin: margin,
      backgroundColor: backgroundColor,
      elevation: elevation,
      borderRadius: borderRadius,
      onTap: onTap,
    );
  }
}
