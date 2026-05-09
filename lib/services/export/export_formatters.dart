import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// Formatters for exporting data to different file formats
class ExportFormatters {
  /// Generate CSV string from headers and rows
  ///
  /// [prefaceLines] are optional comment lines prefixed with '#'
  static String generateCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<String>? prefaceLines,
  }) {
    final buffer = StringBuffer();
    if (prefaceLines != null && prefaceLines.isNotEmpty) {
      for (final line in prefaceLines) {
        buffer.writeln('# $line');
      }
      buffer.writeln();
    }
    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    buffer.write(csv);
    return buffer.toString();
  }

  /// Generate Excel (XLSX) file from headers and rows
  ///
  /// [prefaceLines] are optional comment rows at the top
  static Uint8List generateXlsx({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    List<String>? prefaceLines,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel[sheetName];

    if (prefaceLines != null && prefaceLines.isNotEmpty) {
      for (final line in prefaceLines) {
        sheet.appendRow([TextCellValue(line)]);
      }
      sheet.appendRow([TextCellValue('')]);
    }

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (final row in rows) {
      sheet.appendRow(
        row.map<CellValue?>((v) {
          if (v == null) return TextCellValue('');
          if (v is num) return DoubleCellValue(v.toDouble());
          return TextCellValue(v.toString());
        }).toList(),
      );
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }

  /// Escape CSV field values properly
  static String escapeCsvField(dynamic field) {
    if (field == null) return '';
    final value = field.toString();
    // Escape commas, quotes, and newlines
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Convert a row map to a CSV row with proper column ordering
  static List<dynamic> mapToRow(
    Map<String, dynamic> row,
    List<String> headers,
  ) {
    return [for (final header in headers) row[header] ?? ''];
  }

  /// Convert dynamic value to string for CSV/Excel export
  static String stringValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }

  /// Convert dynamic value to ISO string format
  static String isoString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed.toUtc().toIso8601String();
      }
      return trimmed;
    }
    return value.toString();
  }

  /// Sanitize a filename for safe export.
  ///
  /// - Trims whitespace
  /// - Replaces invalid characters with underscores
  /// - Collapses multiple underscores/spaces to single underscore
  /// - Converts to lowercase
  /// - Returns 'export' if result would be empty
  static String sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'export';

    return trimmed
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'[^\w\s.-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '_')
        .toLowerCase();
  }
}
