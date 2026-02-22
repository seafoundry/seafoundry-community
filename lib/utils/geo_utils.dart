// @tier: community
import 'dart:math';

import 'package:seafoundry_app/models/events/outplant_geometry.dart';

/// Common helpers for working with geographic coordinates without pulling in a
/// heavyweight GIS dependency.
class GeoUtils {
  const GeoUtils._();

  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static bool isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool isValidLongitude(double value) => value >= -180 && value <= 180;

  static bool isWithinDeltaDegrees({
    required GeoCoordinate coordinate,
    required GeoCoordinate center,
    double deltaDegrees = 0.5,
  }) {
    return (coordinate.latitude - center.latitude).abs() <= deltaDegrees &&
        (coordinate.longitude - center.longitude).abs() <= deltaDegrees;
  }

  /// Approximate great-circle distance in meters between two coordinates.
  static double distanceMeters(GeoCoordinate a, GeoCoordinate b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;

    final sinHalfLat = sin(dLat / 2);
    final sinHalfLng = sin(dLng / 2);
    final h = sinHalfLat * sinHalfLat +
        cos(lat1) * cos(lat2) * sinHalfLng * sinHalfLng;
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return earthRadius * c;
  }

  /// Great-circle distance in miles between two coordinates.
  static double distanceMiles(GeoCoordinate a, GeoCoordinate b) {
    return distanceMeters(a, b) / 1609.344;
  }

  static bool isWithinDistanceMiles({
    required GeoCoordinate coordinate,
    required GeoCoordinate center,
    double maxDistanceMiles = 0.25,
  }) {
    return distanceMiles(coordinate, center) <= maxDistanceMiles;
  }

  static GeoBounds computeBounds(List<GeoCoordinate> coordinates) {
    if (coordinates.isEmpty) {
      throw ArgumentError('Cannot compute bounds for empty coordinate list.');
    }

    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final coord in coordinates) {
      minLat = min(minLat, coord.latitude);
      maxLat = max(maxLat, coord.latitude);
      minLng = min(minLng, coord.longitude);
      maxLng = max(maxLng, coord.longitude);
    }

    return GeoBounds(
      southWest: GeoCoordinate(latitude: minLat, longitude: minLng),
      northEast: GeoCoordinate(latitude: maxLat, longitude: maxLng),
    );
  }

  static GeoCoordinate computeCentroid(List<GeoCoordinate> coordinates) {
    if (coordinates.isEmpty) {
      throw ArgumentError('Cannot compute centroid for empty coordinate list.');
    }

    double latSum = 0;
    double lngSum = 0;
    for (final coord in coordinates) {
      latSum += coord.latitude;
      lngSum += coord.longitude;
    }

    return GeoCoordinate(
      latitude: latSum / coordinates.length,
      longitude: lngSum / coordinates.length,
    );
  }

  /// Encode a geohash for the provided coordinate. Defaults to 7-character
  /// precision (~153m). Implementation adapted from the standard reference
  /// algorithm to avoid adding a new dependency.
  static String encodeGeohash(
    GeoCoordinate coordinate, {
    int precision = 7,
  }) {
    var latMin = -90.0;
    var latMax = 90.0;
    var lngMin = -180.0;
    var lngMax = 180.0;

    final buffer = StringBuffer();
    var bit = 0;
    var ch = 0;
    var evenBit = true;

    while (buffer.length < precision) {
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (coordinate.longitude >= mid) {
          ch |= 1 << (4 - bit);
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (coordinate.latitude >= mid) {
          ch |= 1 << (4 - bit);
          latMin = mid;
        } else {
          latMax = mid;
        }
      }

      evenBit = !evenBit;

      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Compute the area of a polygon in square meters using a spherical projection.
  /// This is an approximation suitable for regional-scale outplanting sites.
  static double computeAreaSquareMeters(List<GeoCoordinate> polygon) {
    if (polygon.length < 3) return 0.0;

    // Radius of the Earth in meters
    const earthRadius = 6371000.0;
    double area = 0.0;

    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;

      // Convert to radians
      final lat1 = polygon[i].latitude * pi / 180;
      final lat2 = polygon[j].latitude * pi / 180;
      final lng1 = polygon[i].longitude * pi / 180;
      final lng2 = polygon[j].longitude * pi / 180;

      area += (lng2 - lng1) * (2 + sin(lat1) + sin(lat2));
    }

    // Multiply by R^2 / 2 and take absolute value
    return (area * earthRadius * earthRadius / 2.0).abs();
  }

  /// Compute the area of a polygon in hectares.
  static double computeAreaHectares(List<GeoCoordinate> polygon) {
    return computeAreaSquareMeters(polygon) / 10000.0;
  }
}
