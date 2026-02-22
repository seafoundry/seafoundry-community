// @tier: community

/// Type of structure to create in the unified structure dialog.
///
/// Used by [StructureDialog.show] to determine which creation flow to display.
enum StructureType {
  /// Create a new site under the organization.
  site,

  /// Create a new group under a site or parent group.
  group,
}
