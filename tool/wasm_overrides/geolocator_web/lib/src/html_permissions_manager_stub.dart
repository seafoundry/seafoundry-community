import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'permissions_manager.dart';

/// Fallback permissions manager for environments without dart:html (e.g. Wasm).
class HtmlPermissionsManager implements PermissionsManager {
  @override
  bool get permissionsSupported => false;

  @override
  Future<LocationPermission> query(Map permission) async {
    return LocationPermission.unableToDetermine;
  }
}
