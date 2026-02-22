// @tier: community
import 'dart:typed_data';

import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/services/outplant_geometry_builder.dart';
import 'package:seafoundry_app/services/outplant_geometry_parser.dart';

/// Result of parsing geometry from file or text input.
class GeometryParseResult {
  const GeometryParseResult({
    this.input,
    this.label,
    this.kmlBytes,
    this.errorMessage,
  });

  /// Parsed geometry input ready for validation and building.
  final OutplantGeometryInput? input;

  /// Display label for the parsed geometry (e.g., filename).
  final String? label;

  /// Raw KML bytes if the source was a KML file upload.
  final Uint8List? kmlBytes;

  /// Error message if parsing failed.
  final String? errorMessage;

  /// Whether parsing succeeded without errors.
  bool get success => errorMessage == null && input != null;

  /// Whether parsing failed with an error.
  bool get hasError => errorMessage != null;
}

/// Service for parsing, validating, and building outplant geometry from
/// various input sources (KML, CSV, GeoJSON, manual text entry).
///
/// Extracted from OutplantBatchBloc to provide reusable geometry parsing
/// capabilities across the application.
class GeometryParsingService {
  const GeometryParsingService({
    required OutplantGeometryParser parser,
    required OutplantGeometryBuilder builder,
  })  : _parser = parser,
        _builder = builder;

  final OutplantGeometryParser _parser;
  final OutplantGeometryBuilder _builder;

  /// Parse geometry from uploaded file (KML, CSV, or GeoJSON).
  ///
  /// Supports:
  /// - KML files: Returns parsed coordinates and raw KML bytes for attachment
  /// - CSV files: Parses lat/lng columns (auto-detects headers)
  /// - GeoJSON files: Extracts coordinates from Point, MultiPoint, LineString,
  ///   Polygon, or MultiPolygon geometries
  ///
  /// Returns [GeometryParseResult] with parsed input on success or error
  /// message on failure.
  Future<GeometryParseResult> parseFromFile(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final extension = _extractExtension(fileName);
      final parsed = await _parser.parseFile(
        data: bytes,
        extension: extension,
      );

      return GeometryParseResult(
        input: parsed.input,
        label: fileName,
        kmlBytes: parsed.kmlBytes,
      );
    } on FormatException catch (error) {
      return GeometryParseResult(errorMessage: error.message);
    } catch (error) {
      return GeometryParseResult(
        errorMessage: 'Failed to parse geometry file: $error',
      );
    }
  }

  /// Parse geometry from manual text input.
  ///
  /// Expected format: One coordinate per line in "lat,lng" format.
  /// Lines can be separated by newlines or semicolons.
  ///
  /// Example:
  /// ```
  /// 21.12345,-157.98765
  /// 21.12346,-157.98764
  /// ```
  ///
  /// Returns [GeometryParseResult] with parsed input on success or error
  /// message on failure.
  GeometryParseResult parseFromText(String text) {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        return const GeometryParseResult(
          errorMessage: 'Geometry input is empty',
        );
      }

      final parsed = _parser.parseManual(trimmed);
      return GeometryParseResult(input: parsed.input);
    } on FormatException catch (error) {
      return GeometryParseResult(errorMessage: error.message);
    } catch (error) {
      return GeometryParseResult(
        errorMessage: 'Failed to parse geometry text: $error',
      );
    }
  }

  /// Build OutplantGeometry from parsed input.
  ///
  /// Validates coordinates against site centroid (if provided) and computes
  /// bounds, centroid, and geohash for the geometry.
  ///
  /// Throws [FormatException] if validation fails (e.g., coordinates are too
  /// far from site centroid).
  OutplantGeometry? buildGeometry(
    OutplantGeometryInput? input,
    Site? site,
  ) {
    if (input == null) {
      return null;
    }

    return _builder.build(
      input: input,
      siteCentroid: extractSiteCentroid(site),
    );
  }

  /// Compute preview geometry for display (non-throwing variant).
  ///
  /// Returns null if input is null or if building fails. This is useful for
  /// live preview of geometry as the user types or uploads files.
  OutplantGeometry? computePreview(
    OutplantGeometryInput? input,
    Site? site,
  ) {
    try {
      return buildGeometry(input, site);
    } catch (_) {
      return null;
    }
  }

  /// Extract site centroid from various Site properties.
  ///
  /// Priority order:
  /// 1. site.centroid (explicit centroid property)
  /// 2. site.geometry?.centroid (centroid from outplant geometry)
  /// 3. site.latitude/longitude (fallback to site coordinates)
  ///
  /// Returns null if site is null or has no coordinate information.
  GeoCoordinate? extractSiteCentroid(Site? site) {
    if (site == null) {
      return null;
    }

    if (site.centroid != null) {
      return site.centroid;
    }

    if (site.geometry?.centroid != null) {
      return site.geometry!.centroid;
    }

    if (site.latitude != null && site.longitude != null) {
      return GeoCoordinate(
        latitude: site.latitude!,
        longitude: site.longitude!,
      );
    }

    return null;
  }

  /// Generate prefill text from site centroid (for manual geometry entry).
  ///
  /// Returns a formatted string "lat,lng" suitable for pasting into the
  /// manual geometry text field.
  ///
  /// Returns null if site has no centroid information or coordinates are invalid.
  String? generateSiteCentroidPrefill(Site? site) {
    if (site?.latitude == null || site?.longitude == null) {
      return null;
    }

    final lat = site!.latitude!.toStringAsFixed(5);
    final lng = site.longitude!.toStringAsFixed(5);
    return '$lat,$lng';
  }

  /// Extract file extension from filename.
  String _extractExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last.toLowerCase();
  }
}
