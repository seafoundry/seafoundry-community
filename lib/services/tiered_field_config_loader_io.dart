// @tier: community
import 'dart:io';

import 'package:path/path.dart' as p;

Future<String?> loadTierFieldConfigFromDiskImpl() async {
  try {
    final file = File(
      p.join(Directory.current.path, 'config', 'tier_fields.yaml'),
    );
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  } catch (_) {
    return null;
  }
}
