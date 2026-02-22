// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/common/upgrade_dialog.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Centered paywall panel for tier-gated tabs (Pro/Scale).
class TierPaywall extends StatelessWidget {
  const TierPaywall({
    super.key,
    required this.title,
    required this.subtitle,
    required this.featureName,
    required this.requiredTier,
  });

  final String title;
  final String subtitle;
  final String featureName;
  final Tier requiredTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _tierColor(requiredTier);
    final tierLabel = _tierLabel(requiredTier);
    final features = _featuresForTier(requiredTier);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(UI.borderRadiusLg),
              border: Border.all(color: tierColor.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: UI.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline, color: tierColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: UI.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TierBadge(label: _tierShortLabel(requiredTier), color: tierColor),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Included in $tierLabel:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: tierColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => UpgradeDialog.show(
                        context,
                        featureName: featureName,
                        requiredTier: requiredTier,
                      ),
                      icon: const Icon(Icons.rocket_launch),
                      label: Text('Upgrade to $tierLabel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tierColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(UI.borderRadiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

Color _tierColor(Tier tier) {
  switch (tier) {
    case Tier.community:
      return const Color(0xFF4CAF50);
    case Tier.pro:
      return const Color(0xFF2196F3);
    case Tier.scale:
      return const Color(0xFF9C27B0);
  }
}

String _tierLabel(Tier tier) {
  switch (tier) {
    case Tier.community:
      return 'Community';
    case Tier.pro:
      return 'Pro';
    case Tier.scale:
      return 'Scale';
  }
}

String _tierShortLabel(Tier tier) {
  switch (tier) {
    case Tier.community:
      return 'FREE';
    case Tier.pro:
      return 'PRO';
    case Tier.scale:
      return 'SCALE';
  }
}

List<String> _featuresForTier(Tier tier) {
  switch (tier) {
    case Tier.community:
      return const [
        'Core inventory management',
        'Basic outplanting workflows',
        'Six-field CSV export',
        'Public organization profiles',
        'Community support',
      ];
    case Tier.pro:
      return const [
        'Everything in Community, plus:',
        'Mobile apps (iOS & Android)',
        'Offline sync & data capture',
        'Advanced monitoring with KML/imagery',
        'Mortality reasons & detailed tracking',
        'All husbandry & observation actions',
        'Priority support',
      ];
    case Tier.scale:
      return const [
        'Everything in Pro, plus:',
        'Workforce management tools',
        'Training gates & compliance',
        'Recurring tasks & automation',
        'Advanced analytics & KPIs',
        'Custom deliverables planning',
        'Dedicated account manager',
      ];
  }
}
