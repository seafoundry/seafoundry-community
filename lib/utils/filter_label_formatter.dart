// @tier: community

import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';

/// Utility for formatting filter labels in spreadsheets and filter bars.
class FilterLabelFormatter {
  FilterLabelFormatter._();

  /// Formats a life stage ID into a display label.
  static String lifeStage(String value) {
    final parsed = LifeStageX.tryParse(value);
    return parsed?.displayName ?? formatGeneric(value);
  }

  /// Formats a provenance type ID into a display label.
  static String provenanceType(String value) {
    final parsed = ProvenanceTypeX.tryParse(value);
    return parsed?.displayName ?? formatGeneric(value);
  }

  /// Formats a raw string ID into a human-readable label.
  /// Converts snake_case and camelCase to Title Case.
  static String formatGeneric(String raw) {
    if (raw.trim().isEmpty) return raw;
    final withSpaces = raw
        .replaceAll(RegExp(r'[_\s]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
    return withSpaces
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
