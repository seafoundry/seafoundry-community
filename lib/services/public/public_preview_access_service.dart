// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

enum PreviewAccessBlockReason { unauthenticated, wrongOrganization }

class PreviewAccessDecision {
  const PreviewAccessDecision._({
    required this.allowed,
    required this.pending,
    this.reason,
    this.userId,
  });

  const PreviewAccessDecision.allowed({String? userId})
    : this._(allowed: true, pending: false, userId: userId);

  const PreviewAccessDecision.pending() : this._(allowed: false, pending: true);

  const PreviewAccessDecision.blocked(PreviewAccessBlockReason reason)
    : this._(allowed: false, pending: false, reason: reason);

  final bool allowed;
  final bool pending;
  final PreviewAccessBlockReason? reason;
  final String? userId;
}

/// Validates that preview mode is restricted to org admins.
class PublicPreviewAccessService {
  PublicPreviewAccessService({
    FirebaseFirestore? firestore,
    fbAuth.FirebaseAuth? auth,
    LoggingService? logger,
    FirestoreCollectionResolver? resolver,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? fbAuth.FirebaseAuth.instance,
       _logger = logger ?? LoggingService.instance,
       _resolver = resolver ?? FirestoreCollectionResolver.instance;

  final FirebaseFirestore _firestore;
  final fbAuth.FirebaseAuth _auth;
  final LoggingService _logger;
  final FirestoreCollectionResolver _resolver;

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveUserDoc(
    fbAuth.User user,
  ) async {
    final users = _resolver.collection(_firestore, 'users');
    final uid = user.uid.trim();
    if (uid.isEmpty) {
      return null;
    }
    final userDoc = await users.doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc;
    }
    return null;
  }

  Future<PreviewAccessDecision> evaluate(String organizationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const PreviewAccessDecision.blocked(
        PreviewAccessBlockReason.unauthenticated,
      );
    }

    try {
      final snap = await _resolveUserDoc(user);
      final data = snap?.data();
      if (data == null) {
        return const PreviewAccessDecision.blocked(
          PreviewAccessBlockReason.wrongOrganization,
        );
      }
      final userOrgId = data['organizationId'] as String?;
      final isAdmin = data['role'] == 'admin';
      if (userOrgId != organizationId || !isAdmin) {
        return const PreviewAccessDecision.blocked(
          PreviewAccessBlockReason.wrongOrganization,
        );
      }
      return PreviewAccessDecision.allowed(userId: snap?.id);
    } catch (error) {
      _logger.error('Failed to evaluate preview access', error);
      return const PreviewAccessDecision.blocked(
        PreviewAccessBlockReason.wrongOrganization,
      );
    }
  }
}
