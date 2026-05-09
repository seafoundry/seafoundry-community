import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

/// A row displaying a label-value pair for review steps in structure dialogs.
///
/// Used consistently across site and group creation review steps to display
/// form field summaries before submission.
class ReviewFieldRow extends StatelessWidget {
  const ReviewFieldRow({
    super.key,
    required this.label,
    required this.value,
  });

  /// The field label displayed on the left side.
  final String label;

  /// The field value displayed on the right side.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: UIText.bodySmall('$label:', color: UI.textSecondaryColor),
          ),
          Expanded(child: UIText.bodyMedium(value)),
        ],
      ),
    );
  }
}
