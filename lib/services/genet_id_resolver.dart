// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Canonical genet ID resolution service.
/// Centralizes all resolution implementations into one chain:
/// genetId -> foreignKeys['genetId']?.id
class GenetIdResolver {
  /// Resolve genet ID using canonical priority chain.
  static String? resolve(OrganismRecord record) {
    final directId = record.genetId;
    if (directId != null && directId.isNotEmpty) return directId;
    return record.foreignKeys['genetId']?.id;
  }

  /// Resolves the genet ID, filtering out provenance IDs.
  /// Use this when a Firestore document ID is needed (not a display value).
  static String? resolveDocumentId(OrganismRecord record) {
    final id = resolve(record);
    if (id == null || id.isEmpty) return null;
    return isValid(id) ? id : null;
  }

  /// Resolves genet ID from raw Firestore data.
  /// Use when working with raw maps instead of deserialized models.
  static String? resolveFromJson(Map<String, dynamic> data) {
    final direct = data['genetId'];
    if (direct is String && direct.isNotEmpty) return direct;
    final foreignKeys = data['foreignKeys'];
    if (foreignKeys is Map) {
      final genetEntry = foreignKeys['genetId'];
      if (genetEntry is Map) {
        final id = genetEntry['id'];
        if (id is String && id.isNotEmpty) return id;
      } else if (genetEntry is String && genetEntry.isNotEmpty) {
        return genetEntry;
      }
    }
    return null;
  }

  /// Returns true if the genetId is non-null, non-empty, and not a provenance ID.
  static bool isValid(String? genetId) {
    if (genetId == null || genetId.isEmpty) return false;
    return !_isProvenanceId(genetId) && !_isLegacyProvenanceId(genetId);
  }

  /// Throws StateError if top-level genetId and foreignKeys['genetId'] diverge.
  static void assertConsistency(OrganismRecord record) {
    final topLevel = record.genetId;
    final fkGenetId = record.foreignKeys['genetId']?.id;
    if (topLevel != null &&
        topLevel.isNotEmpty &&
        fkGenetId != null &&
        fkGenetId.isNotEmpty &&
        topLevel != fkGenetId) {
      throw StateError(
        'genetId inconsistency: top-level=$topLevel, foreignKeys=$fkGenetId',
      );
    }
  }

  static bool _isProvenanceId(String value) {
    return RegExp(r'^PID-').hasMatch(value);
  }

  static bool _isLegacyProvenanceId(String value) {
    return RegExp(r'^SF-').hasMatch(value);
  }
}
