import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:seafoundry_community/services/logging_service.dart';

typedef DeepLinkCallback = Future<void> Function(Uri uri);
typedef DeepLinkErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

/// Thin wrapper around the [app_links] plugin that exposes a simple API for
/// receiving both the initial deep link and all subsequent link events.
///
/// IMPORTANT: On web, we only process the initial link, not the stream.
/// The stream subscription is disabled because:
/// 1. Flutter's router system (NavigationRouterDelegate) already handles URL sync
/// 2. app_links on web listens to browser hash changes, including internal navigation
/// 3. This causes a feedback loop where internal navigation triggers deep link processing
///
/// External deep links on web are handled by the initial link (when the page loads)
/// or through the router system's parseRouteInformation.
abstract class DeepLinkServiceBase {
  Future<void> start({
    required DeepLinkCallback onUri,
    DeepLinkErrorHandler? onError,
  });

  Future<void> dispose();
}

class DeepLinkService implements DeepLinkServiceBase {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _uriSubscription;
  bool _initialized = false;

  @override
  Future<void> start({
    required DeepLinkCallback onUri,
    DeepLinkErrorHandler? onError,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await onUri(initialUri);
      }
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'DeepLinkService failed to fetch initial link',
        error,
        stackTrace,
      );
      onError?.call(error, stackTrace);
    }

    // On web, skip stream subscription to avoid conflict with Flutter's router.
    // The NavigationRouterDelegate already handles URL changes, and app_links
    // would pick up internal navigation hash changes, causing a feedback loop.
    if (kIsWeb) {
      LoggingService.instance.info(
        'DeepLinkService: Skipping stream subscription on web (router handles URL changes)',
      );
      return;
    }

    _uriSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        try {
          await onUri(uri);
        } catch (error, stackTrace) {
          LoggingService.instance.error(
            'DeepLinkService failed to process uri stream event',
            error,
            stackTrace,
          );
          onError?.call(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        LoggingService.instance.error(
          'DeepLinkService stream error',
          error,
          stackTrace,
        );
        onError?.call(error, stackTrace);
      },
      cancelOnError: false,
    );
  }

  @override
  Future<void> dispose() async {
    await _uriSubscription?.cancel();
    _uriSubscription = null;
    _initialized = false;
  }
}
