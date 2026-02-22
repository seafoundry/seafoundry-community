// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/app_colors.dart';

/// Displays a completeness percentage indicator for organism records.
///
/// Shows visual feedback for incomplete records to encourage users
/// to fill in optional fields like life stage and physical form.
///
/// Usage:
/// ```dart
/// CompletenessIndicator(
///   completenessScore: organism.completenessScore,
///   incompleteFields: organism.incompleteFields,
/// )
/// ```
class CompletenessIndicator extends StatelessWidget {
  /// Completeness score from 0.0 to 1.0
  final double completenessScore;

  /// List of field names that are incomplete (for tooltip)
  final List<String> incompleteFields;

  /// Whether to use compact display mode (badge only)
  final bool compact;

  /// Whether to hide when record is complete
  final bool hideWhenComplete;

  const CompletenessIndicator({
    super.key,
    required this.completenessScore,
    this.incompleteFields = const [],
    this.compact = false,
    this.hideWhenComplete = true,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = completenessScore >= 1.0;

    // Hide indicator for complete records if requested
    if (isComplete && hideWhenComplete) {
      return const SizedBox.shrink();
    }

    final percent = (completenessScore * 100).round();
    final color = _getColor();
    final tooltipMessage = _buildTooltipMessage();

    if (compact) {
      return Tooltip(
        message: tooltipMessage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.withOpacity(color, 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$percent%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      );
    }

    // Standard display with progress bar
    return Tooltip(
      message: tooltipMessage,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: completenessScore,
                backgroundColor: AppColors.disabled,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    if (completenessScore >= 1.0) {
      return AppColors.success;
    } else if (completenessScore >= 0.5) {
      return AppColors.warning;
    } else {
      return AppColors.unknown;
    }
  }

  String _buildTooltipMessage() {
    if (completenessScore >= 1.0) {
      return 'Record is complete';
    }
    if (incompleteFields.isEmpty) {
      return 'Record is incomplete';
    }
    return 'Missing: ${incompleteFields.join(', ')}';
  }
}
