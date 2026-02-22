// @tier: community
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
  const UrlPathResolver._();

  static const UrlPathResolver instance = UrlPathResolver._();

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
  String buildPath(List<String> segments) {
    if (segments.isEmpty) return '';
    return segments.where((s) => s.isNotEmpty).join(separator);
  }

  /// Append a segment to an existing path.
  ///
  /// Example:
  /// ```dart
  /// appendSegment('demo-seafoundry/site-a', 'tank-a') // 'demo-seafoundry/site-a/tank-a'
  /// ```
  String appendSegment(String basePath, String segment) {
    if (basePath.isEmpty) return segment;
    if (segment.isEmpty) return basePath;
    return '$basePath$separator$segment';
  }

  /// Join two paths together.
  ///
  /// Example:
  /// ```dart
  /// joinPaths('demo-seafoundry', 'site-a/tank-a') // 'demo-seafoundry/site-a/tank-a'
  /// ```
  String joinPaths(String basePath, String relativePath) {
    if (basePath.isEmpty) return relativePath;
    if (relativePath.isEmpty) return basePath;
    return '$basePath$separator$relativePath';
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
  List<String> getSegments(String path) {
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
  int getDepth(String path) => getSegments(path).length;

  /// Get the last segment of a path (the "name").
  ///
  /// Example:
  /// ```dart
  /// getLastSegment('demo-seafoundry/site-a/tank-a') // 'tank-a'
  /// ```
  String getLastSegment(String path) {
    final segments = getSegments(path);
    return segments.isEmpty ? '' : segments.last;
  }

  /// Get the first segment of a path (typically the organization).
  ///
  /// Example:
  /// ```dart
  /// getFirstSegment('demo-seafoundry/site-a/tank-a') // 'demo-seafoundry'
  /// ```
  String getFirstSegment(String path) {
    final segments = getSegments(path);
    return segments.isEmpty ? '' : segments.first;
  }

  /// Get the parent path (remove last segment).
  ///
  /// Example:
  /// ```dart
  /// getParentPath('demo-seafoundry/site-a/tank-a') // 'demo-seafoundry/site-a'
  /// getParentPath('demo-seafoundry') // ''
  /// ```
  String getParentPath(String path) {
    final segments = getSegments(path);
    if (segments.length <= 1) return '';
    return buildPath(segments.sublist(0, segments.length - 1));
  }

  /// Get path at a specific depth from root.
  ///
  /// Example:
  /// ```dart
  /// getPathAtDepth('demo-seafoundry/site-a/tank-a/org-1', 2) // 'demo-seafoundry/site-a'
  /// ```
  String getPathAtDepth(String path, int depth) {
    final segments = getSegments(path);
    if (depth <= 0) return '';
    if (depth >= segments.length) return path;
    return buildPath(segments.sublist(0, depth));
  }

  // =========================================================================
  // Path Relationship Queries
  // =========================================================================

  /// Check if two paths are exactly equal.
  bool isExactMatch(String path1, String path2) => path1 == path2;

  /// Check if a path is a descendant (child, grandchild, etc.) of an ancestor path.
  ///
  /// Note: A path is NOT a descendant of itself.
  ///
  /// Example:
  /// ```dart
  /// isDescendantOf('demo/site/tank', 'demo/site') // true
  /// isDescendantOf('demo/site', 'demo/site') // false (not descendant of itself)
  /// ```
  bool isDescendantOf(String path, String ancestorPath) {
    if (ancestorPath.isEmpty) return false;
    if (path == ancestorPath) return false;
    return path.startsWith('$ancestorPath$separator');
  }

  /// Check if a path is an ancestor (parent, grandparent, etc.) of a descendant path.
  ///
  /// Note: A path is NOT an ancestor of itself.
  ///
  /// Example:
  /// ```dart
  /// isAncestorOf('demo/site', 'demo/site/tank') // true
  /// isAncestorOf('demo/site', 'demo/site') // false (not ancestor of itself)
  /// ```
  bool isAncestorOf(String path, String descendantPath) {
    return isDescendantOf(descendantPath, path);
  }

  /// Check if a path is a direct child (one level below) of a parent path.
  ///
  /// Example:
  /// ```dart
  /// isChildOf('demo/site/tank', 'demo/site') // true
  /// isChildOf('demo/site/tank/org', 'demo/site') // false (grandchild, not child)
  /// ```
  bool isChildOf(String path, String parentPath) {
    if (!isDescendantOf(path, parentPath)) return false;
    final pathDepth = getDepth(path);
    final parentDepth = getDepth(parentPath);
    return pathDepth == parentDepth + 1;
  }

  /// Check if a path is a direct parent (one level above) of a child path.
  ///
  /// Example:
  /// ```dart
  /// isParentOf('demo/site', 'demo/site/tank') // true
  /// isParentOf('demo', 'demo/site/tank') // false (grandparent, not parent)
  /// ```
  bool isParentOf(String path, String childPath) {
    return isChildOf(childPath, path);
  }

  /// Check if two paths share a common ancestor.
  ///
  /// Example:
  /// ```dart
  /// shareAncestor('demo/site-a/tank', 'demo/site-b/tank') // true (share 'demo')
  /// shareAncestor('org1/site', 'org2/site') // false
  /// ```
  bool shareAncestor(String path1, String path2) {
    return getFirstSegment(path1) == getFirstSegment(path2);
  }

  /// Get the common ancestor path between two paths.
  ///
  /// Example:
  /// ```dart
  /// getCommonAncestor('demo/site-a/tank', 'demo/site-a/tray') // 'demo/site-a'
  /// getCommonAncestor('demo/site-a', 'demo/site-b') // 'demo'
  /// getCommonAncestor('org1/site', 'org2/site') // ''
  /// ```
  String getCommonAncestor(String path1, String path2) {
    final segments1 = getSegments(path1);
    final segments2 = getSegments(path2);
    final commonSegments = <String>[];

    for (int i = 0; i < segments1.length && i < segments2.length; i++) {
      if (segments1[i] == segments2[i]) {
        commonSegments.add(segments1[i]);
      } else {
        break;
      }
    }

    return buildPath(commonSegments);
  }

  // =========================================================================
  // Path Validation
  // =========================================================================

  /// Check if a path is valid (non-empty, no double slashes, no leading/trailing slashes).
  bool isValidPath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith(separator)) return false;
    if (path.endsWith(separator)) return false;
    if (path.contains('$separator$separator')) return false;
    return true;
  }

  /// Normalize a path (remove leading/trailing slashes, collapse double slashes).
  String normalizePath(String path) {
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

  // =========================================================================
  // Relative Path Operations
  // =========================================================================

  /// Get the relative path from an ancestor to a descendant.
  ///
  /// Example:
  /// ```dart
  /// getRelativePath('demo/site/tank', 'demo') // 'site/tank'
  /// getRelativePath('demo/site', 'demo/site') // ''
  /// ```
  String getRelativePath(String path, String fromAncestor) {
    if (path == fromAncestor) return '';
    if (!isDescendantOf(path, fromAncestor)) {
      // Not a descendant, return full path
      return path;
    }
    return path.substring(fromAncestor.length + 1);
  }

  /// Get all ancestor paths from root to the given path.
  ///
  /// Example:
  /// ```dart
  /// getAncestorPaths('demo/site/tank') // ['demo', 'demo/site']
  /// ```
  List<String> getAncestorPaths(String path) {
    final segments = getSegments(path);
    final ancestors = <String>[];
    for (int i = 1; i < segments.length; i++) {
      ancestors.add(buildPath(segments.sublist(0, i)));
    }
    return ancestors;
  }

  /// Get the full lineage (all paths from root to this path, inclusive).
  ///
  /// Example:
  /// ```dart
  /// getLineage('demo/site/tank') // ['demo', 'demo/site', 'demo/site/tank']
  /// ```
  List<String> getLineage(String path) {
    final segments = getSegments(path);
    final lineage = <String>[];
    for (int i = 1; i <= segments.length; i++) {
      lineage.add(buildPath(segments.sublist(0, i)));
    }
    return lineage;
  }
}

/// String extension providing path utility methods.
///
/// These methods delegate to [UrlPathResolver] for consistent behavior.
/// The extension syntax is convenient for chaining operations.
extension UrlPathStringExtension on String {
  /// Check if this path is a descendant of the given ancestor path.
  ///
  /// See [UrlPathResolver.isDescendantOf] for details.
  bool isDescendantOfPath(String ancestorPath) =>
      UrlPathResolver.instance.isDescendantOf(this, ancestorPath);

  /// Check if this path is a direct child of the given parent path.
  ///
  /// See [UrlPathResolver.isChildOf] for details.
  bool isChildOfPath(String parentPath) =>
      UrlPathResolver.instance.isChildOf(this, parentPath);

  /// Check if this path is an ancestor of the given descendant path.
  ///
  /// See [UrlPathResolver.isAncestorOf] for details.
  bool isAncestorOfPath(String descendantPath) =>
      UrlPathResolver.instance.isAncestorOf(this, descendantPath);

  /// Check if this path is a direct parent of the given child path.
  ///
  /// See [UrlPathResolver.isParentOf] for details.
  bool isParentOfPath(String childPath) =>
      UrlPathResolver.instance.isParentOf(this, childPath);

  /// Get the parent path of this path.
  ///
  /// See [UrlPathResolver.getParentPath] for details.
  String get urlParentPath => UrlPathResolver.instance.getParentPath(this);

  /// Get the last segment (name) of this path.
  ///
  /// See [UrlPathResolver.getLastSegment] for details.
  String get urlLastSegment => UrlPathResolver.instance.getLastSegment(this);

  /// Get the depth of this path.
  ///
  /// See [UrlPathResolver.getDepth] for details.
  int get urlDepth => UrlPathResolver.instance.getDepth(this);

  /// Append a segment to this path.
  ///
  /// See [UrlPathResolver.appendSegment] for details.
  String appendUrlSegment(String segment) =>
      UrlPathResolver.instance.appendSegment(this, segment);
}

