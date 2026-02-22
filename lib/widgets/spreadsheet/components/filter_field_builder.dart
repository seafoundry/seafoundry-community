// @tier: community

/// Factory methods for building [FilterField] option maps from the various
/// data formats used across filter bars (MapEntry lists, plain string lists,
/// etc.).
///
/// Extracts the duplicated `_buildLookup` pattern found in 6+ filter bars.
class FilterFieldBuilder {
  const FilterFieldBuilder._();

  /// Converts a list of nullable key/value entries into a `{id: label}` map,
  /// skipping entries with null keys.
  ///
  /// This replaces the private `_buildLookup` method duplicated across
  /// inventory, observations, husbandry logged, husbandry tasks, and other
  /// filter bars.
  static Map<String, String> buildLookup(
    List<MapEntry<String?, String?>> entries,
  ) {
    return {
      for (final entry in entries)
        if (entry.key != null) entry.key!: entry.value ?? entry.key!,
    };
  }

  /// Converts a plain list of string IDs into a `{id: label}` map using an
  /// optional [labelBuilder]. Falls back to the ID itself when no builder is
  /// provided.
  ///
  /// Used by monitoring and genetics filter bars that pass `List<String>`
  /// option sets.
  static Map<String, String> buildLookupFromIds(
    List<String> ids, {
    String Function(String)? labelBuilder,
  }) {
    return {
      for (final id in ids) id: labelBuilder?.call(id) ?? id,
    };
  }
}
