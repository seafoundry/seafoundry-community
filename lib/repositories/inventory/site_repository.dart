import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/inventory_record_repository.dart';

class SiteRepository extends InventoryRecordRepository<Site> {
  SiteRepository({
    required super.organization,
    required super.user,
    required super.eventRepository,
    required super.snapshotService,
    required super.firestore,
    OrganismContext? organismContext,
    super.enforceAuth = true,
  }) : super(
         modelType: ModelType.site,
         organismContext:
             organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       );

  /// Persist updated geometry for a site while keeping legacy latitude/longitude
  /// fields in sync for downstream consumers that still rely on them.
  Future<Site> updateGeometry({
    required Site site,
    OutplantGeometry? geometry,
    bool updateLatLngFromGeometry = true,
    WriteBatch? batch,
  }) async {
    final now = DateTime.now().toIso8601String();
    OutplantGeometry? resolvedGeometry = geometry;
    if (resolvedGeometry != null) {
      resolvedGeometry = resolvedGeometry.copyWith(updatedAtIso: now);
    }

    GeoCoordinate? centroidCoordinate;
    if (resolvedGeometry != null) {
      centroidCoordinate = resolvedGeometry.centroid;
      if (centroidCoordinate == null &&
          resolvedGeometry.coordinates.isNotEmpty) {
        centroidCoordinate = resolvedGeometry.coordinates.first;
      }
    }

    final double? targetLatitude =
        updateLatLngFromGeometry && centroidCoordinate != null
        ? centroidCoordinate.latitude
        : site.latitude;
    final double? targetLongitude =
        updateLatLngFromGeometry && centroidCoordinate != null
        ? centroidCoordinate.longitude
        : site.longitude;

    final updatedSite = site.copyWith(
      geometry: resolvedGeometry,
      clearGeometry: resolvedGeometry == null,
      latitude: targetLatitude,
      longitude: targetLongitude,
      updatedAt: now,
      updatedById: user.id,
    );

    await updateRecord(updatedSite, batch: batch);
    return updatedSite;
  }

  Future<Site> clearGeometry({required Site site, WriteBatch? batch}) {
    return updateGeometry(
      site: site,
      geometry: null,
      updateLatLngFromGeometry: false,
      batch: batch,
    );
  }

  Future<Site> updateGridDimensions({
    required Site site,
    required int rowCount,
    required int colCount,
    WriteBatch? batch,
  }) async {
    final clampedRows = rowCount
        .clamp(kInSituMinDimension, kInSituMaxRows)
        .toInt();
    final clampedCols = colCount
        .clamp(kInSituMinDimension, kInSituMaxColumns)
        .toInt();
    final now = DateTime.now().toIso8601String();
    final updatedSite = site.copyWith(
      rowCount: clampedRows,
      colCount: clampedCols,
      updatedAt: now,
      updatedById: user.id,
    );
    await updateRecord(updatedSite, batch: batch);
    return updatedSite;
  }

  /// Update a site record and create a correction event documenting the changes
  ///
  /// Computes field-level diffs between original and updated records,
  /// persists the update, and creates a CorrectionEvent with EventType.inventoryRecordCorrection.
  Future<Site> updateSiteWithCorrection({
    required Site originalSite,
    required Site updatedSite,
    String? notes,
  }) async {
    // Compute changes map
    final changes = _computeSiteChanges(originalSite, updatedSite);

    // Update the record
    await updateRecord(updatedSite);

    // Create correction event if there are actual changes
    if (changes.isNotEmpty) {
      final event = await eventRepository.createInventoryRecordCorrectionEvent(
        originalRecord: originalSite,
        updatedRecord: updatedSite,
        changes: changes,
        notes: notes,
      );

      await snapshotService.createAfterSnapshot(
        record: updatedSite,
        eventId: event.id,
      );
    }

    return updatedSite;
  }

  /// Compute field-level changes between two site records
  Map<String, dynamic> _computeSiteChanges(Site original, Site updated) {
    final changes = <String, dynamic>{};

    if (original.name != updated.name) {
      changes['name'] = {'from': original.name, 'to': updated.name};
    }
    if (!const DeepCollectionEquality()
        .equals(
          original.supportedOrganismKinds,
          updated.supportedOrganismKinds,
        )) {
      changes['supportedOrganismKinds'] = {
        'from': original.supportedOrganismKinds
            .map((kind) => kind.name)
            .toList(),
        'to': updated.supportedOrganismKinds
            .map((kind) => kind.name)
            .toList(),
      };
    }
    if (original.siteTypeId != updated.siteTypeId) {
      changes['siteTypeId'] = {
        'from': original.siteTypeId,
        'to': updated.siteTypeId,
      };
    }
    if (original.description != updated.description) {
      changes['description'] = {
        'from': original.description,
        'to': updated.description,
      };
    }
    if (original.latitude != updated.latitude) {
      changes['latitude'] = {'from': original.latitude, 'to': updated.latitude};
    }
    if (original.longitude != updated.longitude) {
      changes['longitude'] = {
        'from': original.longitude,
        'to': updated.longitude,
      };
    }
    if (original.rowCount != updated.rowCount) {
      changes['rowCount'] = {'from': original.rowCount, 'to': updated.rowCount};
    }
    if (original.colCount != updated.colCount) {
      changes['colCount'] = {'from': original.colCount, 'to': updated.colCount};
    }
    // Compare geometry - simplified to compare JSON strings
    final originalGeometryJson = original.geometry?.toJson().toString();
    final updatedGeometryJson = updated.geometry?.toJson().toString();
    if (originalGeometryJson != updatedGeometryJson) {
      changes['geometry'] = {
        'from': originalGeometryJson,
        'to': updatedGeometryJson,
      };
    }

    return changes;
  }

  /// Find a site by name using case-insensitive matching.
  ///
  /// Returns the first matching site or null if not found.
  /// Uses an in-memory filter on the current snapshot for efficiency.
  Future<Site?> findByName(String name) async {
    if (name.trim().isEmpty) return null;

    final normalizedName = name.trim().toLowerCase();

    // Use current snapshot from the stream for efficiency
    final sites = await streamAll.first;
    return sites.firstWhereOrNull(
      (site) => site.name.toLowerCase() == normalizedName,
    );
  }
}
