// @tier: community
import 'package:flutter/material.dart';

/// A widget that displays a loading overlay on top of its child.
///
/// When [isLoading] is true, a semi-transparent overlay with a
/// [CircularProgressIndicator] is displayed on top of the [child].
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.opacity = 0.5,
    this.color,
  });

  /// Whether the loading overlay should be shown.
  final bool isLoading;

  /// The child widget to display behind the overlay.
  final Widget child;

  /// The opacity of the overlay background (0.0 to 1.0).
  final double opacity;

  /// The color of the overlay background. Defaults to black.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: (color ?? Colors.black).withValues(alpha: opacity),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }
}
