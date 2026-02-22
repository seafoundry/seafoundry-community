// @tier: community
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mixin to handle stream subscription lifecycle automatically
///
/// This mixin provides a standardized way to manage stream subscriptions
/// in widgets, ensuring they are properly cancelled when the widget is disposed.
///
/// Usage:
/// ```dart
/// class MyWidget extends StatefulWidget { ... }
///
/// class _MyWidgetState extends State<MyWidget> with StreamSubscriptionMixin {
///   @override
///   void initState() {
///     super.initState();
///     // Subscriptions are automatically cancelled on dispose
///     subscribe(myStream.listen((data) {
///       if (mounted) setState(() { ... });
///     }));
///   }
/// }
/// ```
mixin StreamSubscriptionMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription> _subscriptions = [];

  /// Add a subscription to be automatically cancelled on dispose
  void subscribe(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Cancel a specific subscription and remove it from tracking
  void unsubscribe(StreamSubscription subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  /// Cancel all subscriptions
  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }
}

/// Mixin for widgets that need automatic keep alive with stream subscriptions
mixin AutoKeepAliveStreamMixin<T extends StatefulWidget>
    on State<T>, AutomaticKeepAliveClientMixin<T> {
  final List<StreamSubscription> _subscriptions = [];

  /// Add a subscription to be automatically cancelled on dispose
  void subscribe(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  /// Cancel all subscriptions
  void cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    super.dispose();
  }
}
