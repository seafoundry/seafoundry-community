// @tier: community
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/cubits/monitoring_dialog/monitoring_dialog_state.dart';
import 'package:seafoundry_app/models/types/organism_context.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

class MonitoringImageAttachmentCard extends StatelessWidget {
  const MonitoringImageAttachmentCard({
    super.key,
    required this.fileName,
    required this.isTiff,
    required this.selection,
    required this.onRemove,
    required this.onToggleOrthomosaic,
    required this.onSelectTargets,
  });

  final String fileName;
  final bool isTiff;
  final ImageAttachmentSelection selection;
  final VoidCallback onRemove;
  final ValueChanged<bool?> onToggleOrthomosaic;
  final VoidCallback onSelectTargets;

  bool get _showOrthomosaicToggle => isTiff || selection.isOrthomosaic;

  OrganismKind _resolveOrganismKind(BuildContext context) {
    try {
      return context.read<OrganismContext>().kind;
    } catch (_) {
      return OrganismKind.coral;
    }
  }

  String _organismLabel(BuildContext context, int count) {
    final kind = _resolveOrganismKind(context);
    final label =
        count == 1
            ? kind.metadata.displayName.toLowerCase()
            : kind.metadata.pluralDisplayName;
    return '$count $label';
  }

  @override
  Widget build(BuildContext context) {
    final organismLabel = _organismLabel(context, selection.coralIds.length);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTiff ? Icons.map : Icons.image,
                  color: isTiff ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remove image',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_showOrthomosaicToggle)
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Orthomosaic (TIFF)'),
                      value: isTiff ? true : selection.isOrthomosaic,
                      onChanged: isTiff ? null : onToggleOrthomosaic,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: onSelectTargets,
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(
                    selection.hasSpecificTargets
                        ? 'Edit Targets'
                        : 'Select Targets',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            if (selection.hasSpecificTargets) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (selection.coralIds.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Chip(
                        label: Text(
                          organismLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        avatar: const Icon(Icons.circle, size: 16),
                      ),
                    ),
                  if (selection.groupIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${selection.groupIds.length} group${selection.groupIds.length > 1 ? 's' : ''}',
                      ),
                      avatar: const Icon(Icons.folder, size: 16),
                    ),
                  if (selection.tagIds.isNotEmpty)
                    Chip(
                      label: Text(
                        '${selection.tagIds.length} tag${selection.tagIds.length > 1 ? 's' : ''}',
                      ),
                      avatar: const Icon(Icons.tag, size: 16),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
