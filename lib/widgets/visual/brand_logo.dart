import 'package:flutter/material.dart';
import 'package:seafoundry_community/providers/brand_theme_provider.dart';

/// Displays the organization's brand logo
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 32.0,
    this.fit = BoxFit.contain,
  });

  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = BrandThemeProvider.of(context);
    final logoUrl = theme.logoUrl;

    if (logoUrl == null || logoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Image.network(
      logoUrl,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          height: height,
          width: height,
          child: Center(
            child: SizedBox(
              width: height * 0.5,
              height: height * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
