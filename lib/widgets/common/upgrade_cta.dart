// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/common/upgrade_dialog.dart';

/// Simple shared Upgrade CTA banner used when a Pro/Scale-only feature
/// is surfaced in Community tier.
class UpgradeCta extends StatelessWidget {
  const UpgradeCta({
    super.key,
    required this.title,
    this.subtitle,
    this.onPressed,
    this.url,
    this.featureName,
    this.requiredTier = Tier.pro,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;
  final String? url;

  /// Optional feature name for upgrade tracking.
  final String? featureName;

  /// The tier required to unlock this feature. Defaults to [Tier.pro].
  final Tier requiredTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_open, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onPressed ?? () => _handleUpgrade(context),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    if (!context.mounted) return;

    UpgradeDialog.show(
      context,
      featureName: featureName ?? title,
      requiredTier: requiredTier,
    );
  }
}
