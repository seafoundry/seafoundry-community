// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Standardized empty state widget for when there's no data
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  final EdgeInsets? padding;

  const EmptyState({super.key, required this.title, this.subtitle, this.icon, this.action, this.padding});

  /// Empty state for search results
  const EmptyState.search({
    super.key,
    this.subtitle = 'Try adjusting your search terms',
    this.icon = Icons.search_off,
    this.action,
    this.padding,
  }) : title = 'No results found';

  /// Empty state for lists
  const EmptyState.list({
    super.key,
    required this.title,
    this.subtitle = 'Add items to see them here',
    this.icon = Icons.inbox,
    this.action,
    this.padding,
  });

  /// Empty state for errors
  const EmptyState.error({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle = 'Please try again later',
    this.icon = Icons.error_outline,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ?? EdgeInsets.all(Spacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 64, color: AppColors.textHint), SizedBox(height: Spacing.lg)],
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: Spacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[SizedBox(height: Spacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
