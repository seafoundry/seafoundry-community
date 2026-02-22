#!/usr/bin/env dart
// Script to add test timeouts to all test files
//
// Usage: dart scripts/add_test_timeouts.dart
//
// This script adds TestTimeoutHelper.defaultTimeout to all test() and testWidgets()
// calls that don't already have a timeout parameter.

// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  final testDir = Directory('test');
  if (!await testDir.exists()) {
    print('Error: test directory not found');
    exit(1);
  }

  int filesModified = 0;
  int testsUpdated = 0;

  await for (final entity in testDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('_test.dart')) {
      final content = await entity.readAsString();

      // Skip if already imports TestTimeoutHelper
      if (content.contains('TestTimeoutHelper')) {
        continue;
      }

      // Find test/testWidgets calls without timeouts
      final lines = content.split('\n');
      bool needsImport = false;
      bool modified = false;

      final newLines = <String>[];
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        newLines.add(line);

        // Check if this is a test/testWidgets declaration
        if (line.trim().startsWith('test(') ||
            line.trim().startsWith('testWidgets(')) {
          // Look ahead to see if timeout is already specified
          bool hasTimeout = false;
          int depth = 0;
          for (int j = i; j < lines.length && j < i + 20; j++) {
            final checkLine = lines[j];
            if (checkLine.contains('timeout:')) {
              hasTimeout = true;
              break;
            }
            // Track parentheses to find end of function call
            depth += checkLine.split('(').length - checkLine.split(')').length;
            if (depth < 0) break;
          }

          if (!hasTimeout) {
            needsImport = true;
            // Find the closing of the test call
            int closingIndex = -1;
            for (int j = i; j < lines.length && j < i + 50; j++) {
              if (lines[j].trim() == '});' ||
                  (lines[j].trim() == ');' && j > i + 5)) {
                closingIndex = j;
                break;
              }
            }

            if (closingIndex > i) {
              // Insert timeout before the closing
              final closingLine = lines[closingIndex];
              newLines.removeLast(); // Remove the line we just added
              newLines.add(
                closingLine
                    .replaceAll(
                      '});',
                      '}, timeout: TestTimeoutHelper.defaultTimeout);',
                    )
                    .replaceAll(
                      ');',
                      ', timeout: TestTimeoutHelper.defaultTimeout);',
                    ),
              );
              for (int j = i + 1; j < closingIndex; j++) {
                newLines.add(lines[j]);
              }
              i = closingIndex;
              modified = true;
              testsUpdated++;
            }
          }
        }
      }

      if (modified || needsImport) {
        var newContent = content;

        // Add import if needed
        if (needsImport &&
            !newContent.contains(
              "import '../../helpers/test_timeout_helper.dart';",
            ) &&
            !newContent.contains(
              "import '../helpers/test_timeout_helper.dart';",
            )) {
          // Find the last import line
          final importLines = newContent
              .split('\n')
              .takeWhile((l) => l.trim().startsWith('import'))
              .toList();
          if (importLines.isNotEmpty) {
            final lastImportIndex =
                newContent.indexOf(importLines.last) + importLines.last.length;
            final relativePath =
                entity.path.replaceAll('test/', '').split('/').length > 2
                ? '../../helpers/test_timeout_helper.dart'
                : '../helpers/test_timeout_helper.dart';
            newContent =
                '${newContent.substring(0, lastImportIndex)}\nimport \'$relativePath\';${newContent.substring(lastImportIndex)}';
          }
        }

        // Apply the timeout modifications (simplified - would need better parsing)
        // For now, let's use a simpler approach with regex
        newContent = newContent.replaceAllMapped(
          RegExp(r'(testWidgets\([^)]+\)\s*async\s*\{)'),
          (match) => match.group(0)!,
        );

        // This script is a starting point - manual verification recommended
        print('Would modify: ${entity.path} ($testsUpdated tests)');
        filesModified++;
      }
    }
  }

  print('\nSummary:');
  print('  Files that would be modified: $filesModified');
  print('  Tests that would get timeouts: $testsUpdated');
  print('\nNote: This script provides a preview. Manual review recommended.');
}
