// @tier: community
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Canonical genet ID resolution service.
/// Centralizes all resolution implementations into one chain:
/// genetRecordId -> foreignKeys['genetRecordId']?.id
class GenetIdResolver {
  /// Resolve genet ID using canonical priority chain.
  static String? resolve(OrganismRecord record) {
    final directId = record.genetRecordId;
    if (directId != null && directId.isNotEmpty) return directId;
    return record.foreignKeys['genetRecordId']?.id;
  }

  /// Resolves genet ID from raw Firestore data.
  /// Use when working with raw maps instead of deserialized models.
  static String? resolveFromJson(Map<String, dynamic> data) {
    final direct = data['genetRecordId'];
    if (direct is String && direct.isNotEmpty) return direct;
    final foreignKeys = data['foreignKeys'];
    if (foreignKeys is Map) {
      final genetEntry = foreignKeys['genetRecordId'];
      if (genetEntry is Map) {
        final id = genetEntry['id'];
        if (id is String && id.isNotEmpty) return id;
      } else if (genetEntry is String && genetEntry.isNotEmpty) {
        return genetEntry;
      }
    }
    return null;
  }

  /// Returns true if the genetRecordId is non-null, non-empty, and not a provenance ID.
  static bool isValid(String? genetRecordId) {
    if (genetRecordId == null || genetRecordId.isEmpty) return false;
    return !_isProvenanceId(genetRecordId) && !_isLegacyProvenanceId(genetRecordId);
  }

  static bool _isProvenanceId(String value) {
    return RegExp(r'^PID-').hasMatch(value);
  }

  static bool _isLegacyProvenanceId(String value) {
    return RegExp(r'^SF-').hasMatch(value);
  }
}
