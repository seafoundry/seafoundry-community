// @tier: community

/// Utility for normalizing and matching local IDs during CSV import.
///
/// Provides case-insensitive, whitespace-normalized matching to handle
/// common data entry variations like "CORAL 001" vs "coral001".
class LocalIdMatcher {
  LocalIdMatcher._();

  /// Normalizes a local ID for comparison purposes.
  ///
  /// Rules:
  /// - Trims leading/trailing whitespace
  /// - Removes all internal whitespace
  /// - Converts to lowercase
  ///
  /// Examples:
  /// - "CORAL 001" → "coral001"
  /// - "  Coral-001  " → "coral-001"
  /// - "ABC_123" → "abc_123"
  ///
  /// Special characters (hyphens, underscores) are preserved,
  /// so "coral-001" ≠ "coral_001".
  static String normalize(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  /// Checks if two local IDs match after normalization.
  static bool matches(String a, String b) {
    return normalize(a) == normalize(b);
  }

  /// Finds a matching item from a list using normalized local ID comparison.
  ///
  /// Returns the first item where [getLocalId] returns a value that matches
  /// [targetLocalId] after normalization, or null if no match is found.
  static T? findMatch<T>(
    String targetLocalId,
    Iterable<T> items,
    String Function(T) getLocalId,
  ) {
    final normalizedTarget = normalize(targetLocalId);
    for (final item in items) {
      if (normalize(getLocalId(item)) == normalizedTarget) {
        return item;
      }
    }
    return null;
  }

  /// Finds all matching items from a list using normalized local ID comparison.
  static List<T> findAllMatches<T>(
    String targetLocalId,
    Iterable<T> items,
    String Function(T) getLocalId,
  ) {
    final normalizedTarget = normalize(targetLocalId);
    return items
        .where((item) => normalize(getLocalId(item)) == normalizedTarget)
        .toList();
  }

  /// Creates a normalized lookup map from a list of items.
  ///
  /// Keys are normalized local IDs, values are the original items.
  /// If multiple items have the same normalized ID, later items overwrite earlier ones.
  static Map<String, T> buildLookupMap<T>(
    Iterable<T> items,
    String Function(T) getLocalId,
  ) {
    final map = <String, T>{};
    for (final item in items) {
      final normalizedId = normalize(getLocalId(item));
      if (normalizedId.isNotEmpty) {
        map[normalizedId] = item;
      }
    }
    return map;
  }

  /// Creates a normalized lookup map that preserves all items with the same ID.
  ///
  /// Keys are normalized local IDs, values are lists of matching items.
  static Map<String, List<T>> buildMultiLookupMap<T>(
    Iterable<T> items,
    String Function(T) getLocalId,
  ) {
    final map = <String, List<T>>{};
    for (final item in items) {
      final normalizedId = normalize(getLocalId(item));
      if (normalizedId.isNotEmpty) {
        map.putIfAbsent(normalizedId, () => []).add(item);
      }
    }
    return map;
  }

  /// Validates that a local ID is non-empty after normalization.
  static bool isValid(String? localId) {
    if (localId == null) return false;
    return normalize(localId).isNotEmpty;
  }
}
