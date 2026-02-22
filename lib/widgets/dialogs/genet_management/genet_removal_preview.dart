// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/components/genet_dialog_preview_row.dart';

/// Preview section for the genet removal/archive dialog.
///
/// Shows the impact of archiving a genet including associated coral count
/// and data preservation status.
class GenetRemovalPreview extends StatelessWidget {
  const GenetRemovalPreview({
    super.key,
    this.coralCount,
    this.isLoadingCoralCount = false,
  });

  /// Number of corals associated with this genet (null if not yet loaded).
  final int? coralCount;

  /// Whether the coral count is currently loading.
  final bool isLoadingCoralCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Archive Impact',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoadingCoralCount)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Loading coral count...',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            )
          else
            GenetDialogPreviewRow(
              label: 'Associated corals',
              value: '${coralCount ?? 0}',
              icon: Icons.eco,
              iconColor: Colors.blue,
            ),
          const GenetDialogPreviewRow(
            label: 'Data preservation',
            value: 'All data retained',
            icon: Icons.security,
            iconColor: Colors.green,
          ),
          const Divider(height: 16),
          const Text(
            'This genet will be archived and hidden from active views. All associated corals and historical data will be preserved. The record can be restored later if needed.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
