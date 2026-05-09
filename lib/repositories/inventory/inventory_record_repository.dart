import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/auth_error_suppression_mixin.dart';
import 'package:seafoundry_app/services/firestore_recovery_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/snapshot_service.dart';
import 'package:seafoundry_app/services/url_path_resolver.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';
import 'package:seafoundry_app/widgets/repositories/registry/disposable.dart';

abstract class InventoryRecordRepository<T extends InventoryRecord>
    with AuthErrorSuppressionMixin
    implements Disposable {
  InventoryRecordRepository({
    required this.modelType,
    required this.organization,
    required this.user,
    required FirebaseFirestore firestore,
    OrganismContext? organismContext,
    EventRepository? eventRepository,
    SnapshotService? snapshotService,
    this.enforceAuth = true,
  }) : organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       db = firestore,
       _eventRepository = eventRepository,
       _snapshotService = snapshotService ??
           (eventRepository != null
               ? SnapshotService(firestore: firestore)
               : null) {
    // Certain model types use nested collections under organizations/{orgId}/
    // This matches how demo data is seeded and provides better data isolation
    if (_usesNestedCollection(modelType)) {
      collectionRef = db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .collection(modelType.collectionPath);
    } else {
      collectionRef = db.collection(modelType.collectionPath);
    }
    _slugCountsRef = db
        .collection(ModelType.organization.collectionPath)
        .doc(organization.id)
        .collection('slugCounts');
  }

  /// Model types that use nested collections under organizations/{orgId}/
  /// These are inventory records that benefit from being scoped to an organization
  /// at the Firestore path level (in addition to the organizationId field)
  static bool _usesNestedCollection(ModelType type) {
    return type == ModelType.group ||
        type == ModelType.organismRecord ||
        type == ModelType.genet ||
        type == ModelType.zone ||
        type == ModelType.subplot;
  }

  final FirebaseFirestore db;
  FirebaseFirestore get firestore => db;
  final ModelType modelType;
  final Organization organization;
  final User user;
  final OrganismContext organismContext;
  final bool enforceAuth;
  late CollectionReference<Map<String, dynamic>> collectionRef;
  late final CollectionReference<Map<String, dynamic>> _slugCountsRef;
  final BehaviorSubject<List<T>> _collectionSubject = BehaviorSubject.seeded(
    <T>[],
  );

  /// Backing field for [eventRepository]. Nullable because subclasses that
  /// don't need event/snapshot support (e.g. EventRepository) omit it.
  final EventRepository? _eventRepository;

  /// Backing field for [snapshotService]. Auto-created from firestore when
  /// [eventRepository] is provided and no explicit service is given.
  final SnapshotService? _snapshotService;

  /// The event repository for creating inventory events.
  ///
  /// Throws [StateError] if accessed on a repository that was constructed
  /// without an [EventRepository].
  EventRepository get eventRepository {
    final repo = _eventRepository;
    if (repo == null) {
      throw StateError(
        '$runtimeType was constructed without an EventRepository. '
        'eventRepository is required for createRecord/moveRecord operations.',
      );
    }
    return repo;
  }

  /// The snapshot service for creating before/after snapshots.
  ///
  /// Throws [StateError] if accessed on a repository that was constructed
  /// without an [EventRepository] (and thus has no snapshot service).
  SnapshotService get snapshotService {
    final svc = _snapshotService;
    if (svc == null) {
      throw StateError(
        '$runtimeType was constructed without a SnapshotService. '
        'snapshotService is required for createRecord operations.',
      );
    }
    return svc;
  }

  /// Subscription to the Firestore collection stream.
  /// Non-final to allow resubscription during error recovery.
  StreamSubscription<List<T>>? _collectionSubscription;
  bool _initialized = false;
  bool _isDisposed = false;

  /// Completer-based mutex to prevent concurrent initialization.
  /// When initialization is in progress, subsequent callers await this completer.
  Completer<void>? _initializationCompleter;

  @protected
  bool shouldIncludeRecord(T record) {
    return true;
  }

  /// Initializes the repository and begins streaming from Firestore.
  ///
  /// This method is idempotent and uses a completer-based mutex to prevent
  /// race conditions when called concurrently from multiple callers.
  /// Returns a Future that completes when initialization is done.
  @mustCallSuper
  Future<void> initialize() async {
    // Already initialized - return immediately
    if (_initialized) {
      return;
    }

    // Initialization in progress - wait for it to complete
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    // Start initialization with mutex
    _initializationCompleter = Completer<void>();

    try {
      _subscribeToCollection();
      _initialized = true;
      _initializationCompleter!.complete();
    } catch (e) {
      // On error, allow retry by clearing the completer
      _initializationCompleter!.completeError(e);
      _initializationCompleter = null;
      rethrow;
    }
  }

  /// Subscribes to the Firestore collection stream.
  ///
  /// This method can be called multiple times for recovery purposes.
  /// It cancels any existing subscription before creating a new one.
  void _subscribeToCollection() {
    // Cancel existing subscription if any (for recovery scenarios)
    _collectionSubscription?.cancel();

    _collectionSubscription = collectionQuery(collectionRef)
        .snapshots()
        .map((snapshot) {
          final records = <T>[];
          final errors = <DomainError>[];

          for (final doc in snapshot.docs) {
            try {
              final record = RecordFactory.recordFromJson<T>(
                doc.data() as Map<String, dynamic>,
              );
              if (!shouldIncludeRecord(record)) {
                continue;
              }
              records.add(record);
            } catch (e, stackTrace) {
              final error = ErrorHandler.transformError(
                e,
                stackTrace: stackTrace,
                context: 'Loading ${modelType.name} from Firestore',
              );
              errors.add(error);

              // Log the error but continue processing other records
              // error is always a DomainError from ErrorHandler.transformError
              LoggingService.instance.logDomainError(
                error,
                context: 'Parsing ${modelType.name} document ${doc.id}',
                stackTrace: stackTrace,
              );
            }
          }

          // If we have some valid records, emit them
          // Errors are logged but don't prevent other records from loading
          // Even if all records failed, return empty list to allow stream to continue
          if (errors.isNotEmpty && records.isEmpty) {
            LoggingService.instance.warning(
              'All ${modelType.name} records failed to parse (${errors.length} errors). Returning empty list.',
            );
          }

          return records;
        })
        .listen(
          (records) {
            if (_isDisposed || _collectionSubject.isClosed) {
              return;
            }
            _collectionSubject.add(records);
          },
          onError: (Object error, StackTrace stackTrace) {
            _handleStreamError(error, stackTrace);
          },
        );
  }

  /// Handles stream errors, including recovery from Firestore internal errors.
  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_isDisposed || _collectionSubject.isClosed) {
      return;
    }
    if (shouldSuppressAuthError(error)) {
      _collectionSubscription?.cancel();
      _collectionSubscription = null;
      return;
    }
    final domainError = ErrorHandler.transformError(
      error,
      stackTrace: stackTrace,
      context: 'Streaming ${modelType.name} collection',
    );

    LoggingService.instance.error(
      'Stream error for ${modelType.name}',
      domainError,
    );

    // Check if this is a Firestore internal assertion error
    final recoveryService = FirestoreRecoveryService.instance;
    if (recoveryService.isFirestoreInternalError(error)) {
      LoggingService.instance.warning(
        'Firestore internal error detected for ${modelType.name}, initiating recovery',
      );

      // Report error and register for recovery
      recoveryService.reportError(
        error: error,
        repositoryType: '${modelType.name}Repository',
        onReconnect: _subscribeToCollection,
      );
    }

    // Add error to the subject so BLoCs can handle it
    if (!_collectionSubject.isClosed) {
      _collectionSubject.addError(domainError, stackTrace);
    }
  }

  Stream<List<T>> get streamAll {
    if (!_initialized) {
      // Fire and forget - stream will emit once initialization completes.
      // Using unawaited to make the async call explicit.
      unawaited(initialize());
    }
    return _collectionSubject.stream;
  }

  Future<List<T>> getAll() async {
    final snapshot = await collectionQuery(collectionRef).get();
    final records = <T>[];
    final errors = <DomainError>[];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final record = RecordFactory.recordFromJson<T>(data);
        if (!shouldIncludeRecord(record)) {
          continue;
        }
        records.add(record);
      } catch (e, stackTrace) {
        final error = ErrorHandler.transformError(
          e,
          stackTrace: stackTrace,
          context: 'Fetching ${modelType.name} documents',
        );
        errors.add(error);
        LoggingService.instance.logDomainError(
          error,
          context: 'Parsing ${modelType.name} document ${doc.id}',
          stackTrace: stackTrace,
        );
      }
    }

    if (errors.isNotEmpty && records.isEmpty) {
      LoggingService.instance.warning(
        'InventoryRecordRepository.getAll: all ${modelType.name} records failed to parse (${errors.length}). Returning empty list.',
      );
    }

    return records;
  }

  Query<Object?> collectionQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    // Keep organization filter explicit for consistency across root and nested
    // collection layouts.
    return collectionRef.where('organizationId', isEqualTo: organization.id);
  }

  Future<String> nextSlugForModelType(ModelType modelType) async {
    return nextSlugForBase(modelType.name);
  }

  /// Generates the next unique slug for a given base string.
  ///
  /// Uses Firestore transactions with exponential backoff retry to handle
  /// contention when multiple concurrent operations try to increment the
  /// same counter. This is common during batch operations or heavy usage.
  Future<String> nextSlugForBase(String slugBase) async {
    final slugCountRef = _slugCountsRef.doc(slugBase);
    const maxRetries = 5;
    const baseDelayMs = 100;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await db.runTransaction((transaction) async {
          // Use transaction.get() to ensure atomic read within transaction context
          final snapshot = await transaction.get(slugCountRef);
          int newCount = 1;
          if (snapshot.exists) {
            newCount = snapshot.get('count') + 1;
          }
          transaction.set(slugCountRef, {'count': newCount});
          return '$slugBase$newCount';
        });
        return result;
      } on FirebaseException catch (e, stackTrace) {
        // Handle permission-denied errors with a clear message
        if (e.code == 'permission-denied') {
          LoggingService.instance.error(
            'nextSlugForBase: Permission denied for slug transaction!\n'
            '   - slugCountRef.path: ${slugCountRef.path}\n'
            '   - organization.id: ${organization.id}\n'
            '   - user.id: ${user.id}\n'
            '   This likely means the membership doc at '
            '/organizations/${organization.id}/members/${user.id} does not exist.',
            e,
            stackTrace,
          );
          throw RepositoryError(
            message:
                'Permission denied: Your account may not be properly '
                'configured for this organization. Please sign out and sign '
                'back in, or contact support if the issue persists.',
            technicalDetails:
                'Missing membership document for user ${user.id} '
                'in organization ${organization.id}. '
                'Path: /organizations/${organization.id}/members/${user.id}',
            originalError: e,
            stackTrace: stackTrace,
            category: AppErrorCategory.permission,
          );
        }
        // Retry on failed-precondition (transaction contention) with exponential backoff
        if (e.code == 'failed-precondition' && attempt < maxRetries) {
          // Exponential backoff with jitter: baseDelay * 2^attempt + random(0-100ms)
          final delayMs =
              (baseDelayMs * pow(2, attempt)).toInt() +
              Random().nextInt(baseDelayMs);
          LoggingService.instance.warning(
            'nextSlugForBase: Transaction contention for $slugBase, '
            'retry ${attempt + 1}/$maxRetries after ${delayMs}ms',
          );
          await Future<void>.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        // Non-retryable error or max retries exceeded
        LoggingService.instance.error(
          'nextSlugForBase: Transaction FAILED after ${attempt + 1} attempts!',
          e,
          stackTrace,
        );
        rethrow;
      } catch (e, stackTrace) {
        // Non-Firebase errors - don't retry
        LoggingService.instance.error(
          'nextSlugForBase: Transaction FAILED with non-Firebase error!',
          e,
          stackTrace,
        );
        rethrow;
      }
    }
    // This should never be reached due to the rethrow above
    throw StateError('nextSlugForBase: Unreachable code');
  }

  Future<T?> getRecordForId(String id) async {
    final snapshot = await collectionRef.doc(id).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data();
    if (data == null) {
      LoggingService.instance.warning(
        'Document ${snapshot.id} exists but has null data',
        {'collection': modelType.collectionPath, 'docId': snapshot.id},
      );
      return null;
    }
    return RecordFactory.recordFromJson<T>(data);
  }

  Stream<List<T>> streamRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  }) {
    final normalizedUrlPath = UrlPathResolver.normalizePath(urlPath);
    if (normalizedUrlPath.isEmpty) {
      LoggingService.instance.warning(
        '${modelType.name} streamRecordsForUrlPath called with empty urlPath; returning empty stream.',
      );
      return Stream<List<T>>.value(const []);
    }

    return streamAll
        .map((recordList) {
          final filtered = recordList.where((record) {
            try {
              // Skip records with missing/empty urlPath to avoid resolver errors.
              final recordPath = UrlPathResolver.normalizePath(
                record.urlPath,
              );
              if (recordPath.isEmpty) return false;

              // Guard against cross-organization bleed. Prefer authoritative orgId
              // when present on the record; fall back to urlPath prefix checks for
              // older records that may not have organizationId populated.
              final hasOrgId = record.organizationId.isNotEmpty;
              if (hasOrgId && record.organizationId != organization.id) {
                return false;
              }

              if (!hasOrgId) {
                final orgPrefix =
                    organization.orgPrefix ?? '${organization.slug}/';
                if (!(recordPath == organization.slug ||
                    recordPath.startsWith(orgPrefix))) {
                  return false;
                }
              }

              // Only include descendants, NOT exact matches (to avoid self-referencing)
              // A record should not appear as its own child
              final isDescendant = UrlPathResolver.isDescendantOf(
                recordPath,
                normalizedUrlPath,
              );
              // Apply shallow filter if needed
              final shallowFilter = shallow
                  ? UrlPathResolver.isChildOf(
                      recordPath,
                      normalizedUrlPath,
                    )
                  : true;
              return isDescendant && shallowFilter;
            } catch (e, stackTrace) {
              LoggingService.instance.logDomainError(
                ErrorHandler.transformError(
                  e,
                  stackTrace: stackTrace,
                  context:
                      'Filtering ${modelType.name} by urlPath "$urlPath" for record ${record.id}',
                ),
                context:
                    'streamRecordsForUrlPath(${modelType.name}) filter failure',
                stackTrace: stackTrace,
              );
              return false;
            }
          }).toList();

          return filtered;
        })
        .toBroadcastIfNeeded(StreamType.children);
  }

  Future<List<T>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  }) async => streamRecordsForUrlPath(urlPath, shallow: shallow).first;

  Future<void> updateRecord(T record, {WriteBatch? batch}) async {
    final payload = Map<String, dynamic>.from(record.toJson());
    // Preserve immutable creation ownership on updates.
    payload.remove('createdById');

    if (batch != null) {
      batch.update(collectionRef.doc(record.id), payload);
    } else {
      try {
        await collectionRef.doc(record.id).update(payload);
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'updateRecord FAILED for ${record.id}',
          e,
          stackTrace,
        );
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // createRecord / moveRecord — require eventRepository
  // ---------------------------------------------------------------------------

  Future<T> createRecord(
    T partialRecord,
    GraphNodeRecord parent, {
    EventBaseParams base = const EventBaseParams(),
  }) async {
    assert(_eventRepository != null,
        'createRecord requires an EventRepository');

    if (enforceAuth) {
      String? authUid;
      var authAvailable = true;
      try {
        authUid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
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
    assert(_eventRepository != null,
        'moveRecord requires an EventRepository');

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

  @override
  @mustCallSuper
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _collectionSubscription?.cancel();
    _collectionSubscription = null;
    if (!_collectionSubject.isClosed) {
      _collectionSubject.close();
    }
  }
}
