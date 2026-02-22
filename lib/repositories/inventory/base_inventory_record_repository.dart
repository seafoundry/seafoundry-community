// @tier: community
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/auth_session_service.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/firestore_recovery_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/url_path_resolver.dart';
import 'package:seafoundry_app/utils/stream_factory.dart';
import 'package:seafoundry_app/widgets/repositories/registry/disposable.dart';

abstract class BaseInventoryRecordRepository<T extends InventoryRecord>
    implements Disposable {
  BaseInventoryRecordRepository({
    required this.modelType,
    required this.organization,
    required this.user,
    required FirebaseFirestore firestore,
    OrganismContext? organismContext,
  }) : organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral),
       db = firestore {
    // Certain model types use nested collections under organizations/{orgId}/
    // This matches how demo data is seeded and provides better data isolation
    if (_usesNestedCollection(modelType)) {
      collectionRef = FirestoreCollectionResolver.instance.subcollection(
        db,
        ModelType.organization.collectionPath,
        organization.id,
        modelType.collectionPath,
      );
    } else {
      // Use root collection with FirestoreCollectionResolver for demo mode support
      collectionRef = FirestoreCollectionResolver.instance.collection(
        db,
        modelType.collectionPath,
      );
    }
    // Debug: Log collection path for demo mode troubleshooting
    LoggingService.instance.debug(
      '🏗️ ${modelType.name}Repository: collectionRef.path=${collectionRef.path}, '
      'organizationId=${organization.id}, nested=${_usesNestedCollection(modelType)}',
    );
    _slugCountsRef = FirestoreCollectionResolver.instance
        .collection(db, ModelType.organization.collectionPath)
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

  static const String _legacyOrganismRecordCollectionId = 'organism_records';
  static const String _organismRecordMigrationFlagKey =
      'organismRecordsMigratedAt';
  static final Map<String, Future<void>> _organismRecordMigrationTasks = {};
  static final Set<String> _organismRecordMigrationCompleted = {};

  final FirebaseFirestore db;
  FirebaseFirestore get firestore => db;
  final ModelType modelType;
  final Organization organization;
  final User user;
  final OrganismContext organismContext;
  late CollectionReference<Map<String, dynamic>> collectionRef;
  late final CollectionReference<Map<String, dynamic>> _slugCountsRef;
  final BehaviorSubject<List<T>> _collectionSubject = BehaviorSubject.seeded(
    <T>[],
  );

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
      LoggingService.instance.debug(
        '$runtimeType already initialized, skipping',
      );
      return;
    }

    // Initialization in progress - wait for it to complete
    if (_initializationCompleter != null) {
      LoggingService.instance.debug(
        '$runtimeType initialization in progress, waiting...',
      );
      return _initializationCompleter!.future;
    }

    // Start initialization with mutex
    _initializationCompleter = Completer<void>();

    try {
      LoggingService.instance.debug('Initializing $runtimeType');
      if (modelType == ModelType.genet) {
        LoggingService.instance.debug(
          '🧬 GenetRepository.initialize: setting up stream',
        );
        LoggingService.instance.debug(
          '   - collectionRef.path=${collectionRef.path}',
        );
        LoggingService.instance.debug('   - organizationId=${organization.id}');
      }
      if (modelType == ModelType.organismRecord) {
        LoggingService.instance.debug(
          '🦠 OrganismRecordRepository.initialize: setting up stream',
        );
        LoggingService.instance.debug(
          '   - collectionRef.path=${collectionRef.path}',
        );
        LoggingService.instance.debug('   - organizationId=${organization.id}');
      }
      if (modelType == ModelType.organismRecord) {
        _initialized = true;
        _initializeOrganismRecordStream();
        _initializationCompleter!.complete();
        return;
      }
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

  void _initializeOrganismRecordStream() {
    final migration = _ensureOrganismRecordCollectionMigrated();
    unawaited(
      migration
          .catchError((Object error, StackTrace stackTrace) {
            LoggingService.instance.error(
              'OrganismRecords migration failed for org ${organization.id}',
              error,
              stackTrace,
            );
          })
          .whenComplete(() {
            if (_isDisposed || _collectionSubject.isClosed) {
              return;
            }
            _subscribeToCollection();
          }),
    );
  }

  Future<void> _ensureOrganismRecordCollectionMigrated() {
    final orgId = organization.id;
    if (_organismRecordMigrationCompleted.contains(orgId)) {
      return Future.value();
    }
    final existing = _organismRecordMigrationTasks[orgId];
    if (existing != null) {
      return existing;
    }

    final task = _migrateLegacyOrganismRecordsIfNeeded().then((_) {
      _organismRecordMigrationCompleted.add(orgId);
    }).whenComplete(() {
      _organismRecordMigrationTasks.remove(orgId);
    });
    _organismRecordMigrationTasks[orgId] = task;
    return task;
  }

  Future<void> _migrateLegacyOrganismRecordsIfNeeded() async {
    if (modelType != ModelType.organismRecord) {
      return;
    }
    final orgId = organization.id;

    final alreadyMigrated = await _hasOrganismRecordMigrationFlag();
    if (alreadyMigrated) {
      LoggingService.instance.debug(
        'OrganismRecords migration already complete for org $orgId.',
      );
      return;
    }

    final legacyCollection = FirestoreCollectionResolver.instance.subcollection(
      db,
      ModelType.organization.collectionPath,
      orgId,
      _legacyOrganismRecordCollectionId,
    );
    final legacyProbe = await legacyCollection.limit(1).get();
    if (legacyProbe.docs.isEmpty) {
      LoggingService.instance.debug(
        'No legacy organism_records found for org $orgId.',
      );
      return;
    }

    LoggingService.instance.warning(
      'Legacy organism_records detected for org $orgId; migrating to '
      'organismRecords.',
    );

    const batchSize = 400;
    DocumentSnapshot<Map<String, dynamic>>? lastDoc;
    var migratedCount = 0;

    while (true) {
      Query<Map<String, dynamic>> query = legacyCollection
          .orderBy(FieldPath.documentId)
          .limit(batchSize);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.set(
          collectionRef.doc(doc.id),
          doc.data(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      migratedCount += snapshot.docs.length;
      lastDoc = snapshot.docs.last;
    }

    await _markOrganismRecordMigrationComplete();
    LoggingService.instance.info(
      'OrganismRecords migration complete for org $orgId '
      '($migratedCount records).',
    );
  }

  Future<bool> _hasOrganismRecordMigrationFlag() async {
    final metadata = organization.metadata;
    if (metadata != null && metadata[_organismRecordMigrationFlagKey] != null) {
      return true;
    }
    try {
      final snapshot = await db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .get();
      final data = snapshot.data();
      final resolvedMetadata = data?['metadata'] as Map<String, dynamic>?;
      return resolvedMetadata?[_organismRecordMigrationFlagKey] != null;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to read organismRecords migration flag for org '
        '${organization.id}',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _markOrganismRecordMigrationComplete() async {
    try {
      await db
          .collection(ModelType.organization.collectionPath)
          .doc(organization.id)
          .update({
            'metadata.$_organismRecordMigrationFlagKey':
                DateTime.now().toIso8601String(),
          });
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to mark organismRecords migration complete for org '
        '${organization.id}',
        error,
        stackTrace,
      );
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
          if (modelType == ModelType.genet) {
            LoggingService.instance.debug(
              '🧬 GenetRepository: snapshot received with ${snapshot.docs.length} docs',
            );
          }
          if (modelType == ModelType.organismRecord) {
            LoggingService.instance.debug(
              '🦠 OrganismRecordRepository: snapshot received with ${snapshot.docs.length} docs',
            );
          }
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
    if (_shouldSuppressAuthError(error)) {
      LoggingService.instance.debug(
        'Suppressing ${modelType.name} stream error after sign out',
      );
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

  bool _shouldSuppressAuthError(Object error) {
    if (!_isSignedOut()) {
      return false;
    }
    return _isPermissionError(error);
  }

  bool _isSignedOut() {
    try {
      return AuthSessionService.instance.isSigningOut ||
          fbAuth.FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return AuthSessionService.instance.isSigningOut;
    }
  }

  bool _isPermissionError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' || error.code == 'unauthenticated';
    }
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission') ||
        message.contains('unauthenticated');
  }

  Stream<List<T>> get streamAll {
    if (!_initialized) {
      // Fire and forget - stream will emit once initialization completes.
      // Using unawaited to make the async call explicit.
      unawaited(initialize());
    }
    if (modelType == ModelType.event) {
      LoggingService.instance.debug(
        'EventRepository.streamAll accessed, hasValue=${_collectionSubject.hasValue}, valueLength=${_collectionSubject.valueOrNull?.length}',
      );
    }
    if (modelType == ModelType.genet) {
      LoggingService.instance.debug(
        '🧬 GenetRepository.streamAll accessed, hasValue=${_collectionSubject.hasValue}, valueLength=${_collectionSubject.valueOrNull?.length}',
      );
      LoggingService.instance.debug(
        '   - collectionRef.path=${collectionRef.path}',
      );
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
        'BaseInventoryRecordRepository.getAll: all ${modelType.name} records failed to parse (${errors.length}). Returning empty list.',
      );
    }

    return records;
  }

  Query<Object?> collectionQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    // For nested collections (under organizations/{orgId}/), the collection path
    // already scopes to the org, but we still filter by organizationId for consistency
    // and to support any legacy data that might exist in root collections
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

    LoggingService.instance.debug(
      'nextSlugForBase: Starting transaction for $slugBase',
    );
    LoggingService.instance.debug(
      '   - slugCountRef.path: ${slugCountRef.path}',
    );
    LoggingService.instance.debug('   - organization.id: ${organization.id}');

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
        LoggingService.instance.debug(
          'nextSlugForBase: Transaction succeeded on attempt ${attempt + 1}, slug=$result',
        );
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
    final normalizedUrlPath = UrlPathResolver.instance.normalizePath(urlPath);
    if (normalizedUrlPath.isEmpty) {
      LoggingService.instance.warning(
        '${modelType.name} streamRecordsForUrlPath called with empty urlPath; returning empty stream.',
      );
      return Stream<List<T>>.value(const []);
    }

    return streamAll
        .map((recordList) {
          // Debug: log filter params once per emission
          if (modelType == ModelType.event && recordList.isNotEmpty) {
            LoggingService.instance.debug(
              'streamRecordsForUrlPath: filtering ${recordList.length} ${modelType.name}s '
              'for urlPath="$urlPath", org.id=${organization.id}, org.slug=${organization.slug}',
            );
          }

          final filtered = recordList.where((record) {
            try {
              // Skip records with missing/empty urlPath to avoid resolver errors.
              final recordPath = UrlPathResolver.instance.normalizePath(
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
                final orgPrefix = '${organization.slug}/';
                if (!(recordPath == organization.slug ||
                    recordPath.startsWith(orgPrefix))) {
                  return false;
                }
              }

              // Only include descendants, NOT exact matches (to avoid self-referencing)
              // A record should not appear as its own child
              final isDescendant = UrlPathResolver.instance.isDescendantOf(
                recordPath,
                normalizedUrlPath,
              );
              // Apply shallow filter if needed
              final shallowFilter = shallow
                  ? UrlPathResolver.instance.isChildOf(
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

          // Debug: log filter results for events
          if (modelType == ModelType.event && recordList.isNotEmpty) {
            LoggingService.instance.debug(
              'streamRecordsForUrlPath: ${modelType.name} filter result: '
              '${filtered.length} of ${recordList.length} passed for urlPath="$urlPath"',
            );
            // Log first record details if none pass to understand why
            if (filtered.isEmpty && recordList.isNotEmpty) {
              final first = recordList.first;
              final recordPath = UrlPathResolver.instance.normalizePath(
                first.urlPath,
              );
              final hasOrgId = first.organizationId.isNotEmpty;
              final isDescendant = UrlPathResolver.instance.isDescendantOf(
                recordPath,
                normalizedUrlPath,
              );
              LoggingService.instance.debug(
                '  First event: urlPath="$recordPath", orgId="${first.organizationId}", '
                'hasOrgId=$hasOrgId, isDescendantOf("$normalizedUrlPath")=$isDescendant',
              );
            }
          }

          return filtered;
        })
        .toBroadcastIfNeeded(StreamType.children);
  }

  Stream<T?> streamRecordForUrlPath(String urlPath) {
    return streamAll
        .map((records) {
          final matchingRecords = records.where(
            (record) => record.urlPath == urlPath,
          );
          if (matchingRecords.length > 1) {
            LoggingService.instance.warning(
              "Multiple ${modelType.name} records found for urlPath: $urlPath",
            );
          }
          return matchingRecords.firstOrNull;
        })
        .toBroadcastIfNeeded(StreamType.record);
  }

  Future<List<T>> getRecordsForUrlPath(
    String urlPath, {
    bool shallow = false,
  }) async => streamRecordsForUrlPath(urlPath, shallow: shallow).first;

  Future<void> updateRecord(T record, {WriteBatch? batch}) async {
    LoggingService.instance.debug(
      '🔵 BaseInventoryRecordRepository.updateRecord',
    );
    LoggingService.instance.debug(
      '   - collectionRef.path: ${collectionRef.path}',
    );
    LoggingService.instance.debug('   - record.id: ${record.id}');
    LoggingService.instance.debug(
      '   - record.organizationId: ${record.organizationId}',
    );
    LoggingService.instance.debug(
      '   - Full doc path: ${collectionRef.path}/${record.id}',
    );
    final payload = Map<String, dynamic>.from(record.toJson());
    // Avoid touching createdById during updates (legacy docs may omit it)
    payload.remove('createdById');

    if (batch != null) {
      LoggingService.instance.debug('   - Using batch.update()');
      batch.update(collectionRef.doc(record.id), payload);
    } else {
      LoggingService.instance.debug('   - Using direct update()...');
      try {
        await collectionRef.doc(record.id).update(payload);
        LoggingService.instance.debug('   ✅ update() succeeded');
      } catch (e, stackTrace) {
        LoggingService.instance.error('   ❌ update() FAILED', e, stackTrace);
        rethrow;
      }
    }
  }

  Future<void> deleteRecord(T record, {WriteBatch? batch}) async {
    if (batch != null) {
      batch.delete(collectionRef.doc(record.id));
    } else {
      await collectionRef.doc(record.id).delete();
    }
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
