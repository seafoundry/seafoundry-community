// @tier: community

/// Utility class for safe YAML string serialization.
///
/// Provides comprehensive escaping for all YAML special characters,
/// keywords, and edge cases to ensure data integrity during serialization.
class YamlUtils {
  YamlUtils._();

  // YAML boolean keywords (case-insensitive)
  static const _yamlBooleans = {
    'true',
    'false',
    'yes',
    'no',
    'on',
    'off',
    'y',
    'n',
  };

  // YAML null keywords
  static const _yamlNulls = {'null', '~'};

  // YAML special float values
  static const _yamlSpecialFloats = {'.inf', '-.inf', '+.inf', '.nan'};

  // Regex for numeric patterns that YAML interprets as numbers
  static final _integerPattern = RegExp(r'^[+-]?\d+$');
  static final _floatPattern = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');
  static final _hexPattern = RegExp(r'^0x[0-9a-fA-F]+$');
  static final _octalPattern = RegExp(r'^0o[0-7]+$');

  /// Escapes a string value for safe YAML serialization.
  ///
  /// Handles all YAML special cases including:
  /// - Control characters: `\n`, `\t`, `\r`
  /// - Quote characters: `"`, `'`
  /// - YAML indicators: `: # , [ ] { } & * ! | > % @ \` ? -`
  /// - Leading/trailing whitespace
  /// - YAML boolean keywords: true, false, yes, no, on, off, y, n
  /// - YAML null values: null, ~
  /// - Numeric patterns: integers, floats, hex, octal, .inf, .nan
  /// - Empty strings
  ///
  /// Returns the value quoted with double quotes if necessary, with
  /// internal special characters properly escaped.
  static String escape(String value) {
    // Empty string must be quoted
    if (value.isEmpty) return '""';

    // Check if quoting is required
    if (_needsQuoting(value)) {
      return _quoteAndEscape(value);
    }

    return value;
  }

  /// Determines if a value needs to be quoted in YAML.
  static bool _needsQuoting(String value) {
    // Leading or trailing whitespace
    if (value.startsWith(' ') ||
        value.startsWith('\t') ||
        value.endsWith(' ') ||
        value.endsWith('\t')) {
      return true;
    }

    // Starts with YAML indicator characters
    if (_startsWithIndicator(value)) {
      return true;
    }

    // Contains special characters requiring quoting
    if (_containsSpecialChars(value)) {
      return true;
    }

    // YAML boolean keywords (case-insensitive)
    if (_yamlBooleans.contains(value.toLowerCase())) {
      return true;
    }

    // YAML null keywords
    if (_yamlNulls.contains(value.toLowerCase())) {
      return true;
    }

    // Numeric patterns that YAML would interpret as numbers
    if (_looksLikeNumber(value)) {
      return true;
    }

    // YAML special floats (case-insensitive)
    if (_yamlSpecialFloats.contains(value.toLowerCase())) {
      return true;
    }

    return false;
  }

  /// Checks if the value starts with a YAML indicator character.
  static bool _startsWithIndicator(String value) {
    if (value.isEmpty) return false;
    final firstChar = value[0];
    // Characters that have special meaning at start of value
    return firstChar == '-' ||
        firstChar == '?' ||
        firstChar == ':' ||
        firstChar == '&' ||
        firstChar == '*' ||
        firstChar == '!' ||
        firstChar == '|' ||
        firstChar == '>' ||
        firstChar == "'" ||
        firstChar == '"' ||
        firstChar == '%' ||
        firstChar == '@' ||
        firstChar == '`' ||
        firstChar == '#' ||
        firstChar == '[' ||
        firstChar == '{';
  }

  /// Checks if the value contains characters that require quoting.
  static bool _containsSpecialChars(String value) {
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char == ':' ||
          char == '#' ||
          char == ',' ||
          char == '[' ||
          char == ']' ||
          char == '{' ||
          char == '}' ||
          char == '&' ||
          char == '*' ||
          char == '!' ||
          char == '|' ||
          char == '>' ||
          char == "'" ||
          char == '"' ||
          char == '\n' ||
          char == '\r' ||
          char == '\t' ||
          char == '\\') {
        return true;
      }
    }
    return false;
  }

  /// Checks if the value looks like a number to YAML.
  static bool _looksLikeNumber(String value) {
    return _integerPattern.hasMatch(value) ||
        _floatPattern.hasMatch(value) ||
        _hexPattern.hasMatch(value) ||
        _octalPattern.hasMatch(value);
  }

  /// Quotes and escapes a string value for YAML.
  static String _quoteAndEscape(String value) {
    final buffer = StringBuffer('"');
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      switch (char) {
        case '\\':
          buffer.write('\\\\');
        case '"':
          buffer.write('\\"');
        case '\n':
          buffer.write('\\n');
        case '\r':
          buffer.write('\\r');
        case '\t':
          buffer.write('\\t');
        default:
          buffer.write(char);
      }
    }
    buffer.write('"');
    return buffer.toString();
  }

  /// Converts a string to a URL-safe slug for use in IDs.
  ///
  /// - Converts to lowercase
  /// - Replaces non-alphanumeric characters with hyphens
  /// - Removes consecutive hyphens
  /// - Trims leading/trailing hyphens
  /// - Returns [fallback] if result would be empty
  static String slug(String value, {String fallback = 'value'}) {
    if (value.isEmpty) return fallback;

    final result = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return result.isEmpty ? fallback : result;
  }
}
