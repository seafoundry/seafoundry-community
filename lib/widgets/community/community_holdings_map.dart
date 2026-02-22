// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/screens/public/public_holdings_map_screen.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';

/// Embedded holdings map for community view
///
/// Reuses logic from PublicHoldingsMapScreen but as an embeddable widget
/// Shows cross-organization impact points with CRC historical data
class CommunityHoldingsMap extends StatefulWidget {
  const CommunityHoldingsMap({
    super.key,
    this.height = 400,
    this.showFilters = false,
    this.isFullWidth = false,
  });

  final double height;
  final bool showFilters;
  final bool isFullWidth;

  @override
  State<CommunityHoldingsMap> createState() => _CommunityHoldingsMapState();
}

class _CommunityHoldingsMapState extends State<CommunityHoldingsMap> {
  // Cache the service to prevent creating a new instance on every rebuild.
  // CRITICAL: Creating PublicReadModelsService in build() causes infinite
  // rebuilds on web because each new instance creates a new Firestore stream,
  // which emits initial data, triggering a rebuild, creating another stream...
  late final PublicReadModelsService _readModelsService;

  @override
  void initState() {
    super.initState();
    _readModelsService = PublicReadModelsService();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullWidth) {
      return SizedBox(
        height: widget.height,
        child: PublicHoldingsMapScreen(
          orgId: 'community',
          enableSampleImpactData: true,
          readModelsService: _readModelsService,
          initialShowFilters: widget.showFilters,
          showBranding: false,
          showCrosswalkSearch: false,
          hideSignIn: true, // User is already authenticated in community view
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(Spacing.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: Spacing.sm),
                Text(
                  'Community Holdings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: widget.height,
            child: PublicHoldingsMapScreen(
              orgId: 'community',
              enableSampleImpactData: true,
              readModelsService: _readModelsService,
              initialShowFilters: widget.showFilters,
              showBranding: false,
              showCrosswalkSearch: false,
              hideSignIn: true, // User is already authenticated in community view
            ),
          ),
        ],
      ),
    );
  }
}
