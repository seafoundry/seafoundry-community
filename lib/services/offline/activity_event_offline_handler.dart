// @tier: community
import 'package:seafoundry_app/models/events/activity_event.dart';

/// Abstraction for offline activity event handling.
abstract class ActivityEventOfflineHandler {
  bool get isOnline;

  Future<void> cacheEvent(ActivityEvent event);

  Future<void> queueEvent(ActivityEvent event);

  Future<ActivityEvent?> findCachedActivityEventBySourceAndParent({
    required String sourceEventId,
    required String parentRecordId,
  });
}

/// No-op handler for tiers without offline support.
class NoopActivityEventOfflineHandler implements ActivityEventOfflineHandler {
  const NoopActivityEventOfflineHandler();

  @override
  bool get isOnline => true;

  @override
  Future<void> cacheEvent(ActivityEvent event) async {}

  @override
  Future<void> queueEvent(ActivityEvent event) async {}

  @override
  Future<ActivityEvent?> findCachedActivityEventBySourceAndParent({
    required String sourceEventId,
    required String parentRecordId,
  }) async {
    return null;
  }
}
