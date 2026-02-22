// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/public_holdings_map/public_holdings_map_cubit.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/crc_filter_panel.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_header.dart';

/// Top bar overlay for the public holdings map.
///
/// Positioned at the top of the map, contains:
/// - Header with branding and action buttons
/// - Upgrade callout for non-Pro users in preview mode
/// - Filter panel for holdings/outplants/CRC data
class HoldingsMapTopBar extends StatelessWidget {
  const HoldingsMapTopBar({
    super.key,
    required this.showHeaderRow,
    required this.showSignIn,
    required this.showUpgradeCallout,
    required this.showBranding,
    required this.showCrosswalkSearch,
    required this.enableSampleImpactData,
    required this.initialShowFilters,
    required this.cubitState,
    required this.onCrosswalkSearch,
    required this.onHoldingsChanged,
    required this.onOutplantsChanged,
    required this.onCrcDataChanged,
    required this.onMapGesturesEnabled,
    this.upgradeUrl,
    this.onUpgrade,
  });

  final bool showHeaderRow;
  final bool showSignIn;
  final bool showUpgradeCallout;
  final bool showBranding;
  final bool showCrosswalkSearch;
  final bool enableSampleImpactData;
  final bool initialShowFilters;
  final PublicHoldingsMapState cubitState;
  final VoidCallback onCrosswalkSearch;
  final ValueChanged<bool> onHoldingsChanged;
  final ValueChanged<bool> onOutplantsChanged;
  final ValueChanged<bool> onCrcDataChanged;
  final ValueChanged<bool> onMapGesturesEnabled;
  final String? upgradeUrl;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final topPadding = showHeaderRow || showUpgradeCallout ? 16.0 : 8.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
          child: MouseRegion(
            onEnter: (_) => onMapGesturesEnabled(false),
            onExit: (_) => onMapGesturesEnabled(true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showUpgradeCallout) ...[
                  SelectiveSharingCallout(
                    upgradeUrl: upgradeUrl,
                    onUpgrade: onUpgrade,
                  ),
                  if (showHeaderRow) const SizedBox(height: 8),
                ],
                if (showHeaderRow)
                  HoldingsMapHeader(
                    showBranding: showBranding,
                    showCrosswalkSearch: showCrosswalkSearch,
                    showSignIn: showSignIn,
                    onCrosswalkSearch: onCrosswalkSearch,
                  ),
                if (showHeaderRow || showUpgradeCallout) const SizedBox(height: 8),
                CrcFilterPanel(
                  showHoldings: cubitState.showHoldings,
                  showOutplants: cubitState.showOutplants,
                  showCrcData: cubitState.showCrcData,
                  enableSampleImpactData: enableSampleImpactData,
                  initialShowFilters: initialShowFilters,
                  onHoldingsChanged: onHoldingsChanged,
                  onOutplantsChanged: onOutplantsChanged,
                  onCrcDataChanged: onCrcDataChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
