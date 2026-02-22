import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

// ignore: avoid_relative_lib_imports
import '../lib/tier_field_registry.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('model', abbr: 'm', defaultsTo: 'inventory_export_row')
    ..addOption('tier', abbr: 't', defaultsTo: 'community')
    ..addOption('input', abbr: 'i', help: 'Path to JSON file containing a list of maps')
    ..addOption('output', abbr: 'o', help: 'Destination path for the filtered JSON payload');

  final results = parser.parse(args);
  final inputPath = results['input'] as String?;
  final outputPath = results['output'] as String?;
  if (inputPath == null || outputPath == null) {
    stderr.writeln('Usage: dart run tool/bin/tier_migration.dart --input=data.json --output=filtered.json [--tier=community|pro|scale]');
    exit(64);
  }

  final tier = _parseTier(results['tier'] as String?);
  final model = results['model'] as String;

  final registry = TierFieldRegistry();
  registry.load();

  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(66);
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List) {
    stderr.writeln('Input JSON must be an array of objects.');
    exit(65);
  }

  final filtered = decoded.map<Map<String, dynamic>>((entry) {
    if (entry is Map) {
      final map = Map<String, dynamic>.from(entry);
      return registry.filter(model, map, tier);
    }
    return <String, dynamic>{};
  }).toList(growable: false);

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(filtered));

  stdout.writeln('Wrote ${filtered.length} records to ${outputFile.path} for tier ${tier.name}.');
}

Tier _parseTier(String? value) {
  final normalized = value?.toLowerCase() ?? 'community';
  switch (normalized) {
    case 'pro':
      return Tier.pro;
    case 'scale':
      return Tier.scale;
    case 'community':
    default:
      return Tier.community;
  }
}
