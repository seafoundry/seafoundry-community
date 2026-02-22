// @tier: community
import 'package:equatable/equatable.dart';

enum ActivitySource {
  internal, // From SeaFoundry (e.g. "New Outplant")
  news, // External news
  socialMedia, // Facebook, Instagram, etc.
}

enum ActivityType {
  outplant,
  nurseryUpdate,
  environmentalAlert,
  newsArticle,
  socialPost,
  milestone,
}

class ActivityEvent extends Equatable {
  const ActivityEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    required this.type,
    required this.title,
    required this.description,
    this.imageUrl,
    this.linkUrl,
    this.metadata,
  });

  final String id;
  final DateTime timestamp;
  final ActivitySource source;
  final ActivityType type;
  final String title;
  final String description;
  final String? imageUrl;
  final String? linkUrl;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [
        id,
        timestamp,
        source,
        type,
        title,
        description,
        imageUrl,
        linkUrl,
        metadata,
      ];
}
