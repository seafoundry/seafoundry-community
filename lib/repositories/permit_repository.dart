import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seafoundry_app/models/permits/permit.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Repository for managing permit records
class PermitRepository {
  final FirebaseFirestore _firestore;
  final LoggingService _logger;

  PermitRepository({
    required FirebaseFirestore firestore,
    LoggingService? logger,
  }) : _firestore = firestore,
       _logger = logger ?? LoggingService.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(ModelType.permit.collectionPath);

  /// Get active permits for an organization
  Future<List<Permit>> getActivePermits(String orgId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final snapshot = await _collection
          .where('organizationId', isEqualTo: orgId)
          .where('validFrom', isLessThanOrEqualTo: now)
          .where('validTo', isGreaterThanOrEqualTo: now)
          .orderBy('validTo', descending: false)
          .get();

      final permits = <Permit>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          permits.add(Permit.fromJson(data));
        } catch (e) {
          _logger.warning('Failed to parse permit ${doc.id}: $e', e);
        }
      }
      return permits;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active permits for org $orgId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
