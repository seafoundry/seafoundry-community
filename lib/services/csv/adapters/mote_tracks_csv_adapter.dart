// @tier: community
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/services/csv/adapters/csv_translation_adapter.dart';
import 'package:seafoundry_app/services/csv/geometry_csv_utils.dart';

/// Lightweight skeleton that demonstrates how partner-specific adapters hook
/// into the translation pipeline. The real mapping logic can be layered on top
/// of this structure without touching the registry or pipeline plumbing.
class MoteTracksCsvAdapter extends CsvTranslationAdapter {
  const MoteTracksCsvAdapter() : super(id: 'mote_tracks_v1');

  @override
  bool supports(CsvTranslationContext context) {
    return context.direction == CsvTranslationDirection.import &&
        context.kind == CsvTemplateKind.outplanting &&
        context.adapterId == id;
  }

  @override
  CsvTranslationResult<String> translateImport(
    CsvTranslationContext context,
    List<Map<String, String>> rows,
  ) {
    final issues = <CsvTranslationIssue>[];
    final translatedRows = <Map<String, String>>[];
    var blockedRowCount = 0;

    if ((context.metadata['orgDomain'] ?? '').trim().isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: context.rowOffset - 1,
          field: 'orgDomain',
          value: '',
          message:
              'Metadata row "orgDomain" is required for the Mote Tracks adapter.',
          severity: CsvTranslationIssueSeverity.warning,
        ),
      );
    }

    for (var i = 0; i < rows.length; i++) {
      final rowNumber = context.rowOffset + i;
      final normalizedRow = Map<String, String>.from(rows[i]);

      final geometryResult = _normalizeGeometryFields(
        rowNumber: rowNumber,
        row: normalizedRow,
      );
      issues.addAll(geometryResult.issues);

      if (geometryResult.blockRow) {
        blockedRowCount++;
        continue;
      }

      geometryResult.apply(normalizedRow);
      translatedRows.add(normalizedRow);
    }

    return CsvTranslationResult<String>(
      rows: translatedRows,
      issues: issues,
      adapterId: id,
      blockedRowCount: blockedRowCount,
    );
  }

  _GeometryNormalizationResult _normalizeGeometryFields({
    required int rowNumber,
    required Map<String, String> row,
  }) {
    String read(String key) => (row[key] ?? '').trim();

    final typeRaw = read('geometryType');
    final coordinatesRaw = read('geometryCoordinates');
    final sourceRaw = read('geometrySource');
    final kmlPath = read('geometryKmlStoragePath');
    final updatedAtRaw = read('geometryUpdatedAt');

    final normalizedType = GeometryCsvUtils.normalizeTypeToken(typeRaw);
    final normalizedSource = GeometryCsvUtils.normalizeSourceToken(sourceRaw);
    final hasAnyGeometryField = normalizedType.isNotEmpty ||
        coordinatesRaw.isNotEmpty ||
        normalizedSource.isNotEmpty ||
        kmlPath.isNotEmpty ||
        updatedAtRaw.isNotEmpty;

    if (!hasAnyGeometryField) {
      return const _GeometryNormalizationResult();
    }

    final issues = <CsvTranslationIssue>[];
    final isClearRequest = GeometryCsvUtils.isClearToken(normalizedType);

    if (isClearRequest) {
      if (coordinatesRaw.isNotEmpty || kmlPath.isNotEmpty) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryType',
            value: typeRaw,
            message:
                'Use geometryType "clear" with empty geometry fields to remove stored geometry.',
            severity: CsvTranslationIssueSeverity.error,
          ),
        );
        return _GeometryNormalizationResult(
          issues: issues,
          blockRow: true,
        );
      }
      return _GeometryNormalizationResult(
        issues: issues,
        type: 'clear',
        coordinates: '',
        source: '',
        kmlPath: '',
        updatedAt: '',
      );
    }

    if (coordinatesRaw.isEmpty) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'geometryCoordinates',
          value: coordinatesRaw,
          message: 'Provide coordinates when geometry fields are populated.',
          severity: CsvTranslationIssueSeverity.error,
        ),
      );
      return _GeometryNormalizationResult(
        issues: issues,
        blockRow: true,
      );
    }

    List<GeoCoordinate> coordinates;
    try {
      coordinates = GeometryCsvUtils.parseCoordinatePairs(coordinatesRaw);
    } on FormatException catch (error) {
      issues.add(
        CsvTranslationIssue(
          rowNumber: rowNumber,
          field: 'geometryCoordinates',
          value: coordinatesRaw,
          message: error.message,
          severity: CsvTranslationIssueSeverity.error,
        ),
      );
      return _GeometryNormalizationResult(
        issues: issues,
        blockRow: true,
      );
    }

    String resolvedType;
    if (normalizedType.isEmpty) {
      resolvedType = GeometryCsvUtils.inferGeometryType(coordinates.length).id;
    } else {
      final matched = GeometryCsvUtils.resolveGeometryType(normalizedType);
      if (matched == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryType',
            value: typeRaw,
            message:
                'Unknown geometry type. Use point, multipoint, polygon, or bounding_box.',
            severity: CsvTranslationIssueSeverity.error,
          ),
        );
        return _GeometryNormalizationResult(
          issues: issues,
          blockRow: true,
        );
      }
      resolvedType = matched.id;
    }

    String resolvedSource;
    if (normalizedSource.isEmpty) {
      resolvedSource = OutplantGeometrySource.csv.id;
    } else {
      final matchedSource = GeometryCsvUtils.resolveSource(normalizedSource);
      if (matchedSource == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometrySource',
            value: sourceRaw,
            message:
                'Unknown geometry source. Use manual, csv, site_centroid, or kml_upload.',
            severity: CsvTranslationIssueSeverity.error,
          ),
        );
        return _GeometryNormalizationResult(
          issues: issues,
          blockRow: true,
        );
      }
      resolvedSource = matchedSource.id;
    }

    String normalizedUpdatedAt = updatedAtRaw;
    if (normalizedUpdatedAt.isNotEmpty) {
      final parsed = DateTime.tryParse(normalizedUpdatedAt);
      if (parsed == null) {
        issues.add(
          CsvTranslationIssue(
            rowNumber: rowNumber,
            field: 'geometryUpdatedAt',
            value: updatedAtRaw,
            message:
                'geometryUpdatedAt must be ISO-8601 (e.g., 2025-01-01T00:00:00Z).',
            severity: CsvTranslationIssueSeverity.error,
          ),
        );
        return _GeometryNormalizationResult(
          issues: issues,
          blockRow: true,
        );
      }
      normalizedUpdatedAt = parsed.toUtc().toIso8601String();
    }

    return _GeometryNormalizationResult(
      issues: issues,
      type: resolvedType,
      coordinates: GeometryCsvUtils.formatCoordinates(coordinates),
      source: resolvedSource,
      kmlPath: kmlPath,
      updatedAt: normalizedUpdatedAt,
    );
  }
}

class _GeometryNormalizationResult {
  const _GeometryNormalizationResult({
    this.type,
    this.coordinates,
    this.source,
    this.kmlPath,
    this.updatedAt,
    this.blockRow = false,
    this.issues = const <CsvTranslationIssue>[],
  });

  final String? type;
  final String? coordinates;
  final String? source;
  final String? kmlPath;
  final String? updatedAt;
  final bool blockRow;
  final List<CsvTranslationIssue> issues;

  void apply(Map<String, String> row) {
    if (type != null) row['geometryType'] = type!;
    if (coordinates != null) row['geometryCoordinates'] = coordinates!;
    if (source != null) row['geometrySource'] = source!;
    if (kmlPath != null) row['geometryKmlStoragePath'] = kmlPath!;
    if (updatedAt != null) row['geometryUpdatedAt'] = updatedAt!;
  }
}
