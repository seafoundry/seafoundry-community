// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing beta signup records.
///
/// Beta signups are stored in a top-level `beta_signups` collection
/// and are not organization-scoped (they're public interest signups).
class BetaSignupRepository {
  BetaSignupRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  })  : _firestore = firestore,
        _logger = logger ?? LoggingService.instance;

  final FirebaseFirestore _firestore;
  final LoggingService _logger;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('beta_signups');

  /// Record a beta signup interest.
  ///
  /// [email] - The email address of the interested user
  /// [featureInterest] - Optional feature name they're interested in
  /// [source] - Source of the signup (e.g., 'upgrade_cta', 'upgrade_dialog')
  Future<void> recordSignup({
    required String email,
    String? featureInterest,
    String source = 'upgrade_cta',
  }) async {
    try {
      await _collection.add({
        'email': email.toLowerCase().trim(),
        'featureInterest': featureInterest ?? 'upgrade',
        'createdAt': FieldValue.serverTimestamp(),
        'source': source,
      });

      _logger.info(
        'Beta signup recorded',
        {'email': email, 'feature': featureInterest},
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to record beta signup', e, stackTrace);
      rethrow;
    }
  }
}
