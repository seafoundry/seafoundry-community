// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// UI design system for the SeaFoundry app
/// Contains all pixel values, colors, typography, and spacing constants
class UI {
  // Deprecated: Use AppColors instead
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLightColor = AppColors.primaryLight;
  static const Color primaryDarkColor = AppColors.primaryDark;
  static const Color secondaryColor = AppColors.secondary;
  static const Color secondaryLightColor = AppColors.secondaryLight;
  static const Color secondaryDarkColor = AppColors.secondaryDark;

  static const Color surfaceColor = AppColors.surface;
  static const Color backgroundColor = AppColors.background;
  static const Color errorColor = AppColors.error;
  static const Color warningColor = AppColors.warning;
  static const Color successColor = AppColors.success;

  static const Color textPrimaryColor = AppColors.textPrimary;
  static const Color textSecondaryColor = AppColors.textSecondary;
  static const Color textDisabledColor = AppColors.disabled;

  static const Color dividerColor = AppColors.divider;
  static const Color cardColor = AppColors.surface;
  static const Color drawerColor = AppColors.surface;

  // Deprecated: Use Spacing instead
  static const double spacingXs = Spacing.xs;
  static const double spacingSm = Spacing.sm;
  static const double spacingMd = Spacing.md;
  static const double spacingLg = Spacing.lg;
  static const double spacingXl = Spacing.xl;
  static const double spacingXxl = Spacing.xxl;

  // Border radius
  static const double borderRadiusSm = 4.0;
  static const double borderRadiusMd = 8.0;
  static const double borderRadiusLg = 12.0;
  static const double borderRadiusXl = 16.0;

  // Elevation
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Typography
  static const double fontSizeXs = 12.0;
  static const double fontSizeSm = 14.0;
  static const double fontSizeMd = 16.0;
  static const double fontSizeLg = 18.0;
  static const double fontSizeXl = 20.0;
  static const double fontSizeXxl = 24.0;
  static const double fontSizeXxxl = 32.0;

  // Icon sizes
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // Avatar sizes
  static const double avatarSizeSm = 32.0;
  static const double avatarSizeMd = 40.0;
  static const double avatarSizeLg = 56.0;
  static const double avatarSizeXl = 80.0;

  // Drawer dimensions
  static const double drawerWidth = 280.0;
  static const double drawerHeaderHeight = 120.0;
  static const double drawerItemHeight = 56.0;

  // App bar height
  static const double appBarHeight = 56.0;

  // Card dimensions
  static const double cardPadding = spacingMd;
  static const double cardMargin = spacingSm;

  // Button dimensions
  static const double buttonHeight = 48.0;
  static const double buttonMinWidth = 88.0;
  static const double buttonPadding = spacingMd;

  // Input field dimensions
  static const double inputFieldHeight = 56.0;
  static const double inputFieldPadding = spacingMd;

  // List item dimensions
  static const double listItemHeight = 72.0;
  static const double listItemPadding = spacingMd;

  // Screen padding
  static const double screenPadding = spacingMd;
  static const EdgeInsets screenPaddingAll = EdgeInsets.all(screenPadding);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: screenPadding);
  static const EdgeInsets screenPaddingVertical = EdgeInsets.symmetric(vertical: screenPadding);

  // Named padding constants
  static const EdgeInsets paddingXs = EdgeInsets.all(spacingXs);
  static const EdgeInsets paddingSm = EdgeInsets.all(spacingSm);
  static const EdgeInsets paddingMd = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingLg = EdgeInsets.all(spacingLg);
  static const EdgeInsets paddingXl = EdgeInsets.all(spacingXl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(spacingXxl);

  // Named horizontal padding constants
  static const EdgeInsets paddingHorizontalXs = EdgeInsets.symmetric(horizontal: spacingXs);
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: spacingSm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: spacingMd);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: spacingLg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: spacingXl);
  static const EdgeInsets paddingHorizontalXxl = EdgeInsets.symmetric(horizontal: spacingXxl);

  // Named vertical padding constants
  static const EdgeInsets paddingVerticalXs = EdgeInsets.symmetric(vertical: spacingXs);
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: spacingSm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: spacingMd);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: spacingLg);
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(vertical: spacingXl);
  static const EdgeInsets paddingVerticalXxl = EdgeInsets.symmetric(vertical: spacingXxl);

  // Named margin constants
  static const EdgeInsets marginXs = EdgeInsets.all(spacingXs);
  static const EdgeInsets marginSm = EdgeInsets.all(spacingSm);
  static const EdgeInsets marginMd = EdgeInsets.all(spacingMd);
  static const EdgeInsets marginLg = EdgeInsets.all(spacingLg);
  static const EdgeInsets marginXl = EdgeInsets.all(spacingXl);
  static const EdgeInsets marginXxl = EdgeInsets.all(spacingXxl);

  // Named divider constants
  static const SizedBox dividerXs = SizedBox(height: Spacing.xs);
  static const SizedBox dividerSm = SizedBox(height: Spacing.sm);
  static const SizedBox dividerMd = SizedBox(height: Spacing.md);
  static const SizedBox dividerLg = SizedBox(height: Spacing.lg);
  static const SizedBox dividerXl = SizedBox(height: Spacing.xl);
  static const SizedBox dividerXxl = SizedBox(height: Spacing.xxl);

  // Named horizontal spacing constants
  static const SizedBox spacingHorizontalXs = SizedBox(width: Spacing.xs);
  static const SizedBox spacingHorizontalSm = SizedBox(width: Spacing.sm);
  static const SizedBox spacingHorizontalMd = SizedBox(width: Spacing.md);
  static const SizedBox spacingHorizontalLg = SizedBox(width: Spacing.lg);
  static const SizedBox spacingHorizontalXl = SizedBox(width: Spacing.xl);
  static const SizedBox spacingHorizontalXxl = SizedBox(width: Spacing.xxl);

  // Named vertical spacing constants
  static const SizedBox spacingVerticalXs = SizedBox(height: Spacing.xs);
  static const SizedBox spacingVerticalSm = SizedBox(height: Spacing.sm);
  static const SizedBox spacingVerticalMd = SizedBox(height: Spacing.md);
  static const SizedBox spacingVerticalLg = SizedBox(height: Spacing.lg);
  static const SizedBox spacingVerticalXl = SizedBox(height: Spacing.xl);
  static const SizedBox spacingVerticalXxl = SizedBox(height: Spacing.xxl);

  static Widget verticalLine({double? width, double? height, Color? color}) {
    return Container(width: width ?? 1, height: height, color: color);
  }

  // Empty widget constant
  static const SizedBox empty = SizedBox.shrink();

  // BoxDecoration helpers
  static BoxDecoration roundedBox({Color? color, double? borderRadius, Color? borderColor, double? borderWidth}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusMd),
      border: borderColor != null ? Border.all(color: borderColor, width: borderWidth ?? 1.0) : null,
    );
  }

  static BoxDecoration cardBox({Color? color, double? borderRadius, double? elevation}) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusXl),
      boxShadow: elevation != null
          ? [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: elevation,
                offset: Offset(0, elevation / 2),
              ),
            ]
          : null,
    );
  }

  // Icon helpers
  static Widget icon(IconData icon, {double? size, Color? color}) {
    return Icon(icon, size: size ?? iconSizeMd, color: color ?? AppColors.textPrimary);
  }

  static Widget iconSmall(IconData icon, {Color? color}) {
    return Icon(icon, size: iconSizeSm, color: color ?? AppColors.textPrimary);
  }

  static Widget iconMedium(IconData icon, {Color? color}) {
    return Icon(icon, size: iconSizeMd, color: color ?? AppColors.textPrimary);
  }

  static Widget iconLarge(IconData icon, {Color? color}) {
    return Icon(icon, size: iconSizeLg, color: color ?? AppColors.textPrimary);
  }

  static Widget iconXLarge(IconData icon, {Color? color}) {
    return Icon(icon, size: iconSizeXl, color: color ?? AppColors.textPrimary);
  }

  // Input field borders
  static OutlineInputBorder inputFieldBorder({Color? borderColor, double? borderRadius}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusLg),
      borderSide: BorderSide(color: borderColor ?? AppColors.divider),
    );
  }

  static OutlineInputBorder inputFieldFocusedBorder({Color? borderColor, double? borderRadius, double? borderWidth}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusLg),
      borderSide: BorderSide(color: borderColor ?? AppColors.primary, width: borderWidth ?? 2),
    );
  }

  static OutlineInputBorder inputFieldErrorBorder({Color? borderColor, double? borderRadius, double? borderWidth}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius ?? borderRadiusLg),
      borderSide: BorderSide(color: borderColor ?? AppColors.error, width: borderWidth ?? 2),
    );
  }

  // Rounded icon helper
  static Widget roundedIcon(
    IconData icon, {
    double? size,
    Color? backgroundColor,
    Color? iconColor,
    double? borderRadius,
  }) {
    return UI.roundedContainer(
      color: backgroundColor ?? AppColors.primary.withValues(alpha: 0.1),
      borderRadius: borderRadius ?? borderRadiusMd,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: size ?? iconSizeMd,
        height: size ?? iconSizeMd,
        child: UI.iconMedium(icon, color: iconColor ?? AppColors.primary),
      ),
    );
  }

  // Container helpers
  static Widget roundedContainer({
    required Widget child,
    Color? color,
    double? borderRadius,
    Color? borderColor,
    double? borderWidth,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      decoration: roundedBox(
        color: color,
        borderRadius: borderRadius,
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
      padding: padding,
      margin: margin,
      child: child,
    );
  }

  static Widget cardContainer({
    required Widget child,
    Color? color,
    double? borderRadius,
    double? elevation,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      decoration: cardBox(color: color, borderRadius: borderRadius, elevation: elevation),
      padding: padding,
      margin: margin,
      child: child,
    );
  }

  static Widget get loading => Center(child: CircularProgressIndicator());

  static Widget get loadingScreen => Scaffold(body: loading);
}
