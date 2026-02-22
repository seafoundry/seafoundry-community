// @tier: community
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui.dart';

/// Typography widget library for consistent text styling
class UIText {
  // Headings
  static TextStyle get h1Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeXxxl,
    fontWeight: FontWeight.bold,
    color: UI.textPrimaryColor,
    height: 1.2,
  );

  static TextStyle get h2Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeXxl,
    fontWeight: FontWeight.w600,
    color: UI.textPrimaryColor,
    height: 1.3,
  );

  static TextStyle get h3Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeXl,
    fontWeight: FontWeight.w600,
    color: UI.textPrimaryColor,
    height: 1.4,
  );

  static TextStyle get h4Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeLg,
    fontWeight: FontWeight.w500,
    color: UI.textPrimaryColor,
    height: 1.4,
  );

  static TextStyle get h5Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeMd,
    fontWeight: FontWeight.w500,
    color: UI.textPrimaryColor,
    height: 1.5,
  );

  static TextStyle get h6Style => GoogleFonts.outfit(
    fontSize: UI.fontSizeSm,
    fontWeight: FontWeight.w500,
    color: UI.textPrimaryColor,
    height: 1.5,
  );

  // Body text
  static TextStyle get bodyLargeStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeLg,
    fontWeight: FontWeight.normal,
    color: UI.textPrimaryColor,
    height: 1.5,
  );

  static TextStyle get bodyMediumStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeMd,
    fontWeight: FontWeight.normal,
    color: UI.textPrimaryColor,
    height: 1.5,
  );

  static TextStyle get bodySmallStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeSm,
    fontWeight: FontWeight.normal,
    color: UI.textSecondaryColor,
    height: 1.5,
  );

  static TextStyle get bodyXSmallStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeXs,
    fontWeight: FontWeight.normal,
    color: UI.textSecondaryColor,
    height: 1.5,
  );

  // Caption
  static TextStyle get captionStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeXs,
    fontWeight: FontWeight.normal,
    color: UI.textSecondaryColor,
    height: 1.4,
  );

  // Button text
  static TextStyle get buttonLargeStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeMd,
    fontWeight: FontWeight.w500,
    color: UI.surfaceColor,
    height: 1.2,
  );

  static TextStyle get buttonMediumStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeSm,
    fontWeight: FontWeight.w500,
    color: UI.surfaceColor,
    height: 1.2,
  );

  static TextStyle get buttonSmallStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeXs,
    fontWeight: FontWeight.w500,
    color: UI.surfaceColor,
    height: 1.2,
  );

  // Link text
  static TextStyle get linkStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeMd,
    fontWeight: FontWeight.w500,
    color: UI.primaryColor,
    height: 1.5,
    decoration: TextDecoration.underline,
  );

  // Overline
  static TextStyle get overlineStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeXs,
    fontWeight: FontWeight.w500,
    color: UI.textSecondaryColor,
    height: 1.2,
    letterSpacing: 1.5,
  );

  // Label
  static TextStyle get labelStyle => GoogleFonts.outfit(
    fontSize: UI.fontSizeSm,
    fontWeight: FontWeight.w500,
    color: UI.textSecondaryColor,
    height: 1.4,
  );

  // Helper methods for creating text widgets
  static Widget h1(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h1Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget h2(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h2Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget h3(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h3Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget h4(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h4Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget h5(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h5Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget h6(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: h6Style.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget bodyLarge(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: bodyLargeStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget bodyMedium(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: bodyMediumStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget bodySmall(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: bodySmallStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget bodyXSmall(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: bodyXSmallStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget caption(
    String text, {
    TextAlign? textAlign,
    Color? color,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: captionStyle.copyWith(color: color),
      textAlign: textAlign,
      overflow: overflow,
    );
  }

  static Widget label(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: labelStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }

  static Widget overline(String text, {TextAlign? textAlign, Color? color}) {
    return Text(
      text,
      style: overlineStyle.copyWith(color: color),
      textAlign: textAlign,
    );
  }
}
