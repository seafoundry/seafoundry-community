// @tier: community
import 'package:flutter/material.dart';

/// Lightweight card used by workspace analytics surfaces to highlight a metric
/// or insight with optional supporting context.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final cardColor = color ?? colors.surfaceContainerHigh;
    final foreground = colors.onSurface;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: colors.primary),
          if (icon != null) const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: foreground,
                fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      ),
    );

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
