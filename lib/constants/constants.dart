// @tier: community

// ---------------------------------------------------------------------------
// Schema constants: sentinel values and field defaults
// ---------------------------------------------------------------------------
const String unknownPhysicalFormId = 'unknown';
const String unknownPhysicalFormSizeBandId = 'unknown';
const String eventReasonField = 'reason';
const String taxonomySpeciesMorphologyField = 'morphology';
const String taxonomySpeciesTagsField = 'tags';
const String eslListedSpeciesTag = 'ESL listed';

// ---------------------------------------------------------------------------
// In-situ grid constants
// ---------------------------------------------------------------------------
const int kInSituMinDimension = 1;
const int kInSituMaxRows = 26;
const int kInSituMaxColumns = 50;

// ---------------------------------------------------------------------------
// Organization constants
// ---------------------------------------------------------------------------
const bool communityInvitationsEnabled = false;

// ---------------------------------------------------------------------------
// Transfer timeout constants
// ---------------------------------------------------------------------------

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
