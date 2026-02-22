// @tier: community
import 'dart:collection';
import 'dart:convert';

import 'package:seafoundry_app/models/husbandry/husbandry_schedule_entry.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:yaml/yaml.dart';

typedef HusbandryScheduleRegistryListener = void Function();

class HusbandryScheduleRegistry {
  HusbandryScheduleRegistry._();

  static final HusbandryScheduleRegistry instance =
      HusbandryScheduleRegistry._();

  final Map<OrganismKind, List<HusbandryScheduleEntry>> _entries = {};
  final List<HusbandryScheduleRegistryListener> _listeners = [];

  void addListener(HusbandryScheduleRegistryListener listener) {
    _listeners.add(listener);
  }

  void removeListener(HusbandryScheduleRegistryListener listener) {
    _listeners.remove(listener);
  }

  void registerEntry(HusbandryScheduleEntry entry) {
    final list = _entries.putIfAbsent(
      entry.organismKind,
      () => <HusbandryScheduleEntry>[],
    );
    list.removeWhere((existing) => existing.id == entry.id);
    list.add(entry);
    _notify();
  }

  void clearEntries(OrganismKind kind) {
    if (_entries.remove(kind) != null) {
      _notify();
    }
  }

  /// Clears all entries. Used during logout to prevent stale data.
  void reset() {
    if (_entries.isNotEmpty) {
      _entries.clear();
      _notify();
    }
  }

  List<HusbandryScheduleEntry> entriesFor({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
  }) {
    final list = _entries[organismKind];
    if (list == null) return const <HusbandryScheduleEntry>[];
    bool predicate(HusbandryScheduleEntry entry) {
      return entry.lifeStage == null || entry.lifeStage == lifeStage;
    }

    final filtered = list.where(predicate).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return List.unmodifiable(filtered);
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
      for (final entry in value) {
        if (entry is! YamlMap) continue;
        final map = Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)));
        registerEntry(HusbandryScheduleEntry.fromMap(kind, map));
      }
    });
  }

  Map<String, List<Map<String, dynamic>>> toSerializableMap() {
    return UnmodifiableMapView({
      for (final entry in _entries.entries)
        entry.key.name: entry.value.map((schedule) => schedule.toJson()).toList(),
    });
  }

  List<HusbandryScheduleEntry> allEntries() => List.unmodifiable(
        _entries.values.expand((entry) => entry),
      );

  void _notify() {
    for (final listener in List<HusbandryScheduleRegistryListener>.from(
      _listeners,
    )) {
      listener();
    }
  }
}
