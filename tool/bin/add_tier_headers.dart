import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  final adder = TierHeaderAdder();
  final updated = await adder.run();
  stdout.writeln('Added tier headers to $updated file(s).');
}

class TierHeaderAdder {
  TierHeaderAdder() {
    _loadConfig();
  }

  final _moduleGlobs = <String, List<Glob>>{};
  final _root = Directory.current.path;

  Future<int> run() async {
    var updatedCount = 0;
    final libDir = Directory(p.join(_root, 'lib'));
    await for (final entity
        in libDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_shouldSkip(entity.path)) continue;
      final content = await entity.readAsString();
      if (_hasTierHeader(content)) {
        continue;
      }
      final relative = _toPosixPath(p.relative(entity.path, from: _root));
      final tier = _resolveTier(relative);
      final newContent = '// @tier: $tier\n$content';
      await entity.writeAsString(newContent);
      updatedCount++;
    }
    return updatedCount;
  }

  void _loadConfig() {
    final configFile = File(p.join(_root, 'config', 'tiers.yaml'));
    if (!configFile.existsSync()) {
      throw StateError('Missing config/tiers.yaml');
    }
    final yaml = loadYaml(configFile.readAsStringSync());
    final modules = (yaml['modules'] ?? const {}) as YamlMap;
    for (final entry in modules.entries) {
      final tier = entry.key.toString();
      final rawPatterns = entry.value is YamlList
          ? List<dynamic>.from(entry.value as YamlList)
          : const <dynamic>[];
      _moduleGlobs[tier] = rawPatterns
          .map((pattern) => Glob(pattern.toString()))
          .toList(growable: false);
    }
  }

  bool _hasTierHeader(String content) {
    final lines = content.split('\n');
    final searchLength = lines.length < 5 ? lines.length : 5;
    for (var i = 0; i < searchLength; i++) {
      if (lines[i].contains('@tier')) {
        return true;
      }
    }
    return false;
  }

  bool _shouldSkip(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart');
  }

  String _resolveTier(String relativePath) {
    if (_matches('scale', relativePath)) return 'scale';
    if (_matches('pro', relativePath)) return 'pro';
    return 'community';
  }

  bool _matches(String tier, String relativePath) {
    final globs = _moduleGlobs[tier];
    if (globs == null) return false;
    for (final glob in globs) {
      if (glob.matches(relativePath)) {
        return true;
      }
    }
    return false;
  }

  String _toPosixPath(String path) {
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }
}
