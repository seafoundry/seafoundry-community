// @tier: community
// This file is only compiled for web via conditional export in js_error_utils.dart.
// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Object? getJsProperty(Object? object, String name) {
  if (object == null) return null;
  // Don't try to convert Dart exceptions to JS objects - they have their own
  // properties that should be accessed directly via Dart, not via JS interop.
  if (object is Exception || object is Error) return null;
  try {
    final jsValue = object.jsify();
    if (jsValue == null || !jsValue.isA<JSObject>()) return null;
    final result = (jsValue as JSObject).getProperty(name.toJS);
    return result?.dartify();
  } catch (_) {
    // jsify() can fail for various Dart types that aren't JS-compatible
    return null;
  }
}

bool hasJsProperty(Object? object, String name) {
  if (object == null) return false;
  // Don't try to convert Dart exceptions to JS objects
  if (object is Exception || object is Error) return false;
  try {
    final jsValue = object.jsify();
    if (jsValue == null || !jsValue.isA<JSObject>()) return false;
    return (jsValue as JSObject).hasProperty(name.toJS).toDart;
  } catch (_) {
    return false;
  }
}

Object? unwrapJsError(Object? error) {
  if (error == null) return null;
  final boxedError = getJsProperty(error, 'error');
  return boxedError ?? error;
}

String? describeJsError(Object? error) {
  final resolved = unwrapJsError(error);
  if (resolved == null) return null;
  final details = <String, String>{};
  final fields = <String>[
    'code',
    'message',
    'name',
    'status',
    'stack',
    'details',
    'cause',
  ];
  for (final field in fields) {
    if (!hasJsProperty(resolved, field)) {
      continue;
    }
    final value = getJsProperty(resolved, field);
    if (value == null) {
      continue;
    }
    if (value is String || value is num || value is bool) {
      details[field] = value.toString();
      continue;
    }
    try {
      final dartified = value.jsify()?.dartify();
      if (dartified != null) {
        details[field] = dartified.toString();
        continue;
      }
    } catch (_) {
      // Best-effort conversion; fall back to toString below.
    }
    details[field] = value.toString();
  }

  if (details.isEmpty) {
    try {
      final jsValue = resolved.jsify();
      if (jsValue != null && jsValue.isA<JSObject>()) {
        final keysArray = _objectKeys(jsValue as JSObject);
        final length = keysArray.length;
        for (var i = 0; i < length; i++) {
          final key = keysArray[i];
          if (key == null) continue;
          final name = (key as JSString).toDart;
          if (name.isEmpty || details.containsKey(name)) {
            continue;
          }
          final value = getJsProperty(resolved, name);
          if (value == null) {
            continue;
          }
          details[name] = value.toString();
        }
      }
    } catch (_) {
      // Ignore object key inspection failures.
    }
  }

  if (details.isEmpty) {
    try {
      final dartified = resolved.jsify()?.dartify();
      if (dartified is Map) {
        final message = dartified['message']?.toString();
        final code = dartified['code']?.toString();
        if (message != null &&
            message.isNotEmpty &&
            code != null &&
            code.isNotEmpty) {
          return '$message (code: $code)';
        }
        if (message != null && message.isNotEmpty) {
          return message;
        }
        if (code != null && code.isNotEmpty) {
          return code;
        }
        return dartified.toString();
      }
      if (dartified is Iterable) {
        return dartified.toString();
      }
    } catch (_) {
      // Fall through to default null.
    }
  }

  if (details.isEmpty) {
    return null;
  }

  final message = details['message'];
  final code = details['code'];
  if (message != null && code != null && code.isNotEmpty) {
    return '$message (code: $code)';
  }
  return message ?? code ?? details.values.first;
}

@JS('Object.keys')
external JSArray _objectKeys(JSObject object);
