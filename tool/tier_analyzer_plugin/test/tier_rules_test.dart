import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:test/test.dart';
import 'package:tier_analyzer_plugin/src/tier_analyzer_plugin.dart';

void main() {
  group('TierRules', () {
    late MemoryResourceProvider provider;
    late TierRules rules;
    late void Function(String contents, String relativePath) writeFile;

    setUp(() {
      provider = MemoryResourceProvider();
      provider.newFolder('/workspace');
      provider.newFile(
        '/workspace/config/tiers.yaml',
        '''
modules:
  pro:
    - lib/pro_only/**
  scale:
    - lib/scale/**
  shared:
    - lib/**
rules:
  deny_imports:
    community:
      - pro
''',
      );
      rules = TierRules(provider, '/workspace');
      writeFile = (String contents, String relativePath) {
        provider.newFile('/workspace/$relativePath', contents);
      };
    });

    test('reports missing tier header', () {
      final result = rules.analyze('lib/foo.dart', 'void main() {}');
      expect(result.errors, hasLength(1));
      expect(result.errors.first.code, 'tier_header_missing');
    });

    test('ignores generated dart files without headers', () {
      final result = rules.analyze('lib/foo.g.dart', 'void main() {}');
      expect(result.errors, isEmpty);
    });

    test('enforces module tier requirements', () {
      final content = '''
// @tier: community
class Foo {}
''';
      final result = rules.analyze('lib/pro_only/widget.dart', content);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.code, 'tier_path_violation');
    });

    test('allows matching tier for module path', () {
      final content = '''
// @tier: pro
class Foo {}
''';
      final result = rules.analyze('lib/pro_only/widget.dart', content);
      expect(result.errors, isEmpty);
    });

    test('flags forbidden tier imports', () {
      writeFile(
        '''
// @tier: pro
class ProOnly {}
''',
        'lib/pro_only/pro_dependency.dart',
      );

      final communityContent = '''
// @tier: community
import 'package:seafoundry_app/pro_only/pro_dependency.dart';

void main() {}
''';
      final result = rules.analyze('lib/src/community.dart', communityContent);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.code, 'tier_import_violation');
    });

    test('ignores imports when target file lacks a tier header', () {
      writeFile(
        '''
// Missing header on purpose
class Legacy {}
''',
        'lib/legacy/legacy.dart',
      );

      final communityContent = '''
// @tier: community
import 'package:seafoundry_app/legacy/legacy.dart';

void main() {}
''';
      final result = rules.analyze('lib/src/community.dart', communityContent);
      expect(result.errors, isEmpty);
    });
  });
}
