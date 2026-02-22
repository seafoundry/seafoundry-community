// @tier: community
import 'dart:convert';

import 'package:yaml/yaml.dart' as y;

/// Registry for action -> required training modules mapping.
///
/// Loads defaults from a bundled YAML and optionally merges organization
/// overrides from Firestore (passed in as raw YAML string by caller).
class TrainingGateRegistry {
  TrainingGateRegistry._();
  static final TrainingGateRegistry instance = TrainingGateRegistry._();

  Map<String, List<String>> _actionToModules = const {};

  /// Clears all mappings. Used during logout to prevent stale data.
  void reset() {
    _actionToModules = const {};
  }

  /// Returns the required modules for an action code.
  List<String> requiredModulesFor(String actionCode) {
    final mods = _actionToModules[actionCode];
    return mods == null ? const [] : List<String>.unmodifiable(mods);
    }

  /// Load mapping from YAML text. When [overrideExisting] is true, values in
  /// the YAML replace existing entries; when false, entries merge and
  /// deduplicate.
  void loadFromYaml(String yaml, {bool overrideExisting = false}) {
    final parsed = _parseYaml(yaml);
    if (overrideExisting || _actionToModules.isEmpty) {
      _actionToModules = parsed;
      return;
    }
    final merged = <String, List<String>>{}..addAll(_actionToModules);
    parsed.forEach((action, modules) {
      final current = merged[action] ?? const <String>[];
      final combined = {...current, ...modules}.toList();
      merged[action] = combined;
    });
    _actionToModules = merged;
  }

  Map<String, List<String>> _parseYaml(String yaml) {
    final doc = y.loadYaml(yaml);
    final dynamicJson = json.decode(json.encode(doc));
    if (dynamicJson is! Map) return const {};
    final out = <String, List<String>>{};
    dynamicJson.forEach((key, value) {
      if (key is String) {
        if (value is List) {
          out[key] = value.map((e) => e.toString()).toList();
        } else if (value is String) {
          out[key] = [value];
        }
      }
    });
    return out;
  }
}

