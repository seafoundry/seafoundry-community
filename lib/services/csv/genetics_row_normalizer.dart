import 'dart:convert';

import 'package:seafoundry_community/services/logging_service.dart';

/// Utility helpers for normalizing genetics CSV / export rows so both the
/// exporter and translation adapters share the same parsing behavior.
class GeneticsRowNormalizer {
  const GeneticsRowNormalizer._();

  static Map<String, dynamic> metadataFromRow(Map<dynamic, dynamic> row) {
    final candidates = [
      row['provenanceMetadata'],
      row['metadataRaw'],
      row['provenance'],
      row['metadata'],
    ];
    for (final candidate in candidates) {
      final map = _coerceMap(candidate);
      if (map != null && map.isNotEmpty) {
        return map;
      }
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic>? _coerceMap(dynamic source) {
    if (source == null) return null;
    if (source is Map<String, dynamic>) {
      return source;
    }
    if (source is Map) {
      final result = <String, dynamic>{};
      source.forEach((key, value) {
        if (key == null) return;
        final keyString = key.toString().trim();
        if (keyString.isEmpty) return;
        result[keyString] = value;
      });
      return result;
    }
    if (source is String) {
      final trimmed = source.trim();
      if (trimmed.isEmpty) return null;
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          final decoded = jsonDecode(trimmed);
          return _coerceMap(decoded);
        } catch (e) {
          LoggingService.instance.debug(
            'Failed to decode map value during genetics row normalization',
            e,
          );
          return null;
        }
      }
    }
    return null;
  }

  static String collectParentGameteIds(Map<dynamic, dynamic> row) {
    final ids = <String>{};
    void collect(dynamic value) => _ingestIdValue(ids, value);

    collect(row['parentGameteIds']);
    collect(row['damGameteIds']);
    collect(row['sireGameteIds']);
    collect(row['cohortParentGameteIds']);

    if (ids.isEmpty) return '';
    return ids.join(';');
  }

  static void _ingestIdValue(Set<String> target, dynamic value) {
    if (value == null) return;
    if (value is String) {
      final tokens = value.split(RegExp(r'[;,]'));
      for (final token in tokens) {
        final trimmed = token.trim();
        if (trimmed.isNotEmpty) {
          target.add(trimmed);
        }
      }
      if (tokens.isEmpty) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          target.add(trimmed);
        }
      }
      return;
    }
    if (value is Iterable) {
      for (final entry in value) {
        _ingestIdValue(target, entry);
      }
      return;
    }
    if (value is Map) {
      if (value.containsKey('id')) {
        _ingestIdValue(target, value['id']);
        return;
      }
      if (value.containsKey('value')) {
        _ingestIdValue(target, value['value']);
        return;
      }
      if (value.containsKey('label')) {
        _ingestIdValue(target, value['label']);
        return;
      }
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) {
      target.add(text);
    }
  }

  static String aliasStringFromRow(Map<dynamic, dynamic> row) {
    final tokens = <String>{};
    void add(dynamic value) {
      for (final token in _multiValueTokens(value)) {
        if (token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }

    add(row['aliases']);
    add(row['aliasLabels']);
    add(row['aliasEntries']);

    if (tokens.isEmpty) return '';
    return tokens.join('; ');
  }

  static Iterable<String> _multiValueTokens(dynamic raw) {
    if (raw == null) return const Iterable<String>.empty();

    final tokens = <String>[];
    void addToken(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) tokens.add(trimmed);
    }

    if (raw is String) {
      final segments = raw.split(RegExp(r'[;,]'));
      for (final segment in segments) {
        addToken(segment);
      }
      if (segments.isEmpty) {
        addToken(raw);
      }
      return tokens;
    }

    if (raw is Iterable) {
      for (final entry in raw) {
        if (entry is Map) {
          addToken(entry['label']?.toString());
          addToken(entry['value']?.toString());
        } else if (entry != null) {
          addToken(entry.toString());
        }
      }
      return tokens;
    }

    if (raw is Map) {
      addToken(raw['label']?.toString());
      addToken(raw['value']?.toString());
      return tokens;
    }

    addToken(raw.toString());
    return tokens;
  }

  static String firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final normalized = normalizedString(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  static String joinDistinctSegments(Iterable<dynamic> values) {
    final segments = <String>{};
    for (final value in values) {
      final normalized = normalizedString(value);
      if (normalized.isNotEmpty) {
        segments.add(normalized);
      }
    }
    if (segments.isEmpty) return '';
    return segments.join(' | ');
  }

  static String normalizedString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static String? metadataString(
    Map<String, dynamic> metadata,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final normalizedKey = key.toLowerCase();
      for (final entry in metadata.entries) {
        final entryKey = entry.key.toLowerCase();
        if (entryKey == normalizedKey) {
          final value = entry.value;
          if (value is String) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              return trimmed;
            }
          } else if (value != null) {
            final text = value.toString().trim();
            if (text.isNotEmpty) {
              return text;
            }
          }
        }
      }
    }
    return null;
  }
}
