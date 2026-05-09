import 'package:flutter/material.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Standardized loading indicator used throughout the app
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool centered;
  final EdgeInsets? padding;

  const LoadingIndicator({super.key, this.message, this.size = 24.0, this.color, this.centered = true, this.padding});

  /// Large loading indicator for full-screen loading states
  const LoadingIndicator.large({super.key, this.message, this.color, this.centered = true, this.padding}) : size = 48.0;

  /// Small loading indicator for inline loading states
  const LoadingIndicator.small({super.key, this.message, this.color, this.centered = false, this.padding})
    : size = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    Widget indicator = CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
      strokeWidth: size < 20 ? 2.0 : 3.0,
    );

    if (message != null) {
      indicator = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: size, height: size, child: indicator),
          SizedBox(height: Spacing.md),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      indicator = SizedBox(width: size, height: size, child: indicator);
    }

    if (padding != null) {
      indicator = Padding(padding: padding!, child: indicator);
    }

    if (centered) {
      return Center(child: indicator);
    }

    return indicator;
  }
}
