import 'dart:isolate';

import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/starter.dart';
import 'package:tier_analyzer_plugin/tier_analyzer_plugin.dart';

void main(List<String> args, SendPort sendPort) {
  ServerPluginStarter(
    TierAnalyzerPlugin(provider: PhysicalResourceProvider.INSTANCE),
  ).start(sendPort);
}
