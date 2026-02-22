// @tier: community
import 'package:intl/intl.dart';

/// Shared utilities for presenting provenance metadata consistently across
/// spreadsheets, exports, and analytics views.
class ProvenanceFormatter {
  /// Formats a provenance metadata map into a single human-friendly string.
  static String summarizeMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) return '';
    final entries = metadata.entries
        .map(
          (entry) => '${_humanizeKey(entry.key)}: ${_stringify(entry.value)}',
        )
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return entries.join(' • ');
  }

  static String summarizeDateRange(DateTime? start, DateTime? end) {
    final formatter = DateFormat('yyyy-MM-dd');
    final startText = start != null ? formatter.format(start) : '';
    final endText = end != null ? formatter.format(end) : '';
    if (startText.isEmpty && endText.isEmpty) return '';
    if (startText.isEmpty) return endText;
    if (endText.isEmpty) return startText;
    return '$startText → $endText';
  }

  static String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is num || value is bool) return value.toString();
    if (value is DateTime) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
    return value.toString();
  }

  static String _humanizeKey(String key) {
    final spaced = key.replaceAll(RegExp(r'[_\-]+'), ' ');
    if (spaced.isEmpty) return key;
    return spaced.length == 1
        ? spaced.toUpperCase()
        : spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String titleCase(String value) {
    if (value.isEmpty) return value;
    final normalized = value.replaceAll('_', ' ').toLowerCase();
    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word.length == 1
              ? word.toUpperCase()
              : word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}
