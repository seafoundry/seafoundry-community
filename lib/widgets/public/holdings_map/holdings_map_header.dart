// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/screens/auth/auth_screen.dart';
import 'package:seafoundry_app/widgets/visual/brand_logo.dart';

/// Header widget for the public holdings map screen.
///
/// Displays brand logo/name and action buttons (crosswalk search, sign in).
class HoldingsMapHeader extends StatelessWidget {
  const HoldingsMapHeader({
    super.key,
    required this.showBranding,
    required this.showCrosswalkSearch,
    required this.showSignIn,
    this.onCrosswalkSearch,
  });

  final bool showBranding;
  final bool showCrosswalkSearch;
  final bool showSignIn;
  final VoidCallback? onCrosswalkSearch;

  @override
  Widget build(BuildContext context) {
    final brand = BrandThemeProvider.of(context);
    final hasLogo = brand.logoUrl != null && brand.logoUrl!.isNotEmpty;
    final showActionButtons = showCrosswalkSearch || showSignIn;

    return Row(
      children: [
        if (showBranding) _buildBrandCard(brand, hasLogo),
        if (showActionButtons) const Spacer(),
        if (showActionButtons)
          _buildActionButtonsCard(context, showActionButtons),
      ],
    );
  }

  Widget _buildBrandCard(BrandTheme brand, bool hasLogo) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasLogo) ...[
              const BrandLogo(height: 24),
              const SizedBox(width: 12),
            ],
            Text(
              brand.brandName ?? 'Holdings Map',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsCard(BuildContext context, bool showActionButtons) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCrosswalkSearch)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Find Genet (Crosswalk)',
              onPressed: onCrosswalkSearch,
            ),
          if (showCrosswalkSearch && showSignIn)
            Container(
              height: 24,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          if (showSignIn)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthScreen(showBackButton: true),
                  ),
                );
              },
              child: const Text('Sign In'),
            ),
        ],
      ),
    );
  }
}

/// Callout widget for selective sharing upgrade prompt.
///
/// Shown to non-Pro users in preview mode to encourage upgrading.
class SelectiveSharingCallout extends StatelessWidget {
  const SelectiveSharingCallout({
    super.key,
    this.upgradeUrl,
    this.onUpgrade,
  });

  final String? upgradeUrl;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFFB26A00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Selective sharing is Pro-only. Use partner-only pins and '
                'private overlays after upgrading.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: upgradeUrl == null ? null : onUpgrade,
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}
