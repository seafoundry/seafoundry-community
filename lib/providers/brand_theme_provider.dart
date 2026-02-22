// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';

/// BrandTheme captures minimal theming for Visual Identity rails.
class BrandTheme {
  const BrandTheme({this.accentColor, this.heroImageUrl, this.logoUrl, this.brandName});

  factory BrandTheme.fromProfile(BrandProfile p) => BrandTheme(
        accentColor: _parseColor(p.accentColor),
        heroImageUrl: p.heroImageUrl,
        logoUrl: p.logoUrl,
        brandName: p.brandName,
      );

  final Color? accentColor;
  final String? heroImageUrl;
  final String? logoUrl;
  final String? brandName;

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final normalized = hex.replaceAll('#', '');
    try {
      if (normalized.length == 6) {
        return Color(int.parse('FF$normalized', radix: 16));
      }
      if (normalized.length == 8) {
        return Color(int.parse(normalized, radix: 16));
      }
    } catch (e) {
      // Invalid hex format, return null
      return null;
    }
    return null;
  }
}

class BrandThemeProvider extends InheritedWidget {
  const BrandThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  final BrandTheme theme;

  static BrandTheme of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<BrandThemeProvider>();
    return provider?.theme ?? const BrandTheme();
  }

  @override
  bool updateShouldNotify(covariant BrandThemeProvider oldWidget) {
    return theme != oldWidget.theme;
  }
}

