// @tier: community
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/widgets/map/platform_marker_helper.dart';

/// Callback type for when a CRC site marker is tapped.
typedef OnSiteDetailsTap = void Function(ImpactCluster cluster);

/// Cache for pre-loaded marker icons used by [buildClusterMarkers].
Map<double, BitmapDescriptor> _markerIconCache = {};

/// Pre-loads marker icons for use in [buildClusterMarkers].
///
/// Call this once before using [buildClusterMarkers] to ensure colored markers
/// work on web. Icons are cached for reuse.
Future<void> preloadClusterMarkerIcons() async {
  final hues = [
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueOrange,
  ];
  for (final hue in hues) {
    if (!_markerIconCache.containsKey(hue)) {
      _markerIconCache[hue] = await PlatformMarkerHelper.getMarkerIcon(hue);
    }
  }
}

/// Gets a marker icon for the given hue, using cache if available.
BitmapDescriptor _getMarkerIcon(double hue) {
  return _markerIconCache[hue] ?? BitmapDescriptor.defaultMarkerWithHue(hue);
}

/// Builds map markers from impact clusters.
///
/// Uses different colors for CRC data vs regular holdings/outplants.
/// For best results on web, call [preloadClusterMarkerIcons] first.
Set<Marker> buildClusterMarkers(
  List<ImpactCluster> clusters, {
  OnSiteDetailsTap? onSiteDetailsTap,
}) {
  return clusters.map((cluster) {
    final isHolding = cluster.pointType == PublicImpactPointType.holding;
    final isCrcData = cluster.id.startsWith('crc-') ||
        cluster.id.startsWith('nursery-') ||
        cluster.id.startsWith('partner-');

    BitmapDescriptor color;
    if (isCrcData) {
      color = isHolding
          ? _getMarkerIcon(BitmapDescriptor.hueCyan)
          : _getMarkerIcon(BitmapDescriptor.hueGreen);
    } else {
      color = isHolding
          ? _getMarkerIcon(BitmapDescriptor.hueBlue)
          : _getMarkerIcon(BitmapDescriptor.hueOrange);
    }

    final multiSite = cluster.siteCount > 1;
    final titleBase = multiSite
        ? (isHolding ? 'Holdings' : 'Outplants')
        : (cluster.label ?? (isHolding ? 'Holdings' : 'Outplants'));
    final title =
        multiSite ? '$titleBase (${cluster.siteCount} sites)' : titleBase;
    final source = isCrcData ? ' (CRC)' : '';
    final snippetLines = <String>['${cluster.magnitude} colonies$source'];
    final breakdownSnippet = _formatBreakdownSnippet(cluster);
    if (breakdownSnippet != null) {
      snippetLines.add(breakdownSnippet);
    }
    if (onSiteDetailsTap != null) {
      snippetLines.add('Tap for details');
    }
    final snippet = snippetLines.join('\n');

    return Marker(
      markerId: MarkerId(cluster.id),
      position: LatLng(cluster.latitude, cluster.longitude),
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
        onTap: onSiteDetailsTap != null ? () => onSiteDetailsTap(cluster) : null,
      ),
      icon: color,
      onTap: onSiteDetailsTap != null ? () => onSiteDetailsTap(cluster) : null,
    );
  }).toSet();
}

String? _formatBreakdownSnippet(ImpactCluster cluster) {
  final breakdown = cluster.provenanceIdBreakdown.isNotEmpty
      ? cluster.provenanceIdBreakdown
      : cluster.genetBreakdown;
  if (breakdown.isEmpty) return null;

  final entries = breakdown.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = entries.first;
  final remaining = entries.length - 1;
  final label = cluster.provenanceIdBreakdown.isNotEmpty
      ? 'Top PID'
      : 'Top genet';
  final extra = remaining > 0 ? ' +$remaining' : '';
  return '$label: ${top.key} (${top.value})$extra';
}
