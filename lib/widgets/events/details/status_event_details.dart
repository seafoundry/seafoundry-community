// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/events/status_event.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

import 'base_event_details.dart';

/// Details widget for status events.
class StatusEventDetails extends BaseEventDetails {
  const StatusEventDetails({super.key, required StatusEvent event})
      : super(
          event: event,
          icon: Icons.flag_outlined,
          title: 'Status Change',
        );

  StatusEvent get statusEvent => event as StatusEvent;

  @override
  EventColors getDefaultColors() =>
      EventColors.fromBaseColor(AppColors.secondary);

  @override
  Widget buildEventContent(BuildContext context) {
    final concludedAt = statusEvent.concludedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventDetailRow(
          label: 'Status',
          value: statusEvent.isConcluded ? 'Concluded' : 'Active',
          icon:
              statusEvent.isConcluded ? Icons.check_circle : Icons.flag_outlined,
        ),
        if (concludedAt != null) ...[
          SizedBox(height: Spacing.xs),
          EventDetailRow(
            label: 'Ended',
            value: _formatTimestamp(concludedAt),
            icon: Icons.schedule,
          ),
        ],
        if (statusEvent.subEventIds.isNotEmpty) ...[
          SizedBox(height: Spacing.sm),
          UIText.caption(
            'Related Events:',
            color: AppColors.textSecondary,
          ),
          SizedBox(height: Spacing.xs),
          UIText.bodySmall(
            statusEvent.subEventIds.take(3).join(', '),
          ),
          if (statusEvent.subEventIds.length > 3) ...[
            SizedBox(height: Spacing.xs),
            UIText.bodySmall(
              '+${statusEvent.subEventIds.length - 3} more',
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) return timestamp;
    return DateFormat.yMMMd().add_jm().format(parsed.toLocal());
  }
}
