import 'package:flutter/material.dart';

/// Educational widget that explains the five-axis data model
///
/// Shows color-coded cards for each axis:
/// - Taxonomy (organism type)
/// - Provenance (genetic origin)
/// - Location (site)
/// - Life Stage (development phase)
/// - Measurement (counts/metrics)
class FiveAxisEducationWidget extends StatelessWidget {
  const FiveAxisEducationWidget({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Understanding the Five-Axis Data Model',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Introduction
          Text(
            'SeaFoundry tracks organisms across 5 dimensions. Two axes do not ever change (Taxonomy, Provenance), and three will change over the lifecycle (Life Stage, Physical Form, Size). Liquid forms (gametes, embryos, larvae) use size for density and do not contribute to outplant tissue/volume totals.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Visual diagram
          _buildAxisDiagram(context),
          const SizedBox(height: 32),

          // Five axis cards
          _buildAxisCard(
            context,
            icon: Icons.category,
            color: Colors.blue,
            title: '1. Taxonomy (does not ever change)',
            description: 'What organism type and species?',
            example: 'Example: Coral - Acropora cervicornis',
          ),
          const SizedBox(height: 16),

          _buildAxisCard(
            context,
            icon: Icons.account_tree,
            color: Colors.green,
            title: '2. Provenance Type (does not ever change)',
            description: 'What is the genetic origin?',
            example: 'Example: Wild Collection, Sexual Cohort, Graduated Individual',
          ),
          const SizedBox(height: 16),

          _buildAxisCard(
            context,
            icon: Icons.timeline,
            color: Colors.purple,
            title: '3. Life Stage (will change over the lifecycle)',
            description: 'What developmental phase is it in?',
            example: 'Example: Gamete, Larva, Juvenile, Adult, Broodstock',
          ),
          const SizedBox(height: 16),

          _buildAxisCard(
            context,
            icon: Icons.location_on,
            color: Colors.orange,
            title: '4. Physical Form (will change over the lifecycle)',
            description: 'What is its physical state or form?',
            example: 'Example: Fragment, Mounted Individual (Plug), Colony, Settlement Substrate',
          ),
          const SizedBox(height: 16),

          _buildAxisCard(
            context,
            icon: Icons.straighten,
            color: Colors.teal,
            title: '5. Size + Quantity (will change over the lifecycle)',
            description: 'How many and how big are they? Size drives tissue/volume for non-liquid forms.',
            example: 'Example: 50 fragments, 12cm average length',
          ),
          const SizedBox(height: 32),

          // Why it matters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Why This Matters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBulletPoint(context, 'Complete data ensures accurate reports and analytics'),
                _buildBulletPoint(context, 'Improves traceability across restoration partners'),
                _buildBulletPoint(context, 'Enables data exchange with other restoration systems'),
                _buildBulletPoint(context, 'Provides full context for restoration decisions'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAxisDiagram(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.purple.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hub,
            size: 64,
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'Five Dimensions of Every Record',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Taxonomy • Provenance • Life Stage • Physical Form • Size/Quantity',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.blue.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAxisCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String example,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  example,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
