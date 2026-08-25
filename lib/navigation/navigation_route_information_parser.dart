import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_community/services/logging_service.dart';

/// Parses route information (URLs) to/from String paths.
/// Works with NavigationRouterDelegate to sync browser URL with app state.
class NavigationRouteInformationParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (kDebugMode) {
      LoggingService.instance.debug(
        'NavigationRouteInformationParser.parseRouteInformation: '
        'uri=$uri, path="${uri.path}", fragment="${uri.fragment}"',
      );
    }

    // On web with hash routing, the path might be in the fragment
    // Check both path and fragment to handle different URL strategies
    String location = uri.path;

    // If path is empty or just '/', check if there's meaningful content in fragment
    // This handles hash-based routing where the navigation path is in the fragment
    if ((location.isEmpty || location == '/') && uri.fragment.isNotEmpty) {
      location = uri.fragment;
      if (kDebugMode) {
        LoggingService.instance.debug('Using fragment as location: "$location"');
      }
    }

    // Clean up leading slash if present (normalize path)
    if (location.startsWith('/')) {
      location = location.substring(1);
    }

    if (kDebugMode) {
      LoggingService.instance.debug(
        'Final location: "${location.isEmpty ? '/' : location}"',
      );
    }
    return location.isEmpty ? '/' : location;
  }

  @override
  RouteInformation? restoreRouteInformation(String configuration) {
    if (kDebugMode) {
      LoggingService.instance.debug(
        'NavigationRouteInformationParser.restoreRouteInformation: '
        'configuration="$configuration"',
      );
    }
    // Flutter's hash URL strategy (default on web) expects the route in the
    // URI's path, NOT the fragment. The strategy handles adding the # prefix.
    //
    // Configuration 'seafoundry' → Uri(path: '/seafoundry') → Browser shows #/seafoundry
    // Configuration '/' → Uri(path: '/') → Browser shows #/
    //
    // Using fragment causes double-hash issues because both our code and
    // Flutter's strategy try to add the hash.
    final path = configuration == '/' || configuration.isEmpty
        ? '/'
        : (configuration.startsWith('/') ? configuration : '/$configuration');
    final uri = Uri(path: path);
    if (kDebugMode) {
      LoggingService.instance.debug('Created uri: $uri');
    }
    return RouteInformation(uri: uri);
  }
}
