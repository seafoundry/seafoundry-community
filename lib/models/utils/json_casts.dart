// @tier: community

/// Shared JSON casting helpers for model parsing.
///
/// Firestore web SDKs can surface nested maps as `Map<dynamic, dynamic>`.
/// These helpers normalize them safely without throwing type errors.
library;

/// Safely cast a single map, handling null and `Map<dynamic, dynamic>`.
/// Returns null if the value is not a Map.
Map<String, dynamic>? safeMapCast(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Recursively normalizes a map and all its nested maps/lists.
/// This ensures all nested Map values are `Map<String, dynamic>`.
///
/// Use this at the Firestore data entry point to normalize all data upfront
/// before it reaches individual model parsers.
///
/// Accepts any value - returns empty map for null or non-Map values.
/// This defensive approach handles web Firestore edge cases where
/// expected maps may be null or have unexpected types.
Map<String, dynamic> deepNormalizeMap(dynamic value) {
  if (value == null) return const <String, dynamic>{};
  if (value is! Map) return const <String, dynamic>{};
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key?.toString();
    if (key == null || key.isEmpty) continue;
    result[key] = _normalizeValue(entry.value);
  }
  return result;
}

/// Normalizes a list, recursively normalizing any map elements within it.
List<dynamic> normalizeList(List<dynamic> list) {
  return list.map(_normalizeValue).toList();
}

/// Safely parse a list of maps, filtering out non-map items.
/// Each map element is normalized to `Map<String, dynamic>`.
List<Map<String, dynamic>> safeListOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((e) => safeMapCast(e))
      .whereType<Map<String, dynamic>>()
      .toList();
}

/// Safely parse a dynamic value as [double], rejecting booleans and other
/// non-numeric types.
///
/// On dart2js, `as num?` casts are elided in production builds, allowing
/// booleans to slip through and crash downstream arithmetic. This explicit
/// `is num` check is always enforced by the VM and dart2js alike.
double? safeDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return null;
}

/// Safely parse a dynamic value as [int], rejecting booleans and other
/// non-numeric types. See [safeDouble] for rationale.
int? safeInt(dynamic value) {
  if (value is num) return value.toInt();
  return null;
}

/// Safely converts a dynamic map to `Map<String, int>`, coercing numeric
/// values via [safeInt]. Non-numeric values are excluded.
Map<String, int> safeIntMap(dynamic value) {
  if (value is! Map) return const {};
  final result = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key?.toString();
    if (key == null) continue;
    final intVal = safeInt(entry.value);
    if (intVal != null) result[key] = intVal;
  }
  return result;
}

/// Internal helper to normalize any value recursively.
dynamic _normalizeValue(dynamic value) {
  if (value is Map) {
    return deepNormalizeMap(value);
  }
  if (value is List) {
    return normalizeList(value);
  }
  return value;
}
