// @tier: community
import 'package:seafoundry_app/services/url_path_resolver.dart';

/// String extension providing path utility methods.
///
/// For comprehensive path operations, consider using [UrlPathResolver] directly:
/// - Path construction: `buildPath()`, `appendSegment()`, `joinPaths()`
/// - Path parsing: `getSegments()`, `getDepth()`, `getLastSegment()`
/// - Path relationships: `isDescendantOf()`, `isAncestorOf()`, `isChildOf()`
/// - Path validation: `isValidPath()`, `normalizePath()`
///
/// See also: [UrlPathStringExtension] for additional path extension methods.
extension StringUtils on String {
  /// Returns true if this path is a direct child of the given parent path.
  ///
  /// Delegates to [UrlPathResolver.isChildOf].
  ///
  /// Example:
  /// - "org1/site1/tank1".isChildOfPath("org1/site1") returns true
  /// - "org1/site1/tank1/coral1".isChildOfPath("org1/site1") returns false
  bool isChildOfPath(String parentPath) =>
      UrlPathResolver.instance.isChildOf(this, parentPath);

  /// Returns true if this path is a descendant (child, grandchild, etc.) of the given ancestor path.
  ///
  /// Delegates to [UrlPathResolver.isDescendantOf].
  ///
  /// Example:
  /// - "org1/site1/tank1".isDescendantOfPath("org1/site1") returns true
  /// - "org1/site1/tank1/coral1".isDescendantOfPath("org1/site1") returns true
  /// - "org1/site1".isDescendantOfPath("org1/site1") returns false (not a descendant of itself)
  bool isDescendantOfPath(String ancestorPath) =>
      UrlPathResolver.instance.isDescendantOf(this, ancestorPath);

  String truncate(int maxLength) {
    return length > maxLength ? substring(0, maxLength) : this;
  }

  /// Returns the last [maxLength] characters of the string.
  ///
  /// Useful for displaying truncated UUIDs where the last characters
  /// are the most unique/distinguishing.
  ///
  /// Example:
  /// - "a1b2c3d4-e5f6-7890-abcd-ef1234567890".truncateLast(8)
  ///   returns "34567890"
  String truncateLast(int maxLength) {
    return length > maxLength ? substring(length - maxLength) : this;
  }

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

  /// Returns the parent path (removes last segment).
  ///
  /// Delegates to [UrlPathResolver.getParentPath].
  String get parentPath => UrlPathResolver.instance.getParentPath(this);
}

extension DateTimeUtils on DateTime {
  static DateTime parseTimestamp(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return value.toDate();
    } catch (e) {
      return DateTime.now();
    }
  }
}

extension SafeCasts on Object? {
  /// Returns this object as [T] if possible, otherwise `null`.
  T? asOrNull<T>() => this is T ? this as T : null;

  /// Returns this object as [T] if possible, otherwise [fallback].
  T tryCast<T>(T fallback) => this is T ? this as T : fallback;
}
