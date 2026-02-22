import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'geolocation_manager.dart';

/// Fallback geolocation manager for environments without dart:html (e.g. Wasm).
class HtmlGeolocationManager implements GeolocationManager {
  @override
  Future<Position> getCurrentPosition({
    bool? enableHighAccuracy,
    Duration? timeout,
  }) {
    return Future<Position>.error(_unsupported());
  }

  @override
  Stream<Position> watchPosition({
    bool? enableHighAccuracy,
    Duration? timeout,
  }) {
    return Stream<Position>.error(_unsupported());
  }

  PlatformException _unsupported() {
    return PlatformException(
      code: 'UNSUPPORTED_OPERATION',
      message: 'Geolocation is not supported in this environment.',
    );
  }
}
