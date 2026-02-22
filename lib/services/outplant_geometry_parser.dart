// @tier: community
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:xml/xml.dart' as xml;

class ParsedOutplantGeometry {
  const ParsedOutplantGeometry({
    required this.input,
    this.kmlBytes,
  });

  final OutplantGeometryInput input;
  final Uint8List? kmlBytes;
}

/// Utility for parsing geometry inputs supplied by the outplant dialogs.
class OutplantGeometryParser {
  const OutplantGeometryParser({this.maxCoordinatePoints = 250});

  final int maxCoordinatePoints;

  ParsedOutplantGeometry parseManual(String raw) {
    final coordinates = _parseManualCoordinates(raw);
    final input = _buildInput(
      coordinates,
      source: OutplantGeometrySource.manual,
    );
    return ParsedOutplantGeometry(input: input);
  }

  Future<ParsedOutplantGeometry> parseFile({
    required Uint8List data,
    required String extension,
  }) async {
    final ext = extension.toLowerCase();
    final content = utf8.decode(data, allowMalformed: true).trim();

    switch (ext) {
      case 'csv':
        return ParsedOutplantGeometry(
          input: _buildInput(
            _parseCsv(content),
            source: OutplantGeometrySource.csv,
          ),
        );
      case 'geojson':
      case 'json':
        final parsedGeo = _parseGeoJson(content);
        return ParsedOutplantGeometry(
          input: _buildInput(
            parsedGeo.coordinates,
            source: OutplantGeometrySource.csv,
            typeHint: parsedGeo.hint,
          ),
        );
      case 'kml':
        return ParsedOutplantGeometry(
          input: _buildInput(
            _parseKml(content),
            source: OutplantGeometrySource.kmlUpload,
          ),
          kmlBytes: data,
        );
      default:
        throw const FormatException(
          'Unsupported file type. Upload CSV, GeoJSON, or KML.',
        );
    }
  }

  List<GeoCoordinate> _parseManualCoordinates(String raw) {
    final coordinates = <GeoCoordinate>[];
    final rows = raw.split(RegExp(r'[\n;]+'));
    for (final row in rows) {
      final trimmed = row.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(',');
      if (parts.length != 2) {
        throw FormatException(
          'Invalid coordinate "$trimmed". Use "lat,lng" per line.',
        );
      }
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) {
        throw FormatException(
          'Could not parse "$trimmed" as decimal degrees.',
        );
      }
      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return coordinates;
  }

  List<GeoCoordinate> _parseCsv(String content) {
    final converter = CsvToListConverter();
    final rows = converter.convert(
      content,
      shouldParseNumbers: false,
      eol: '\n',
    );
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    int? latIndex;
    int? lngIndex;
    int startRow = 0;

    if (rows.first.every((cell) => cell is String)) {
      final header = rows.first.map((cell) => cell.toString().toLowerCase());
      latIndex = header.toList().indexWhere(
        (value) =>
            value.contains('lat') || value.contains('latitude') || value == 'y',
      );
      lngIndex = header.toList().indexWhere(
        (value) =>
            value.contains('lng') ||
            value.contains('lon') ||
            value.contains('longitude') ||
            value == 'x',
      );
      startRow = 1;
    }

    final coordinates = <GeoCoordinate>[];
    for (var i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      double? lat;
      double? lng;

      if (latIndex != null &&
          latIndex >= 0 &&
          latIndex < row.length &&
          lngIndex != null &&
          lngIndex >= 0 &&
          lngIndex < row.length) {
        lat = double.tryParse(row[latIndex].toString());
        lng = double.tryParse(row[lngIndex].toString());
      } else if (row.length >= 2) {
        lat = double.tryParse(row[0].toString());
        lng = double.tryParse(row[1].toString());
      }

      if (lat == null || lng == null) {
        throw FormatException(
          'Row ${i + 1} is missing latitude/longitude values.',
        );
      }

      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return coordinates;
  }

  ({List<GeoCoordinate> coordinates, OutplantGeometryType? hint})
  _parseGeoJson(String content) {
    final decoded = jsonDecode(content);
    final coordinates = _extractGeoJsonCoordinates(decoded);
    if (coordinates.isEmpty) {
      throw const FormatException(
        'No coordinates found in GeoJSON payload.',
      );
    }

    final typeLabel = _resolveGeoJsonType(decoded);
    final hint = typeLabel == null ? null : _geoJsonTypeToHint(typeLabel);
    return (coordinates: coordinates, hint: hint);
  }

  List<GeoCoordinate> _extractGeoJsonCoordinates(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = (node['type'] as String?)?.toLowerCase();
      switch (type) {
        case 'featurecollection':
          final features = node['features'];
          if (features is List) {
            return features
                .expand((feature) => _extractGeoJsonCoordinates(feature))
                .toList();
          }
          return const [];
        case 'feature':
          return _extractGeoJsonCoordinates(node['geometry']);
        case 'geometrycollection':
          final geometries = node['geometries'];
          if (geometries is List) {
            return geometries
                .expand((geometry) => _extractGeoJsonCoordinates(geometry))
                .toList();
          }
          return const [];
        case 'point':
          final coord = node['coordinates'];
          if (coord is List) {
            return [_fromCoordinateArray(coord)];
          }
          return const [];
        case 'multipoint':
        case 'linestring':
          final coords = node['coordinates'];
          if (coords is List) {
            return coords
                .map((value) => _fromCoordinateArray(value as List))
                .toList();
          }
          return const [];
        case 'multilinestring':
          final coords = node['coordinates'];
          if (coords is List) {
            return coords
                .expand((value) => (value as List)
                    .map((coord) => _fromCoordinateArray(coord as List)))
                .toList();
          }
          return const [];
        case 'polygon':
          final rings = node['coordinates'];
          if (rings is List && rings.isNotEmpty) {
            final outer = rings.first as List;
            return outer
                .map((coord) => _fromCoordinateArray(coord as List))
                .toList();
          }
          return const [];
        case 'multipolygon':
          final polygons = node['coordinates'];
          if (polygons is List && polygons.isNotEmpty) {
            final outer = polygons.first;
            if (outer is List && outer.isNotEmpty) {
              final ring = outer.first;
              if (ring is List) {
                return ring
                    .map((coord) => _fromCoordinateArray(coord as List))
                    .toList();
              }
            }
          }
          return const [];
        default:
          return const [];
      }
    }
    return const [];
  }

  String? _resolveGeoJsonType(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = node['type'] as String?;
      if (type == null) {
        return null;
      }
      switch (type.toLowerCase()) {
        case 'featurecollection':
          final features = node['features'];
          if (features is List && features.isNotEmpty) {
            return _resolveGeoJsonType(features.first);
          }
          return null;
        case 'feature':
          return _resolveGeoJsonType(node['geometry']);
        default:
          return type;
      }
    }
    return null;
  }

  OutplantGeometryType? _geoJsonTypeToHint(String rawType) {
    switch (rawType.toLowerCase()) {
      case 'polygon':
      case 'multipolygon':
        return OutplantGeometryType.polygon;
      case 'point':
        return OutplantGeometryType.point;
      case 'multipoint':
        return OutplantGeometryType.multipoint;
      case 'linestring':
      case 'multilinestring':
        return OutplantGeometryType.multipoint;
      default:
        return null;
    }
  }

  /// Parse KML file content and extract coordinates.
  ///
  /// **Strategy**: Uses XML parser for robust handling of namespaces, CDATA sections,
  /// and complex KML structures. Falls back to regex-based parsing if XML parsing fails
  /// (for backward compatibility with malformed KML files).
  ///
  /// **XML Parser Benefits**:
  /// - Handles XML namespaces (e.g., `xmlns="http://www.opengis.net/kml/2.2"`)
  /// - Properly processes CDATA sections
  /// - Case-insensitive element matching
  /// - Validates XML structure
  ///
  /// **Fallback**: Regex parsing is maintained for KML files that fail XML validation
  /// but may still contain valid coordinate data.
  List<GeoCoordinate> _parseKml(String content) {
    // Try XML parsing first (more robust)
    try {
      return _parseKmlWithXml(content);
    } catch (e) {
      LoggingService.instance.warning(
        'XML-based KML parsing failed, falling back to regex: $e',
      );
      // Fall back to regex-based parsing for backward compatibility
      return _parseKmlWithRegex(content);
    }
  }

  /// Parse KML using XML parser for robust handling of namespaces, CDATA, etc.
  List<GeoCoordinate> _parseKmlWithXml(String content) {
    final coordinates = <GeoCoordinate>[];

    try {
      // Parse XML document
      final document = xml.XmlDocument.parse(content);
      final root = document.rootElement;

      // KML files may have different root elements (kml, KML, etc.)
      // and may use namespaces (e.g., xmlns="http://www.opengis.net/kml/2.2")
      // Find all coordinate elements regardless of namespace
      var coordinateElements = root.findAllElements('coordinates').toList();

      if (coordinateElements.isEmpty) {
        // Try with namespace-aware search
        final namespace = root.namespaceUri;
        if (namespace != null && namespace.isNotEmpty) {
          final nsElements = root.findAllElements(
            'coordinates',
            namespace: namespace,
          ).toList();
          coordinateElements.addAll(nsElements);
        }
      }

      // If still empty, try case-insensitive search by iterating all elements
      if (coordinateElements.isEmpty) {
        final allElements = root.findAllElements('*');
        for (final element in allElements) {
          if (element.localName.toLowerCase() == 'coordinates') {
            coordinateElements.add(element);
          }
        }
      }

      if (coordinateElements.isEmpty) {
        throw const FormatException('No <coordinates> elements found in KML.');
      }

      // Extract coordinates from each <coordinates> element
      for (final coordElement in coordinateElements) {
        final coordText = coordElement.innerText.trim();
        if (coordText.isEmpty) continue;

        // Parse coordinate string (format: "lng,lat[,altitude]")
        final tokens = coordText.split(RegExp(r'[\s\r\n]+'));
        for (final token in tokens) {
          final trimmed = token.trim();
          if (trimmed.isEmpty) continue;

          final parts = trimmed.split(',');
          if (parts.length < 2) continue;

          final lng = double.tryParse(parts[0].trim());
          final lat = double.tryParse(parts[1].trim());

          if (lat == null || lng == null) {
            throw FormatException(
              'Invalid KML coordinate "$trimmed". Expected "lng,lat" format.',
            );
          }

          coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
        }
      }

      if (coordinates.isEmpty) {
        throw const FormatException(
          'No valid coordinates found in KML <coordinates> elements.',
        );
      }

      return coordinates;
    } on xml.XmlException catch (e) {
      throw FormatException('Failed to parse KML as XML: ${e.message}');
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Unexpected error parsing KML: $e');
    }
  }

  /// Parse KML using regex-based parsing (fallback for backward compatibility).
  ///
  /// This method uses regex to extract coordinates, which is less robust
  /// but may work with malformed KML files that fail XML parsing.
  List<GeoCoordinate> _parseKmlWithRegex(String content) {
    final regex = RegExp(
      r'<coordinates>(.*?)</coordinates>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = regex.allMatches(content);

    final coordinates = <GeoCoordinate>[];
    for (final match in matches) {
      final body = match.group(1) ?? '';
      final tokens = body.split(RegExp(r'[\s\r\n]+'));
      for (final token in tokens) {
        final trimmed = token.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(',');
        if (parts.length < 2) continue;
        final lng = double.tryParse(parts[0]);
        final lat = double.tryParse(parts[1]);
        if (lat == null || lng == null) {
          throw FormatException('Invalid KML coordinate "$trimmed".');
        }
        coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
      }
    }

    if (coordinates.isEmpty) {
      throw const FormatException('No coordinates found in KML file.');
    }

    return coordinates;
  }

  OutplantGeometryInput _buildInput(
    List<GeoCoordinate> coordinates, {
    required OutplantGeometrySource source,
    OutplantGeometryType? typeHint,
  }) {
    if (coordinates.isEmpty) {
      throw const FormatException('No coordinates were provided.');
    }

    final uniqueCoordinates = _dedupeTrailingDuplicate(coordinates);

    if (uniqueCoordinates.length > maxCoordinatePoints) {
      throw FormatException(
        'Too many coordinates (${uniqueCoordinates.length}). '
        'Limit is $maxCoordinatePoints.',
      );
    }

    final type = _inferType(
      uniqueCoordinates,
      source,
      typeHint: typeHint,
    );
    return OutplantGeometryInput(
      type: type,
      coordinates: uniqueCoordinates,
      source: source,
    );
  }

  List<GeoCoordinate> _dedupeTrailingDuplicate(List<GeoCoordinate> coords) {
    if (coords.length < 2) return coords;
    final first = coords.first;
    final last = coords.last;
    if (first == last) {
      return coords.sublist(0, coords.length - 1);
    }
    return coords;
  }

  OutplantGeometryType _inferType(
    List<GeoCoordinate> coordinates,
    OutplantGeometrySource source, {
    OutplantGeometryType? typeHint,
  }) {
    if (typeHint != null) {
      return typeHint;
    }
    if (coordinates.length >= 3) {
      return OutplantGeometryType.polygon;
    }
    if (coordinates.length == 2) {
      return OutplantGeometryType.boundingBox;
    }
    if (coordinates.length > 1) {
      return OutplantGeometryType.multipoint;
    }
    return OutplantGeometryType.point;
  }

  GeoCoordinate _fromCoordinateArray(List<dynamic> raw) {
    if (raw.length < 2) {
      throw const FormatException('Coordinate entry missing lat/lng values.');
    }
    final lon = safeDouble(raw[0]);
    final lat = safeDouble(raw[1]);
    if (lat == null || lon == null) {
      throw const FormatException('Unable to parse GeoJSON coordinate pair.');
    }
    return GeoCoordinate(latitude: lat, longitude: lon);
  }
}
