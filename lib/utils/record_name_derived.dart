// @tier: community

import 'package:seafoundry_app/utils/string_formatters.dart';

/// Derives a deterministic record name from a localId using hash-based adjective selection.
///
/// This class is SYNCHRONOUS and requires NO I/O. It's suitable for:
/// - Deserialization fallbacks when recordName is missing
/// - Quick UI placeholders before async suggestion completes
///
/// For uniqueness-aware suggestions that query the database, use [RecordNameSuggester].
class RecordNameDerived {
  RecordNameDerived._();

  /// Canonical hardcoded subset of adjectives for deterministic record name derivation.
  /// Used as fallback when the larger wordlist asset cannot be loaded.
  static const List<String> adjectives = [
    'able',
    'bright',
    'calm',
    'clear',
    'clean',
    'cool',
    'cozy',
    'crisp',
    'dry',
    'fair',
    'fast',
    'fresh',
    'gentle',
    'glad',
    'good',
    'grand',
    'green',
    'happy',
    'kind',
    'light',
    'lively',
    'local',
    'long',
    'lucky',
    'mellow',
    'neat',
    'new',
    'nice',
    'plain',
    'proud',
    'quick',
    'quiet',
    'rare',
    'ready',
    'real',
    'rich',
    'safe',
    'sharp',
    'short',
    'soft',
    'solid',
    'steady',
    'strong',
    'sweet',
    'swift',
    'tidy',
    'true',
    'warm',
    'wide',
    'young',
    'brave',
    'bold',
    'blue',
    'gold',
    'red',
    'smooth',
    'small',
    'tall',
  ];

  /// Derives a record name from localId using hash-based adjective selection.
  /// Returns just the capitalized adjective (e.g., "Crimson") - localId is stored
  /// separately on OrganismRecord and can be referenced directly.
  /// Returns null if localId is null/empty.
  static String? fromLocalId(String? localId) {
    final normalized = _normalizeLocalId(localId);
    if (normalized == null) return null;
    final adjective = adjectives[_hash(normalized) % adjectives.length];
    return capitalize(adjective);
  }

  /// Derives a record name from a document ID.
  /// Truncates the ID to first 8 characters for readability.
  /// Returns null if id is null/empty.
  static String? fromId(String? id) {
    if (id == null) return null;
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final truncated = trimmed.length > 8 ? trimmed.substring(0, 8) : trimmed;
    return fromLocalId(truncated);
  }

  static String? _normalizeLocalId(String? localId) {
    if (localId == null) return null;
    final trimmed = localId.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'\s+'), '-').toLowerCase();
  }

  static int _hash(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
