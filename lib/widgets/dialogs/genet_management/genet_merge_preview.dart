// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/components/genet_dialog_preview_row.dart';

/// Preview section for the genet merge dialog.
///
/// Shows a summary of the merge operation including primary/secondary genets,
/// coral reassignment count, and merged alias count.
class GenetMergePreview extends StatelessWidget {
  const GenetMergePreview({
    super.key,
    required this.primaryGenetName,
    required this.secondaryGenetName,
    required this.mergedAliasCount,
    this.coralCount,
    this.isLoadingCoralCount = false,
  });

  /// Name of the genet that will be kept (primary).
  final String primaryGenetName;

  /// Name of the genet that will be archived (secondary).
  final String secondaryGenetName;

  /// Total number of aliases after merge.
  final int mergedAliasCount;

  /// Number of corals to reassign (null if not yet loaded).
  final int? coralCount;

  /// Whether the coral count is currently loading.
  final bool isLoadingCoralCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          GenetDialogPreviewRow(
            label: 'Primary genet (kept)',
            value: primaryGenetName,
            icon: Icons.check_circle,
            iconColor: Colors.green,
          ),
          GenetDialogPreviewRow(
            label: 'Secondary genet (archived)',
            value: secondaryGenetName,
            icon: Icons.archive,
            iconColor: Colors.orange,
          ),
          if (isLoadingCoralCount)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading coral count...',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            )
          else if (coralCount != null)
            GenetDialogPreviewRow(
              label: 'Corals to reassign',
              value: '$coralCount',
              icon: Icons.sync_alt,
              iconColor: Colors.blue,
            ),
          GenetDialogPreviewRow(
            label: 'Total aliases after merge',
            value: '$mergedAliasCount',
            icon: Icons.label,
            iconColor: Colors.purple,
          ),
        ],
      ),
    );
  }
}
