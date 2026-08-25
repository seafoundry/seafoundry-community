import 'package:flutter/material.dart';

/// Optimized network image with caching-friendly hints, placeholders, fade-in,
/// and repaint isolation to reduce jank.
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.placeholder,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // Hint decoder to downscale to target size when possible.
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      // Smooth fade-in when first frame arrives.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: child,
        );
      },
      // Lightweight placeholder while loading.
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder(context);
      },
      // Graceful error fallback.
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildErrorFallback(context);
      },
    );

    // Isolate repaints for smoother scrolling.
    image = RepaintBoundary(child: image);

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    if (backgroundColor != null || padding != null) {
      image = Container(color: backgroundColor, padding: padding, child: image);
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color:
          (backgroundColor ?? Theme.of(context).dividerColor.withValues(alpha: 0.08)),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color:
          (backgroundColor ?? Theme.of(context).dividerColor.withValues(alpha: 0.08)),
      child: const Icon(Icons.broken_image, size: 24),
    );
  }
}

