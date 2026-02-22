// @tier: community
import 'dart:convert';

import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/measurement_unit.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/constants/csv_schema.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/validation_service.dart';

/// Parsing utilities for inventory CSV import rows.
///
/// Contains static methods for parsing various field types from CSV row data.
/// All methods are pure functions with no side effects.
class InventoryRowParser {
  InventoryRowParser._();

  /// Parses population measurement from value and unit strings.
  ///
  /// Returns null if both fields are empty.
  /// Adds errors to [existingErrors] if validation fails.
  static PopulationMeasurement? parsePopulationMeasurement({
    required int rowNumber,
    required String valueRaw,
    required String unitRaw,
    required List<CSVImportError> existingErrors,
  }) {
    if (valueRaw.isEmpty && unitRaw.isEmpty) return null;
    if (valueRaw.isEmpty || unitRaw.isEmpty) {
      existingErrors.add(
        CSVImportError(
          row: rowNumber,
          field: valueRaw.isEmpty ? 'quantityValue' : 'measurementUnit',
          value: valueRaw.isEmpty ? valueRaw : unitRaw,
          message: 'quantityValue and measurementUnit must both be provided',
        ),
      );
      return null;
    }

    final parsedValue = double.tryParse(valueRaw);
    if (parsedValue == null || parsedValue < 0) {
      existingErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'quantityValue',
          value: valueRaw,
          message: 'quantityValue must be a non-negative number',
        ),
      );
      return null;
    }

    final measurementUnit = MeasurementUnitX.tryParse(unitRaw);
    if (measurementUnit == null) {
      existingErrors.add(
        CSVImportError(
          row: rowNumber,
          field: 'measurementUnit',
          value: unitRaw,
          message: 'Unknown measurementUnit',
        ),
      );
      return null;
    }

    return PopulationMeasurement(value: parsedValue, unit: measurementUnit);
  }

  /// Parses aliases from JSON or falls back to delimited string parsing.
  ///
  /// Supports JSON array format or comma/semicolon delimited strings.
  /// When JSON parsing fails but a valid fallback is available, the fallback
  /// is used. Errors are added to [warnings] (non-blocking) rather than
  /// [errors] (blocking) when fallback succeeds.
  static List<OrganismAlias> parseAliases(
    String? raw, {
    String? fallbackRaw,
    List<CSVImportError>? errors,
    List<CSVImportError>? warnings,
    int? rowNum,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return parseAliasesFromDelimitedString(fallbackRaw);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return OrganismAlias.listFromJson(decoded);
      }
      if (decoded is Map && decoded.containsKey('aliases')) {
        return OrganismAlias.listFromJson(decoded['aliases']);
      }
      throw FormatException(
        'aliasesJson must be a JSON array or object with "aliases" key, got ${decoded.runtimeType}',
      );
    } catch (e, stackTrace) {
      // Prefer explicit aliases field if provided, otherwise reuse raw value.
      final fallback = (fallbackRaw != null && fallbackRaw.trim().isNotEmpty)
          ? fallbackRaw
          : raw;
      final fallbackResult = parseAliasesFromDelimitedString(fallback);

      // Add to warnings (non-blocking) if fallback succeeded, errors (blocking) if not
      if (fallbackResult.isNotEmpty) {
        final warning = CSVImportError(
          row: rowNum ?? 0,
          field: 'aliasesJson',
          value: raw,
          message: 'Invalid JSON format: ${e.toString()}',
          isWarning: true,
        );
        warnings?.add(warning);
        LoggingService.instance.warning(
          'aliasesJson invalid at row $rowNum, fell back to aliases field',
        );
      } else if (rowNum != null) {
        final error = CSVImportError(
          row: rowNum,
          field: 'aliasesJson',
          value: raw,
          message: 'Invalid JSON format: ${e.toString()}',
        );
        errors?.add(error);
        LoggingService.instance.error(
          'Failed to parse aliasesJson at row $rowNum: $raw',
          e,
          stackTrace,
        );
      }

      return fallbackResult;
    }
  }

  /// Parses aliases from a comma or semicolon delimited string.
  static List<OrganismAlias> parseAliasesFromDelimitedString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <OrganismAlias>[];
    final segments = raw
        .split(RegExp(r'[;,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return const <OrganismAlias>[];
    return List<OrganismAlias>.unmodifiable(
      segments.map((v) => OrganismAlias(sourceSystem: 'custom', value: v, label: v)),
    );
  }

  /// Parses foreign keys from a JSON string.
  ///
  /// Returns an empty map if parsing fails.
  static Map<String, ForeignKeyReference> parseForeignKeys(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String, ForeignKeyReference>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(
            key,
            value is Map<String, dynamic>
                ? ForeignKeyReference.fromJson(value)
                : ForeignKeyReference(id: value.toString()),
          ),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to parse foreignKeys JSON: $raw',
        e,
        stackTrace,
      );
    }
    return const <String, ForeignKeyReference>{};
  }

  /// Parses an organism kind from a string value.
  ///
  /// Returns null if the value is empty or unrecognized.
  static OrganismKind? parseOrganismKindValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    for (final kind in OrganismKind.values) {
      if (kind.name.toLowerCase() == normalized) {
        return kind;
      }
    }
    return null;
  }

  /// Parses a double from a string.
  ///
  /// Returns null if the value is empty or cannot be parsed.
  static double? parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return double.tryParse(raw.trim());
  }

  /// Parses an integer from a string.
  ///
  /// Returns null if the value is empty or cannot be parsed.
  static int? parseInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return int.tryParse(raw.trim());
  }

  /// Parses an ISO-8601 date string.
  ///
  /// Returns null if the value is empty or cannot be parsed.
  static DateTime? parseIsoDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.trim());
  }

  /// Splits a string by comma or semicolon into a list.
  ///
  /// Returns an empty list if the input is null or empty.
  static List<String> splitList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    return raw
        .split(RegExp(r'[;,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  /// Converts an empty string to null, otherwise trims and returns the value.
  static String? emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  /// Checks if a string looks like a valid provenance ID.
  ///
  /// Returns true if the string passes validation, false otherwise.
  static bool looksLikeProvenanceId(String value) {
    if (value.trim().isEmpty) return false;
    return ValidationService.provenanceId(value) == null;
  }

  /// Validates that [value] in [columnName] has the expected ID format.
  ///
  /// For doc ID columns (organism_id, genet_id, holding_id): rejects PID- and
  /// legacy SF- prefixes. For lineage ID columns (provenance_id,
  /// genet_provenance_id): rejects non-PID format values.
  ///
  /// Returns null if valid, or a [CSVImportError] if the format is wrong.
  static CSVImportError? validateIdFormat({
    required int rowNumber,
    required String columnName,
    required String value,
  }) {
    if (value.trim().isEmpty) return null;

    final isDocIdColumn = columnName == CsvColumnNames.organismId ||
        columnName == CsvColumnNames.genetId ||
        columnName == CsvColumnNames.holdingId;
    final isLineageIdColumn = columnName == CsvColumnNames.provenanceId ||
        columnName == CsvColumnNames.genetProvenanceId;

    final isLegacyProvenance = CsvColumnNames.isLegacyProvenanceIdFormat(value);

    if (isDocIdColumn &&
        (CsvColumnNames.isProvenanceIdFormat(value) || isLegacyProvenance)) {
      return CSVImportError(
        row: rowNumber,
        field: columnName,
        value: value,
        message: '$columnName expects a Firestore document ID, not a '
            'provenance/lineage ID (PID- prefix). '
            'Found "$value". Use provenance_id or genet_provenance_id '
            'for lineage identifiers.',
      );
    }

    if (isLineageIdColumn && isLegacyProvenance) {
      return CSVImportError(
        row: rowNumber,
        field: columnName,
        value: value,
        message: '$columnName must use the PID- prefix. Legacy SF- '
            'provenance IDs are not supported.',
      );
    }

    if (isLineageIdColumn && CsvColumnNames.isDocIdFormat(value)) {
      return CSVImportError(
        row: rowNumber,
        field: columnName,
        value: value,
        message: '$columnName expects a lineage ID (PID- prefix), '
            'not a Firestore document ID. '
            'Found "$value". Use organism_id or genet_id '
            'for Firestore document IDs.',
      );
    }

    return null;
  }
}
