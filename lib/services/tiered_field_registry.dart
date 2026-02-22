// @tier: community
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/tier.dart';
import 'package:seafoundry_app/services/tiered_field_config_loader.dart';

/// Loads tier-specific field policies from `config/tier_fields.yaml` and
/// provides helpers to filter payloads for Community/Pro/Scale exports.
class TieredFieldRegistry {
  TieredFieldRegistry._();

  static final TieredFieldRegistry instance = TieredFieldRegistry._();

  Map<String, _TierFieldPolicy>? _policies;
  Future<void>? _pendingLoad;

  /// Ensures the YAML config is loaded before performing tier-based filtering.
  Future<void> ensureInitialized() {
    if (_policies != null) {
      return Future.value();
    }
    _pendingLoad ??= _loadFromAsset();
    return _pendingLoad!;
  }

  Future<void> _loadFromAsset() async {
    try {
      final yaml = await rootBundle.loadString('config/tier_fields.yaml');
      _policies = _parseYaml(yaml);
      return;
    } catch (error) {
      if (kDebugMode) {
        LoggingService.instance.warning(
          'Failed loading tier fields config from asset bundle: $error',
        );
      }
    }

    final diskYaml = await loadTierFieldConfigFromDisk();
    if (diskYaml != null) {
      _policies = _parseYaml(diskYaml);
    } else {
      if (kDebugMode) {
        LoggingService.instance.warning('Tier fields config not found; applying empty policy set.');
      }
      _policies = {};
    }
  }

  Map<String, dynamic> filterFields({
    required String model,
    required Map<String, dynamic> payload,
    required Tier tier,
  }) {
    final policy = _policies?[model];
    if (policy == null) {
      return payload;
    }
    final allowed = policy.allowedFieldsFor(tier);
    if (allowed == null) {
      return payload;
    }
    if (allowed.isEverything) {
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

  Map<String, _TierFieldPolicy> _parseYaml(String yaml) {
    final decoded = loadYaml(yaml);
    final modelsNode = decoded is YamlMap ? decoded['models'] : null;
    if (modelsNode is! YamlMap) {
      return {};
    }
    final policies = <String, _TierFieldPolicy>{};
    modelsNode.forEach((dynamic key, dynamic value) {
      final modelName = key.toString();
      if (value is YamlMap) {
        policies[modelName] = _TierFieldPolicy.fromYaml(value);
      }
    });
    return policies;
  }
}

class _TierFieldPolicy {
  _TierFieldPolicy({
    required this.community,
    required this.pro,
    required this.scale,
  });

  factory _TierFieldPolicy.fromYaml(YamlMap yaml) {
    Set<String> readTier(dynamic node) {
      if (node is YamlList) {
        return LinkedHashSet<String>.from(
          node.map((value) => value.toString()),
        );
      }
      return <String>{};
    }

    return _TierFieldPolicy(
      community: readTier(yaml['community'] ?? yaml['shared']),
      pro: readTier(yaml['pro']),
      scale: readTier(yaml['scale']),
    );
  }

  final Set<String> community;
  final Set<String> pro;
  final Set<String> scale;

  _AllowedFieldSet? allowedFieldsFor(Tier tier) {
    final allowed = LinkedHashSet<String>.from(community);
    if (allowed.contains('*')) {
      return const _AllowedFieldSet.all();
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
    return _AllowedFieldSet(allowed);
  }
}

class _AllowedFieldSet {
  const _AllowedFieldSet(this._exact) : isEverything = false;
  const _AllowedFieldSet.all()
    : _exact = const {},
      isEverything = true;

  final Set<String> _exact;
  final bool isEverything;

  bool contains(String key) {
    if (isEverything) return true;
    if (_exact.contains(key)) return true;
    for (final entry in _exact) {
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
