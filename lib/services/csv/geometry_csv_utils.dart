// @tier: community
import 'package:seafoundry_app/models/events/outplant_geometry.dart';

/// Shared utilities for parsing geometry metadata from CSV cells so both the
/// translation adapters and the import service follow the same rules.
class GeometryCsvUtils {
  static const Set<String> _clearTokens = {'clear', 'remove', 'none'};
  static final RegExp _coordinateDelimiter = RegExp(r'[;\n|]+');

  static String normalizeTypeToken(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static bool isClearToken(String normalizedType) =>
      _clearTokens.contains(normalizedType);

  static OutplantGeometryType? resolveGeometryType(String normalizedType) {
    if (normalizedType.isEmpty) return null;
    if (normalizedType == 'bbox') return OutplantGeometryType.boundingBox;
    for (final type in OutplantGeometryType.values) {
      if (type.id == normalizedType || type.name == normalizedType) {
        return type;
      }
    }
    return null;
  }

  static List<GeoCoordinate> parseCoordinatePairs(String raw) {
    final segments = raw.split(_coordinateDelimiter);
    final coordinates = <GeoCoordinate>[];

    for (final segment in segments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(',');
      if (parts.length != 2) {
        throw FormatException(
          'Invalid coordinate "$trimmed". Expected "lat,lng".',
        );
      }
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) {
        throw FormatException(
          'Invalid coordinate "$trimmed". Expected decimal degrees.',
        );
      }
      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }

    if (coordinates.isEmpty) {
      throw const FormatException('Provide at least one coordinate.');
    }

    return coordinates;
  }

  static OutplantGeometryType inferGeometryType(int coordinateCount) {
    if (coordinateCount >= 3) {
      return OutplantGeometryType.polygon;
    }
    if (coordinateCount == 2) {
      return OutplantGeometryType.boundingBox;
    }
    return OutplantGeometryType.point;
  }

  static String normalizeSourceToken(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static OutplantGeometrySource? resolveSource(String normalizedSource) {
    if (normalizedSource.isEmpty) return null;
    for (final source in OutplantGeometrySource.values) {
      if (source.id == normalizedSource || source.name == normalizedSource) {
        return source;
      }
    }
    return null;
  }

  static String formatCoordinates(List<GeoCoordinate> coordinates) {
    return coordinates
        .map((coordinate) => '${coordinate.latitude},${coordinate.longitude}')
        .join('; ');
  }
}
