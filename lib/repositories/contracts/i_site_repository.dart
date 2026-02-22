// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';

/// Interface contract for SiteRepository.
///
/// This mirrors the concrete repository API used in production so concrete
/// repositories can implement it and tests can mock it.
abstract class ISiteRepository {
  /// Stream all sites for the organization.
  Stream<List<Site>> get streamAll;

  /// Stream sites for a URL path using client-side filtering.
  Stream<List<Site>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Stream a single site for a URL path.
  Stream<Site?> streamRecordForUrlPath(String urlPath);

  /// Get all sites.
  Future<List<Site>> getAll();

  /// Get a single site by ID.
  Future<Site?> getRecordForId(String id);

  /// Get sites for a URL path.
  Future<List<Site>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  });

  /// Create a new site.
  Future<Site> createRecord(
    Site partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  });

  /// Move a site between parents.
  Future<Site> moveRecord({
    required Site record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  });

  /// Update an existing site.
  Future<void> updateRecord(Site record, {WriteBatch? batch});

  /// Delete a site.
  Future<void> deleteRecord(Site record, {WriteBatch? batch});

  /// Persist updated geometry for a site.
  Future<Site> updateGeometry({
    required Site site,
    OutplantGeometry? geometry,
    bool updateLatLngFromGeometry = true,
    WriteBatch? batch,
  });

  /// Clear geometry for a site.
  Future<Site> clearGeometry({required Site site, WriteBatch? batch});

  /// Update in-situ grid dimensions for a site.
  Future<Site> updateGridDimensions({
    required Site site,
    required int rowCount,
    required int colCount,
    WriteBatch? batch,
  });

  /// Update a site and emit correction events for changes.
  Future<Site> updateSiteWithCorrection({
    required Site originalSite,
    required Site updatedSite,
    String? notes,
  });

  /// Find a site by name using case-insensitive matching.
  ///
  /// Returns the first matching site or null if not found.
  Future<Site?> findByName(String name);
}
