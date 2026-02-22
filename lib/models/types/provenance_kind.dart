// @tier: community
import 'package:collection/collection.dart';

/// Identifies the type of provenance record captured in Firestore.
/// This is a legacy lineage bucket; newer workflows map provenance types
/// (founder/cohort/graduated individual) onto these values.
enum ProvenanceKind { genet, broodstock, donorMeadow, hatcheryLot, cohort }

extension ProvenanceKindX on ProvenanceKind {
  static ProvenanceKind fromName(String value) {
    final normalized = value.trim().toLowerCase();
    return ProvenanceKind.values.firstWhere(
      (kind) => kind.name.toLowerCase() == normalized,
      orElse: () {
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported provenanceKind. Expected one of: '
              '${ProvenanceKind.values.map((k) => k.name).join(', ')}',
        );
      },
    );
  }

  static ProvenanceKind? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return ProvenanceKind.values.firstWhereOrNull(
      (kind) => kind.name.toLowerCase() == value.trim().toLowerCase(),
    );
  }
}
