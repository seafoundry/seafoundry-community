// @tier: community
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seafoundry_app/cubits/public_holdings_map/public_holdings_map_cubit.dart';
import 'package:seafoundry_app/cubits/tour/tour_cubit.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_legend.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_top_bar.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/holdings_map_utils.dart';
import 'package:seafoundry_app/widgets/public/holdings_map/marker_builder.dart';

/// Loading state widget shown while CRC data is being fetched.
class HoldingsMapLoadingState extends StatelessWidget {
  const HoldingsMapLoadingState({
    super.key,
    required this.loadingStatus,
  });

  final String loadingStatus;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            loadingStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: crcAccentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// The main map view with markers, top bar overlay, and legend.
class HoldingsMapView extends StatelessWidget {
  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      };

  const HoldingsMapView({
    super.key,
    required this.points,
    required this.cubitState,
    required this.controller,
    required this.showHeaderRow,
    required this.showSignIn,
    required this.showUpgradeCallout,
    required this.showBranding,
    required this.showCrosswalkSearch,
    required this.enableSampleImpactData,
    required this.initialShowFilters,
    required this.onSiteDetailsTap,
    required this.onCrosswalkSearch,
    required this.onHoldingsChanged,
    required this.onOutplantsChanged,
    required this.onCrcDataChanged,
    required this.onMapGesturesEnabled,
    this.upgradeUrl,
    this.onUpgrade,
  });

  final List<PublicImpactPoint> points;
  final PublicHoldingsMapState cubitState;
  final Completer<GoogleMapController> controller;
  final bool showHeaderRow;
  final bool showSignIn;
  final bool showUpgradeCallout;
  final bool showBranding;
  final bool showCrosswalkSearch;
  final bool enableSampleImpactData;
  final bool initialShowFilters;
  final void Function(ImpactCluster) onSiteDetailsTap;
  final VoidCallback onCrosswalkSearch;
  final ValueChanged<bool> onHoldingsChanged;
  final ValueChanged<bool> onOutplantsChanged;
  final ValueChanged<bool> onCrcDataChanged;
  final ValueChanged<bool> onMapGesturesEnabled;
  final String? upgradeUrl;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final tourCubit = context.read<TourCubit?>();
    if (kIsWeb && tourCubit != null) {
      return BlocBuilder<TourCubit, TourState>(
        builder: (context, tourState) {
          if (tourState is TourInProgress) {
            return _buildTourPlaceholder(context);
          }
          return _buildContent(context);
        },
      );
    }

    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final filtered = _filterPoints(points, cubitState);
    final clusters = clusterPoints(filtered);
    final markers = buildClusterMarkers(
      clusters,
      onSiteDetailsTap: onSiteDetailsTap,
    );

    return Stack(
      children: [
        _buildMap(
          deriveCamera(points),
          markers,
          points,
          cubitState.mapGesturesEnabled,
        ),
        HoldingsMapTopBar(
          showHeaderRow: showHeaderRow,
          showSignIn: showSignIn,
          showUpgradeCallout: showUpgradeCallout,
          showBranding: showBranding,
          showCrosswalkSearch: showCrosswalkSearch,
          enableSampleImpactData: enableSampleImpactData,
          initialShowFilters: initialShowFilters,
          cubitState: cubitState,
          onCrosswalkSearch: onCrosswalkSearch,
          onHoldingsChanged: onHoldingsChanged,
          onOutplantsChanged: onOutplantsChanged,
          onCrcDataChanged: onCrcDataChanged,
          onMapGesturesEnabled: onMapGesturesEnabled,
          upgradeUrl: upgradeUrl,
          onUpgrade: onUpgrade,
        ),
        const Positioned(
          bottom: 16,
          right: 16,
          child: SafeArea(child: HoldingsMapLegend()),
        ),
      ],
    );
  }

  Widget _buildTourPlaceholder(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'Map hidden during tour',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Finish the tour to explore the community map.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(
    CameraPosition camera,
    Set<Marker> markers,
    List<PublicImpactPoint> points,
    bool mapGesturesEnabled,
  ) {
    return Positioned.fill(
      child: GoogleMap(
        initialCameraPosition: camera,
        markers: markers,
        gestureRecognizers: _gestureRecognizers,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        zoomGesturesEnabled: mapGesturesEnabled,
        scrollGesturesEnabled: mapGesturesEnabled,
        onMapCreated: (mapController) {
          if (!controller.isCompleted) {
            controller.complete(mapController);
            fitCameraToPoints(mapController, points);
          }
        },
        compassEnabled: false,
        mapType: MapType.satellite,
      ),
    );
  }

  List<PublicImpactPoint> _filterPoints(
    List<PublicImpactPoint> points,
    PublicHoldingsMapState state,
  ) {
    return points
        .where((p) {
          if (p.pointType == PublicImpactPointType.holding) {
            return state.showHoldings;
          }
          return state.showOutplants;
        })
        .toList(growable: false);
  }
}
