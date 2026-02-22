import 'dart:collection';
import 'dart:io';

import 'package:yaml/yaml.dart';

enum Tier { community, pro, scale }

class TierFieldRegistry {
  TierFieldRegistry({String? configPath})
    : _configPath = configPath ?? 'config/tier_fields.yaml';

  final String _configPath;
  Map<String, _TierPolicy>? _policies;

  void load() {
    final file = File(_configPath);
    if (!file.existsSync()) {
      _policies = {};
      return;
    }
    final yaml = loadYaml(file.readAsStringSync());
    final models = yaml is YamlMap ? yaml['models'] : null;
    if (models is! YamlMap) {
      _policies = {};
      return;
    }
    final parsed = <String, _TierPolicy>{};
    models.forEach((dynamic key, dynamic value) {
      if (key == null) return;
      if (value is YamlMap) {
        parsed[key.toString()] = _TierPolicy.fromYaml(value);
      }
    });
    _policies = parsed;
  }

  Map<String, dynamic> filter(
    String model,
    Map<String, dynamic> payload,
    Tier tier,
  ) {
    final policy = _policies?[model];
    if (policy == null) return payload;
    final allowed = policy.allowedFields(tier);
    if (allowed == null || allowed.isEverything) {
      return payload;
    }
    final filtered = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (allowed.contains(entry.key)) {
        filtered[entry.key] = entry.value;
      }
    }
    return filtered;
  }
}

class _TierPolicy {
  _TierPolicy({
    required this.community,
    required this.pro,
    required this.scale,
  });

  factory _TierPolicy.fromYaml(YamlMap yaml) {
    Set<String> readList(dynamic node) {
      if (node is YamlList) {
        return LinkedHashSet<String>.from(
          node.map((value) => value.toString()),
        );
      }
      return <String>{};
    }

    return _TierPolicy(
      community: readList(yaml['community'] ?? yaml['shared']),
      pro: readList(yaml['pro']),
      scale: readList(yaml['scale']),
    );
  }

  final Set<String> community;
  final Set<String> pro;
  final Set<String> scale;

  _AllowedFields? allowedFields(Tier tier) {
    final allowed = LinkedHashSet<String>.from(community);
    if (allowed.contains('*')) {
      return const _AllowedFields.all();
    }
    if (tier == Tier.pro || tier == Tier.scale) {
      allowed.addAll(pro);
    }
    if (tier == Tier.scale) {
      allowed.addAll(scale);
    }
    if (allowed.isEmpty) {
      return null;
    }
    return _AllowedFields(allowed);
  }
}

class _AllowedFields {
  const _AllowedFields(this._fields) : isEverything = false;
  const _AllowedFields.all()
    : _fields = const {},
      isEverything = true;

  final Set<String> _fields;
  final bool isEverything;

  bool contains(String key) {
    if (isEverything) return true;
    if (_fields.contains(key)) return true;
    for (final entry in _fields) {
      if (entry.endsWith('*')) {
        final prefix = entry.substring(0, entry.length - 1);
        if (prefix.isEmpty || key.startsWith(prefix)) {
          return true;
        }
      }
    }
    return false;
  }
}
