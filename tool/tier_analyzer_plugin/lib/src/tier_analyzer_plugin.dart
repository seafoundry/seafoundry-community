import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_generated.dart'
    as protocol_generated;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:glob/glob.dart';

class TierAnalyzerPlugin extends ServerPlugin {
  TierAnalyzerPlugin({ResourceProvider? provider})
      : super(
          resourceProvider: provider ?? PhysicalResourceProvider.INSTANCE,
        );

  final Map<String, TierRules> _rulesByRoot = {};

  @override
  String get contactInfo => 'pod-a@seafoundry.org';

  @override
  List<String> get fileGlobsToAnalyze => const ['**/*.dart'];

  @override
  String get name => 'tier_analyzer_plugin';

  @override
  String get version => '0.1.0';

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    if (!path.endsWith('.dart')) {
      return;
    }
    final rules = _rulesForContext(analysisContext);
    final file = resourceProvider.getFile(path);
    if (!file.exists) {
      _publishErrors(path, const []);
      return;
    }
    final rootPath = analysisContext.contextRoot.root.path;
    String relative;
    try {
      relative = p.relative(path, from: rootPath);
    } catch (_) {
      relative = path;
    }
    final normalized = relative.replaceAll('\\', '/');
    final content = file.readAsStringSync();
    final result = rules.analyze(normalized, content);
    final lineInfo = LineInfo.fromContent(content);
    final errors = result.errors
        .map(
          (error) => protocol.AnalysisError(
            error.severity,
            error.type,
            protocol.Location(
              path,
              error.offset,
              error.length,
              lineInfo.getLocation(error.offset).lineNumber,
              lineInfo.getLocation(error.offset).columnNumber,
            ),
            error.message,
            error.code,
          ),
        )
        .toList(growable: false);
    _publishErrors(path, errors);
  }

  @override
  Future<void> beforeContextCollectionDispose({
    required AnalysisContextCollection contextCollection,
  }) async {
    _rulesByRoot.clear();
  }

  TierRules _rulesForContext(AnalysisContext context) {
    final rootPath = context.contextRoot.root.path;
    return _rulesByRoot.putIfAbsent(
      rootPath,
      () => TierRules(resourceProvider, rootPath),
    );
  }

  void _publishErrors(
    String path,
    List<protocol.AnalysisError> errors,
  ) {
    channel.sendNotification(
      protocol_generated.AnalysisErrorsParams(path, errors).toNotification(),
    );
  }
}

class TierRules {
  TierRules(this.resourceProvider, this.rootPath) {
    _loadConfig();
  }

  final ResourceProvider resourceProvider;
  final String rootPath;
  Map<String, List<Glob>> _moduleGlobs = {};
  Map<String, Set<String>> _denyImports = {};
  final Map<String, String?> _fileTierCache = {};

  void _loadConfig() {
    final configPath = p.join(rootPath, 'config', 'tiers.yaml');
    final file = resourceProvider.getFile(configPath);
    if (!file.exists) {
      _moduleGlobs = {};
      _denyImports = {};
      return;
    }
    final yaml = loadYaml(file.readAsStringSync());
    final modules = (yaml['modules'] ?? {}) as YamlMap;
    final moduleMap = <String, List<Glob>>{};
    modules.forEach((key, value) {
      final tier = key.toString();
      final patterns =
          value is YamlList ? List<dynamic>.from(value) : const <dynamic>[];
      moduleMap[tier] = patterns
          .map((pattern) => Glob(pattern.toString()))
          .toList(growable: false);
    });
    _moduleGlobs = moduleMap;

    final rules = yaml['rules'] as YamlMap?;
    final denies = rules?['deny_imports'] as YamlMap?;
    if (denies != null) {
      _denyImports = denies.map((key, value) {
        final tier = key.toString();
        final targets = value is YamlList
            ? value.map((item) => item.toString()).toSet()
            : <String>{};
        return MapEntry(tier, targets);
      });
    } else {
      _denyImports = {};
    }
  }

  TierAnalysisResult analyze(String relativePath, String content) {
    if (_shouldSkip(relativePath)) {
      return TierAnalysisResult(const []);
    }
    final errors = <TierError>[];
    final tier = _extractTier(content);
    if (tier == null) {
      errors.add(
        TierError(
          message: 'Missing @tier annotation on first lines.',
          code: 'tier_header_missing',
          offset: 0,
          length: 0,
          severity: protocol.AnalysisErrorSeverity.ERROR,
          type: protocol.AnalysisErrorType.LINT,
        ),
      );
      return TierAnalysisResult(errors);
    }
    _fileTierCache[relativePath] = tier;

    final requirement = _resolveRequirement(relativePath);
    if (!_meetsRequirement(tier, requirement)) {
      errors.add(
        TierError(
          message:
              'File declared @$tier but path ${requirement.source ?? relativePath} requires ${requirement.tier}.',
          code: 'tier_path_violation',
          offset: 0,
          length: 0,
          severity: protocol.AnalysisErrorSeverity.ERROR,
          type: protocol.AnalysisErrorType.LINT,
        ),
      );
    }

    final denyTargets =
        _denyImports[_normalizeTierForRules(tier)] ?? const <String>{};
    if (denyTargets.isNotEmpty) {
      final dir = p.dirname(relativePath);
      final importPattern = RegExp(r'''(?:import|export)\s+["']([^"']+)["']''');
      for (final match in importPattern.allMatches(content)) {
        final uri = match.group(1)!;
        final offset = match.start;
        final targetRelative = _resolveImport(dir, uri);
        if (targetRelative == null) {
          continue;
        }
        final targetTier =
            _fileTierCache[targetRelative] ?? _readTierFor(targetRelative);
        if (targetTier == null) {
          continue;
        }
        final normalizedTargetTier = _normalizeTierForRules(targetTier);
        if (denyTargets.contains(normalizedTargetTier)) {
          errors.add(
            TierError(
              message:
                  'Tier @$tier file cannot import `$uri` (tier $targetTier).',
              code: 'tier_import_violation',
              offset: offset,
              length: match.group(0)!.length,
              severity: protocol.AnalysisErrorSeverity.ERROR,
              type: protocol.AnalysisErrorType.LINT,
            ),
          );
        }
      }
    }

    return TierAnalysisResult(errors);
  }

  String? _extractTier(String content) {
    final lines = content.split('\n');
    final searchLength = lines.length < 5 ? lines.length : 5;
    final regex = RegExp(r'@tier:\s*(\w+)', caseSensitive: false);
    for (var i = 0; i < searchLength; i++) {
      final match = regex.firstMatch(lines[i]);
      if (match != null) {
        return match.group(1)!.toLowerCase();
      }
    }
    return null;
  }

  TierRequirement _resolveRequirement(String relativePath) {
    String? matched;
    if (_matches('scale', relativePath, (pattern) => matched = pattern)) {
      return TierRequirement('scale', matched);
    }
    if (_matches('pro', relativePath, (pattern) => matched = pattern)) {
      return TierRequirement('pro', matched);
    }
    return TierRequirement('community', matched);
  }

  bool _matches(
      String tier, String relativePath, void Function(String pattern) onMatch) {
    final globs = _moduleGlobs[tier];
    if (globs == null) return false;
    for (final glob in globs) {
      if (glob.matches(relativePath)) {
        onMatch(glob.pattern);
        return true;
      }
    }
    return false;
  }

  bool _meetsRequirement(String declared, TierRequirement requirement) {
    const ranks = {'community': 0, 'pro': 1, 'scale': 2};
    final declaredRank = ranks[declared] ?? 0;
    final requiredRank = ranks[requirement.tier] ?? 0;
    return declaredRank >= requiredRank;
  }

  String _normalizeTierForRules(String tier) {
    return tier == 'shared' ? 'community' : tier;
  }

  bool _shouldSkip(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.mocks.dart');
  }

  String? _resolveImport(String fromDir, String uri) {
    if (uri.startsWith('dart:') || uri.startsWith('package:flutter')) {
      return null;
    }
    String candidate;
    if (uri.startsWith('package:seafoundry_app/')) {
      final relative = uri.substring('package:seafoundry_app/'.length);
      candidate = p.normalize(p.join('lib', relative));
    } else if (uri.startsWith('package:')) {
      return null;
    } else {
      candidate = p.normalize(p.join(fromDir, uri));
    }
    final absolute = p.join(rootPath, candidate);
    if (!resourceProvider.getFile(absolute).exists) {
      return null;
    }
    return candidate.replaceAll('\\', '/');
  }

  String? _readTierFor(String relativePath) {
    final absolute = p.join(rootPath, relativePath);
    final file = resourceProvider.getFile(absolute);
    if (!file.exists) return null;
    final content = file.readAsStringSync();
    final tier = _extractTier(content);
    _fileTierCache[relativePath] = tier;
    return tier;
  }
}

class TierAnalysisResult {
  TierAnalysisResult(this.errors);
  final List<TierError> errors;
}

class TierError {
  TierError({
    required this.message,
    required this.code,
    required this.offset,
    required this.length,
    required this.severity,
    required this.type,
  });

  final String message;
  final String code;
  final int offset;
  final int length;
  final protocol.AnalysisErrorSeverity severity;
  final protocol.AnalysisErrorType type;
}

class TierRequirement {
  const TierRequirement(this.tier, this.source);
  final String tier;
  final String? source;
}
