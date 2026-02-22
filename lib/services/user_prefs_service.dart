// @tier: community
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Simple local preferences for UI hints such as dismissals.
/// Stores a small JSON file with keys -> expiry (epoch ms).
class UserPrefsService {
  UserPrefsService._();
  static UserPrefsService? _instance;
  static UserPrefsService get instance => _instance ??= UserPrefsService._();

  static const _fileName = 'seafoundry_prefs.json';
  Directory? _dir;
  Map<String, int> _dismissals = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _dir = await getApplicationDocumentsDirectory();
    final file = File('${_dir!.path}/$_fileName');
    if (await file.exists()) {
      try {
        final data = json.decode(await file.readAsString());
        if (data is Map && data['dismissals'] is Map) {
          _dismissals = (data['dismissals'] as Map)
              .map((k, v) => MapEntry(k.toString(), safeInt(v) ?? 0));
        }
      } catch (_) {
        _dismissals = {};
      }
    } else {
      await file.writeAsString(json.encode({'dismissals': {}}));
    }
    _loaded = true;
    _purgeExpired();
  }

  Future<bool> isDismissed(String key) async {
    await _ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = _dismissals[key];
    if (expiry == null) return false;
    if (expiry <= now) {
      _dismissals.remove(key);
      await _save();
      return false;
    }
    return true;
  }

  Future<void> dismiss(String key, Duration ttl) async {
    await _ensureLoaded();
    final expiry = DateTime.now().add(ttl).millisecondsSinceEpoch;
    _dismissals[key] = expiry;
    await _save();
  }

  Future<void> _save() async {
    if (_dir == null) return;
    final file = File('${_dir!.path}/$_fileName');
    await file.writeAsString(json.encode({'dismissals': _dismissals}));
  }

  void _purgeExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _dismissals.removeWhere((_, expiry) => expiry <= now);
  }
}

