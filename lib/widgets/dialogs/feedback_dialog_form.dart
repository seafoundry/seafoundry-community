// @tier: community
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:seafoundry_app/services/feedback_service.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'components/dialog_scroll_view.dart';

class FeedbackDialogForm extends StatelessWidget {
  const FeedbackDialogForm({
    super.key,
    required this.formKey,
    required this.descriptionController,
    required this.stepsController,
    required this.type,
    required this.severity,
    required this.includeShakeDiagnostics,
    required this.showSebastianTools,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    required this.onIncludeShakeChanged,
    required this.onOpenSebastian,
    required this.onOpenShake,
    required this.onCancel,
    required this.onSubmit,
    required this.descriptionValidator,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController descriptionController;
  final TextEditingController stepsController;
  final FeedbackType type;
  final FeedbackSeverity severity;
  final bool includeShakeDiagnostics;
  final bool showSebastianTools;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<FeedbackType?> onTypeChanged;
  final ValueChanged<FeedbackSeverity?> onSeverityChanged;
  final ValueChanged<bool> onIncludeShakeChanged;
  final VoidCallback? onOpenSebastian;
  final VoidCallback onOpenShake;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String? Function(String?) descriptionValidator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: DialogScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us what\'s happening. Your feedback is sent to dev@seafoundry.com and logged for the SeaFoundry team.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.md),
            DropdownButtonFormField<FeedbackType>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'Feedback type',
                border: OutlineInputBorder(),
              ),
              items: FeedbackType.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: isSubmitting ? null : onTypeChanged,
            ),
            if (type == FeedbackType.bugReport) ...[
              const SizedBox(height: Spacing.sm),
              DropdownButtonFormField<FeedbackSeverity>(
                initialValue: severity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                ),
                items: FeedbackSeverity.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: isSubmitting ? null : onSeverityChanged,
              ),
            ],
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: descriptionController,
              enabled: !isSubmitting,
              maxLines: 5,
              minLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue, idea, or question...',
                border: OutlineInputBorder(),
              ),
              validator: descriptionValidator,
            ),
            const SizedBox(height: Spacing.sm),
            TextFormField(
              controller: stepsController,
              enabled: !isSubmitting,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Steps to reproduce (optional)',
                hintText: '1. Go to...\n2. Tap...\n3. See error...',
                border: OutlineInputBorder(),
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: Spacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include Shake diagnostics'),
                subtitle: Text(
                  'Attach device diagnostics and screen context.',
                  style: theme.textTheme.bodySmall,
                ),
                value: includeShakeDiagnostics,
                onChanged: isSubmitting ? null : onIncludeShakeChanged,
              ),
            ],
            if (showSebastianTools) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                'Scale orgs can use Sebastian AI and Shake diagnostics for richer feedback.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: isSubmitting ? null : onOpenSebastian,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Ask Sebastian AI'),
                  ),
                  if (!kIsWeb)
                    OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onOpenShake,
                      icon: const Icon(Icons.vibration_outlined),
                      label: const Text('Open Shake Report'),
                    ),
                ],
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSubmitting ? null : onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(isSubmitting ? 'Sending...' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}