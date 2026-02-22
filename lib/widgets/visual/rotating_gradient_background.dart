// @tier: community
import 'dart:math';
import 'package:flutter/material.dart';

class RotatingGradientBackground extends StatefulWidget {
  const RotatingGradientBackground({
    super.key,
    this.color1 = const Color(0xFF0D47A1), // Blue 900
    this.color2 = const Color(0xFF0277BD), // Light Blue 800
  });

  final Color color1;
  final Color color2;

  @override
  State<RotatingGradientBackground> createState() =>
      _RotatingGradientBackgroundState();
}

class _RotatingGradientBackgroundState extends State<RotatingGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20), // Slow rotation
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * pi;
        // Rotate the gradient direction
        // Alignment ranges from -1 to 1.
        // We want Start to opposite End.
        final cosVal = cos(angle);
        final sinVal = sin(angle);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color1, widget.color2],
              begin: Alignment(cosVal, sinVal),
              end: Alignment(-cosVal, -sinVal),
            ),
          ),
        );
      },
    );
  }
}
