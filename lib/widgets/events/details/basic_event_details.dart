// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'base_event_details.dart';

/// Widget for displaying basic event details (create, update, delete)
class BasicEventDetails extends BaseEventDetails {
  const BasicEventDetails({super.key, required super.event, super.icon, super.title});

  @override
  EventColors getDefaultColors() {
    // Use different colors based on event type ID
    if (event is CreateEvent) {
      return EventColors.fromBaseColor(AppColors.createEventColor);
    }

    // Handle other basic events by eventTypeId since they use base Event class
    switch (event.eventTypeId) {
      case 'event_update':
        return EventColors.fromBaseColor(Colors.blue);
      case 'event_delete':
        return EventColors.fromBaseColor(AppColors.error);
      case 'event_create':
        return EventColors.fromBaseColor(AppColors.createEventColor);
      default:
        return EventColors.fromBaseColor(Colors.grey);
    }
  }

  @override
  Widget buildEventContent(BuildContext context) {
    return UIText.caption('Event ID: ${event.id}', color: AppColors.textSecondary);
  }
}

/// Specific widget for create events
class CreateEventDetails extends BasicEventDetails {
  const CreateEventDetails({super.key, required CreateEvent event})
    : super(event: event, icon: Icons.add_circle_outline, title: 'Creation');
}

/// Specific widget for update events
class UpdateEventDetails extends BasicEventDetails {
  const UpdateEventDetails({super.key, required super.event}) : super(icon: Icons.edit_outlined, title: 'Update');
}

/// Specific widget for delete events
class DeleteEventDetails extends BasicEventDetails {
  const DeleteEventDetails({super.key, required super.event}) : super(icon: Icons.delete_outline, title: 'Deletion');
}
