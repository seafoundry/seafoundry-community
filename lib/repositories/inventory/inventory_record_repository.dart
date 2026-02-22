// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/services.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/base_inventory_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';

abstract class InventoryRecordRepository<T extends InventoryRecord>
    extends BaseInventoryRecordRepository<T> {
  InventoryRecordRepository({
    required super.modelType,
    required super.organization,
    required super.user,
    required this.eventRepository,
    this.enforceAuth = true,
    SnapshotService? snapshotService,
    required super.firestore,
    super.organismContext,
  }) : snapshotService =
           snapshotService ?? SnapshotService(firestore: firestore);

  final EventRepository eventRepository;
  final SnapshotService snapshotService;
  final bool enforceAuth;

  Future<T> createRecord(
    T partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  }) async {
    if (enforceAuth) {
      String? authUid;
      var authAvailable = true;
      try {
        authUid = fbAuth.FirebaseAuth.instance.currentUser?.uid;
      } on PlatformException catch (e) {
        authAvailable = false;
        LoggingService.instance.warning(
          'InventoryRecordRepository.createRecord: FirebaseAuth unavailable; '
          'skipping auth guard.',
          e,
        );
      }
      if (authAvailable) {
        if (authUid == null) {
          throw RepositoryError(
            message: 'You are not signed in. Please sign in and try again.',
            recoverySuggestion: 'Sign out and sign back in to continue.',
            context: {
              'userId': user.id,
              'userEmail': user.email,
            },
          );
        }
        if (authUid != user.id) {
          throw RepositoryError(
            message:
                'Your account session is out of sync. Please sign in again.',
            recoverySuggestion:
                'Sign out and sign back in to refresh your session.',
            context: {
              'userId': user.id,
              'authUid': authUid,
            },
          );
        }
      }
    }

    final batch = db.batch();
    final String recordId = generateId(firestore: db);
    final String recordSlug = await nextSlugForModelType(modelType);

    final urlPath = '${parent.urlPath}/$recordSlug';
    final internalPath = '${parent.internalPath}/$recordId';

    // For OrganismRecord, extract siteId and groupId from the parent path
    T fullRecord =
        partialRecord.copyWith(
              id: recordId,
              slug: recordSlug,
              urlPath: urlPath,
              internalPath: internalPath,
              organizationId: organization.id,
              createdById: user.id,
              updatedById: user.id,
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            )
            as T;

    // Special handling for OrganismRecord to set siteId and groupId
    if (fullRecord is OrganismRecord && parent is Group) {
      // Use the parent group's siteId and groupId directly
      fullRecord =
          fullRecord.copyWith(siteId: parent.siteId, groupId: parent.id) as T;
    }

    // Special handling for Group to set siteId and parentId from parent
    if (fullRecord is Group) {
      if (parent is Site) {
        fullRecord = fullRecord.copyWith(
          siteId: parent.id,
          parentId: parent.id,
        ) as T;
      } else if (parent is Group) {
        fullRecord = fullRecord.copyWith(
          siteId: parent.siteId,
          parentId: parent.id,
        ) as T;
      }
    }

    final createEvent = await eventRepository.addCreateEvent(
      fullRecord,
      parent,
      batch,
      base: base,
    );

    if (!fullRecord.validate()) {
      throw RepositoryError(
        message: 'Record is not valid: ${fullRecord.toJson()}',
      );
    }

    batch.set(collectionRef.doc(recordId), fullRecord.toJson());

    try {
      await batch.commit();
      LoggingService.instance.debug('InventoryRecordRepository.createRecord: batch commit succeeded!');
    } catch (e, stackTrace) {
      LoggingService.instance.error('InventoryRecordRepository.createRecord: batch commit FAILED!', e, stackTrace);
      rethrow;
    }

    await snapshotService.createAfterSnapshot(
      record: fullRecord,
      eventId: createEvent.id,
    );

    return fullRecord;
  }

  Future<T> moveRecord({
    required T record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    PartialMoveSelection? partialSelection,
    String? moveReason,
    EventBaseParams base = const EventBaseParams(),
  }) async {
    final now = DateTime.now().toIso8601String();

    // Detect if this is a partial move that requires splitting
    final isPartialMove = _shouldSplitOrganism(record, partialSelection);

    if (isPartialMove && record is OrganismRecord) {
      return await _handlePartialMove(
            record: record as OrganismRecord,
            fromParent: fromParent,
            toParent: toParent,
            transaction: transaction,
            partialSelection: partialSelection!,
            moveReason: moveReason,
            base: base,
            now: now,
          )
          as T;
    }

    // ... existing full-move logic continues ...
    T movedRecord;

    if (record is OrganismRecord && toParent is Group) {
      movedRecord =
          record.copyWith(
                urlPath: '${toParent.urlPath}/${record.slug}',
                internalPath: '${toParent.internalPath}/${record.id}',
                groupId: toParent.id,
                siteId: toParent.siteId,
                updatedAt: now,
                updatedById: user.id,
              )
              as T;
    } else if (record is Group) {
      String parentId = record.parentId;
      String siteId = record.siteId;

      if (toParent is Group) {
        parentId = toParent.id;
        siteId = toParent.siteId;
      } else if (toParent is Site) {
        parentId = toParent.id;
        siteId = toParent.id;
      } else if (toParent is Organization) {
        parentId = toParent.id;
      }

      movedRecord =
          record.copyWith(
                urlPath: '${toParent.urlPath}/${record.slug}',
                internalPath: '${toParent.internalPath}/${record.id}',
                parentId: parentId,
                siteId: siteId,
                updatedAt: now,
                updatedById: user.id,
              )
              as T;
    } else {
      movedRecord =
          record.copyWith(
                urlPath: '${toParent.urlPath}/${record.slug}',
                internalPath: '${toParent.internalPath}/${record.id}',
                updatedAt: now,
                updatedById: user.id,
              )
              as T;
    }
    transaction.set(collectionRef.doc(record.id), movedRecord.toJson());

    // Create MoveOutEvent FIRST using the OLD record (before move)
    await eventRepository.createMoveOutEvent(
      record,
      fromParent,
      toParent,
      transaction,
      quantity: partialSelection?.partialQuantities[record.id],
      moveReason: moveReason,
      base: base,
    );
    // Create MoveInEvent SECOND using the NEW record (after move)
    await eventRepository.createMoveInEvent(
      movedRecord,
      fromParent,
      toParent,
      transaction,
      quantity: partialSelection?.partialQuantities[record.id],
      moveReason: moveReason,
      base: base,
    );

    return movedRecord;
  }

  /// Check if this move requires organism splitting
  bool _shouldSplitOrganism(T record, PartialMoveSelection? partialSelection) {
    if (partialSelection == null || partialSelection.moveAll) return false;
    if (record is! OrganismRecord) return false;

    final requestedQty = partialSelection.partialQuantities[record.id];
    if (requestedQty == null || requestedQty <= 0) return false;

    final totalQty = record.measurement.value.toInt();
    return requestedQty < totalQty;
  }

  /// Handle partial organism move by splitting
  Future<OrganismRecord> _handlePartialMove({
    required OrganismRecord record,
    required GraphNodeRecord fromParent,
    required GraphNodeRecord toParent,
    required Transaction transaction,
    required PartialMoveSelection partialSelection,
    String? moveReason,
    required EventBaseParams base,
    required String now,
  }) async {
    final requestedQty = partialSelection.partialQuantities[record.id]!;
    final totalQty = record.measurement.value.toInt();
    final remainingQty = totalQty - requestedQty;

    // Generate new ID for split organism
    final newOrganismId = generateId(firestore: db);
    final newSlug = await nextSlugForModelType(modelType);

    // Determine groupId and siteId based on toParent type
    String groupId;
    String siteId;
    if (toParent is Group) {
      groupId = toParent.id;
      siteId = toParent.siteId;
    } else {
      // Fallback to record's current values if toParent is not a Group
      groupId = record.groupId ?? '';
      siteId = record.siteId ?? '';
    }

    // Create new organism at destination with moved quantity
    final newOrganism = record.copyWith(
      id: newOrganismId,
      slug: newSlug,
      urlPath: '${toParent.urlPath}/$newSlug',
      internalPath: '${toParent.internalPath}/$newOrganismId',
      groupId: groupId,
      siteId: siteId,
      measurement: record.measurement.copyWith(value: requestedQty.toDouble()),
      createdAt: now,
      updatedAt: now,
      createdById: user.id,
      updatedById: user.id,
      metadata: {
        ...?record.metadata,
        'sourceOrganismId': record.id,
        'splitFromAt': now,
      },
    );

    // Update source organism (reduce quantity)
    final reducedSource = record.copyWith(
      measurement: record.measurement.copyWith(value: remainingQty.toDouble()),
      updatedAt: now,
      updatedById: user.id,
    );

    // Write both to transaction
    transaction.set(collectionRef.doc(newOrganismId), newOrganism.toJson());
    transaction.update(collectionRef.doc(record.id), reducedSource.toJson());

    // Create events
    await eventRepository.createMoveOutEvent(
      record, // Original record (old path)
      fromParent,
      toParent,
      transaction,
      quantity: requestedQty,
      moveReason: moveReason,
      base: base,
    );

    await eventRepository.createMoveInEvent(
      newOrganism, // New organism (new path)
      fromParent,
      toParent,
      transaction,
      quantity: requestedQty,
      moveReason: moveReason,
      base: base,
    );

    return newOrganism;
  }
}
