// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/factories/record_factory.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/user_role.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

/// Repository for managing current user and organization data
class CurrentUserRepository {
  // Singleton pattern with configurable Firestore for testing
  static bool get isInitialized => instance != null;

  factory CurrentUserRepository({FirebaseFirestore? firestore}) {
    if (instance != null) return instance!;
    if (firestore == null) {
      throw StateError(
        'CurrentUserRepository not initialized. Call with firestore first.',
      );
    }
    instance = CurrentUserRepository._internal(firestore: firestore);
    return instance!;
  }

  CurrentUserRepository._internal({required FirebaseFirestore firestore})
    : db = firestore;

  static CurrentUserRepository? instance;

  final FirebaseFirestore db;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  StreamSubscription<DocumentSnapshot>? _organizationSubscription;

  late StreamController<User?> _userStreamController =
      StreamController<User?>.broadcast();
  late StreamController<Organization?> _organizationStreamController =
      StreamController<Organization?>.broadcast();

  /// Safely add a value to a StreamController, handling closure race conditions.
  ///
  /// Returns true if the value was successfully added, false if the controller
  /// was closed (either before or during the add operation).
  bool tryAddToSink<T>(
    StreamController<T> controller,
    T value, {
    String? debugLabel,
  }) {
    try {
      controller.add(value);
      return true;
    } catch (e) {
      final label = debugLabel ?? 'StreamController';
      LoggingService.instance.debug('$label closed during add, value dropped');
      return false;
    }
  }

  /// Stream of current user
  Stream<User?> get userStream => _userStreamController.stream;

  /// Stream of current organization
  Stream<Organization?> get organizationStream =>
      _organizationStreamController.stream;

  /// Get user by UID doc ID.
  Future<User?> getUser(String userId) async {
    try {
      final docId = UserIdentity.normalizeUserDocId(userId);
      if (docId.isEmpty) return null;
      final doc = await db.collection('users').doc(docId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data.isEmpty) {
        LoggingService.instance.warning(
          'Document ${doc.id} exists but has empty data',
          {'collection': 'users', 'docId': doc.id},
        );
        return null;
      }
      data['id'] = doc.id;
      return RecordFactory.recordFromJson<User>(data);
    } catch (e, stackTrace) {
      final error = ErrorHandler.transformError(
        e,
        stackTrace: stackTrace,
        context: 'Fetching user $userId',
      );
      LoggingService.instance.error(
        'Error fetching user: ${error.technicalDetails ?? error.message}',
      );
      // Return null for backwards compatibility, but log the detailed error
      return null;
    }
  }

  /// Get organization by ID
  Future<Organization?> getOrganization(String organizationId) async {
    // Guard against invalid organization IDs
    if (organizationId.isEmpty || organizationId.isMissing) {
      LoggingService.instance.warning(
        'CurrentUserRepository: Cannot get organization with invalid ID: $organizationId',
      );
      return null;
    }

    try {
      final doc = await db
          .collection('organizations')
          .doc(organizationId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      if (data == null) {
        LoggingService.instance.warning(
          'Document ${doc.id} exists but has null data',
          {'collection': 'organizations', 'docId': doc.id},
        );
        return null;
      }
      final normalized = Map<String, dynamic>.from(data);
      normalized['id'] = doc.id;
      final orgId = normalized['organizationId'];
      if (orgId == null || (orgId is String && orgId.trim().isEmpty)) {
        normalized['organizationId'] = doc.id;
      }

      return RecordFactory.recordFromJson<Organization>(normalized);
    } catch (e, stackTrace) {
      final error = ErrorHandler.transformError(
        e,
        stackTrace: stackTrace,
        context: 'Fetching organization $organizationId',
      );
      LoggingService.instance.error(
        'Error fetching organization: ${error.technicalDetails ?? error.message}',
      );
      // Return null for backwards compatibility, but log the detailed error
      return null;
    }
  }

  /// Create a new user (userId is the Firebase Auth UID)
  Future<User> createUser({
    required String userId,
    required String email,
    String? name,
    String? organizationId,
  }) async {
    final normalizedEmail = UserIdentity.normalizeEmail(email) ?? email.trim();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError('email must be provided for user creation');
    }
    final user = User(
      id: userId,
      email: normalizedEmail,
      name: name ?? normalizedEmail.split('@')[0],
      organizationId: organizationId ?? Missing.string,
      role: UserRole.practitioner.id,
      createdById: userId,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: userId,
      imageUrl: null,
    );

    final data = user.toJson();
    await db.collection('users').doc(userId).set(data);

    return user;
  }

  /// Update user's organization
  Future<User> updateUserOrganization({
    required User user,
    required String organizationId,
  }) async {
    await db.collection('users').doc(user.id).update({
      'organizationId': organizationId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return user.copyWith(
      organizationId: organizationId,
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: user.id,
    );
  }

  /// Update user profile (name, tagline, image)
  Future<User> updateUserProfile({
    required User user,
    String? name,
    String? tagline,
    String? imageUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedById': user.id,
    };

    if (name != null) updates['name'] = name;
    if (tagline != null) updates['tagline'] = tagline;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;

    await db.collection('users').doc(user.id).update(updates);

    return user.copyWith(
      name: name,
      tagline: tagline,
      imageUrl: imageUrl,
      updatedAt: DateTime.now().toIso8601String(),
      updatedById: user.id,
    );
  }

  /// Subscribe to user changes
  void subscribeToUser(String userId) {
    LoggingService.instance.trace(
      'CurrentUserRepository.subscribeToUser invoked with userId=$userId',
    );
    _userSubscription?.cancel();

    final resolvedId = UserIdentity.normalizeUserDocId(userId);
    LoggingService.instance.trace(
      'CurrentUserRepository normalized user identifier: $resolvedId',
    );
    LoggingService.instance.debug(
      'CurrentUserRepository: Setting up user snapshot listener for: $resolvedId',
    );

    try {
      LoggingService.instance.trace(
        'CurrentUserRepository: subscribing to users/$resolvedId snapshots',
      );
      final userDocRef = db.collection('users').doc(resolvedId);
      _userSubscription = userDocRef.snapshots()
          .handleError((error, stackTrace) {
            LoggingService.instance.error(
              'Firestore stream error [${userDocRef.path}]',
              error,
              stackTrace,
            );
            throw error;
          })
          .listen(
            (snapshot) {
              LoggingService.instance.trace(
                'CurrentUserRepository: user snapshot received (exists=${snapshot.exists})',
              );
              if (snapshot.exists) {
                final data = snapshot.data();
                if (data == null) {
                  LoggingService.instance.warning(
                    'Document ${snapshot.id} exists but has null data',
                    {'collection': 'users', 'docId': snapshot.id},
                  );
                  tryAddToSink(
                    _userStreamController,
                    null,
                    debugLabel: 'CurrentUserRepository.userStream',
                  );
                  return;
                }
                try {
                  LoggingService.instance.trace(
                    'CurrentUserRepository: user snapshot data $data',
                  );
                  final user = RecordFactory.recordFromJson<User>(data);
                  LoggingService.instance.trace(
                    'CurrentUserRepository: parsed user ${user.email}',
                  );
                  // Debug: Log user.id for permission-denied diagnosis
                  // This id is used as createdById in events - must match request.auth.uid.
                  LoggingService.instance.debug(
                    '🔵 CurrentUserRepository: user loaded from stream',
                  );
                  LoggingService.instance.debug(
                    '   - user.id (used as createdById): "${user.id}"',
                  );
                  LoggingService.instance.debug(
                    '   - user.email: "${user.email}"',
                  );
                  LoggingService.instance.debug(
                    '   - user.organizationId: "${user.organizationId}"',
                  );
                  tryAddToSink(
                    _userStreamController,
                    user,
                    debugLabel: 'CurrentUserRepository.userStream',
                  );
                } catch (e, stackTrace) {
                  final error = ErrorHandler.transformError(
                    e,
                    stackTrace: stackTrace,
                    context: 'Parsing user stream data',
                  );
                  LoggingService.instance.error(
                    'Error parsing user in stream: ${error.technicalDetails ?? error.message}',
                    e,
                    stackTrace,
                  );
                  _userStreamController.addError(error, stackTrace);
                }
              } else {
                tryAddToSink(
                  _userStreamController,
                  null,
                  debugLabel: 'CurrentUserRepository.userStream',
                );
              }
            },
            onError: (error, stackTrace) {
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                LoggingService.instance.debug(
                  'User stream permission denied after sign-out; emitting null.',
                );
                tryAddToSink(
                  _userStreamController,
                  null,
                  debugLabel: 'CurrentUserRepository.userStream',
                );
                return;
              }
              final domainError = ErrorHandler.transformError(
                error,
                stackTrace: stackTrace,
                context: 'User stream subscription',
              );
              LoggingService.instance.error(
                'Error in user stream: ${domainError.message}',
                error,
                stackTrace,
              );
              _userStreamController.addError(domainError, stackTrace);
            },
          );
      LoggingService.instance.debug(
        'CurrentUserRepository: User snapshot listener successfully created',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'CurrentUserRepository: Failed to create user snapshot listener',
        e,
        stackTrace,
      );
      final error = ErrorHandler.transformError(
        e,
        stackTrace: stackTrace,
        context: 'Creating user snapshot listener',
      );
      _userStreamController.addError(error, stackTrace);
    }
  }

  /// Subscribe to organization changes
  void subscribeToOrganization(String organizationId) {
    LoggingService.instance.trace(
      'CurrentUserRepository.subscribeToOrganization invoked with organizationId=$organizationId',
    );
    _organizationSubscription?.cancel();

    // Guard against invalid organization IDs that would cause Firestore errors
    if (organizationId.isEmpty || organizationId.isMissing) {
      LoggingService.instance.warning(
        'CurrentUserRepository: Cannot subscribe to organization with invalid ID: $organizationId',
      );
      tryAddToSink(
        _organizationStreamController,
        null,
        debugLabel: 'CurrentUserRepository.organizationStream',
      );
      return;
    }

    LoggingService.instance.debug(
      'CurrentUserRepository: Setting up organization snapshot listener for: $organizationId',
    );

    try {
      LoggingService.instance.trace(
        'CurrentUserRepository: subscribing to organizations/$organizationId snapshots',
      );
      final orgDocRef = db
          .collection('organizations')
          .doc(organizationId);
      _organizationSubscription = orgDocRef.snapshots()
          .handleError((error, stackTrace) {
            LoggingService.instance.error(
              'Firestore stream error [${orgDocRef.path}]',
              error,
              stackTrace,
            );
            throw error;
          })
          .listen(
            (snapshot) {
              LoggingService.instance.trace(
                'CurrentUserRepository: organization snapshot received (exists=${snapshot.exists})',
              );
              if (snapshot.exists) {
                final data = snapshot.data();
                if (data == null) {
                  LoggingService.instance.warning(
                    'Document ${snapshot.id} exists but has null data',
                    {'collection': 'organizations', 'docId': snapshot.id},
                  );
                  tryAddToSink(
                    _organizationStreamController,
                    null,
                    debugLabel: 'CurrentUserRepository.organizationStream',
                  );
                  return;
                }
                try {
                  LoggingService.instance.trace(
                    'CurrentUserRepository: organization snapshot data $data',
                  );
                  final normalized = Map<String, dynamic>.from(data);
                  normalized['id'] = snapshot.id;
                  final orgId = normalized['organizationId'];
                  if (orgId == null || (orgId is String && orgId.trim().isEmpty)) {
                    normalized['organizationId'] = snapshot.id;
                  }
                  final organization =
                      RecordFactory.recordFromJson<Organization>(normalized);
                  LoggingService.instance.trace(
                    'CurrentUserRepository: parsed organization ${organization.name}',
                  );
                  tryAddToSink(
                    _organizationStreamController,
                    organization,
                    debugLabel: 'CurrentUserRepository.organizationStream',
                  );
                } catch (e, stackTrace) {
                  final error = ErrorHandler.transformError(
                    e,
                    stackTrace: stackTrace,
                    context: 'Parsing organization stream data',
                  );
                  LoggingService.instance.error(
                    'Error parsing organization in stream: ${error.technicalDetails ?? error.message}',
                    e,
                    stackTrace,
                  );
                  _organizationStreamController.addError(error, stackTrace);
                }
              } else {
                tryAddToSink(
                  _organizationStreamController,
                  null,
                  debugLabel: 'CurrentUserRepository.organizationStream',
                );
              }
            },
            onError: (error, stackTrace) {
              if (error is FirebaseException &&
                  error.code == 'permission-denied') {
                LoggingService.instance.debug(
                  'Organization stream permission denied after sign-out; emitting null.',
                );
                tryAddToSink(
                  _organizationStreamController,
                  null,
                  debugLabel: 'CurrentUserRepository.organizationStream',
                );
                return;
              }
              final domainError = ErrorHandler.transformError(
                error,
                stackTrace: stackTrace,
                context: 'Organization stream subscription',
              );
              LoggingService.instance.error(
                'Error in organization stream: ${domainError.message}',
                error,
                stackTrace,
              );
              _organizationStreamController.addError(domainError, stackTrace);
            },
          );
      LoggingService.instance.debug(
        'CurrentUserRepository: Organization snapshot listener successfully created',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'CurrentUserRepository: Failed to create organization snapshot listener',
        e,
        stackTrace,
      );
      final error = ErrorHandler.transformError(
        e,
        stackTrace: stackTrace,
        context: 'Creating organization snapshot listener',
      );
      _organizationStreamController.addError(error, stackTrace);
    }
  }

  /// Ensures a membership document exists for UID-keyed security rules.
  ///
  /// Membership docs live at `/organizations/{orgId}/members/{uid}`.
  /// If the membership document doesn't exist, it's created with basic data.
  /// If it already exists, this is a no-op.
  Future<void> ensureMembershipExists({
    required String organizationId,
    required String userId,
    String? email,
  }) async {
    final normalizedEmail = UserIdentity.normalizeEmail(email);
    if (organizationId.isEmpty || userId.isEmpty) {
      LoggingService.instance.warning(
        'CurrentUserRepository: Cannot ensure membership - missing orgId or uid',
      );
      return;
    }

    LoggingService.instance.debug('🔐 ensureMembershipExists called:');
    LoggingService.instance.debug('   - organizationId: $organizationId');
    LoggingService.instance.debug('   - uid: $userId');
    if (normalizedEmail != null) {
      LoggingService.instance.debug('   - email: $normalizedEmail');
    }

    try {
      final membershipRef = db
          .collection('organizations')
          .doc(organizationId)
          .collection('members')
          .doc(userId);

      LoggingService.instance.debug(
        '🔐 Ensuring membership exists at: ${membershipRef.path}',
      );

      // Create only when missing to avoid overwriting existing roles/metadata.
      final created = await db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(membershipRef);
        if (snapshot.exists) {
          return false;
        }

        final now = DateTime.now().toIso8601String();
        final membershipData = {
          'uid': userId,
          if (normalizedEmail != null) 'email': normalizedEmail,
          'role': UserRole.practitioner.id,
          'joinedAt': now,
          'createdById': userId,
          'organizationId': organizationId,
          'backfilledAt': now,
          'backfillReason':
              'Auto-created during login for UID-keyed membership',
        };

        transaction.set(membershipRef, membershipData);
        return true;
      });

      if (created) {
        LoggingService.instance.info(
          '✅ Ensured membership document at ${membershipRef.path}',
        );
      } else {
        LoggingService.instance.debug(
          '🔐 Membership already exists at ${membershipRef.path}; skipping backfill',
        );
      }
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied') {
        // Log detailed info for permission-denied debugging
        LoggingService.instance.warning(
          '🔐 Permission denied creating membership. This may be due to:\n'
          '   1. User doc organizationId mismatch\n'
          '   2. Missing membership doc for self-creation rule\n'
          '   3. createdById mismatch\n'
          '   Firestore rules require UID-keyed user docs (2026-01-20).\n'
          '   User may still be able to operate via isOrgMember() fallback.',
        );
        LoggingService.instance.debug(
          '   - organizationId: $organizationId\n'
          '   - uid: $userId',
        );
      }
      // Log but don't throw - membership creation failure shouldn't block login
      // The user may still be able to operate if isOrgMember() passes
      LoggingService.instance.error(
        'Failed to ensure membership exists',
        e,
        stackTrace,
      );
    } catch (e, stackTrace) {
      // Log but don't throw - membership creation failure shouldn't block login
      LoggingService.instance.error(
        'Failed to ensure membership exists (non-Firebase error)',
        e,
        stackTrace,
      );
    }
  }

  /// Unsubscribe from all streams
  void unsubscribe() {
    _userSubscription?.cancel();
    _organizationSubscription?.cancel();
    _userSubscription = null;
    _organizationSubscription = null;
  }

  /// Resets the repository state for user logout/switch scenarios.
  ///
  /// Creates fresh StreamControllers for user and organization streams.
  /// This allows clean re-subscription after login without "already closed" errors.
  ///
  /// **IMPORTANT**: Existing stream listeners (from [userStream] and
  /// [organizationStream]) will NOT receive events after reset. Callers
  /// (typically [CurrentUserCubit]) MUST:
  /// 1. Cancel their existing stream subscriptions before calling reset
  /// 2. Resubscribe to [userStream] and [organizationStream] after reset
  ///
  /// The [CurrentUserCubit.reset()] method handles this correctly by:
  /// - Canceling subscriptions
  /// - Calling this method
  /// - Emitting initial state (which triggers widget rebuild and resubscription)
  ///
  /// Example:
  /// ```dart
  /// // In cubit:
  /// await _userSubscription?.cancel();
  /// await _organizationSubscription?.cancel();
  /// _repository.reset();
  /// emit(CurrentUserInitial()); // Triggers UI rebuild
  /// ```
  Future<void> reset() async {
    LoggingService.instance.debug(
      'CurrentUserRepository: Resetting to clean state',
    );

    // Cancel and null out subscriptions
    await _userSubscription?.cancel();
    await _organizationSubscription?.cancel();
    _userSubscription = null;
    _organizationSubscription = null;

    // Close old stream controllers
    await _userStreamController.close();
    await _organizationStreamController.close();

    // Create fresh broadcast stream controllers
    _userStreamController = StreamController<User?>.broadcast();
    _organizationStreamController = StreamController<Organization?>.broadcast();

    LoggingService.instance.debug('CurrentUserRepository: Reset complete');
  }

  /// Dispose of resources by closing stream controllers and canceling subscriptions.
  ///
  /// **WARNING**: This should NOT be called by cubits during normal operation.
  /// - Cubits should use [reset()] for logout/switch scenarios
  /// - This method is only for app-level shutdown via [teardown()]
  ///
  /// Calling dispose() directly will close the stream controllers permanently,
  /// preventing any future stream events. Use [teardown()] for app-level cleanup.
  void dispose() {
    unsubscribe();
    _userStreamController.close();
    _organizationStreamController.close();
  }

  /// Teardown the singleton instance entirely (for app-level cleanup).
  /// This should only be called when the app is shutting down or tests are cleaning up.
  static Future<void> teardown() async {
    if (instance != null) {
      LoggingService.instance.debug(
        'CurrentUserRepository: Tearing down singleton instance',
      );
      instance!.dispose();
      instance = null;
    }
  }

}
