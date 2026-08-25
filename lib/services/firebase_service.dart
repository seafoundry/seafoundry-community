import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Centralized Firebase service that wraps all Firebase instances.
///
/// This service abstracts direct Firebase access and enables dependency injection
/// for better testability and architecture compliance.
///
/// All Firebase operations should go through this service rather than accessing
/// Firebase instances directly (e.g., FirebaseFirestore.instance).
class FirebaseService {
  /// Firestore instance
  final FirebaseFirestore firestore;

  /// Firebase Auth instance
  final fb_auth.FirebaseAuth auth;

  /// Create a FirebaseService with specific instances (for testing)
  FirebaseService({
    FirebaseFirestore? firestore,
    fb_auth.FirebaseAuth? auth,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? fb_auth.FirebaseAuth.instance;

  /// Default instance using Firebase singletons
  static final FirebaseService instance = FirebaseService();
}
