import 'package:flutter/material.dart';

import 'ui.dart';
import 'ui_text.dart';

/// Button widget library for consistent button styling
class AppButtons {
  // Primary button (56dp for better touch targets)
  static Widget primary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height ?? 56.0, // Increased from 48dp to 56dp for accessibility
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: UI.primaryColor,
          foregroundColor: UI.surfaceColor,
          disabledBackgroundColor: UI.textDisabledColor,
          disabledForegroundColor: UI.surfaceColor,
          elevation: UI.elevationSm,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.borderRadiusMd)),
          padding: UI.paddingHorizontalMd,
        ),
        child: _buildButtonContent(text, icon, isLoading),
      ),
    );
  }

  // Secondary button (48dp Material Design standard)
  static Widget secondary({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height ?? 48.0, // Material Design standard for secondary actions
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: UI.primaryColor,
          disabledForegroundColor: UI.textDisabledColor,
          side: BorderSide(color: onPressed == null ? UI.textDisabledColor : UI.primaryColor, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.borderRadiusMd)),
          padding: UI.paddingHorizontalMd,
        ),
        child: _buildButtonContent(text, icon, isLoading),
      ),
    );
  }

  // Text button (48dp for less prominent actions)
  static Widget text({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    IconData? icon,
    double? width,
    double? height,
  }) {
    return SizedBox(
      width: width,
      height: height ?? 48.0, // Standard height for text-only buttons
      child: TextButton(
        onPressed: isDisabled || isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: UI.primaryColor,
          disabledForegroundColor: UI.textDisabledColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.borderRadiusMd)),
          padding: UI.paddingHorizontalMd,
        ),
        child: _buildButtonContent(text, icon, isLoading),
      ),
    );
  }

  // Icon button (56x56dp minimum touch target)
  static Widget icon({
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    double? size,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: size ?? 56.0, // Increased from 32dp to 56dp for better touch targets
      height: size ?? 56.0,
      child: IconButton(
        onPressed: isDisabled || isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: UI.iconSizeSm,
                height: UI.iconSizeSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor ?? UI.primaryColor),
                ),
              )
            : UI.iconMedium(icon),
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor ?? UI.primaryColor,
          disabledForegroundColor: UI.textDisabledColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UI.borderRadiusMd)),
        ),
      ),
    );
  }

  // Floating action button
  static Widget floating({
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isDisabled = false,
    String? tooltip,
    Object? heroTag,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: isDisabled || isLoading ? null : onPressed,
      backgroundColor: UI.primaryColor,
      foregroundColor: UI.surfaceColor,
      tooltip: tooltip,
      child: isLoading
          ? SizedBox(
              width: UI.iconSizeSm,
              height: UI.iconSizeSm,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(UI.surfaceColor),
              ),
            )
          : UI.iconMedium(icon),
    );
  }

  // Helper method to build button content
  static Widget _buildButtonContent(String text, IconData? icon, bool isLoading) {
    if (isLoading) {
      return SizedBox(
        width: UI.iconSizeSm,
        height: UI.iconSizeSm,
        child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(UI.surfaceColor)),
      );
    }

    // Create text style without color to let button's foregroundColor take effect
    final textStyle = TextStyle(
      fontSize: UIText.buttonMediumStyle.fontSize,
      fontWeight: UIText.buttonMediumStyle.fontWeight,
      height: UIText.buttonMediumStyle.height,
      // No color specified - inherits from button's foregroundColor
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UI.iconSmall(icon),
          UI.spacingHorizontalSm,
          Text(text, style: textStyle),
        ],
      );
    }

    return Text(text, style: textStyle);
  }

  // Small primary button
  static Widget primarySmall({required String text, VoidCallback? onPressed, bool isLoading = false, IconData? icon}) {
    return primary(text: text, onPressed: onPressed, isLoading: isLoading, icon: icon, height: 36.0);
  }

  // Small secondary button
  static Widget secondarySmall({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return secondary(text: text, onPressed: onPressed, isLoading: isLoading, icon: icon, height: 36.0);
  }

  // Large primary button
  static Widget primaryLarge({required String text, VoidCallback? onPressed, bool isLoading = false, IconData? icon}) {
    return primary(text: text, onPressed: onPressed, isLoading: isLoading, icon: icon, height: 56.0);
  }

  // Large secondary button
  static Widget secondaryLarge({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
  }) {
    return secondary(text: text, onPressed: onPressed, isLoading: isLoading, icon: icon, height: 56.0);
  }
}
