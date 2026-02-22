// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/posts/post.dart';

/// Feed item types for unified event+post feeds
enum FeedItemType { event, post, milestone, alert }

/// Sealed class for unified event+post feeds
sealed class FeedItem {
  String get id;
  DateTime get timestamp;
  String get organizationId;
  FeedItemType get type;
}

/// Feed item wrapping an Event
class EventFeedItem extends FeedItem {
  final Event event;

  EventFeedItem(this.event);

  @override
  String get id => event.id;

  @override
  DateTime get timestamp => event.createdAtDateTime;

  @override
  String get organizationId => event.organizationId;

  @override
  FeedItemType get type => FeedItemType.event;
}

/// Feed item wrapping a Post
class PostFeedItem extends FeedItem {
  final Post post;

  PostFeedItem(this.post);

  @override
  String get id => post.id;

  @override
  DateTime get timestamp => post.createdAtDateTime;

  @override
  String get organizationId => post.organizationId;

  @override
  FeedItemType get type => FeedItemType.post;
}
