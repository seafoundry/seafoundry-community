// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/widgets/visual/brand_logo.dart';

/// Minimal BrandAware Kiosk Entry placeholder; mount via public route in the future.
class BrandAwareKioskEntry extends StatelessWidget {
  const BrandAwareKioskEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = BrandThemeProvider.of(context);
    final hasLogo = brand.logoUrl != null && brand.logoUrl!.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: [
          if (hasLogo)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const BrandLogo(height: 80),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(240, 56),
                ),
                onPressed: () {},
                child: Text('Enter ${brand.brandName ?? 'Kiosk'}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
