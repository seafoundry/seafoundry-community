// @tier: community
import 'package:flutter/material.dart';

/// Legend widget for the public holdings map.
///
/// Displays color swatches for holdings and outplants markers.
class HoldingsMapLegend extends StatelessWidget {
  const HoldingsMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            LegendSwatch(
              color: Color(0xFF1E88E5),
              label: 'Holdings',
            ),
            SizedBox(width: 12),
            LegendSwatch(
              color: Color(0xFFFF9100),
              label: 'Outplants',
            ),
          ],
        ),
      ),
    );
  }
}

/// A single color swatch with label for the legend.
class LegendSwatch extends StatelessWidget {
  const LegendSwatch({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
