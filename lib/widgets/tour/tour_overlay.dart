// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/tour_step.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'package:seafoundry_app/widgets/buttons.dart';

/// Overlay widget that displays tour steps with spotlight effect
class TourOverlay extends StatefulWidget {
  const TourOverlay({
    super.key,
    required this.currentStep,
    required this.currentIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.targetRect,
  });

  final TourStep currentStep;
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final Rect? targetRect;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Darkened backdrop with spotlight hole
          _buildBackdrop(),
          
          // Tooltip positioned relative to target (or centered if no target)
          _buildTooltip(context),
          
          // Progress indicator
          _buildProgressIndicator(),
          
          // Skip button
          _buildSkipButton(),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    return CustomPaint(
      painter: _SpotlightPainter(
        targetRect: widget.targetRect,
        pulseAnimation: _pulseAnimation,
      ),
      child: Container(color: Colors.transparent),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    final tooltipWidth = (screenSize.width * 0.92).clamp(280.0, 420.0);
    final tooltipHeight =
        ((screenSize.height - safePadding.vertical) * 0.7).clamp(220.0, 420.0);
    final tooltipPosition = _calculateTooltipPosition(
      screenSize,
      safePadding,
      tooltipWidth,
      tooltipHeight,
    );
    
    return Positioned(
      left: tooltipPosition.dx,
      top: tooltipPosition.dy,
      child: _TourTooltip(
        title: widget.currentStep.title,
        description: widget.currentStep.description,
        onNext: widget.onNext,
        onSkip: widget.onSkip,
        onBack: widget.onBack,
        canGoBack: widget.onBack != null,
        currentStep: widget.currentStep,
        maxWidth: tooltipWidth,
        maxHeight: tooltipHeight,
      ),
    );
  }

  /// Calculates the position for the tooltip based on the target element and desired position.
  ///
  /// The tooltip is positioned relative to the target element (if provided) or centered on screen.
  /// Positions are clamped to screen bounds to prevent tooltips from rendering off-screen.
  ///
  /// Position logic:
  /// - `center`: Always centered on screen, ignoring target
  /// - `above/below/left/right`: Positioned relative to target with padding
  /// - If no target provided for directional positions, falls back to center
  Offset _calculateTooltipPosition(
    Size screenSize,
    EdgeInsets safePadding,
    double tooltipWidth,
    double tooltipHeight,
  ) {
    const tooltipPadding = 16.0;
    const minLeft = 12.0;
    final availableHorizontalSpace =
        screenSize.width - tooltipWidth - (minLeft * 2);
    final maxLeft =
        availableHorizontalSpace > 0 ? minLeft + availableHorizontalSpace : minLeft;
    final safeTop = safePadding.top + 12.0;
    final safeBottom = screenSize.height - safePadding.bottom - 12.0;
    double clampedY(double value) {
      final maxY = (safeBottom - tooltipHeight).clamp(safeTop, safeBottom - tooltipHeight);
      return value.clamp(safeTop, maxY);
    }
    double clampedX(double value) => value.clamp(minLeft, maxLeft);

    // For center position, always center regardless of targetRect
    if (widget.currentStep.position == TourTooltipPosition.center) {
      final dx = clampedX((screenSize.width - tooltipWidth) / 2);
      final dy = clampedY(safeTop + ((safeBottom - safeTop - tooltipHeight) / 2));
      return Offset(dx, dy);
    }

    // For other positions, need targetRect
    if (widget.targetRect == null) {
      // Fallback to center if no targetRect available
      final dx = clampedX((screenSize.width - tooltipWidth) / 2);
      final dy = clampedY(safeTop + ((safeBottom - safeTop - tooltipHeight) / 2));
      return Offset(dx, dy);
    }

    final targetRect = widget.targetRect!;

    switch (widget.currentStep.position) {
      case TourTooltipPosition.above:
        return Offset(
          // Center horizontally on target, clamp to screen bounds
          clampedX(targetRect.center.dx - tooltipWidth / 2),
          // Position above target with padding
          clampedY(targetRect.top - tooltipHeight - tooltipPadding),
        );
      case TourTooltipPosition.below:
        return Offset(
          clampedX(targetRect.center.dx - tooltipWidth / 2),
          clampedY(targetRect.bottom + tooltipPadding),
        );
      case TourTooltipPosition.left:
        return Offset(
          clampedX(targetRect.left - tooltipWidth - tooltipPadding),
          // Center vertically on target, clamp to screen bounds
          clampedY(targetRect.center.dy - tooltipHeight / 2),
        );
      case TourTooltipPosition.right:
        return Offset(
          clampedX(targetRect.right + tooltipPadding),
          clampedY(targetRect.center.dy - tooltipHeight / 2),
        );
      case TourTooltipPosition.center:
        // Already handled above
        return Offset(
          (screenSize.width - tooltipWidth) / 2,
          (screenSize.height - tooltipHeight) / 2,
        );
    }
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: UIText.bodySmall(
            'Step ${widget.currentIndex + 1} of ${widget.totalSteps}',
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return Positioned(
      top: 60,
      right: 20,
      child: Semantics(
        label: 'Skip tour',
        hint: 'Skip the tutorial and go directly to the application',
        button: true,
        child: TextButton(
          onPressed: widget.onSkip,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
          child: const Text('Skip Tour'),
        ),
      ),
    );
  }
}

/// Custom painter for spotlight effect (dark backdrop with transparent hole)
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.targetRect,
    required this.pulseAnimation,
  });

  final Rect? targetRect;
  final Animation<double> pulseAnimation;

  @override
  void paint(Canvas canvas, Size size) {
    // Cut out spotlight hole around target while dimming the rest of the screen
    final backdropPaint = Paint()..color = Colors.black54;

    if (targetRect == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backdropPaint);
      return;
    }

    final expandedRect = Rect.fromLTWH(
      targetRect!.left - 8,
      targetRect!.top - 8,
      targetRect!.width + 16,
      targetRect!.height + 16,
    );

    // Outer rect minus inner rect, leaving a transparent hole over the target
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(expandedRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    if (pulseAnimation.value > 0) {
      final pulsePaint = Paint()
        ..color = Colors.blue.withValues(alpha: pulseAnimation.value * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(expandedRect, const Radius.circular(8)),
        pulsePaint,
      );
    }

    canvas.drawPath(path, backdropPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        pulseAnimation.value != oldDelegate.pulseAnimation.value;
  }
}

/// Tooltip widget that displays tour step information
class _TourTooltip extends StatelessWidget {
  const _TourTooltip({
    required this.title,
    required this.description,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.canGoBack = false,
    required this.currentStep,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final bool canGoBack;
  final TourStep currentStep;
  final double maxWidth;
  final double maxHeight;

  void _defer(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tooltipWidth = maxWidth;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _defer(onSkip);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab) {
            // Allow Shift+Tab to move backwards when possible
            final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
            if (isShiftPressed && canGoBack && onBack != null) {
              _defer(onBack!);
              return KeyEventResult.handled;
            }
            _defer(onNext);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _defer(onNext);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && canGoBack && onBack != null) {
            _defer(onBack!);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: 'Tour step: $title',
        hint: description,
        button: true,
        child: Container(
          width: tooltipWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: UI.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: UIText.h4(title),
              ),
              
              // Description
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    child: UIText.bodyMedium(description),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canGoBack && onBack != null) ...[
                      AppButtons.secondary(
                        text: 'Back',
                        onPressed: onBack!,
                      ),
                      const SizedBox(width: 12),
                    ],
                    AppButtons.primary(
                      text: 'Next',
                      onPressed: onNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
