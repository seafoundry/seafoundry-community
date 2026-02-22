// @tier: community
import 'dart:collection';
import 'dart:convert';

import 'package:seafoundry_app/models/mortality/mortality_cause_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:yaml/yaml.dart';

typedef MortalityCauseRegistryListener = void Function();

class MortalityCauseRegistry {
  MortalityCauseRegistry._();

  static final MortalityCauseRegistry instance = MortalityCauseRegistry._();

  final Map<OrganismKind, List<MortalityCauseEntry>> _entries = {};
  final List<MortalityCauseRegistryListener> _listeners = [];

  void addListener(MortalityCauseRegistryListener listener) {
    _listeners.add(listener);
  }

  void removeListener(MortalityCauseRegistryListener listener) {
    _listeners.remove(listener);
  }

  void registerEntry(MortalityCauseEntry entry) {
    final list = _entries.putIfAbsent(
      entry.organismKind,
      () => <MortalityCauseEntry>[],
    );
    list.removeWhere((existing) => existing.id == entry.id);
    list.add(entry);
    _notifyListeners();
  }

  void clearEntries(OrganismKind kind) {
    if (_entries.remove(kind) != null) {
      _notifyListeners();
    }
  }

  /// Clears all entries. Used during logout to prevent stale data.
  void reset() {
    if (_entries.isNotEmpty) {
      _entries.clear();
      _notifyListeners();
    }
  }

  List<MortalityCauseEntry> causesFor({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
  }) {
    final list = _entries[organismKind];
    if (list == null || list.isEmpty) {
      return const <MortalityCauseEntry>[];
    }
    final filtered = lifeStage == null
        ? list
        : list.where(
            (entry) =>
                entry.lifeStage == null || entry.lifeStage == lifeStage,
          );
    return List.unmodifiable(
      filtered.toList()
        ..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        ),
    );
  }

  void loadFromYaml(String yaml, {bool overrideExisting = false}) {
    final document = loadYaml(yaml);
    if (document is! YamlMap) return;
    document.forEach((dynamic key, dynamic value) {
      final kind = OrganismKindX.tryParse(key?.toString());
      if (kind == null || value is! YamlList) return;
      if (overrideExisting) {
        _entries.remove(kind);
      }
      for (final item in value) {
        if (item is! YamlMap) continue;
        final map = Map<String, dynamic>.from(jsonDecode(jsonEncode(item)));
        registerEntry(MortalityCauseEntry.fromMap(kind, map));
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> toSerializableMap() {
    return UnmodifiableMapView({
      for (final entry in _entries.entries)
        entry.key.name: entry.value.map((cause) => cause.toJson()).toList(),
    });
  }

  void _notifyListeners() {
    for (final listener in List<MortalityCauseRegistryListener>.from(
      _listeners,
    )) {
      listener();
    }
  }
}
