// @tier: community
class SpreadsheetFilterUtils {
  static String? firstString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final stringValue = value.toString().trim();
      if (stringValue.isNotEmpty) {
        return stringValue;
      }
    }
    return null;
  }

  static bool matchesField(
    Map<String, dynamic> row,
    String? filter,
    List<String> keys, {
    bool partial = false,
  }) {
    if (filter == null || filter.isEmpty) {
      return true;
    }
    final value = firstString(row, keys);
    if (value == null || value.isEmpty) return false;
    return partial ? value.contains(filter) : value == filter;
  }

  static List<MapEntry<String?, String?>> dedupeEntries(
    Iterable<MapEntry<String?, String?>> source,
  ) {
    final map = <String, String?>{};
    for (final entry in source) {
      final key = entry.key;
      if (key == null || key.isEmpty || map.containsKey(key)) continue;
      map[key] = entry.value;
    }
    return map.entries.toList()
      ..sort((a, b) => (a.value ?? '').compareTo(b.value ?? ''));
  }

  static String entryLabel(MapEntry<String?, String?> entry) =>
      entry.value ?? entry.key ?? '';
}
