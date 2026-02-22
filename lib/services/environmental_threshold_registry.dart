// @tier: community
// NOTE: Registry is community for infrastructure, but threshold UI features
// are pro-gated via FeatureAccessService.
import 'dart:collection';
import 'dart:convert';

import 'package:seafoundry_app/models/environment/environmental_threshold.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:yaml/yaml.dart';

typedef EnvironmentalThresholdRegistryListener = void Function();

class EnvironmentalThresholdRegistry {
  EnvironmentalThresholdRegistry._();

  static final EnvironmentalThresholdRegistry instance =
      EnvironmentalThresholdRegistry._();

  final Map<OrganismKind, List<EnvironmentalThreshold>> _thresholds = {};
  final List<EnvironmentalThresholdRegistryListener> _listeners = [];

  void addListener(EnvironmentalThresholdRegistryListener listener) {
    _listeners.add(listener);
  }

  void removeListener(EnvironmentalThresholdRegistryListener listener) {
    _listeners.remove(listener);
  }

  void registerThreshold(EnvironmentalThreshold threshold) {
    final entries = _thresholds.putIfAbsent(
      threshold.organismKind,
      () => <EnvironmentalThreshold>[],
    );
    entries.removeWhere((existing) => existing.id == threshold.id);
    entries.add(threshold);
    _notify();
  }

  void clearThresholds(OrganismKind organismKind) {
    if (_thresholds.remove(organismKind) != null) {
      _notify();
    }
  }

  /// Clears all thresholds. Used during logout to prevent stale data.
  void reset() {
    if (_thresholds.isNotEmpty) {
      _thresholds.clear();
      _notify();
    }
  }

  List<EnvironmentalThreshold> thresholdsFor({
    required OrganismKind organismKind,
    LifeStage? lifeStage,
    String? metric,
  }) {
    final entries = _thresholds[organismKind];
    if (entries == null) return const <EnvironmentalThreshold>[];
    bool predicate(EnvironmentalThreshold threshold) {
      final lifeStageMatch =
          threshold.lifeStage == null || threshold.lifeStage == lifeStage;
      final metricMatch = metric == null || threshold.metric == metric;
      return lifeStageMatch && metricMatch;
    }

    final filtered = entries.where(predicate).toList()
      ..sort((a, b) => a.metric.compareTo(b.metric));
    return List<EnvironmentalThreshold>.unmodifiable(filtered);
  }

  void loadFromYaml(String yaml, {bool overrideExisting = false}) {
    final document = loadYaml(yaml);
    if (document is! YamlMap) {
      return;
    }
    document.forEach((dynamic key, dynamic value) {
      final kind = OrganismKindX.tryParse(key?.toString());
      if (kind == null || value is! YamlList) {
        return;
      }
      if (overrideExisting) {
        _thresholds.remove(kind);
      }
      for (final entry in value) {
        if (entry is! YamlMap) continue;
        final map = Map<String, dynamic>.from(jsonDecode(jsonEncode(entry)));
        registerThreshold(EnvironmentalThreshold.fromMap(kind, map));
      }
    });
  }

  List<EnvironmentalThreshold> allThresholds() =>
      List.unmodifiable(_thresholds.values.expand((entry) => entry));

  Map<String, List<Map<String, dynamic>>> toSerializableMap() {
    return UnmodifiableMapView({
      for (final entry in _thresholds.entries)
        entry.key.name: entry.value
            .map((threshold) => threshold.toJson())
            .toList(),
    });
  }

  void _notify() {
    for (final listener in List<EnvironmentalThresholdRegistryListener>.from(
      _listeners,
    )) {
      listener();
    }
  }
}
