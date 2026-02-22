// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/cubits/event/event.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// Widget for displaying move event details
class MoveEventDetails extends StatelessWidget {
  final EventLoaded eventState;

  const MoveEventDetails({super.key, required this.eventState});

  @override
  Widget build(BuildContext context) {
    if (!eventState.isMoveEvent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UIText.bodySmall('Move Details', color: AppColors.textSecondary),
        SizedBox(height: Spacing.sm),
        if (eventState.fromParentRecord != null) ...[
          _buildMoveCard('From', eventState.fromParentRecord!, Icons.arrow_upward, Colors.orange),
          SizedBox(height: Spacing.sm),
        ],
        if (eventState.toParentRecord != null) ...[
          _buildMoveCard('To', eventState.toParentRecord!, Icons.arrow_downward, Colors.indigo),
        ],
      ],
    );
  }

  Widget _buildMoveCard(String label, GraphNodeRecord record, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        color: color.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: Spacing.sm),
          UIText.caption('$label: ', color: AppColors.textSecondary),
          Expanded(child: UIText.bodyMedium(record.name)),
        ],
      ),
    );
  }
}
