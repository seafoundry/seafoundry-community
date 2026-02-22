import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Fallback web implementation for environments without dart:html (e.g. Wasm).
class FlutterSecureStorageWeb extends FlutterSecureStoragePlatform {
  static const _publicKey = 'publicKey';
  static final Map<String, String> _memoryStore = <String, String>{};

  /// Registrar for FlutterSecureStorageWeb.
  static void registerWith(Registrar registrar) {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWeb();
  }

  String _namespacedKey(String key, Map<String, String> options) {
    final prefix = options[_publicKey];
    if (prefix == null || prefix.isEmpty) {
      return key;
    }
    return '$prefix.$key';
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _memoryStore.containsKey(_namespacedKey(key, options));
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _memoryStore.remove(_namespacedKey(key, options));
  }

  @override
  Future<void> deleteAll({
    required Map<String, String> options,
  }) async {
    _memoryStore.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _memoryStore[_namespacedKey(key, options)];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final prefix = options[_publicKey];
    if (prefix == null || prefix.isEmpty) {
      return Map<String, String>.from(_memoryStore);
    }

    final map = <String, String>{};
    final namespacedPrefix = '$prefix.';
    for (final entry in _memoryStore.entries) {
      if (!entry.key.startsWith(namespacedPrefix)) {
        continue;
      }
      map[entry.key.substring(namespacedPrefix.length)] = entry.value;
    }

    return map;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _memoryStore[_namespacedKey(key, options)] = value;
  }
}
