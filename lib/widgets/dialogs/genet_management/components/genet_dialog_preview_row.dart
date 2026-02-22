// @tier: community
import 'package:flutter/material.dart';

/// A reusable preview row widget for genet management dialogs.
///
/// Displays an icon, label, and value in a consistent format used across
/// split, merge, and removal preview sections.
class GenetDialogPreviewRow extends StatelessWidget {
  const GenetDialogPreviewRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  /// The descriptive label for this row.
  final String label;

  /// The value to display (right-aligned, bold).
  final String value;

  /// The icon to display at the start of the row.
  final IconData icon;

  /// The color for the icon.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
