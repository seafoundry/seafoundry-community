// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/widgets/cards.dart';
import 'package:seafoundry_app/widgets/ui.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';

class GeneticsSummaryCards extends StatelessWidget {
  const GeneticsSummaryCards({
    super.key,
    required this.hasRows,
    required this.stats,
    required this.typeCounts,
  });

  final bool hasRows;
  final Map<String, int> stats;
  final Map<String, int> typeCounts;

  @override
  Widget build(BuildContext context) {
    if (!hasRows) {
      return AppCards.basic(
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueGrey),
            const SizedBox(width: 12),
            Expanded(
              child: UIText.bodyMedium(
                'No genetics data found. Showing example row while data loads.',
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Calculate card width based on screen size
        // Wide screens (>900): 6 cards per row
        // Medium screens (600-900): 3 cards per row
        // Narrow screens (<600): 2 cards per row
        final int cardsPerRow;
        if (availableWidth > 900) {
          cardsPerRow = 6;
        } else if (availableWidth > 600) {
          cardsPerRow = 3;
        } else {
          cardsPerRow = 2;
        }

        const spacing = 8.0;
        final cardWidth =
            (availableWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        Widget statCard(
          String label,
          String value,
          IconData icon,
          Color color,
        ) {
          return SizedBox(
            width: cardWidth,
            child: AppCards.outlined(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  UI.spacingHorizontalSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UIText.bodySmall(label, color: UI.textSecondaryColor),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            statCard(
              'Genets',
              '${stats['genets'] ?? 0}',
              Icons.biotech,
              Colors.blue,
            ),
            statCard(
              'Species',
              '${stats['species'] ?? 0}',
              Icons.category,
              Colors.teal,
            ),
            statCard(
              'Corals',
              '${stats['corals'] ?? 0}',
              Icons.scatter_plot,
              Colors.deepPurple,
            ),
            statCard(
              'Wild',
              '${typeCounts[ProvenanceType.wild.id] ?? 0}',
              Icons.dns,
              Colors.indigo,
            ),
            statCard(
              'Transfer',
              '${typeCounts[ProvenanceType.transfer.id] ?? 0}',
              Icons.swap_horiz,
              Colors.orange,
            ),
            statCard(
              'Unknown',
              '${typeCounts[ProvenanceType.unknown.id] ?? 0}',
              Icons.help_outline,
              Colors.grey,
            ),
          ],
        );
      },
    );
  }
}
