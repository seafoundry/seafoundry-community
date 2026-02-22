// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/dialogs/genet_management/components/genet_dialog_preview_row.dart';

/// Preview section for the genet split dialog.
///
/// Shows a summary of the split operation including number of new genets,
/// inherited species/provenance, and the fate of the original genet.
class GenetSplitPreview extends StatelessWidget {
  const GenetSplitPreview({
    super.key,
    required this.record,
    required this.childCount,
    required this.archiveSource,
  });

  /// The source genet being split.
  final ProvenanceRecord record;

  /// Number of child genets to be created.
  final int childCount;

  /// Whether the source genet will be archived after split.
  final bool archiveSource;

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
            'Split Preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          GenetDialogPreviewRow(
            label: 'New genets to create',
            value: '$childCount',
            icon: Icons.add_circle,
            iconColor: Colors.green,
          ),
          GenetDialogPreviewRow(
            label: 'Inherited species',
            value: record.speciesId,
            icon: Icons.science,
            iconColor: Colors.blue,
          ),
          GenetDialogPreviewRow(
            label: 'Inherited provenance',
            value: record.provenanceKind.name,
            icon: Icons.account_tree,
            iconColor: Colors.purple,
          ),
          if (archiveSource)
            const GenetDialogPreviewRow(
              label: 'Original genet',
              value: 'Will be archived',
              icon: Icons.archive,
              iconColor: Colors.orange,
            )
          else
            const GenetDialogPreviewRow(
              label: 'Original genet',
              value: 'Will remain active',
              icon: Icons.check_circle,
              iconColor: Colors.green,
            ),
          const Divider(height: 16),
          const Text(
            'Note: Aliases are NOT copied to avoid conflicts.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
