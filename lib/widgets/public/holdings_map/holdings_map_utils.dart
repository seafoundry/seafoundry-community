// @tier: community
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:seafoundry_app/models/historical/nomenclature_system.dart';
import 'package:seafoundry_app/models/historical/provenance_id.dart';
import 'package:seafoundry_app/models/public_read_models/impact_cluster.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';

/// Accent color used for CRC (Coral Restoration Consortium) data display.
const Color crcAccentColor = Color(0xFF00897B);

/// Radius in degrees for geographic clustering (~2km bucket).
const double clusterRadiusDegrees = 0.02;

/// Dataset identifier for CRC 2024 historical data.
const String crcDatasetId = 'crc_2024';

/// Default camera position centered on the Caribbean to show CRC restoration sites.
const CameraPosition fallbackCameraPosition = CameraPosition(
  target: LatLng(20.0, -75.0),
  zoom: 4,
);

/// Clusters impact points by geographic proximity.
///
/// When there are 8 or fewer points, returns each point as its own cluster.
/// Otherwise, groups points into buckets based on [clusterRadiusDegrees].
List<ImpactCluster> clusterPoints(List<PublicImpactPoint> points) {
  if (points.length <= 8) {
    return points
        .map((p) => ImpactCluster.fromPoint(p))
        .toList(growable: false);
  }
  final buckets = <String, ImpactCluster>{};
  for (final point in points) {
    final latBucket = (point.latitude / clusterRadiusDegrees).floor();
    final lngBucket = (point.longitude / clusterRadiusDegrees).floor();
    final key = '${point.pointType.name}_${latBucket}_$lngBucket';
    final existing = buckets[key];
    if (existing == null) {
      buckets[key] = ImpactCluster.fromPoint(point);
    } else {
      buckets[key] = existing.merge(point);
    }
  }
  return buckets.values.toList(growable: false);
}

/// Derives the initial camera position for the map.
/// Currently returns a Caribbean-wide view to show the scope of restoration work.
CameraPosition deriveCamera(List<PublicImpactPoint> points) {
  // Always start with Caribbean-wide view to show scope of restoration work
  return fallbackCameraPosition;
}

/// Fits the camera bounds to show all points in the Caribbean/Atlantic region.
///
/// Filters to Caribbean region (lat 10-35, lon -100 to -50) to prevent
/// outliers from affecting zoom level.
Future<void> fitCameraToPoints(
  GoogleMapController controller,
  List<PublicImpactPoint> points,
) async {
  if (points.length < 2) return;

  // Filter to Caribbean/Atlantic region only for initial camera bounds
  // This prevents Australia, Pacific, etc. from affecting zoom
  final caribbeanPoints = points
      .where((p) =>
          p.latitude >= 10 &&
          p.latitude <= 35 &&
          p.longitude >= -100 &&
          p.longitude <= -50)
      .toList();

  if (caribbeanPoints.length < 2) return;

  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;

  for (final point in caribbeanPoints) {
    minLat =
        minLat == null ? point.latitude : math.min(minLat, point.latitude);
    maxLat =
        maxLat == null ? point.latitude : math.max(maxLat, point.latitude);
    minLng =
        minLng == null ? point.longitude : math.min(minLng, point.longitude);
    maxLng =
        maxLng == null ? point.longitude : math.max(maxLng, point.longitude);
  }

  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return;
  }

  final bounds = LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );

  await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
}

/// Formats a number with K/M suffixes for large values.
String formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

/// Formats an event date string (YYYY-MM-DD) into a human-readable format.
String formatEventDate(String date) {
  if (date == 'Unknown') return date;
  try {
    final parts = date.split('-');
    if (parts.length == 3) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      if (month >= 1 && month <= 12) {
        return '${months[month - 1]} $day, ${parts[0]}';
      }
    }
  } catch (_) {
    // Return original date if parsing fails
  }
  return date;
}

/// Abbreviates a species name (e.g., "Acropora cervicornis" to "A. cervicornis").
String abbreviateSpecies(String speciesName) {
  final parts = speciesName.split(' ');
  if (parts.length >= 2 && parts[0].isNotEmpty) {
    return '${parts[0][0]}. ${parts.sublist(1).join(' ')}';
  }
  return speciesName;
}

/// Picks a stable alias label for map tables, preferring Mote (Org A).
String resolveAliasLabel(ProvenanceId? provenance, {String? localId}) {
  if (provenance == null) return '-';

  final candidates = <String>[];

  void addCandidate(String? value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (!ClonalIdDisplayService.isHumanReadable(trimmed)) return;
    if (!candidates.contains(trimmed)) {
      candidates.add(trimmed);
    }
  }

  // Prefer Mote alias when available, then all other aliases, then raw aliases.
  addCandidate(provenance.aliases[NomenclatureSystem.orgA.aliasKey]);
  for (final alias in provenance.aliases.values) {
    addCandidate(alias);
  }
  for (final alias in provenance.rawAliases) {
    addCandidate(alias);
  }

  if (candidates.isEmpty) return '-';

  final localNormalized = localId?.trim().toUpperCase();
  if (localNormalized != null && localNormalized.isNotEmpty) {
    final candidate = candidates.firstWhere(
      (alias) => alias.trim().toUpperCase() != localNormalized,
      orElse: () => candidates.first,
    );
    return candidate;
  }

  return candidates.first;
}
