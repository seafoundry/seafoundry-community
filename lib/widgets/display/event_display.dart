// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/events/move_event.dart';
import 'package:seafoundry_app/models/events/observation_event.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Community-tier event display widget
///
/// A simplified version of EventDisplay that:
/// - Does NOT depend on any Pro-tier event cards
/// - Does NOT use EventCubit - renders events directly
/// - Does NOT have monitoring dialog actions
/// - Does NOT have chat/comments integration
///
/// This widget provides a basic event display suitable for community
/// tier features and web-based implementations.
class EventDisplay extends StatelessWidget {
  const EventDisplay({
    super.key,
    required this.event,
    this.onTap,
    this.currentUserId,
    this.onReaction,
    this.isPending = false,
  });

  final Event event;
  final VoidCallback? onTap;
  final String? currentUserId;
  final ValueChanged<String>? onReaction;

  /// Whether this post is pending server confirmation (optimistic update)
  final bool isPending;

  static const List<String> _quickReactions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  @override
  Widget build(BuildContext context) {
    // Error boundary for failed events
    try {
      return _buildEventCard(context);
    } catch (e, stackTrace) {
      LoggingService.instance.error('EventDisplay rendering error', e, stackTrace);
      return _buildFallbackCard();
    }
  }

  Widget _buildEventCard(BuildContext context) {
    final eventType = EventType.builtins[event.eventTypeId] ?? EventType.unknown;
    final icon = _getIcon(event, eventType);
    final color = _getColor(event, eventType);
    final title = _getTitle(event, eventType);
    final description = _getDescription(event);
    final timeAgo = _formatTimeAgo(event.createdAtDateTime);
    final isCommunityPost = event.metadata?['isCommunityPost'] == true;
    final authorInfo = _getAuthorInfo(event);
    final reactions = _parseReactions(event.metadata);

    // Community posts get expanded card with description
    if (isCommunityPost && description != null) {
      final card = InkWell(
        onTap: isPending ? null : onTap, // Disable tap while pending
        borderRadius: BorderRadius.circular(12),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      radius: 16,
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Author and organization info
                          if (authorInfo != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                authorInfo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Row(
                            children: [
                              if (isPending) ...[
                                Semantics(
                                  label: 'Post is being submitted',
                                  child: SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Posting...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.outline,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  timeAgo,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                                if (_isEdited(event))
                                  Text(
                                    ' (edited)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                if (reactions.isNotEmpty || onReaction != null) ...[
                  const SizedBox(height: 8),
                  _buildReactionsSection(context, reactions),
                ],
              ],
            ),
          ),
        ),
      );

      // Apply subtle opacity for pending posts
      return isPending
          ? Opacity(opacity: 0.7, child: card)
          : card;
    }

    // Standard compact event card
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          radius: 16,
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          timeAgo,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Map<String, List<String>> _parseReactions(Map<String, dynamic>? metadata) {
    if (metadata == null) return const {};
    final raw = metadata['reactions'];
    if (raw is! Map) return const {};
    final parsed = <String, List<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String) continue;
      if (value is List) {
        parsed[key] = value.whereType<String>().toList();
      }
    }
    return parsed;
  }

  Widget _buildReactionsSection(
    BuildContext context,
    Map<String, List<String>> reactions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reactions.isNotEmpty) _buildReactionChips(context, reactions),
        if (onReaction != null && currentUserId != null) ...[
          if (reactions.isNotEmpty) const SizedBox(height: 6),
          _buildQuickReactions(context),
        ],
      ],
    );
  }

  Widget _buildReactionChips(
    BuildContext context,
    Map<String, List<String>> reactions,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final hasReacted = currentUserId != null &&
            users.contains(currentUserId);

        return InkWell(
          onTap: isPending || onReaction == null || currentUserId == null
              ? null
              : () => onReaction!(emoji),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasReacted
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasReacted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  users.length.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasReacted ? FontWeight.bold : FontWeight.w500,
                    color: hasReacted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickReactions(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _quickReactions.map((emoji) {
        return InkWell(
          onTap: isPending ? null : () => onReaction?.call(emoji),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Fallback card for events that fail to render
  Widget _buildFallbackCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEEEEEE),
          radius: 16,
          child: Icon(Icons.event_outlined, color: Colors.grey, size: 18),
        ),
        title: Text(
          event.eventTypeId.replaceAll('event_', '').replaceAll('_', ' '),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: const Text(
          'Unable to load details',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  /// Get icon based on event type
  IconData _getIcon(Event event, EventType eventType) {
    // Check specific event types first
    if (event is HusbandryEvent) {
      switch (event.eventTypeId) {
        case 'event_cleaning':
          return Icons.cleaning_services;
        case 'event_feeding':
          return Icons.restaurant;
        case 'event_treatment':
          return Icons.medical_services;
        case 'event_environmental_adjustment':
          return Icons.tune;
        case 'event_structure_maintenance':
          return Icons.build_circle;
        case 'event_water_quality_test':
          return Icons.science;
        case 'event_husbandry_log':
          return Icons.note_alt_outlined;
        default:
          return Icons.favorite_outline;
      }
    }

    if (event is ObservationEvent) {
      return Icons.visibility_outlined;
    }

    if (event is MoveEvent) {
      return Icons.swap_horiz;
    }

    if (event is OutplantEvent) {
      return Icons.park_outlined;
    }

    // Generic event type icons
    switch (eventType.id) {
      case 'event_create':
        return Icons.add_circle_outline;
      case 'event_update':
        return Icons.edit_outlined;
      case 'event_delete':
        return Icons.delete_outline;
      case 'event_move_in':
        return Icons.arrow_downward;
      case 'event_move_out':
        return Icons.arrow_upward;
      case 'event_observation':
        return Icons.visibility_outlined;
      case 'event_activity':
        return Icons.local_activity_outlined;
      case 'event_spawn':
        return Icons.bubble_chart_outlined;
      case 'event_cross':
        return Icons.merge_type;
      case 'event_settle':
        return Icons.foundation;
      case 'event_propagation':
        return Icons.content_cut;
      case 'event_task':
        return Icons.task_alt;
      case 'event_population_gain':
        return Icons.add;
      case 'event_population_loss':
        return Icons.remove;
      case 'event_mortality':
        return Icons.warning_amber_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  /// Get color based on event type
  Color _getColor(Event event, EventType eventType) {
    // Check specific event types first
    if (event is HusbandryEvent) {
      switch (event.eventTypeId) {
        case 'event_cleaning':
          return Colors.teal;
        case 'event_feeding':
          return Colors.green;
        case 'event_treatment':
          return Colors.red;
        case 'event_environmental_adjustment':
          return Colors.blue;
        case 'event_structure_maintenance':
          return Colors.orange;
        case 'event_water_quality_test':
          return Colors.cyan;
        case 'event_husbandry_log':
          return Colors.blueGrey;
        default:
          return Colors.green;
      }
    }

    if (event is ObservationEvent) {
      return Colors.blue;
    }

    if (event is MoveEvent) {
      return Colors.indigo;
    }

    if (event is OutplantEvent) {
      return Colors.green;
    }

    // Generic event type colors
    switch (eventType.id) {
      case 'event_create':
        return Colors.green;
      case 'event_update':
        return Colors.blue;
      case 'event_delete':
        return Colors.red;
      case 'event_move_in':
      case 'event_move_out':
        return Colors.indigo;
      case 'event_observation':
        return Colors.blue;
      case 'event_activity':
        return Colors.purple;
      case 'event_spawn':
        return Colors.cyan;
      case 'event_cross':
        return Colors.pink;
      case 'event_settle':
        return Colors.teal;
      case 'event_propagation':
        return Colors.deepOrange;
      case 'event_task':
        return Colors.amber;
      case 'event_population_gain':
        return Colors.lightGreen;
      case 'event_population_loss':
        return Colors.orange;
      case 'event_mortality':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get title based on event type
  String _getTitle(Event event, EventType eventType) {
    // Check for community post title in metadata
    final metadata = event.metadata;
    if (metadata != null && metadata['isCommunityPost'] == true) {
      final title = metadata['title'];
      if (title is String && title.isNotEmpty) {
        return title;
      }
    }

    if (eventType.name.isNotEmpty) {
      return eventType.name;
    }

    // Fallback for unknown types
    return event.eventTypeId
        .replaceAll('event_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Get description for community posts
  String? _getDescription(Event event) {
    final metadata = event.metadata;
    if (metadata != null && metadata['isCommunityPost'] == true) {
      final description = metadata['description'];
      if (description is String && description.isNotEmpty) {
        return description;
      }
    }
    return null;
  }

  /// Check if the post has been edited
  bool _isEdited(Event event) {
    final metadata = event.metadata;
    return metadata?['isEdited'] == true;
  }

  /// Get author info (name and organization) for community posts
  String? _getAuthorInfo(Event event) {
    final metadata = event.metadata;
    if (metadata == null) return null;

    // Get author name from metadata
    final authorName = metadata['createdByName'] as String?;

    // Get organization name from metadata
    final orgName = metadata['createdByOrgName'] as String?;

    if (authorName == null || authorName.isEmpty) return null;

    // If org name is available and not already embedded in author name
    if (orgName != null &&
        orgName.isNotEmpty &&
        !authorName.contains(orgName)) {
      return '$authorName • $orgName';
    }

    return authorName;
  }

  /// Format time ago for display
  String _formatTimeAgo(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} year(s) ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} month(s) ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day(s) ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour(s) ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute(s) ago';
      } else {
        return 'Just now';
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error formatting time ago', e, stackTrace);
      return 'Unknown time';
    }
  }
}
