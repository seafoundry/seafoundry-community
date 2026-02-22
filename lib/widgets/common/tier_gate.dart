// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/common/upgrade_dialog.dart';

/// Visual gate for tier-locked features with clear visual indicators
///
/// Wraps widgets and provides visual feedback when features are locked:
/// - Overlay with lock icon for locked features
/// - Reduced opacity to indicate unavailability
/// - Tap to show upgrade dialog
/// - Supports both subtle and prominent display modes
///
/// Usage:
/// ```dart
/// TierGate(
///   requiredTier: Tier.pro,
///   featureName: 'Advanced Fragmentation',
///   child: FragmentationButton(),
/// )
/// ```
class TierGate extends StatelessWidget {
  /// The widget to display (may be locked/disabled)
  final Widget child;

  /// Minimum tier required to access this feature
  final Tier requiredTier;

  /// Human-readable name of the feature for upgrade messaging
  final String featureName;

  /// Optional feature key for checking specific feature flags
  final String? featureKey;

  /// Whether to show a prominent lock overlay vs subtle indicator
  final TierGateMode mode;

  /// Whether to completely hide the feature when locked (vs showing disabled)
  final bool hideWhenLocked;

  /// Optional callback when user taps locked feature
  final VoidCallback? onLockedTap;

  /// Custom message to show when feature is locked
  final String? lockedMessage;

  /// Whether to show a badge indicator
  final bool showBadge;

  const TierGate({
    super.key,
    required this.child,
    required this.requiredTier,
    required this.featureName,
    this.featureKey,
    this.mode = TierGateMode.overlay,
    this.hideWhenLocked = false,
    this.onLockedTap,
    this.lockedMessage,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use maybeOf pattern to safely access FeatureAccessService
    // SECURITY: Deny access by default when provider is missing
    FeatureAccessService? featureAccess;
    try {
      featureAccess = context.watch<FeatureAccessService>();
    } catch (_) {
      // FeatureAccessService not provided - deny access by default (security)
      // Show graceful UI indicating tier cannot be determined
      if (hideWhenLocked) {
        return const SizedBox.shrink();
      }
      return _buildTierUnavailable(context);
    }

    // Check if feature is accessible
    final hasAccess = _checkAccess(featureAccess);

    // Hide completely if requested
    if (!hasAccess && hideWhenLocked) {
      return const SizedBox.shrink();
    }

    // Feature is accessible, show normally
    if (hasAccess) {
      return child;
    }

    // Feature is locked, show with visual indicators
    return _buildLockedFeature(context, featureAccess);
  }

  bool _checkAccess(FeatureAccessService featureAccess) {
    // Check specific feature flag if provided
    if (featureKey != null) {
      return featureAccess.isFeatureEnabled(featureKey!);
    }

    // Otherwise check tier level
    return featureAccess.tier.allows(requiredTier);
  }

  Widget _buildLockedFeature(BuildContext context, FeatureAccessService featureAccess) {
    switch (mode) {
      case TierGateMode.overlay:
        return _buildOverlayMode(context, featureAccess);
      case TierGateMode.subtle:
        return _buildSubtleMode(context, featureAccess);
      case TierGateMode.badge:
        return _buildBadgeMode(context, featureAccess);
    }
  }

  /// Build UI when tier information is unavailable (provider missing)
  /// SECURITY: This denies access by showing a locked state rather than granting access
  Widget _buildTierUnavailable(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _showTierUnavailableMessage(context);
      },
      child: Stack(
        children: [
          // Disabled child with reduced opacity
          Opacity(
            opacity: 0.3,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: AbsorbPointer(
                absorbing: true,
                child: child,
              ),
            ),
          ),
          // Unavailable indicator overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(UI.borderRadiusMd),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(UI.borderRadiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 32.0,
                        color: UI.textSecondaryColor,
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          'UNAVAILABLE',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTierUnavailableMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Unable to verify access for "$featureName". Please try again later.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildOverlayMode(BuildContext context, FeatureAccessService featureAccess) {
    return GestureDetector(
      onTap: () => _handleLockedTap(context, featureAccess),
      child: Stack(
        children: [
          // Disabled child with reduced opacity
          Opacity(
            opacity: 0.4,
            child: AbsorbPointer(
              absorbing: true,
              child: child,
            ),
          ),
          // Lock overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UI.borderRadiusMd),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(UI.borderRadiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 32.0,
                        color: UI.textSecondaryColor,
                      ),
                      if (showBadge) ...[
                        const SizedBox(height: 4.0),
                        _buildTierLabel(requiredTier),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtleMode(BuildContext context, FeatureAccessService featureAccess) {
    return GestureDetector(
      onTap: () => _handleLockedTap(context, featureAccess),
      child: Opacity(
        opacity: 0.6,
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: true,
              child: child,
            ),
            if (showBadge)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: _getTierColor(requiredTier),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 12.0,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2.0),
                      Text(
                        _getTierShortLabel(requiredTier),
                        style: const TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeMode(BuildContext context, FeatureAccessService featureAccess) {
    return GestureDetector(
      onTap: () => _handleLockedTap(context, featureAccess),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Child with reduced opacity but unchanged layout
          Opacity(
            opacity: 0.5,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: AbsorbPointer(
                absorbing: true,
                child: child,
              ),
            ),
          ),
          // Badge positioned in top-right corner
          Positioned(
            top: -4,
            right: -4,
            child: _buildCompactTierBadge(requiredTier),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTierBadge(Tier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _getTierColor(tier), width: 1.5),
        borderRadius: BorderRadius.circular(6.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 12.0,
            color: _getTierColor(tier),
          ),
          const SizedBox(width: 3.0),
          Text(
            _getTierShortLabel(tier),
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
              color: _getTierColor(tier),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierLabel(Tier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: _getTierColor(tier),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        _getTierShortLabel(tier),
        style: const TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  void _handleLockedTap(BuildContext context, FeatureAccessService featureAccess) {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Custom callback
    if (onLockedTap != null) {
      onLockedTap!();
      return;
    }

    // Show upgrade dialog
    UpgradeDialog.show(
      context,
      featureName: featureName,
      requiredTier: requiredTier,
      customMessage: lockedMessage,
    );
  }

  Color _getTierColor(Tier tier) {
    switch (tier) {
      case Tier.community:
        return const Color(0xFF4CAF50); // Green
      case Tier.pro:
        return const Color(0xFF2196F3); // Blue
      case Tier.scale:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  String _getTierShortLabel(Tier tier) {
    switch (tier) {
      case Tier.community:
        return 'FREE';
      case Tier.pro:
        return 'PRO';
      case Tier.scale:
        return 'SCALE';
    }
  }
}

/// Display mode for tier-gated features
enum TierGateMode {
  /// Prominent overlay with lock icon
  overlay,

  /// Subtle opacity reduction with small badge
  subtle,

  /// Side badge with lock icon
  badge,
}

/// Convenience widget for Pro-only features
class ProGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final String? featureKey;
  final TierGateMode mode;
  final bool hideWhenLocked;

  const ProGate({
    super.key,
    required this.child,
    required this.featureName,
    this.featureKey,
    this.mode = TierGateMode.overlay,
    this.hideWhenLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return TierGate(
      requiredTier: Tier.pro,
      featureName: featureName,
      featureKey: featureKey,
      mode: mode,
      hideWhenLocked: hideWhenLocked,
      child: child,
    );
  }
}

/// Convenience widget for Scale-only features
class ScaleGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final String? featureKey;
  final TierGateMode mode;
  final bool hideWhenLocked;

  const ScaleGate({
    super.key,
    required this.child,
    required this.featureName,
    this.featureKey,
    this.mode = TierGateMode.overlay,
    this.hideWhenLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return TierGate(
      requiredTier: Tier.scale,
      featureName: featureName,
      featureKey: featureKey,
      mode: mode,
      hideWhenLocked: hideWhenLocked,
      child: child,
    );
  }
}