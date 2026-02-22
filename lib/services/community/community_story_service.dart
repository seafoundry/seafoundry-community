// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/types/health_status.dart';

/// Service for generating engaging community stories from technical mission data.
class CommunityStoryService {
  /// Generates a human-friendly story from an event record.
  static CommunityStory generateStory(Event event) {
    if (event is OutplantEvent) {
      final siteName = (event.name == 'Outplant') ? 'the site' : event.name;
      return CommunityStory(
        title: 'New Corals Outplanted!',
        content: 'Our team successfully outplanted ${event.totalQuantity} corals at $siteName. '
            'This effort helps restore the native ecosystem and increase biodiversity.',
        imageUrl: event.metadata?['previewUrl'] as String?,
        date: DateTime.parse(event.createdAt),
        category: 'Restoration',
      );
    }
    
    if (event is MonitoringEventRecord) {
      final healthDisplay = HealthStatus.maybeFromId(event.newHealthStatus)?.displayName ?? "stable";
      return CommunityStory(
        title: 'Ecosystem Health Check',
        content: 'We just completed a monitoring session at site. '
            'Health status was recorded as $healthDisplay.',
        imageUrl: event.imageUrl,
        date: DateTime.parse(event.createdAt),
        category: 'Science',
      );
    }

    return CommunityStory(
      title: 'Mission Update',
      content: 'Mission Update: ${event.eventType.name}. Every action counts towards a healthier ocean!',
      date: DateTime.parse(event.createdAt),
      category: 'General',
    );
  }
}

class CommunityStory {
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime date;
  final String category;

  CommunityStory({
    required this.title,
    required this.content,
    this.imageUrl,
    required this.date,
    required this.category,
  });
}
