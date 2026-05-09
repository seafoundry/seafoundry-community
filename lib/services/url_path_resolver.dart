/// Centralized service for URL path operations in SeaFoundry.
///
/// URL paths in SeaFoundry follow a hierarchical structure:
/// `{organization}/{site}/{group}/{organism}/{event}`
///
/// Examples:
/// - Organization: `demo-seafoundry`
/// - Site: `demo-seafoundry/community-land-nursery`
/// - Group (Tank): `demo-seafoundry/community-land-nursery/tank-a`
/// - Organism: `demo-seafoundry/community-land-nursery/tank-a/acer-001`
/// - Event: `demo-seafoundry/community-land-nursery/tank-a/acer-001/evt123`
///
/// This service provides utilities for:
/// - Path construction and validation
/// - Path relationship queries (parent, child, ancestor, descendant)
/// - Path parsing and segment extraction
class UrlPathResolver {
  UrlPathResolver._();

  /// Path segment separator
  static const String separator = '/';

  // =========================================================================
  // Path Construction
  // =========================================================================

  /// Build a URL path from segments.
  ///
  /// Example:
  /// ```dart
  /// buildPath(['demo-seafoundry', 'site-a', 'tank-a']) // 'demo-seafoundry/site-a/tank-a'
  /// ```
  static String buildPath(List<String> segments) {
    if (segments.isEmpty) return '';
    return segments.where((s) => s.isNotEmpty).join(separator);
  }

  // =========================================================================
  // Path Parsing
  // =========================================================================

  /// Split a path into its segments.
  ///
  /// Example:
  /// ```dart
  /// getSegments('demo-seafoundry/site-a/tank-a') // ['demo-seafoundry', 'site-a', 'tank-a']
  /// ```
  static List<String> getSegments(String path) {
    if (path.isEmpty) return [];
    return path.split(separator).where((s) => s.isNotEmpty).toList();
  }

  /// Get the depth of a path (number of segments).
  ///
  /// Example:
  /// ```dart
  /// getDepth('demo-seafoundry/site-a/tank-a') // 3
  /// getDepth('demo-seafoundry') // 1
  /// getDepth('') // 0
  /// ```
  static int getDepth(String path) => getSegments(path).length;

  /// Get the parent path (remove last segment).
  ///
  /// Example:
  /// ```dart
  /// getParentPath('demo-seafoundry/site-a/tank-a') // 'demo-seafoundry/site-a'
  /// getParentPath('demo-seafoundry') // ''
  /// ```
  static String getParentPath(String path) {
    final segments = getSegments(path);
    if (segments.length <= 1) return '';
    return buildPath(segments.sublist(0, segments.length - 1));
  }

  // =========================================================================
  // Path Relationship Queries
  // =========================================================================

  /// Check if a path is a descendant (child, grandchild, etc.) of an ancestor path.
  ///
  /// Note: A path is NOT a descendant of itself.
  ///
  /// Example:
  /// ```dart
  /// isDescendantOf('demo/site/tank', 'demo/site') // true
  /// isDescendantOf('demo/site', 'demo/site') // false (not descendant of itself)
  /// ```
  static bool isDescendantOf(String path, String ancestorPath) {
    if (ancestorPath.isEmpty) return false;
    if (path == ancestorPath) return false;
    return path.startsWith('$ancestorPath$separator');
  }

  /// Check if a path is a direct child (one level below) of a parent path.
  ///
  /// Example:
  /// ```dart
  /// isChildOf('demo/site/tank', 'demo/site') // true
  /// isChildOf('demo/site/tank/org', 'demo/site') // false (grandchild, not child)
  /// ```
  static bool isChildOf(String path, String parentPath) {
    if (!isDescendantOf(path, parentPath)) return false;
    final pathDepth = getDepth(path);
    final parentDepth = getDepth(parentPath);
    return pathDepth == parentDepth + 1;
  }

  // =========================================================================
  // Path Validation
  // =========================================================================

  /// Normalize a path (remove leading/trailing slashes, collapse double slashes).
  static String normalizePath(String path) {
    if (path.isEmpty) return path;
    // Remove leading/trailing slashes
    var normalized = path.trim();
    while (normalized.startsWith(separator)) {
      normalized = normalized.substring(1);
    }
    while (normalized.endsWith(separator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    // Collapse double slashes
    while (normalized.contains('$separator$separator')) {
      normalized = normalized.replaceAll('$separator$separator', separator);
    }
    return normalized;
  }
}
