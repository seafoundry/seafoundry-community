// @tier: community
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/buttons.dart';
import 'package:seafoundry_app/widgets/dialogs/beta_signup_dialog.dart';
import 'package:seafoundry_app/widgets/ui.dart';

/// Upgrade dialog that shows when users try to access tier-locked features
///
/// Features:
/// - Beautiful feature comparison table
/// - Clear value proposition for each tier
/// - Direct upgrade CTA with Stripe Payment Links
/// - Contextual messaging based on current tier
///
/// Usage:
/// ```dart
/// UpgradeDialog.show(
///   context,
///   featureName: 'Advanced Monitoring',
///   requiredTier: Tier.pro,
/// );
/// ```
class UpgradeDialog extends StatelessWidget {
  /// Name of the feature that triggered the dialog
  final String featureName;

  /// Tier required for the feature
  final Tier requiredTier;

  /// Optional custom message to display
  final String? customMessage;

  /// Whether to show the full feature comparison
  final bool showFeatureComparison;

  /// Current user's tier (passed in to avoid provider scope issues in dialogs)
  final Tier currentTier;

  /// URL for upgrading (passed in to avoid provider scope issues in dialogs)
  final String? upgradeUrl;

  /// Callback to show the purchase sheet (uses caller context, not dialog context)
  final VoidCallback _onUpgrade;

  const UpgradeDialog({
    super.key,
    required this.featureName,
    required this.requiredTier,
    required this.currentTier,
    required VoidCallback onUpgrade,
    this.upgradeUrl,
    this.customMessage,
    this.showFeatureComparison = true,
  }) : _onUpgrade = onUpgrade;

  /// Maps a required [Tier] to the primary purchasable feature key
  /// from `config/features.yaml`. Falls back to the tier name when
  /// no specific mapping exists.
  static String featureKeyForTier(Tier tier) {
    return switch (tier) {
      Tier.community => 'community',
      Tier.pro => 'monitoring_advanced',
      Tier.scale => 'recurring_tasks',
    };
  }

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required Tier requiredTier,
    String? customMessage,
    bool showFeatureComparison = true,
  }) {
    final featureAccess = context.read<FeatureAccessService>();
    final currentTier = featureAccess.tier;
    final upgradeUrl = featureAccess.upgradeUrlForTier(requiredTier);

    // Capture the caller context for the purchase sheet callback.
    // The dialog context (inside showDialog) does not inherit parent
    // providers, so we must use the original context here.
    final callerContext = context;

    return showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => UpgradeDialog(
        featureName: featureName,
        requiredTier: requiredTier,
        currentTier: currentTier,
        upgradeUrl: upgradeUrl,
        customMessage: customMessage,
        showFeatureComparison: showFeatureComparison,
        onUpgrade: () {
          // Pop the upgrade dialog first
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          // Community edition: show beta signup instead of purchase
          if (callerContext.mounted) {
            showBetaSignupDialog(
              context: callerContext,
              featureName: featureName,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UI.borderRadiusXl),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            _buildContent(theme),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: UI.paddingLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getTierColor(requiredTier),
            _getTierColor(requiredTier).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(UI.borderRadiusXl),
          topRight: Radius.circular(UI.borderRadiusXl),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _getTierIcon(requiredTier),
            size: 48.0,
            color: Colors.white,
          ),
          UI.dividerSm,
          Text(
            _getTierTitle(requiredTier),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          UI.dividerXs,
          Text(
            _getTierTagline(requiredTier),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Container(
      padding: UI.paddingLg,
      child: Column(
        children: [
          // Feature context
          Container(
            padding: UI.paddingMd,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(UI.borderRadiusMd),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                  size: 20.0,
                ),
                UI.spacingHorizontalSm,
                Expanded(
                  child: Text(
                    customMessage ??
                        '"$featureName" is available in ${_getTierLabel(requiredTier)} and above',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          UI.dividerLg,

          // Feature highlights
          if (showFeatureComparison) ...[
            Text(
              'What\'s included in ${_getTierLabel(requiredTier)}:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            UI.dividerMd,
            _buildFeatureList(requiredTier),
            UI.dividerLg,
          ],

          // Current tier status
          _buildCurrentTierStatus(currentTier, requiredTier),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: UI.paddingLg,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(UI.borderRadiusXl),
          bottomRight: Radius.circular(UI.borderRadiusXl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButtons.text(
            text: 'Maybe Later',
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          UI.spacingHorizontalMd,
          AppButtons.primary(
            text: _getUpgradeButtonText(currentTier, requiredTier),
            icon: Icons.rocket_launch,
            onPressed: _onUpgrade,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(Tier tier) {
    final features = _getFeaturesForTier(tier);

    return Column(
      children: features
          .map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _getTierColor(tier),
                    size: 20.0,
                  ),
                  UI.spacingHorizontalSm,
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCurrentTierStatus(Tier currentTier, Tier requiredTier) {
    final isEligibleForUpgrade = currentTier.rank < requiredTier.rank;

    if (!isEligibleForUpgrade) {
      return Container(
        padding: UI.paddingMd,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(UI.borderRadiusMd),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green[700], size: 20.0),
            UI.spacingHorizontalSm,
            Expanded(
              child: Text(
                'This feature requires ${_getTierLabel(requiredTier)} tier',
                style: TextStyle(color: Colors.green[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: UI.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTierColor(currentTier).withValues(alpha: 0.05),
            _getTierColor(requiredTier).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(UI.borderRadiusMd),
        border: Border.all(
          color: _getTierColor(requiredTier).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTierIndicator(currentTier, 'Current', true),
              Expanded(
                child: Container(
                  height: 2,
                  margin: UI.paddingHorizontalSm,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getTierColor(currentTier),
                        _getTierColor(requiredTier),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              _buildTierIndicator(requiredTier, 'Required', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierIndicator(Tier tier, String label, bool isCurrent) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isCurrent
                ? _getTierColor(tier).withValues(alpha: 0.1)
                : _getTierColor(tier),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getTierColor(tier),
              width: isCurrent ? 1.0 : 0.0,
            ),
          ),
          child: Text(
            _getTierShortLabel(tier),
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: isCurrent ? _getTierColor(tier) : Colors.white,
            ),
          ),
        ),
        UI.dividerXs,
        Text(
          label,
          style: TextStyle(fontSize: 11.0, color: UI.textSecondaryColor),
        ),
      ],
    );
  }

  Color _getTierColor(Tier tier) {
    return switch (tier) {
      Tier.community => const Color(0xFF4CAF50),
      Tier.pro => const Color(0xFF2196F3),
      Tier.scale => const Color(0xFF9C27B0),
    };
  }

  IconData _getTierIcon(Tier tier) {
    return switch (tier) {
      Tier.community => Icons.waves,
      Tier.pro => Icons.workspace_premium,
      Tier.scale => Icons.rocket_launch,
    };
  }

  String _getTierLabel(Tier tier) {
    return switch (tier) {
      Tier.community => 'Community',
      Tier.pro => 'Pro',
      Tier.scale => 'Scale',
    };
  }

  String _getTierShortLabel(Tier tier) {
    return switch (tier) {
      Tier.community => 'FREE',
      Tier.pro => 'PRO',
      Tier.scale => 'SCALE',
    };
  }

  String _getTierTitle(Tier tier) {
    return switch (tier) {
      Tier.community => 'SeaFoundry Community',
      Tier.pro => 'SeaFoundry Pro',
      Tier.scale => 'SeaFoundry Scale',
    };
  }

  String _getTierTagline(Tier tier) {
    return switch (tier) {
      Tier.community => 'Essential tools for marine restoration',
      Tier.pro => 'Advanced features for professional teams',
      Tier.scale => 'Enterprise-grade workforce management',
    };
  }

  String _getUpgradeButtonText(Tier current, Tier required) {
    if (current.rank >= required.rank) {
      return 'Learn More';
    }
    return 'Upgrade to ${_getTierLabel(required)}';
  }

  List<String> _getFeaturesForTier(Tier tier) {
    return switch (tier) {
      Tier.community => [
          'Core inventory management',
          'Basic outplanting workflows',
          'Six-field CSV export',
          'Public organization profiles',
          'Community support',
        ],
      Tier.pro => [
          'Everything in Community, plus:',
          'Mobile apps (iOS & Android)',
          'Offline sync & data capture',
          'Advanced monitoring with KML/imagery',
          'Mortality reasons & detailed tracking',
          'All husbandry & observation actions',
          'Priority support',
        ],
      Tier.scale => [
          'Everything in Pro, plus:',
          'Workforce management tools',
          'Training gates & compliance',
          'Recurring tasks & automation',
          'Advanced analytics & KPIs',
          'Custom deliverables planning',
          'Dedicated account manager',
        ],
    };
  }
}
