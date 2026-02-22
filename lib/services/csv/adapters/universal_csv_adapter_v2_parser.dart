// @tier: community
part of 'universal_csv_adapter_v2.dart';

/// Geometry parsing methods for [UniversalCsvAdapterV2].
///
/// This part file contains all the geometry parsing logic for WKT and GeoJSON
/// formats, including coordinate extraction and validation.
extension _UniversalCsvAdapterV2Parser on UniversalCsvAdapterV2 {
  _GeometryTranslation translateGeometry(
    Map<String, String> row,
    int rowNumber,
    List<CsvTranslationIssue> issues,
  ) {
    final format = row['geometryFormat']?.trim().toUpperCase();
    final wkt = row['geometryWkt']?.trim() ?? '';
    if (format == 'WKT' && wkt.isNotEmpty) {
      try {
        final points = parseWktPoints(wkt);
        if (points.isNotEmpty) {
          final formattedPoints = points
              .map((point) => '${point.latitude},${point.longitude}')
              .join('; ');
          return _GeometryTranslation(
            centerLat: points.first.latitude.toString(),
            centerLng: points.first.longitude.toString(),
            outplantPointsCsv: formattedPoints,
          );
        }
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse WKT geometry at row $rowNumber: $wkt',
          error,
          stackTrace,
        );
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryWkt',
            value: wkt,
            message: error.toString(),
          ),
        );
        return const _GeometryTranslation();
      }
    }

    final geoJsonRaw = row['geometryGeojson']?.trim() ?? '';
    if (format == 'GEOJSON' && geoJsonRaw.isNotEmpty) {
      try {
        final points = parseGeoJsonPoints(geoJsonRaw);
        if (points.isNotEmpty) {
          final formattedPoints = points
              .map((point) => '${point.latitude},${point.longitude}')
              .join('; ');
          return _GeometryTranslation(
            centerLat: points.first.latitude.toString(),
            centerLng: points.first.longitude.toString(),
            outplantPointsCsv: formattedPoints,
          );
        }
      } catch (error, stackTrace) {
        LoggingService.instance.error(
          'Failed to parse GeoJSON geometry at row $rowNumber: $geoJsonRaw',
          error,
          stackTrace,
        );
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryGeojson',
            value: geoJsonRaw,
            message: error.toString(),
          ),
        );
        return const _GeometryTranslation();
      }
    }

    return const _GeometryTranslation();
  }

  List<_Coordinate> parseWktPoints(String wkt) {
    final normalized = wkt.trim().toUpperCase();
    if (normalized.startsWith('POINT')) {
      final content = _extractPointContent(wkt);
      final coordinate = _parseSingleCoordinate(content);
      return [coordinate];
    } else if (normalized.startsWith('MULTIPOINT')) {
      final content = wkt.substring(wkt.indexOf('(') + 1, wkt.lastIndexOf(')'));
      final segments = content.split('),');
      final points = <_Coordinate>[];
      for (final segment in segments) {
        final cleaned = segment.replaceAll('(', '').replaceAll(')', '').trim();
        if (cleaned.isEmpty) continue;
        points.add(_parseSingleCoordinate(cleaned));
      }
      return points;
    }

    throw const FormatException(
      'Only POINT and MULTIPOINT geometries are supported in v2 imports.',
    );
  }

  List<_Coordinate> parseGeoJsonPoints(String geoJson) {
    dynamic parsed;
    try {
      parsed = jsonDecode(geoJson);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to decode GeoJSON: $geoJson',
        e,
        stackTrace,
      );
      throw const FormatException('Invalid GeoJSON payload.');
    }
    final points = extractGeoJsonCoordinates(parsed);
    if (points.isEmpty) {
      throw const FormatException(
        'GeoJSON must contain Point or MultiPoint coordinates.',
      );
    }
    return points;
  }

  List<_Coordinate> extractGeoJsonCoordinates(dynamic node) {
    if (node == null) {
      return const [];
    }
    if (node is Map<String, dynamic>) {
      final type = (node['type'] as String?)?.toUpperCase();
      if (type == null || type.isEmpty) {
        return const [];
      }
      switch (type) {
        case 'POINT':
          final coords = node['coordinates'];
          if (coords is List) {
            return [_coordinateFromList(coords)];
          }
          break;
        case 'MULTIPOINT':
          final coords = node['coordinates'];
          if (coords is List) {
            return coords
                .map((value) {
                  if (value is List) {
                    return _coordinateFromList(value);
                  }
                  throw const FormatException(
                    'MultiPoint coordinates must be arrays of [lng, lat].',
                  );
                })
                .toList(growable: false);
          }
          break;
        case 'FEATURE':
          return extractGeoJsonCoordinates(node['geometry']);
        case 'FEATURECOLLECTION':
          final features = node['features'];
          if (features is List) {
            return features
                .expand((feature) => extractGeoJsonCoordinates(feature))
                .toList(growable: false);
          }
          break;
        case 'GEOMETRYCOLLECTION':
          final geometries = node['geometries'];
          if (geometries is List) {
            return geometries
                .expand((geometry) => extractGeoJsonCoordinates(geometry))
                .toList(growable: false);
          }
          break;
        default:
          break;
      }
    } else if (node is List) {
      // Allow bare coordinate arrays for legacy payloads.
      return [_coordinateFromList(node)];
    }
    throw const FormatException(
      'Only Point, MultiPoint, Feature, and FeatureCollection GeoJSON types are supported.',
    );
  }

  _Coordinate _coordinateFromList(List<dynamic> coords) {
    if (coords.length < 2) {
      throw const FormatException(
        'GeoJSON coordinates must include longitude and latitude.',
      );
    }
    final lng = double.tryParse(coords[0].toString());
    final lat = double.tryParse(coords[1].toString());
    if (lat == null || lng == null) {
      throw const FormatException('GeoJSON coordinates must be numeric.');
    }

    // Validate coordinate order (GeoJSON is [lng, lat] per RFC 7946)
    // Detect likely reversed coordinates using range checks
    if (lng.abs() <= 90 && lat.abs() > 90 && lat.abs() <= 180) {
      throw FormatException(
        'GeoJSON coordinates appear reversed. Expected [longitude, latitude] '
        'per RFC 7946, but received [$lng, $lat]. '
        'Longitude must be -180 to 180, latitude must be -90 to 90.',
      );
    }

    // Validate ranges
    if (lng < -180 || lng > 180) {
      throw FormatException(
          'Invalid longitude: $lng. Must be between -180 and 180.');
    }
    if (lat < -90 || lat > 90) {
      throw FormatException(
          'Invalid latitude: $lat. Must be between -90 and 90.');
    }

    return _Coordinate(latitude: lat, longitude: lng);
  }

  String _extractPointContent(String wkt) {
    final start = wkt.indexOf('(');
    final end = wkt.lastIndexOf(')');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('Invalid POINT syntax.');
    }
    return wkt.substring(start + 1, end).trim();
  }

  _Coordinate _parseSingleCoordinate(String segment) {
    final parts = segment.split(RegExp(r'[ ,]+'));
    if (parts.length < 2) {
      throw FormatException(
        'Invalid coordinate "$segment". Expected "lng lat".',
      );
    }
    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lng == null) {
      throw FormatException(
        'Invalid coordinate "$segment". Expected decimals.',
      );
    }
    return _Coordinate(latitude: lat, longitude: lng);
  }
}
