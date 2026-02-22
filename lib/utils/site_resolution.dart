// @tier: community
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/site.dart';

/// Extension for resolving site IDs from inventory records.
///
/// This provides a unified way to extract the site ID from different record
/// types that have a site association:
/// - [Site]: Returns its own ID
/// - [Group]: Returns its siteId field
/// - [OrganismRecord]: Returns its siteId field (nullable)
///
/// Used by dialogs that need to display site-scoped data (e.g., holdings
/// panels) regardless of the record type being operated on.
extension SiteResolution on InventoryRecord {
  /// Returns the site ID associated with this record.
  ///
  /// For [Site], returns the record's own ID.
  /// For [Group], returns the siteId field.
  /// For [OrganismRecord], returns the siteId field (may be null).
  /// For other record types, returns null.
  String? get resolvedSiteId {
    final record = this;
    if (record is Site) return record.id;
    if (record is Group) return record.siteId;
    if (record is OrganismRecord) return record.siteId;
    return null;
  }
}

/// Resolves site ID from a dynamic record value.
///
/// This standalone function handles dynamic typing scenarios where the
/// record type isn't statically known at compile time (e.g., when
/// accessing records from GraphNode state).
///
/// Returns null if the record is not a recognized type with site association.
String? resolveSiteIdFromRecord(dynamic record) {
  if (record is Site) return record.id;
  if (record is Group) return record.siteId;
  if (record is OrganismRecord) return record.siteId;
  return null;
}
