// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/spacing.dart';

/// Shows a simple confirmation dialog with customizable title and message.
///
/// Returns `true` if confirmed, `false` if cancelled, and `null` if dismissed.
///
/// Use this for simple delete confirmations and similar yes/no decisions
/// that don't require complex forms or additional input.
///
/// Example:
/// ```dart
/// final confirmed = await showSimpleConfirmationDialog(
///   context: context,
///   title: 'Delete Schedule',
///   message: 'Are you sure you want to delete "Feed juveniles"?',
///   confirmLabel: 'Delete',
///   isDestructive: true,
/// );
/// if (confirmed == true) {
///   cubit.deleteSchedule(id);
/// }
/// ```
Future<bool?> showSimpleConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => _SimpleConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
}

class _SimpleConfirmationDialog extends StatelessWidget {
  const _SimpleConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destructiveColor = Colors.red[700];

    return AlertDialog(
      title: Row(
        children: [
          if (isDestructive) ...[
            Icon(
              Icons.warning_amber_rounded,
              color: destructiveColor,
              size: 24,
            ),
            SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: isDestructive
                  ? theme.textTheme.titleLarge?.copyWith(
                      color: destructiveColor,
                      fontWeight: FontWeight.bold,
                    )
                  : null,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        if (isDestructive)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: destructiveColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    );
  }
}
