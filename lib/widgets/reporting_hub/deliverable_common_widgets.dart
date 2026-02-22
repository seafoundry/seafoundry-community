// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/permits/deliverable.dart';

/// Status badge for displaying deliverable status
class DeliverableStatusBadge extends StatelessWidget {
  final DeliverableStatus status;

  const DeliverableStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(status),
        ),
      ),
    );
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

/// Info chip for displaying deliverable metadata
class DeliverableInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const DeliverableInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isWarning ? Colors.orange : Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
