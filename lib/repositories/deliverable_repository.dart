// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing deliverable records
class DeliverableRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver =
      FirestoreCollectionResolver.instance;

  DeliverableRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  }) : _firestore = firestore,
       _logger = logger ?? LoggingService.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _resolver.collection(_firestore, ModelType.deliverable.collectionPath);

  /// Watch deliverables for an organization
  Stream<List<Deliverable>> watchDeliverablesForOrg(String orgId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .snapshots()
          .map((snapshot) {
            final deliverables = <Deliverable>[];
            for (final doc in snapshot.docs) {
              final deliverable = _parseDeliverable(doc);
              if (deliverable != null) {
                deliverables.add(deliverable);
              }
            }
            // Sort by dueDate ascending (soonest first)
            deliverables.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return deliverables;
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch deliverables for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Watch deliverables for a specific permit
  Stream<List<Deliverable>> watchDeliverablesForPermit(String permitId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('permitId', isEqualTo: permitId)
          .snapshots()
          .map((snapshot) {
            final deliverables = <Deliverable>[];
            for (final doc in snapshot.docs) {
              final deliverable = _parseDeliverable(doc);
              if (deliverable != null) {
                deliverables.add(deliverable);
              }
            }
            // Sort by dueDate ascending (soonest first)
            deliverables.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return deliverables;
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch deliverables for permit $permitId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get deliverables by permit ID
  Future<List<Deliverable>> findByPermit(String permitId) async {
    try {
      final snapshot = await _collection
          .where('permitId', isEqualTo: permitId)
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find deliverables by permit $permitId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get deliverables by funder ID
  ///
  /// Returns deliverables where the funderIds array contains the given funderId.
  Future<List<Deliverable>> findByFunder(String orgId, String funderId) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('funderIds', arrayContains: funderId)
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find deliverables by funder $funderId in org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Watch deliverables for a specific funder
  Stream<List<Deliverable>> watchByFunder(String orgId, String funderId) {
    try {
      // Avoid orderBy to prevent composite index requirements - sort in-memory
      return _collection
          .where('organizationId', isEqualTo: orgId)
          .where('funderIds', arrayContains: funderId)
          .snapshots()
          .map((snapshot) {
            final deliverables = <Deliverable>[];
            for (final doc in snapshot.docs) {
              final deliverable = _parseDeliverable(doc);
              if (deliverable != null) {
                deliverables.add(deliverable);
              }
            }
            // Sort by dueDate ascending (soonest first)
            deliverables.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return deliverables;
          });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to watch deliverables by funder $funderId in org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get deliverables by site ID
  Future<List<Deliverable>> findBySite(String orgId, String siteId) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('requiredSiteIds', arrayContains: siteId)
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find deliverables by site $siteId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get upcoming deliverables (due within specified days)
  Future<List<Deliverable>> getUpcomingDeliverables(
    String orgId, {
    int daysAhead = 30,
  }) async {
    try {
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: daysAhead));

      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('dueDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('dueDate', isLessThanOrEqualTo: futureDate.toIso8601String())
          .where('statusId', whereNotIn: [DeliverableStatus.completed.id])
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get upcoming deliverables for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get overdue deliverables
  Future<List<Deliverable>> getOverdueDeliverables(String orgId) async {
    try {
      final now = DateTime.now();

      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('dueDate', isLessThan: now.toIso8601String())
          .where('statusId', whereNotIn: [DeliverableStatus.completed.id])
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get overdue deliverables for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get deliverables by status
  Future<List<Deliverable>> getDeliverablesByStatus(
    String orgId,
    DeliverableStatus status, {
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _collection
          .where('organizationId', isEqualTo: orgId)
          .where('statusId', isEqualTo: status.id)
          .orderBy('dueDate', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final deliverables = <Deliverable>[];

      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get deliverables by status ${status.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all active (non-completed) deliverables for an organization.
  ///
  /// This returns all deliverables in the organization regardless of their
  /// requiredSiteIds configuration. Use this when you want to show all
  /// available deliverables for selection (e.g., in outplanting dialogs).
  ///
  /// Results are ordered by dueDate ascending.
  Future<List<Deliverable>> getActiveDeliverablesForOrganization(
    String orgId,
  ) async {
    try {
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .orderBy('dueDate', descending: false)
          .get();

      final deliverables = <Deliverable>[];
      for (final doc in snapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        // Filter out completed deliverables (only return active ones)
        if (deliverable != null && !deliverable.status.isCompleted) {
          deliverables.add(deliverable);
        }
      }
      return deliverables;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active deliverables for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get a deliverable by ID
  Future<Deliverable?> getDeliverableById(String deliverableId) async {
    try {
      final doc = await _collection.doc(deliverableId).get();
      if (!doc.exists) return null;

      return _parseDeliverable(doc);
    } catch (e, stackTrace) {
      _logger.error('Failed to get deliverable $deliverableId', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new deliverable
  Future<String> createDeliverable(Deliverable deliverable) async {
    try {
      final needsId = deliverable.id.isEmpty || deliverable.id == '__missing__';
      final docRef = needsId
          ? _collection.doc()
          : _collection.doc(deliverable.id);
      final deliverableToSave = needsId
          ? deliverable.copyWith(id: docRef.id)
          : deliverable;

      if (!deliverableToSave.validate()) {
        throw ArgumentError('Invalid deliverable data');
      }

      final jsonPayload = deliverableToSave.toJson();
      _logger.debug(
        'DeliverableRepository: Writing to ${docRef.path} with '
        'organizationId=${deliverableToSave.organizationId}',
      );

      await docRef.set(jsonPayload);
      _logger.debug('DeliverableRepository: Write succeeded');
      return docRef.id;
    } catch (e, stackTrace) {
      _logger.error('Failed to create deliverable', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing deliverable
  Future<void> updateDeliverable(Deliverable deliverable) async {
    try {
      if (!deliverable.validate()) {
        throw ArgumentError('Invalid deliverable data');
      }

      await _collection.doc(deliverable.id).update(deliverable.toJson());
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update deliverable ${deliverable.id}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a deliverable
  Future<void> deleteDeliverable(String deliverableId) async {
    try {
      await _collection.doc(deliverableId).delete();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete deliverable $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update deliverable status
  Future<void> updateDeliverableStatus(
    String deliverableId,
    DeliverableStatus status,
  ) async {
    try {
      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> updateData = {
        'statusId': status.id,
        'updatedAt': now,
      };

      // If marking as completed, set completedAt and progress
      if (status.isCompleted) {
        updateData['completedAt'] = now;
        updateData['progressPercent'] = 100.0;
      }

      await _collection.doc(deliverableId).update(updateData);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update deliverable status for $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Update deliverable progress
  Future<void> updateDeliverableProgress(
    String deliverableId,
    double progressPercent,
  ) async {
    try {
      if (progressPercent < 0.0 || progressPercent > 100.0) {
        throw ArgumentError('Progress must be between 0 and 100');
      }

      await _collection.doc(deliverableId).update({
        'progressPercent': progressPercent,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update deliverable progress for $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Mark a report as generated for this deliverable
  ///
  /// Updates the lastReportGeneratedAt timestamp to the current time.
  Future<void> markReportGenerated(String deliverableId) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _collection.doc(deliverableId).update({
        'lastReportGeneratedAt': now,
        'updatedAt': now,
      });
      _logger.info('Marked report generated for deliverable $deliverableId');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark report generated for $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Add a required site to a deliverable
  Future<void> addRequiredSite(String deliverableId, String siteId) async {
    try {
      final deliverable = await getDeliverableById(deliverableId);
      if (deliverable == null) {
        throw StateError('Deliverable $deliverableId not found');
      }

      if (deliverable.requiredSiteIds.contains(siteId)) {
        return; // Site already required
      }

      await _collection.doc(deliverableId).update({
        'requiredSiteIds': FieldValue.arrayUnion([siteId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add required site $siteId to deliverable $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove a required site from a deliverable
  Future<void> removeRequiredSite(String deliverableId, String siteId) async {
    try {
      await _collection.doc(deliverableId).update({
        'requiredSiteIds': FieldValue.arrayRemove([siteId]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to remove required site $siteId from deliverable $deliverableId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Gets deliverables applicable to a specific outplant site.
  ///
  /// Returns deliverables where:
  /// - requiredSiteIds is empty (applies to all sites), OR
  /// - requiredSiteIds contains the given siteId
  /// - status is not 'completed' (we only want active deliverables)
  ///
  /// Results are ordered by dueDate ascending.
  Future<List<Deliverable>> getDeliverablesForOutplantSite(
    String orgId,
    String siteId,
  ) async {
    try {
      // Firestore doesn't support OR queries, so we need two separate queries:
      // 1. Deliverables with empty requiredSiteIds (applies to all sites)
      // 2. Deliverables where requiredSiteIds contains this siteId

      // Query 1: Get deliverables where requiredSiteIds is empty
      // Note: Firestore doesn't have a direct "array is empty" query,
      // so we filter in memory after fetching all org deliverables
      final allOrgSnapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .get();

      // Query 2: Get deliverables where requiredSiteIds contains siteId
      final siteSpecificSnapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('requiredSiteIds', arrayContains: siteId)
          .get();

      // Combine results using a Map to deduplicate by ID
      final deliverableMap = <String, Deliverable>{};

      // Process all org deliverables, filtering for empty requiredSiteIds
      for (final doc in allOrgSnapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null &&
            deliverable.requiredSiteIds.isEmpty &&
            !deliverable.status.isCompleted) {
          deliverableMap[deliverable.id] = deliverable;
        }
      }

      // Add site-specific deliverables (may overlap, but Map handles dedup)
      for (final doc in siteSpecificSnapshot.docs) {
        final deliverable = _parseDeliverable(doc);
        if (deliverable != null && !deliverable.status.isCompleted) {
          deliverableMap[deliverable.id] = deliverable;
        }
      }

      // Convert to list and sort by dueDate ascending
      final result = deliverableMap.values.toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get deliverables for site $siteId in org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Deliverable? _parseDeliverable(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      _logger.warning(
        'Deliverable ${doc.id} exists but has null data; skipping parse',
        {'docId': doc.id},
      );
      return null;
    }
    try {
      data['id'] = doc.id;
      return Deliverable.fromJson(data);
    } catch (e, stackTrace) {
      _logger.error('Failed to parse deliverable ${doc.id}', e, stackTrace);
      return null;
    }
  }

}
