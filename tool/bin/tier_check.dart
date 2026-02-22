import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _tierRank = {
  'shared': -1,
  'community': 0,
  'pro': 1,
  'scale': 2,
};

const _seafoundryPackagePrefix = 'package:seafoundry_app/';

Future<void> main(List<String> args) async {
  final checker = TierChecker();
  final errors = await checker.run();
  if (errors.isNotEmpty) {
    stderr.writeln('Tier checker found ${errors.length} issue(s):');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Tier checker passed.');
}

class TierChecker {
  TierChecker() {
    _loadConfig();
  }

  final _moduleGlobs = <String, List<Glob>>{};
  final _denyImports = <String, Set<String>>{};
  final _fileInfos = <String, TieredFile>{};
  final _errors = <String>[];
  final _root = Directory.current.path;

  Future<List<String>> run() async {
    await _scanFiles();
    _validateImports();
    return _errors;
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

    final rules = yaml['rules'] as YamlMap?;
    final denies = rules?['deny_imports'] as YamlMap?;
    if (denies != null) {
      for (final entry in denies.entries) {
        final tier = entry.key.toString();
        final targets = entry.value is YamlList
            ? (entry.value as YamlList)
                .map((e) => e.toString())
                .toSet()
            : <String>{};
        _denyImports[tier] = targets;
      }
    }
  }

  Future<void> _scanFiles() async {
    final libDir = Directory(p.join(_root, 'lib'));
    await for (final entity
        in libDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_shouldSkip(entity.path)) continue;
      final relative = _toPosixPath(p.relative(entity.path, from: _root));
      final content = await entity.readAsString();
      final headerTier = _extractTier(content);
      if (headerTier == null) {
        _errors.add('Missing @tier annotation in $relative');
        continue;
      }
      if (!_tierRank.containsKey(headerTier)) {
        _errors.add('Unknown tier "$headerTier" in $relative');
        continue;
      }

      final requirement = _resolveRequirement(relative);
      if (!_meetsTier(headerTier, requirement.tier)) {
        final reqMsg = requirement.source == null
            ? 'requires at least ${requirement.tier}'
            : 'matches ${requirement.source} which requires ${requirement.tier} tier';
        _errors.add(
          'File $relative declared @$headerTier but $reqMsg.',
        );
      }

      final imports = _resolveImports(relative, content);
      _fileInfos[relative] = TieredFile(
        path: relative,
        tier: headerTier,
        requirement: requirement,
        imports: imports,
      );
    }
  }

  void _validateImports() {
    for (final file in _fileInfos.values) {
      final fileTier = _normalizeTierForRules(file.tier);
      final denied = _denyImports[fileTier];
      if (denied == null || denied.isEmpty) continue;

      for (final importRef in file.imports) {
        final target = importRef.targetPath;
        if (target == null) continue;
        final targetFile = _fileInfos[target];
        final targetTier = targetFile?.tier ??
            _resolveRequirement(target).tier;
        final targetNormalized = _normalizeTierForRules(targetTier);
        if (denied.contains(targetNormalized)) {
          _errors.add(
            '${file.path} (tier ${file.tier}) may not import '
            '${importRef.uri} (tier $targetTier)',
          );
        }
      }
    }
  }

  bool _shouldSkip(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart');
  }

  String? _extractTier(String content) {
    final lines = content.split('\n');
    final tierRegex = RegExp(r'//\s*@tier:\s*(\w+)', caseSensitive: false);
    final searchLength = lines.length < 10 ? lines.length : 10;
    for (var i = 0; i < searchLength; i++) {
      final match = tierRegex.firstMatch(lines[i]);
      if (match != null) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  TierRequirement _resolveRequirement(String relativePath) {
    String? matchedSource;
    String tier = 'community';

    bool matchesTier(String candidateTier) {
      final globs = _moduleGlobs[candidateTier];
      if (globs == null) return false;
      for (final glob in globs) {
        if (glob.matches(relativePath)) {
          matchedSource = glob.pattern;
          tier = candidateTier;
          return true;
        }
      }
      return false;
    }

    if (matchesTier('scale')) {
      return TierRequirement('scale', matchedSource);
    }
    if (matchesTier('pro')) {
      return TierRequirement('pro', matchedSource);
    }
    return TierRequirement(tier, matchedSource);
  }

  bool _meetsTier(String declared, String required) {
    final declaredRank = _tierRank[declared];
    final requiredRank = _tierRank[required] ?? 0;
    if (declaredRank == null) return false;
    return declaredRank >= requiredRank;
  }

  List<ImportRef> _resolveImports(String relativePath, String content) {
    final imports = <ImportRef>[];
    final pattern = RegExp(r'''(?:import|export)\s+["']([^"']+)["']''');
    final matches = pattern.allMatches(content);
    final fileDir = p.dirname(relativePath);
    for (final match in matches) {
      final uri = match.group(1)!;
      final target = _resolveImportTarget(uri, fileDir);
      imports.add(ImportRef(uri: uri, targetPath: target));
    }
    return imports;
  }

  String? _resolveImportTarget(String uri, String fromDir) {
    if (uri.startsWith('dart:') || uri.startsWith('package:flutter')) {
      return null;
    }
    String candidate;
    if (uri.startsWith(_seafoundryPackagePrefix)) {
      final relative = uri.substring(_seafoundryPackagePrefix.length);
      candidate = p.normalize(p.join('lib', relative));
    } else if (uri.startsWith('package:')) {
      return null;
    } else {
      candidate = p.normalize(p.join(fromDir, uri));
    }
    final normalized = _toPosixPath(candidate);
    final absolute = p.join(_root, normalized);
    if (!File(absolute).existsSync()) {
      return null;
    }
    if (_shouldSkip(normalized)) {
      return null;
    }
    return normalized;
  }

  String _normalizeTierForRules(String tier) {
    return tier == 'shared' ? 'community' : tier;
  }

  String _toPosixPath(String path) {
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    return normalized;
  }
}

class TieredFile {
  const TieredFile({
    required this.path,
    required this.tier,
    required this.requirement,
    required this.imports,
  });

  final String path;
  final String tier;
  final TierRequirement requirement;
  final List<ImportRef> imports;
}

class TierRequirement {
  const TierRequirement(this.tier, this.source);

  final String tier;
  final String? source;
}

class ImportRef {
  const ImportRef({required this.uri, required this.targetPath});

  final String uri;
  final String? targetPath;
}
