// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/generation_method.dart';
import 'package:seafoundry_app/theme/theme.dart';

/// Displays the generation lineage context for an organism created via
/// split or propagation.
///
/// Reads generation metadata from the organism record's metadata map
/// (carried by the CreateEvent snapshot). Supports backward compatibility
/// via [GenerationMethod.infer].
class GenerationLineageSection extends StatelessWidget {
  const GenerationLineageSection({super.key, required this.metadata});

  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final method = GenerationMethod.infer(metadata);
    if (method == null) return const SizedBox.shrink();

    final sourceName = _resolveSourceDisplayName(metadata!);

    final theme = Theme.of(context);
    final icon = method == GenerationMethod.split
        ? Icons.call_split
        : Icons.content_cut;
    final color = method == GenerationMethod.split
        ? AppColors.info
        : AppColors.success;
    final label = method == GenerationMethod.split
        ? 'Split from'
        : 'Propagated from';

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              '$label ${sourceName ?? 'another record'}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveSourceDisplayName(Map<String, dynamic> metadata) {
    final localId = metadata['sourceOrganismLocalId'] as String?;
    final recordName = metadata['sourceOrganismRecordName'] as String?;
    if (localId != null && recordName != null) {
      return '$localId ($recordName)';
    }
    return localId ?? recordName;
  }
}
