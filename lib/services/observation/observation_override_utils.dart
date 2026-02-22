// @tier: community
import 'package:seafoundry_app/models/observation/observation_field_override.dart';

/// Formats an override entry label consistently across services and UI.
String formatOverrideEntryLabel(ObservationFieldOverrideEntry entry) {
  final organism = entry.organismKind.name.toUpperCase();
  final dialogType = entry.dialogType.name;
  final title = entry.title;
  final recordType = entry.recordTypeId?.isNotEmpty == true
      ? ' · ${entry.recordTypeId}'
      : '';
  final lifeStage = entry.lifeStage != null
      ? ' · ${entry.lifeStage!.name}'
      : '';
  return '$organism · $dialogType · $title$recordType$lifeStage';
}

/// Returns the formatted labels for every entry in [document].
List<String> buildOverrideLabels(ObservationFieldOverrideDocument document) {
  return document.entries
      .map(formatOverrideEntryLabel)
      .toSet()
      .toList(growable: false);
}

/// Tokenizes a note/annotation into normalized search tokens.
List<String> tokenizeAnnotation(String? note) {
  if (note == null) return const [];
  final normalized = note.toLowerCase().trim();
  if (normalized.isEmpty) {
    return const [];
  }
  final tokens = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 2)
      .take(20)
      .toList(growable: true);
  if (!tokens.contains(normalized) && normalized.length >= 2) {
    tokens.add(normalized);
  }
  return tokens.toSet().toList(growable: false);
}
