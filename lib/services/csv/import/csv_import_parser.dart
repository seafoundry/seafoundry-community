class CsvParsedData {
  const CsvParsedData({
    required this.metadata,
    required this.headers,
    required this.rows,
  });

  final Map<String, String> metadata;
  final List<String> headers;
  final List<Map<String, String>> rows;

  bool get isEmpty => headers.isEmpty || rows.isEmpty;
}

/// Lightweight CSV parser that extracts metadata rows preceding the header and
/// returns the structured row maps used by `CSVImportService`.
class CsvImportParser {
  const CsvImportParser({required Set<String> metadataKeys})
      : _metadataKeys = metadataKeys;

  final Set<String> _metadataKeys;

  CsvParsedData parse(String csvString) {
    final lines = csvString
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const CsvParsedData(
        metadata: <String, String>{},
        headers: <String>[],
        rows: <Map<String, String>>[],
      );
    }

    final metadata = <String, String>{};
    List<String>? headers;
    List<String>? normalizedHeaders;
    int headerIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      final trimmedLine = lines[i].trim();
      if (trimmedLine.startsWith('#')) {
        continue;
      }
      final cells = _parseCsvLine(lines[i]);
      if (cells.isEmpty) continue;

      final key = cells.first.trim();
      final normalizedKey = _normalizeHeaderKey(key);
      if (cells.length == 2 &&
          (_metadataKeys.contains(key) ||
              (normalizedKey.isNotEmpty && _metadataKeys.contains(normalizedKey)))) {
        final resolvedKey =
            _metadataKeys.contains(key) ? key : normalizedKey;
        metadata[resolvedKey] = cells[1].trim();
        continue;
      }

      headers = cells;
      normalizedHeaders = headers.map(_normalizeHeaderKey).toList();
      headerIndex = i;
      break;
    }

    if (headers == null) {
      return CsvParsedData(
        metadata: metadata,
        headers: const <String>[],
        rows: const <Map<String, String>>[],
      );
    }

    final rows = <Map<String, String>>[];
    for (int i = headerIndex + 1; i < lines.length; i++) {
      final trimmedLine = lines[i].trim();
      if (trimmedLine.startsWith('#')) {
        continue;
      }
      final values = _parseCsvLine(lines[i]);
      if (values.isEmpty || values.length != headers.length) {
        continue;
      }

      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        final header = headers[j];
        row[header] = values[j];
        if (normalizedHeaders != null) {
          final normalized = normalizedHeaders[j];
          if (normalized.isNotEmpty && !row.containsKey(normalized)) {
            row[normalized] = values[j];
          }
        }
      }
      rows.add(row);
    }

    return CsvParsedData(metadata: metadata, headers: headers, rows: rows);
  }

  /// Parse a single CSV line handling quotes and commas.
  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        final isEscapedQuote =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    values.add(buffer.toString().trim());
    return values;
  }

  String _normalizeHeaderKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split('.');
    final normalizedParts =
        parts.map(_normalizeHeaderSegment).where((part) => part.isNotEmpty);
    return normalizedParts.join('.');
  }

  String _normalizeHeaderSegment(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // Step 1-2: Replace all separators (spaces, underscores, hyphens) with spaces
    var value = trimmed.replaceAll(RegExp(r'[\s_\-]+'), ' ');

    // Step 3a: Insert space on camelCase boundary: lowercase/digit → uppercase
    value = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Step 3b: Insert space on acronym boundary: MULTI-UPPER → last upper + lower
    value = value.replaceAllMapped(
      RegExp(r'([A-Z]+)([A-Z][a-z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // Step 4: Strip non-alphanumeric from each word, discard empties
    final words = value
        .split(' ')
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '';

    // Step 5: Rejoin as camelCase
    final buffer = StringBuffer(words.first.toLowerCase());
    for (var i = 1; i < words.length; i++) {
      final word = words[i];
      buffer.write(word[0].toUpperCase());
      if (word.length > 1) {
        buffer.write(word.substring(1).toLowerCase());
      }
    }
    return buffer.toString();
  }
}
