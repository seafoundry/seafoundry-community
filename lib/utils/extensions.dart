import 'package:seafoundry_app/services/url_path_resolver.dart';

/// String extension providing path utility methods.
///
/// For comprehensive path operations, consider using [UrlPathResolver] directly:
/// - Path construction: `buildPath()`
/// - Path parsing: `getSegments()`, `getDepth()`, `getParentPath()`
/// - Path relationships: `isDescendantOf()`, `isChildOf()`
/// - Path validation: `normalizePath()`
extension StringUtils on String {
  /// Returns true if this path is a direct child of the given parent path.
  ///
  /// Delegates to [UrlPathResolver.isChildOf].
  ///
  /// Example:
  /// - "org1/site1/tank1".isChildOfPath("org1/site1") returns true
  /// - "org1/site1/tank1/coral1".isChildOfPath("org1/site1") returns false
  bool isChildOfPath(String parentPath) =>
      UrlPathResolver.isChildOf(this, parentPath);

  /// Capitalizes the first character of a string.
  ///
  /// Returns empty string unchanged, single char uppercase,
  /// multi-char with first character capitalized.
  ///
  /// Example:
  /// - "".capitalizeFirst() returns ""
  /// - "a".capitalizeFirst() returns "A"
  /// - "hello".capitalizeFirst() returns "Hello"
  String capitalizeFirst() {
    if (isEmpty) return this;
    if (length == 1) return toUpperCase();
    return this[0].toUpperCase() + substring(1);
  }
}
