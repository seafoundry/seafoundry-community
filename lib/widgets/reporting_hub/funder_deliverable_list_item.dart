// @tier: community
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// List item for displaying a deliverable within a funder's expansion tile
class FunderDeliverableListItem extends StatelessWidget {
  final Deliverable deliverable;

  const FunderDeliverableListItem({super.key, required this.deliverable});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return ListTile(
      dense: true,
      leading: Icon(
        _getStatusIcon(deliverable.status),
        color: _getStatusColor(deliverable.status),
        size: 20,
      ),
      title: Text(
        deliverable.name,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        _buildSubtitle(deliverable, dateFormat),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: deliverable.hasReportGenerated
          ? Tooltip(
              message:
                  'Last report: ${dateFormat.format(deliverable.lastReportGeneratedAt!)}',
              child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
            )
          : Tooltip(
              message: 'No report generated',
              child: Icon(Icons.radio_button_unchecked,
                  color: Colors.grey.shade400, size: 18),
            ),
    );
  }

  String _buildSubtitle(Deliverable d, DateFormat dateFormat) {
    final dueDateStr = 'Due: ${dateFormat.format(d.dueDate)}';
    if (d.hasReportGenerated) {
      final daysSince = d.daysSinceLastReport;
      if (daysSince == 0) {
        return '$dueDateStr • Report generated today';
      } else if (daysSince == 1) {
        return '$dueDateStr • Report generated yesterday';
      } else {
        return '$dueDateStr • Report generated $daysSince days ago';
      }
    }
    return '$dueDateStr • No report generated';
  }

  IconData _getStatusIcon(DeliverableStatus status) {
    switch (status) {
      case DeliverableStatus.completed:
        return Icons.check_circle;
      case DeliverableStatus.inProgress:
        return Icons.play_circle;
      case DeliverableStatus.atRisk:
        return Icons.warning;
      case DeliverableStatus.pendingReview:
        return Icons.pending;
      case DeliverableStatus.overdue:
        return Icons.error;
      case DeliverableStatus.notStarted:
        return Icons.circle_outlined;
    }
  }

  Color _getStatusColor(DeliverableStatus status) {
    switch (status) {
      case DeliverableStatus.completed:
        return Colors.green;
      case DeliverableStatus.inProgress:
        return Colors.blue;
      case DeliverableStatus.atRisk:
        return Colors.orange;
      case DeliverableStatus.pendingReview:
        return Colors.purple;
      case DeliverableStatus.overdue:
        return Colors.red;
      case DeliverableStatus.notStarted:
        return Colors.grey;
    }
  }
}
