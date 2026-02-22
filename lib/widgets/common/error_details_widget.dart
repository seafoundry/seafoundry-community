// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/error_details_cubit.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// A reusable widget for displaying detailed error information
class ErrorDetailsWidget extends StatelessWidget {
  const ErrorDetailsWidget({super.key, required this.error, this.onRetry, this.compactMode = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compactMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (context) => ErrorDetailsCubit(), child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    // Extract error information based on type
    String message;
    String? recoverySuggestion;
    String? technicalDetails;
    bool isRecoverable = false;

    if (error is DomainError) {
      final domainError = error as DomainError;
      message = domainError.message;
      recoverySuggestion = domainError.recoverySuggestion;
      technicalDetails = domainError.technicalDetails;
      isRecoverable = domainError.isRecoverable;
    } else {
      message = 'An unexpected error occurred';
      technicalDetails = error.toString();
    }

    if (compactMode) {
      return _buildCompactError(
        context,
        message: message,
        recoverySuggestion: recoverySuggestion,
        isRecoverable: isRecoverable,
      );
    }

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            if (recoverySuggestion != null) ...[
              const SizedBox(height: Spacing.sm * 1.5),
              Text(
                recoverySuggestion,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ],
            if (technicalDetails != null)
              BlocBuilder<ErrorDetailsCubit, ErrorDetailsState>(
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Spacing.sm * 1.5),
                      InkWell(
                        onTap: () {
                          context.read<ErrorDetailsCubit>().toggleDetails();
                        },
                        child: Row(
                          children: [
                            Icon(
                              state.showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 20,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: Spacing.xs),
                            Text(
                              state.showDetails ? 'Hide details' : 'Show details',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.showDetails) ...[
                        const SizedBox(height: Spacing.sm),
                        Container(
                          padding: const EdgeInsets.all(Spacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          child: SelectableText(
                            technicalDetails!,
                            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            if (onRetry != null || isRecoverable) ...[
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onRetry != null)
                    FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactError(
    BuildContext context, {
    required String message,
    String? recoverySuggestion,
    required bool isRecoverable,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm * 1.5, vertical: Spacing.sm),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              recoverySuggestion ?? message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null && isRecoverable) ...[
            const SizedBox(width: Spacing.sm),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              color: theme.colorScheme.onErrorContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper widget for displaying errors in lists
class ErrorListTile extends StatelessWidget {
  const ErrorListTile({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String message;
    String? subtitle;

    if (error is DomainError) {
      final domainError = error as DomainError;
      message = domainError.message;
      subtitle = domainError.recoverySuggestion;
    } else {
      message = 'An error occurred';
      subtitle = error.toString();
    }

    return ListTile(
      leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
      title: Text(message),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: onRetry != null ? IconButton(icon: const Icon(Icons.refresh), onPressed: onRetry) : null,
    );
  }
}
