import 'package:flutter/material.dart';

/// Loading view for spreadsheets with optional progress indicator.
class SpreadsheetLoadingView extends StatelessWidget {
  const SpreadsheetLoadingView({
    super.key,
    this.status,
    this.progress,
  });

  /// Optional loading status message.
  final String? status;

  /// Optional progress value (0.0 to 1.0).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(
              status!,
              textAlign: TextAlign.center,
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(value: progress),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error view for spreadsheets with retry button.
class SpreadsheetErrorView extends StatelessWidget {
  const SpreadsheetErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  /// Error message to display.
  final String message;

  /// Callback when retry button is pressed.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
