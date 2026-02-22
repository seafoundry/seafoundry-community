// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/base_inventory_record_repository.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for Zone CRUD operations.
///
/// Zones are part of the outplant hierarchy: Site -> Zone -> Subplot -> Tag
/// Collection path: organizations/{orgId}/zones/{zoneId}
class ZoneRepository extends BaseInventoryRecordRepository<Zone> {
  ZoneRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    OrganismContext? organismContext,
  }) : super(
          modelType: ModelType.zone,
          organismContext:
              organismContext ?? OrganismContext.forKind(OrganismKind.coral),
        ) {
    // Override collection reference to use nested path under organization
    collectionRef = FirestoreCollectionResolver.instance.subcollection(
      db,
      ModelType.organization.collectionPath,
      organization.id,
      modelType.collectionPath,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD Operations
  // ---------------------------------------------------------------------------

  /// Create a new zone.
  ///
  /// The zone should have at minimum [siteId] and [name] set.
  /// Fields like [id], [slug], [urlPath], timestamps, etc. will be generated.
  Future<Zone> create(Zone partialZone, {WriteBatch? batch}) async {
    final now = DateTime.now().toIso8601String();
    final zoneId = db.collection('zones').doc().id;
    final slug = await nextSlugForModelType(modelType);

    // Fetch parent site to build urlPath and internalPath
    final siteDoc = await FirestoreCollectionResolver.instance
        .subcollection(
          db,
          ModelType.organization.collectionPath,
          organization.id,
          ModelType.site.collectionPath,
        )
        .doc(partialZone.siteId)
        .get();

    String urlPath;
    String internalPath;

    if (siteDoc.exists) {
      final siteData = siteDoc.data();
      final siteUrlPath = siteData?['urlPath'] as String? ?? '';
      final siteInternalPath = siteData?['internalPath'] as String? ?? '';
      urlPath = '$siteUrlPath/$slug';
      internalPath = '$siteInternalPath/$zoneId';
    } else {
      // Fallback: construct paths from organization
      urlPath = '${organization.slug}/$slug';
      internalPath = '${organization.id}/$zoneId';
    }

    final zone = Zone(
      id: zoneId,
      createdAt: now,
      createdById: user.id,
      updatedAt: now,
      updatedById: user.id,
      organizationId: organization.id,
      urlPath: urlPath,
      internalPath: internalPath,
      slug: slug,
      siteId: partialZone.siteId,
      name: partialZone.name,
      description: partialZone.description,
      centroid: partialZone.centroid,
      boundary: partialZone.boundary,
      sortOrder: partialZone.sortOrder,
      metadata: partialZone.metadata,
    );

    if (batch != null) {
      batch.set(collectionRef.doc(zoneId), zone.toJson());
    } else {
      await collectionRef.doc(zoneId).set(zone.toJson());
    }

    LoggingService.instance.debug(
      'ZoneRepository.create: created zone ${zone.id} (${zone.name}) for site ${zone.siteId}',
    );

    return zone;
  }

  /// Update an existing zone.
  Future<Zone> update(Zone zone, {WriteBatch? batch}) async {
    final now = DateTime.now().toIso8601String();
    final updatedZone = zone.copyWith(
      updatedAt: now,
      updatedById: user.id,
    );

    if (batch != null) {
      batch.update(collectionRef.doc(zone.id), updatedZone.toJson());
    } else {
      await collectionRef.doc(zone.id).update(updatedZone.toJson());
    }

    LoggingService.instance.debug(
      'ZoneRepository.update: updated zone ${zone.id} (${zone.name})',
    );

    return updatedZone;
  }

  /// Delete a zone by ID.
  Future<void> delete(String zoneId, {WriteBatch? batch}) async {
    if (batch != null) {
      batch.delete(collectionRef.doc(zoneId));
    } else {
      await collectionRef.doc(zoneId).delete();
    }

    LoggingService.instance.debug(
      'ZoneRepository.delete: deleted zone $zoneId',
    );
  }

  /// Get a zone by ID.
  ///
  /// Returns null if the zone does not exist.
  Future<Zone?> getById(String zoneId) async {
    return getRecordForId(zoneId);
  }

  /// Stream a zone by ID.
  ///
  /// Emits null if the zone does not exist.
  Stream<Zone?> streamById(String zoneId) {
    return collectionRef.doc(zoneId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      try {
        return Zone.fromJson(data);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'ZoneRepository.streamById: failed to parse zone $zoneId',
          e,
          stackTrace,
        );
        return null;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Query Methods
  // ---------------------------------------------------------------------------

  /// Get all zones for a site.
  Future<List<Zone>> getZonesForSite(String siteId) async {
    try {
      final snapshot = await collectionRef
          .where('organizationId', isEqualTo: organization.id)
          .where('siteId', isEqualTo: siteId)
          .get();

      final zones = <Zone>[];
      for (final doc in snapshot.docs) {
        try {
          zones.add(Zone.fromJson(doc.data()));
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'ZoneRepository.getZonesForSite: failed to parse zone ${doc.id}',
            e,
            stackTrace,
          );
        }
      }

      // Sort by sortOrder if present, otherwise by name
      zones.sort((a, b) {
        if (a.sortOrder != null && b.sortOrder != null) {
          return a.sortOrder!.compareTo(b.sortOrder!);
        }
        if (a.sortOrder != null) return -1;
        if (b.sortOrder != null) return 1;
        return a.name.compareTo(b.name);
      });

      return zones;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'ZoneRepository.getZonesForSite: failed to fetch zones for site $siteId',
        e,
        stackTrace,
      );
      return [];
    }
  }

  /// Stream all zones for a site.
  Stream<List<Zone>> streamZonesForSite(String siteId) {
    return collectionRef
        .where('organizationId', isEqualTo: organization.id)
        .where('siteId', isEqualTo: siteId)
        .snapshots()
        .map((snapshot) {
      final zones = <Zone>[];
      for (final doc in snapshot.docs) {
        try {
          zones.add(Zone.fromJson(doc.data()));
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'ZoneRepository.streamZonesForSite: failed to parse zone ${doc.id}',
            e,
            stackTrace,
          );
        }
      }

      // Sort by sortOrder if present, otherwise by name
      zones.sort((a, b) {
        if (a.sortOrder != null && b.sortOrder != null) {
          return a.sortOrder!.compareTo(b.sortOrder!);
        }
        if (a.sortOrder != null) return -1;
        if (b.sortOrder != null) return 1;
        return a.name.compareTo(b.name);
      });

      return zones;
    });
  }

  /// Get zones by their IDs.
  Future<List<Zone>> getZonesByIds(List<String> zoneIds) async {
    if (zoneIds.isEmpty) return [];

    // Firestore whereIn has a limit of 10 items, so batch if needed
    final zones = <Zone>[];
    for (var i = 0; i < zoneIds.length; i += 10) {
      final batch = zoneIds.skip(i).take(10).toList();
      final snapshot = await collectionRef
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        try {
          zones.add(Zone.fromJson(doc.data()));
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'ZoneRepository.getZonesByIds: failed to parse zone ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
    }

    return zones;
  }

  /// Update a zone record and create a correction event documenting the changes.
  ///
  /// This is a simplified version - if you need full event tracking,
  /// consider extending InventoryRecordRepository instead.
  Future<Zone> updateZoneWithCorrection({
    required Zone originalZone,
    required Zone updatedZone,
    String? notes,
  }) async {
    // Compute changes map
    final changes = _computeZoneChanges(originalZone, updatedZone);

    // Update the record
    final result = await update(updatedZone);

    // Log changes if any
    if (changes.isNotEmpty) {
      LoggingService.instance.info(
        'ZoneRepository.updateZoneWithCorrection: zone ${updatedZone.id} updated',
        {'changes': changes, 'notes': notes},
      );
    }

    return result;
  }

  /// Compute field-level changes between two zone records.
  Map<String, dynamic> _computeZoneChanges(Zone original, Zone updated) {
    final changes = <String, dynamic>{};

    if (original.name != updated.name) {
      changes['name'] = {'from': original.name, 'to': updated.name};
    }
    if (original.description != updated.description) {
      changes['description'] = {
        'from': original.description,
        'to': updated.description,
      };
    }
    if (original.sortOrder != updated.sortOrder) {
      changes['sortOrder'] = {
        'from': original.sortOrder,
        'to': updated.sortOrder,
      };
    }
    // Compare centroid
    final originalCentroidJson = original.centroid?.toJson().toString();
    final updatedCentroidJson = updated.centroid?.toJson().toString();
    if (originalCentroidJson != updatedCentroidJson) {
      changes['centroid'] = {
        'from': originalCentroidJson,
        'to': updatedCentroidJson,
      };
    }
    // Compare boundary
    final originalBoundaryJson =
        original.boundary?.map((c) => c.toJson()).toList().toString();
    final updatedBoundaryJson =
        updated.boundary?.map((c) => c.toJson()).toList().toString();
    if (originalBoundaryJson != updatedBoundaryJson) {
      changes['boundary'] = {
        'from': originalBoundaryJson,
        'to': updatedBoundaryJson,
      };
    }

    return changes;
  }
}
