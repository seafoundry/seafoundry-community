
/// Base exception class for errors that occur during graph node loading.
///
/// This provides specific error types to distinguish between different failure
/// modes when loading parent nodes or navigating the graph hierarchy.
sealed class NodeLoadError implements Exception {
  const NodeLoadError(this.message, {this.urlPath, this.cause});

  /// A descriptive message explaining the error.
  final String message;

  /// The URL path that was being loaded when the error occurred.
  final String? urlPath;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (urlPath != null) {
      buffer.write(' (urlPath: $urlPath)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Error thrown when a parent node fails to load due to network issues.
///
/// This typically occurs when there's no network connectivity or when
/// Firestore requests timeout.
class NodeLoadNetworkError extends NodeLoadError {
  const NodeLoadNetworkError(
    super.message, {
    super.urlPath,
    super.cause,
  });
}

/// Error thrown when loading a node fails due to permission denied.
///
/// This occurs when the user doesn't have read access to the requested
/// document in Firestore.
class NodeLoadPermissionError extends NodeLoadError {
  const NodeLoadPermissionError(
    super.message, {
    super.urlPath,
    super.cause,
  });
}

/// Error thrown when the requested node does not exist.
///
/// This can happen when navigating to a deleted or non-existent URL path.
class NodeLoadNotFoundError extends NodeLoadError {
  const NodeLoadNotFoundError(
    super.message, {
    super.urlPath,
    super.cause,
  });
}

/// Error thrown when a parent node in the hierarchy fails to load.
///
/// This is used when attempting to load a child node but the parent
/// cannot be resolved, preventing hierarchical traversal.
class ParentNodeLoadError extends NodeLoadError {
  const ParentNodeLoadError(
    super.message, {
    super.urlPath,
    required this.parentPath,
    super.cause,
  });

  /// The URL path of the parent that failed to load.
  final String parentPath;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    buffer.write(' (urlPath: $urlPath, parentPath: $parentPath)');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
