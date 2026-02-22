#!/usr/bin/env dart
// Script to audit Flutter widgets for potential memory leaks from undisposed controllers

// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:io';

void main() {
  print('Memory Leak Audit - Controller Disposal\n');
  print('=' * 60);

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib directory not found');
    exit(1);
  }

  final issues = <Issue>[];

  // Find all Dart files in lib/
  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  print('Scanning ${dartFiles.length} Dart files...\n');

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    final lines = content.split('\n');

    // Skip files that clearly don't declare State classes
    if (!content.contains('extends State<') &&
        !content.contains('extends StatefulWidget') &&
        !content.contains('StreamSubscription') &&
        !content.contains('FocusNode') &&
        !content.contains('TextEditingController')) {
      continue;
    }

    final fileIssues = _analyzeFile(file.path, content, lines);
    issues.addAll(fileIssues);
  }

  final issuesByFile = <String, List<Issue>>{};
  for (final issue in issues) {
    issuesByFile.putIfAbsent(issue.file, () => []).add(issue);
  }

  if (issues.isEmpty) {
    print('✅ No memory leak issues found!');
  } else {
    print('⚠️  Found ${issues.length} potential memory leak issues:\n');

    for (final entry in issuesByFile.entries) {
      print('📄 ${entry.key}');
      for (final issue in entry.value) {
        print('   ${issue.severity} Line ${issue.line}: ${issue.message}');
      }
      print('');
    }
  }

  print('=' * 60);
  print(
    '\nAudit complete. Review the issues above and fix controller disposal.',
  );
}

final _resourceTypes = <ResourceType>[
  ResourceType(
    name: 'TextEditingController',
    constructorPatterns: [r'TextEditingController'],
    disposeMethods: ['dispose'],
    supportsMap: true,
  ),
  ResourceType(
    name: 'FocusNode',
    constructorPatterns: [r'FocusNode'],
    disposeMethods: ['dispose'],
    supportsMap: true,
  ),
  ResourceType(
    name: 'ScrollController',
    constructorPatterns: [r'ScrollController'],
    disposeMethods: ['dispose'],
    supportsMap: false,
  ),
  ResourceType(
    name: 'PageController',
    constructorPatterns: [r'PageController'],
    disposeMethods: ['dispose'],
  ),
  ResourceType(
    name: 'TabController',
    constructorPatterns: [r'TabController'],
    disposeMethods: ['dispose'],
  ),
  ResourceType(
    name: 'AnimationController',
    constructorPatterns: [r'AnimationController'],
    disposeMethods: ['dispose'],
  ),
  ResourceType(
    name: 'StreamController',
    constructorPatterns: [r'StreamController'],
    disposeMethods: ['close'],
  ),
  ResourceType(
    name: 'StreamSubscription',
    constructorPatterns: [r'StreamSubscription'],
    disposeMethods: ['cancel'],
  ),
  ResourceType(
    name: 'Timer',
    constructorPatterns: [r'Timer(?:\.\w+)?'],
    disposeMethods: ['cancel'],
  ),
  ResourceType(
    name: 'OverlayEntry',
    constructorPatterns: [r'OverlayEntry'],
    disposeMethods: ['remove', 'dispose'],
  ),
  ResourceType(
    name: 'MobileScannerController',
    constructorPatterns: [r'MobileScannerController'],
    disposeMethods: ['dispose'],
  ),
];

List<Issue> _analyzeFile(String filePath, String content, List<String> lines) {
  final issues = <Issue>[];
  final resources = _collectResources(lines);

  if (resources.isEmpty) {
    return issues;
  }

  final resourcesByClass = <String?, List<ResourceRef>>{};
  for (final resource in resources) {
    resourcesByClass.putIfAbsent(resource.className, () => []).add(resource);
  }

  for (final entry in resourcesByClass.entries) {
    final className = entry.key;
    final refs = entry.value;
    final cleanupMethod = _findCleanupMethod(content, className: className);

    if (cleanupMethod == null) {
      final allManagedByMixin = refs.every((r) => r.managedByControllerMixin);
      if (allManagedByMixin) {
        continue;
      }
      final summary = refs.map((r) => '${r.name} (${r.type.name})').join(', ');
      final classLabel = className != null ? 'class $className' : 'file';
      issues.add(
        Issue(
          file: filePath,
          line: refs.first.line,
          severity: '❌ MISSING',
          message:
              'No dispose()/close() method found for $classLabel but resource(s) declared: $summary',
        ),
      );
      continue;
    }

    for (final resource in refs) {
      if (!_isResourceDisposed(resource, cleanupMethod)) {
        issues.add(
          Issue(
            file: filePath,
            line: resource.line,
            severity: '⚠️  POTENTIAL',
            message:
                'Resource "${resource.name}" (${resource.type.name}) may not be cleaned up in ${cleanupMethod.name}()',
          ),
        );
      }
    }
  }

  return issues;
}

List<ResourceRef> _collectResources(List<String> lines) {
  final resources = <ResourceRef>[];
  final seen = <String>{};
  final classStack = <_ClassScope>[];
  final classMixinUsage = <String, bool>{};
  _ClassScope? pendingClass;
  var depth = 0;

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final trimmed = rawLine.trim();
    final currentDepth = depth;
    final currentClass = classStack.isEmpty ? null : classStack.last.name;
    final currentClassUsesMixin =
        currentClass != null && classMixinUsage[currentClass] == true;

    if (trimmed.isNotEmpty && !trimmed.startsWith('//')) {
      final hasInitializer = trimmed.contains('=');

      for (final type in _resourceTypes) {
        final name = type.matchLine(trimmed, currentDepth, hasInitializer);
        if (name != null && seen.add(_resourceKey(currentClass, name))) {
          resources.add(
            ResourceRef(
              type: type,
              name: name,
              line: i + 1,
              className: currentClass,
              managedByControllerMixin:
                  currentClassUsesMixin && type.name == 'TextEditingController',
            ),
          );
          continue;
        }

        final mapName = type.matchMap(trimmed, currentDepth, hasInitializer);
        if (mapName != null && seen.add(_resourceKey(currentClass, mapName))) {
          resources.add(
            ResourceRef(
              type: type,
              name: mapName,
              line: i + 1,
              isMap: true,
              className: currentClass,
              managedByControllerMixin:
                  currentClassUsesMixin && type.name == 'TextEditingController',
            ),
          );
          continue;
        }
      }
    }

    final classMatch = RegExp(
      r'^(?:abstract\s+)?class\s+(\w+)',
    ).firstMatch(trimmed);
    if (classMatch != null) {
      pendingClass = _ClassScope(
        classMatch.group(1)!,
        currentDepth + 1,
        usesControllerMixin: _containsControllerLifecycleMixin(trimmed),
      );
    } else if (pendingClass != null && !pendingClass.usesControllerMixin) {
      if (_containsControllerLifecycleMixin(trimmed)) {
        pendingClass.usesControllerMixin = true;
      }
    }

    depth += _countOccurrences(rawLine, '{') - _countOccurrences(rawLine, '}');

    if (pendingClass != null && depth >= pendingClass.depth) {
      classMixinUsage[pendingClass.name] = pendingClass.usesControllerMixin;
      classStack.add(
        _ClassScope(
          pendingClass.name,
          depth,
          usesControllerMixin: pendingClass.usesControllerMixin,
        ),
      );
      pendingClass = null;
    }

    while (classStack.isNotEmpty && depth < classStack.last.depth) {
      classStack.removeLast();
    }
  }

  return resources;
}

bool _isResourceDisposed(
  ResourceRef resource,
  MethodBody method, [
  Set<String>? visitedHelpers,
]) {
  if (resource.managedByControllerMixin) {
    return true;
  }

  visitedHelpers ??= {method.name};

  if (_resourceDisposedInBody(resource, method.body)) {
    return true;
  }

  if (resource.isMap && _isMapDisposed(resource, method.body)) {
    return true;
  }

  final helperCalls = _extractHelperCalls(method.body);
  for (final helper in helperCalls) {
    if (visitedHelpers.contains(helper)) {
      continue;
    }
    final helperBody = _findHelperMethodBody(method.scopeBody, helper);
    if (helperBody == null) {
      continue;
    }
    visitedHelpers.add(helper);
    final helperMethod = MethodBody(
      name: helper,
      body: helperBody,
      scopeBody: method.scopeBody,
    );
    if (_isResourceDisposed(resource, helperMethod, visitedHelpers)) {
      return true;
    }
  }

  return false;
}

bool _resourceDisposedInBody(ResourceRef resource, String body) {
  for (final method in resource.type.disposeMethods) {
    final directPattern = RegExp('${resource.name}(?:[?!])?.$method\\(');
    if (directPattern.hasMatch(body)) {
      return true;
    }
  }
  return false;
}

bool _isMapDisposed(ResourceRef resource, String methodBody) {
  final methodPattern = resource.type.disposeMethods
      .map((m) => '\\.$m\\(')
      .join('|');

  final forPattern = RegExp(
    r'for\s*\([^)]*' +
        resource.name +
        r'\.(?:values|entries)[^)]*\)[^{]*\{[^}]*(' +
        methodPattern +
        ')',
    dotAll: true,
  );
  if (forPattern.hasMatch(methodBody)) {
    return true;
  }

  final forEachPattern = RegExp(
    resource.name +
        r'\.(?:values|entries)\.forEach\s*\([^)]*(' +
        methodPattern +
        ')',
    dotAll: true,
  );
  if (forEachPattern.hasMatch(methodBody)) {
    return true;
  }

  return false;
}

MethodBody? _findCleanupMethod(String content, {String? className}) {
  var searchContent = content;
  if (className != null) {
    final classRegex = RegExp(
      r'(?:abstract\s+)?class\s+' + className + r'\b[^\{]*\{',
    );
    final classMatch = classRegex.firstMatch(content);
    if (classMatch == null) {
      return null;
    }
    final classStart = classMatch.end - 1;
    final classBlock = _extractBlock(content, classStart);
    if (classBlock == null) {
      return null;
    }
    searchContent = classBlock.body;
  }

  const candidates = ['dispose', 'close'];

  for (final name in candidates) {
    final methodRegex = RegExp(
      r'(?:@override\s+)?(?:Future<void>|void)\s+' +
          name +
          r'\(\)\s*(?:async\s*)?\{',
      multiLine: true,
    );
    final match = methodRegex.firstMatch(searchContent);
    if (match != null) {
      final braceIndex = match.end - 1;
      final block = _extractBlock(searchContent, braceIndex);
      if (block != null) {
        return MethodBody(
          name: name,
          body: block.body,
          scopeBody: searchContent,
        );
      }
    }
  }

  return null;
}

_BlockResult? _extractBlock(String source, int startBrace) {
  var depth = 0;
  final length = source.length;
  final start = startBrace + 1;
  depth++;
  for (var i = start; i < length; i++) {
    final char = source[i];
    if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        return _BlockResult(source.substring(start, i), i);
      }
    }
  }
  return null;
}

String _resourceKey(String? className, String name) =>
    '${className ?? '<root>'}::$name';

int _countOccurrences(String source, String target) {
  var count = 0;
  for (var i = 0; i < source.length; i++) {
    if (source[i] == target) {
      count++;
    }
  }
  return count;
}

bool _containsControllerLifecycleMixin(String text) {
  return text.contains('ControllerLifecycleMixin') ||
      text.contains('AutoKeepAliveControllerMixin');
}

Set<String> _extractHelperCalls(String body) {
  final helpers = <String>{};
  final helperRegex = RegExp(r'(?<![\w.])(\w+)\s*\(');
  final ignored = {'if', 'for', 'while', 'switch', 'return', 'super', 'await'};
  for (final match in helperRegex.allMatches(body)) {
    final name = match.group(1);
    if (name == null) {
      continue;
    }
    if (ignored.contains(name)) {
      continue;
    }
    helpers.add(name);
  }
  return helpers;
}

String? _findHelperMethodBody(String scopeBody, String methodName) {
  final helperRegex = RegExp(
    r'(?:@override\s+)?(?:Future<void>|void)\s+' +
        methodName +
        r'\([^)]*\)\s*(?:async\s*)?\{',
    multiLine: true,
  );
  final match = helperRegex.firstMatch(scopeBody);
  if (match == null) {
    return null;
  }
  final braceIndex = match.end - 1;
  final block = _extractBlock(scopeBody, braceIndex);
  return block?.body;
}

class ResourceType {
  ResourceType({
    required this.name,
    required this.constructorPatterns,
    required this.disposeMethods,
    this.supportsMap = false,
  });

  final String name;
  final List<String> constructorPatterns;
  final List<String> disposeMethods;
  final bool supportsMap;

  String get _typePattern => '$name(?:<[^>]+>)?\\??';

  String get _mapPattern => 'Map<[^>]*$name[^>]*>';

  String? matchLine(String line, int depth, bool hasInitializer) {
    if (depth >= 2) {
      return null;
    }

    final declarationPattern = RegExp(
      r'^(?:late\s+)?(?:final|var)?\s*' + _typePattern + r'\s+(\w+)\s*(?:[=;])',
    );
    final declarationMatch = declarationPattern.firstMatch(line);
    if (declarationMatch != null) {
      final name = declarationMatch.group(1)!;
      if (!hasInitializer && !name.startsWith('_')) {
        return null;
      }
      return name;
    }

    if (depth >= 2) {
      return null;
    }

    for (final pattern in constructorPatterns) {
      final constructorRegex = RegExp(
        r'^(?:late\s+)?(?:final|var)\s+(\w+)\s*=\s*(?:const\s+)?' +
            pattern +
            r'(?:<[^>]+>)?\(',
      );
      final constructorMatch = constructorRegex.firstMatch(line);
      if (constructorMatch != null) {
        final name = constructorMatch.group(1)!;
        if (!name.startsWith('_') && depth >= 2) {
          return null;
        }
        return name;
      }
    }

    return null;
  }

  String? matchMap(String line, int depth, bool hasInitializer) {
    if (!supportsMap || depth >= 2) {
      return null;
    }

    final mapRegex = RegExp(
      r'^(?:late\s+)?(?:final|var)?\s*' + _mapPattern + r'\s+(\w+)\s*(?:=|;)',
    );
    final match = mapRegex.firstMatch(line);
    if (match != null) {
      final name = match.group(1)!;
      if (!hasInitializer && !name.startsWith('_')) {
        return null;
      }
      return name;
    }

    return null;
  }
}

class ResourceRef {
  ResourceRef({
    required this.type,
    required this.name,
    required this.line,
    required this.className,
    this.isMap = false,
    this.managedByControllerMixin = false,
  });

  final ResourceType type;
  final String name;
  final int line;
  final String? className;
  final bool isMap;
  final bool managedByControllerMixin;
}

class MethodBody {
  MethodBody({required this.name, required this.body, required this.scopeBody});

  final String name;
  final String body;
  final String scopeBody;
}

class _BlockResult {
  _BlockResult(this.body, this.endIndex);

  final String body;
  final int endIndex;
}

class _ClassScope {
  _ClassScope(this.name, this.depth, {this.usesControllerMixin = false});

  final String name;
  final int depth;
  bool usesControllerMixin;
}

class Issue {
  Issue({
    required this.file,
    required this.line,
    required this.severity,
    required this.message,
  });

  final String file;
  final int line;
  final String severity;
  final String message;
}
