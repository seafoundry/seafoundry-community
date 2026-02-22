// @tier: community
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/base_inventory_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';

/// Repository for CRUD operations on Subplot entities.
///
/// Subplots are the second level of subdivision in the outplant site hierarchy:
/// Site -> Zone -> Subplot -> Tag
///
/// Firestore collection path: organizations/{orgId}/subplots/{subplotId}
class SubplotRepository extends BaseInventoryRecordRepository<Subplot> {
  SubplotRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  }) : super(modelType: ModelType.subplot);

  // ---------------------------------------------------------------------------
  // CRUD Operations
  // ---------------------------------------------------------------------------

  /// Create a new subplot in Firestore.
  ///
  /// The [subplot] should be created with `Subplot.partial()` containing
  /// at minimum the required fields: zoneId, siteId, and name.
  Future<Subplot> create(Subplot subplot) async {
    try {
      final docRef = collectionRef.doc(subplot.id);
      await docRef.set(subplot.toJson());
      LoggingService.instance.debug(
        'SubplotRepository.create: created subplot ${subplot.id} in zone ${subplot.zoneId}',
      );
      return subplot;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.create: failed to create subplot ${subplot.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing subplot in Firestore.
  Future<Subplot> update(Subplot subplot) async {
    try {
      await updateRecord(subplot);
      LoggingService.instance.debug(
        'SubplotRepository.update: updated subplot ${subplot.id}',
      );
      return subplot;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.update: failed to update subplot ${subplot.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a subplot from Firestore.
  Future<void> delete(String subplotId) async {
    try {
      await collectionRef.doc(subplotId).delete();
      LoggingService.instance.debug(
        'SubplotRepository.delete: deleted subplot $subplotId',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.delete: failed to delete subplot $subplotId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a subplot by its ID.
  ///
  /// Returns null if the subplot does not exist.
  Future<Subplot?> getById(String subplotId) async {
    try {
      return await getRecordForId(subplotId);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.getById: failed to get subplot $subplotId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream a single subplot by its ID.
  ///
  /// Emits null if the subplot does not exist.
  Stream<Subplot?> streamById(String subplotId) {
    return collectionRef
        .doc(subplotId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data();
          if (data == null) return null;
          return RecordFactory.recordFromJson<Subplot>(data);
        })
        .handleError((error, stackTrace) {
          LoggingService.instance.error(
            'SubplotRepository.streamById: error streaming subplot $subplotId',
            error,
            stackTrace,
          );
        });
  }

  // ---------------------------------------------------------------------------
  // Query Methods - By Zone
  // ---------------------------------------------------------------------------

  /// Get all subplots for a specific zone.
  Future<List<Subplot>> getSubplotsForZone(String zoneId) async {
    try {
      final snapshot = await collectionRef
          .where('zoneId', isEqualTo: zoneId)
          .where('organizationId', isEqualTo: organization.id)
          .orderBy('sortOrder')
          .get();

      final subplots = <Subplot>[];
      for (final doc in snapshot.docs) {
        try {
          final subplot = RecordFactory.recordFromJson<Subplot>(doc.data());
          subplots.add(subplot);
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'SubplotRepository.getSubplotsForZone: failed to parse subplot ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
      return subplots;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.getSubplotsForZone: failed to get subplots for zone $zoneId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream all subplots for a specific zone.
  Stream<List<Subplot>> streamSubplotsForZone(String zoneId) {
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return collectionRef
        .where('zoneId', isEqualTo: zoneId)
        .where('organizationId', isEqualTo: organization.id)
        .snapshots()
        .map((snapshot) {
          final subplots = <Subplot>[];
          for (final doc in snapshot.docs) {
            try {
              final subplot = RecordFactory.recordFromJson<Subplot>(doc.data());
              subplots.add(subplot);
            } catch (e, stackTrace) {
              LoggingService.instance.error(
                'SubplotRepository.streamSubplotsForZone: failed to parse subplot ${doc.id}',
                e,
                stackTrace,
              );
            }
          }
          // Sort in-memory by sortOrder ascending
          subplots.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
          return subplots;
        })
        .handleError((error, stackTrace) {
          LoggingService.instance.error(
            'SubplotRepository.streamSubplotsForZone: error streaming subplots for zone $zoneId',
            error,
            stackTrace,
          );
        })
        .toBroadcastIfNeeded(StreamType.children);
  }

  // ---------------------------------------------------------------------------
  // Query Methods - By Site
  // ---------------------------------------------------------------------------

  /// Get all subplots for a specific site.
  ///
  /// Uses the denormalized siteId field for efficient querying without
  /// needing to join through zones.
  Future<List<Subplot>> getSubplotsForSite(String siteId) async {
    try {
      final snapshot = await collectionRef
          .where('siteId', isEqualTo: siteId)
          .where('organizationId', isEqualTo: organization.id)
          .orderBy('sortOrder')
          .get();

      final subplots = <Subplot>[];
      for (final doc in snapshot.docs) {
        try {
          final subplot = RecordFactory.recordFromJson<Subplot>(doc.data());
          subplots.add(subplot);
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'SubplotRepository.getSubplotsForSite: failed to parse subplot ${doc.id}',
            e,
            stackTrace,
          );
        }
      }
      return subplots;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.getSubplotsForSite: failed to get subplots for site $siteId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Stream all subplots for a specific site.
  ///
  /// Uses the denormalized siteId field for efficient querying without
  /// needing to join through zones.
  Stream<List<Subplot>> streamSubplotsForSite(String siteId) {
    // Avoid orderBy to prevent composite index requirements - sort in-memory
    return collectionRef
        .where('siteId', isEqualTo: siteId)
        .where('organizationId', isEqualTo: organization.id)
        .snapshots()
        .map((snapshot) {
          final subplots = <Subplot>[];
          for (final doc in snapshot.docs) {
            try {
              final subplot = RecordFactory.recordFromJson<Subplot>(doc.data());
              subplots.add(subplot);
            } catch (e, stackTrace) {
              LoggingService.instance.error(
                'SubplotRepository.streamSubplotsForSite: failed to parse subplot ${doc.id}',
                e,
                stackTrace,
              );
            }
          }
          // Sort in-memory by sortOrder ascending
          subplots.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
          return subplots;
        })
        .handleError((error, stackTrace) {
          LoggingService.instance.error(
            'SubplotRepository.streamSubplotsForSite: error streaming subplots for site $siteId',
            error,
            stackTrace,
          );
        })
        .toBroadcastIfNeeded(StreamType.children);
  }

  // ---------------------------------------------------------------------------
  // Batch Operations
  // ---------------------------------------------------------------------------

  /// Create multiple subplots in a single batch write.
  Future<List<Subplot>> createBatch(List<Subplot> subplots) async {
    if (subplots.isEmpty) return [];

    try {
      final batch = db.batch();
      for (final subplot in subplots) {
        batch.set(collectionRef.doc(subplot.id), subplot.toJson());
      }
      await batch.commit();
      LoggingService.instance.debug(
        'SubplotRepository.createBatch: created ${subplots.length} subplots',
      );
      return subplots;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.createBatch: failed to create ${subplots.length} subplots',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all subplots for a specific zone.
  ///
  /// Useful when deleting a zone and its children.
  Future<void> deleteSubplotsForZone(String zoneId) async {
    try {
      final snapshot = await collectionRef
          .where('zoneId', isEqualTo: zoneId)
          .where('organizationId', isEqualTo: organization.id)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      LoggingService.instance.debug(
        'SubplotRepository.deleteSubplotsForZone: deleted ${snapshot.docs.length} subplots for zone $zoneId',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'SubplotRepository.deleteSubplotsForZone: failed to delete subplots for zone $zoneId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
