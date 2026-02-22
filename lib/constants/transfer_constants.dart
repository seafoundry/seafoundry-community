// @tier: community

/// Timeout constants for transfer-related operations.
///
/// Centralizes all timeout durations used in transfer dialogs and services
/// to ensure consistency and ease of adjustment.
class TransferTimeouts {
  const TransferTimeouts._();

  /// Timeout for loading organism selection data from repository.
  static const Duration selectionLoad = Duration(seconds: 12);

  /// Timeout for stream-based fallback when getAll() fails.
  static const Duration streamFallback = Duration(seconds: 5);

  /// Timeout for loading site data in transfer dialogs.
  static const Duration siteLoad = Duration(seconds: 12);

  /// Timeout for loading group data in transfer dialogs.
  static const Duration groupLoad = Duration(seconds: 12);
}
