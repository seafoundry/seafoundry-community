// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/seeding_service.dart';
import 'package:seafoundry_app/widgets/dialogs/seeding/seeding_dialog_config.dart';

/// Banner widget showing seeding execution support status
class SeedingSupportStatusBanner extends StatelessWidget {
  const SeedingSupportStatusBanner({
    super.key,
    required this.status,
    required this.isRunning,
  });

  final SeedingSupportStatus status;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final ready = status.isReady;
    final background = ready ? Colors.green.shade50 : Colors.orange.shade50;
    final border = ready ? Colors.green.shade200 : Colors.orange.shade200;
    final icon = ready ? Icons.check_circle : Icons.warning_amber_rounded;
    final color = ready ? Colors.green.shade700 : Colors.orange.shade700;

    final executableLabel = status.dartExecutable ?? 'dart';
    final message = ready
        ? (isRunning
            ? 'Running on this device (using $executableLabel). Output streams below.'
            : 'Ready to run locally (using $executableLabel).')
        : !status.hasDart
            ? 'Dart SDK not detected. Install Flutter or set the DART_EXECUTABLE environment variable.'
            : 'Required seeding scripts are missing. Confirm scripts/seed_*.dart exist.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// List widget displaying seeding command output logs
class SeedingLogList extends StatelessWidget {
  const SeedingLogList({super.key, required this.outputs});

  final List<SeedingOutput> outputs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(12),
        itemCount: outputs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final output = outputs[index];
          final color = _logColor(theme, output.type);
          final icon = _logIcon(output.type);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  output.message,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Color _logColor(ThemeData theme, SeedingOutputType type) {
    switch (type) {
      case SeedingOutputType.start:
      case SeedingOutputType.progress:
        return theme.colorScheme.onSurfaceVariant;
      case SeedingOutputType.success:
        return Colors.green.shade700;
      case SeedingOutputType.error:
        return Colors.red.shade700;
      case SeedingOutputType.warning:
        return Colors.orange.shade700;
    }
  }

  static IconData _logIcon(SeedingOutputType type) {
    switch (type) {
      case SeedingOutputType.start:
        return Icons.play_arrow;
      case SeedingOutputType.progress:
        return Icons.more_horiz;
      case SeedingOutputType.success:
        return Icons.check_circle;
      case SeedingOutputType.error:
        return Icons.error;
      case SeedingOutputType.warning:
        return Icons.warning_amber_rounded;
    }
  }
}
