// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/user.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/utils/user_identity.dart';

/// Repository responsible for authentication and user/organization verification
class AuthRepository {
  final fbAuth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseService? firebaseService,
    fbAuth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth =
           firebaseAuth ??
           firebaseService?.auth ??
           fbAuth.FirebaseAuth.instance,
       _firestore =
           firestore ??
           firebaseService?.firestore ??
           (throw ArgumentError(
             'FirebaseFirestore must be provided via firestore parameter or FirebaseService',
           ));

  /// Stream of authentication state changes
  Stream<fbAuth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Current Firebase user
  fbAuth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  String _resolveUserDocId(String userId) {
    return UserIdentity.normalizeUserDocId(userId);
  }

  /// Sign in with email and password
  Future<fbAuth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password
  Future<fbAuth.UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }


  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Sign in with credential (for Google Sign In)
  Future<fbAuth.UserCredential> signInWithCredential(
    fbAuth.AuthCredential credential,
  ) async {
    return await _firebaseAuth.signInWithCredential(credential);
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    return await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Check if a user exists in the database
  Future<User?> getUser(String userId) async {
    try {
      final docId = _resolveUserDocId(userId);
      if (docId.isEmpty) return null;
      final doc = await _firestore
          .collection('users')
          .doc(docId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || data.isEmpty) {
        LoggingService.instance.warning(
          'Document ${doc.id} exists but has empty data',
          {'collection': 'users', 'docId': doc.id},
        );
        return null;
      }
      final normalized = deepNormalizeMap(data);
      normalized['id'] = doc.id;
      return User.fromJson(normalized);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Get the organization for a user
  Future<Organization?> getUserOrganization(String userId) async {
    try {
      final docId = _resolveUserDocId(userId);
      if (docId.isEmpty) return null;
      final userDoc = await _firestore
          .collection('users')
          .doc(docId)
          .get();
      if (!userDoc.exists) return null;
      final userData = userDoc.data();
      if (userData == null) return null;
      final organizationId = userData['organizationId'] as String?;
      if (organizationId == null) return null;

      final orgDoc = await _firestore
          .collection('organizations')
          .doc(organizationId)
          .get();

      if (!orgDoc.exists) return null;

      final orgData = orgDoc.data();
      if (orgData == null) {
        LoggingService.instance.warning(
          'Document ${orgDoc.id} exists but has null data',
          {'collection': 'organizations', 'docId': orgDoc.id},
        );
        return null;
      }
      final normalizedOrg = deepNormalizeMap(orgData);
      normalizedOrg['id'] = orgDoc.id;
      return Organization.fromJson(normalizedOrg);
    } catch (e) {
      throw Exception('Failed to get user organization: $e');
    }
  }

  /// Stream of user changes
  Stream<User?> userStream(String userId) {
    final docId = _resolveUserDocId(userId);
    return _firestore.collection('users').doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null) {
        LoggingService.instance.warning(
          'Document ${snapshot.id} exists but has null data',
          {'collection': 'users', 'docId': snapshot.id},
        );
        return null;
      }
      final normalized = deepNormalizeMap(data);
      normalized['id'] = snapshot.id;
      return User.fromJson(normalized);
    });
  }

  /// Determine if the current user needs onboarding
  Future<bool> needsOnboarding(String uid) async {
    final user = await getUser(uid);
    if (user == null) return true;

    final organization = await getUserOrganization(uid);
    return organization == null;
  }
}
