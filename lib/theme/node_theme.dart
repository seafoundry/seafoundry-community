// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Theme data for a specific node type
class NodeThemeData {
  final Color primaryColor;
  final Color accentColor;
  final IconData icon;
  final TextStyle? labelStyle;
  final BoxDecoration? decoration;

  const NodeThemeData({
    required this.primaryColor,
    required this.accentColor,
    required this.icon,
    this.labelStyle,
    this.decoration,
  });

  NodeThemeData copyWith({
    Color? primaryColor,
    Color? accentColor,
    IconData? icon,
    TextStyle? labelStyle,
    BoxDecoration? decoration,
  }) {
    return NodeThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      icon: icon ?? this.icon,
      labelStyle: labelStyle ?? this.labelStyle,
      decoration: decoration ?? this.decoration,
    );
  }
}

/// Theme extension for node styling
class NodeTheme extends ThemeExtension<NodeTheme> {
  final NodeThemeData organizationTheme;
  final NodeThemeData siteTheme;
  final NodeThemeData groupTheme;
  final NodeThemeData coralTheme;
  final NodeThemeData genetTheme;
  final NodeThemeData defaultTheme;

  const NodeTheme({
    required this.organizationTheme,
    required this.siteTheme,
    required this.groupTheme,
    required this.coralTheme,
    required this.genetTheme,
    required this.defaultTheme,
  });

  /// Get theme data for a specific model type
  NodeThemeData forModelType(ModelType type) {
    switch (type) {
      case ModelType.organization:
        return organizationTheme;
      case ModelType.site:
        return siteTheme;
      case ModelType.group:
        return groupTheme;
      case ModelType.organismRecord:
        return coralTheme;
      case ModelType.genet:
        return genetTheme;
      default:
        return defaultTheme;
    }
  }

  /// Default light theme
  static NodeTheme light() {
    return const NodeTheme(
      organizationTheme: NodeThemeData(
        primaryColor: AppColors.organizationColor,
        accentColor: AppColors.primaryLight,
        icon: Icons.home,
      ),
      siteTheme: NodeThemeData(
        primaryColor: AppColors.siteColor,
        accentColor: AppColors.primaryLight,
        icon: Icons.location_on,
      ),
      groupTheme: NodeThemeData(
        primaryColor: AppColors.groupColor,
        accentColor: AppColors.success,
        icon: Icons.group_work,
      ),
      // Use scatter_plot icon to represent coral polyp structure
      coralTheme: NodeThemeData(primaryColor: AppColors.coralColor, accentColor: AppColors.warning, icon: Icons.scatter_plot),
      genetTheme: NodeThemeData(
        primaryColor: AppColors.genetColor,
        accentColor: AppColors.secondaryDark,
        icon: Icons.hub,
      ),
      defaultTheme: NodeThemeData(
        primaryColor: AppColors.textSecondary,
        accentColor: AppColors.disabled,
        icon: Icons.folder_outlined,
      ),
    );
  }

  @override
  ThemeExtension<NodeTheme> copyWith({
    NodeThemeData? organizationTheme,
    NodeThemeData? siteTheme,
    NodeThemeData? groupTheme,
    NodeThemeData? coralTheme,
    NodeThemeData? genetTheme,
    NodeThemeData? defaultTheme,
  }) {
    return NodeTheme(
      organizationTheme: organizationTheme ?? this.organizationTheme,
      siteTheme: siteTheme ?? this.siteTheme,
      groupTheme: groupTheme ?? this.groupTheme,
      coralTheme: coralTheme ?? this.coralTheme,
      genetTheme: genetTheme ?? this.genetTheme,
      defaultTheme: defaultTheme ?? this.defaultTheme,
    );
  }

  @override
  ThemeExtension<NodeTheme> lerp(covariant ThemeExtension<NodeTheme>? other, double t) {
    if (other is! NodeTheme) {
      return this;
    }
    return NodeTheme(
      organizationTheme: organizationTheme,
      siteTheme: siteTheme,
      groupTheme: groupTheme,
      coralTheme: coralTheme,
      genetTheme: genetTheme,
      defaultTheme: defaultTheme,
    );
  }
}
