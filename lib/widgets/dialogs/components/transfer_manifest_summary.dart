// @tier: community
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/common/alias_badges.dart';
import 'dialog_scroll_view.dart';
import '../../notifications/toast_overlay.dart';

/// Component displaying a transfer manifest summary.
class TransferManifestSummary extends StatelessWidget {
  const TransferManifestSummary({
    super.key,
    required this.manifest,
    this.title = 'Transfer Manifest',
    this.showFullMetadata = false,
  });

  final TransferManifest manifest;
  final String title;
  final bool showFullMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromName =
        (manifest.fromOrganization['name'] as String?) ??
        (manifest.fromOrganization['id'] as String?) ??
        'Unknown';
    final toName =
        (manifest.toOrganization['name'] as String?) ??
        (manifest.toOrganization['id'] as String?) ??
        'Unknown';
    final genetName = (manifest.genet['name'] as String?)?.trim();
    final speciesId = manifest.genet['speciesId']?.toString().trim();
    final manifestSpeciesCode =
        manifest.genet['speciesCode']?.toString().trim();
    final species =
        SpeciesRegistry.globalById(speciesId, allowFallback: true);
    final resolvedCode = species?.code.trim();
    final speciesLabel =
        (manifestSpeciesCode != null && manifestSpeciesCode.isNotEmpty)
            ? manifestSpeciesCode
            : ((resolvedCode != null && resolvedCode.isNotEmpty)
                ? resolvedCode
                : 'Unknown');
    final localIdRaw = manifest.genet['localGenetId']?.toString().trim();
    final localGenetId = (localIdRaw != null && localIdRaw.isNotEmpty)
        ? localIdRaw
        : (genetName != null &&
                genetName.isNotEmpty &&
                genetName != speciesLabel
            ? genetName
            : null);
    final provenanceId = manifest.genet['provenanceId']?.toString().trim();
    final aliasEntries = _manifestAliases(manifest);
    final ownership = manifest.genet['ownership'] is Map
        ? Map<String, dynamic>.from(manifest.genet['ownership'] as Map)
        : const <String, dynamic>{};
    final ownerOrg = ownership['ownerOrganizationId']?.toString();
    final managingOrg = ownership['managingOrganizationId']?.toString();

    final canonicalSources = <Map<String, dynamic>>[];
    final genetMetadata = manifest.genet['metadata'];
    if (genetMetadata is Map<String, dynamic>) {
      canonicalSources.add(Map<String, dynamic>.from(genetMetadata));
    }
    if (manifest.metadata != null) {
      canonicalSources.add(Map<String, dynamic>.from(manifest.metadata!));
    }
    final provenanceSelection =
        canonicalSources.isEmpty && manifest.genet['provenanceKind'] == null
            ? null
            : ProvenanceLifeStageSelection.fromCanonicalSources(
                sources: canonicalSources,
                fallbackProvenanceKind:
                    manifest.genet['provenanceKind']?.toString(),
              );
    final provenanceKindLabel =
        manifest.genet['provenanceKind']?.toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Status',
            value: manifest.status.name.toUpperCase(),
          ),
          _SummaryRow(label: 'From', value: fromName),
          _SummaryRow(label: 'To', value: toName),
          _SummaryRow(label: 'Species Code', value: speciesLabel),
          if ((localGenetId ?? '').isNotEmpty)
            _SummaryRow(label: 'Source Local ID', value: localGenetId!),
          if ((provenanceId ?? '').isNotEmpty)
            _SummaryRow(label: 'Provenance ID', value: provenanceId!),
          _SummaryRow(label: 'Quantity', value: manifest.quantity.toString()),
          if (provenanceSelection != null) ...[
            _SummaryRow(
              label: 'Provenance Type',
              value: provenanceSelection.provenanceType.displayName,
            ),
            _SummaryRow(
              label: 'Life Stage',
              value: provenanceSelection.lifeStage.displayName,
            ),
          ],
          if (manifest.metadata != null) ...[
            if (manifest.metadata!['physicalFormId'] != null)
              _SummaryRow(
                label: 'Physical Form',
                value: manifest.metadata!['physicalFormId'].toString(),
              ),
            if (manifest.metadata!['sizeBandId'] != null)
              _SummaryRow(
                label: 'Size Band',
                value: manifest.metadata!['sizeBandId'].toString(),
              ),
            if (manifest.metadata!['size'] != null)
              _SummaryRow(
                label: 'Size',
                value: _formatSize(manifest.metadata!['size']),
              ),
          ],
          if ((provenanceKindLabel ?? '').isNotEmpty)
            _SummaryRow(label: 'Provenance Kind', value: provenanceKindLabel!),
          if ((ownerOrg ?? '').isNotEmpty)
            _SummaryRow(label: 'Owner Org', value: ownerOrg!),
          if ((managingOrg ?? '').isNotEmpty)
            _SummaryRow(label: 'Managing Org', value: managingOrg!),
          if ((manifest.comment ?? '').isNotEmpty)
            _SummaryRow(label: 'Notes', value: manifest.comment!),
          if (aliasEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aliases',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AliasBadges(aliases: aliasEntries),
          ],
          if (showFullMetadata) ...[
            const SizedBox(height: 16),
            _ManifestMetadataExpansion(manifest: manifest),
          ],
        ],
      ),
    );
  }

  static String _formatSize(dynamic sizeData) {
    if (sizeData == null) return 'Unknown';
    if (sizeData is Map<String, dynamic>) {
      final dimension = sizeData['measuredDimension'];
      final unit = sizeData['dimensionUnit'];
      final sizeClass = sizeData['sizeClass'];
      if (dimension != null && unit != null) {
        return '$dimension $unit';
      }
      if (sizeClass != null) {
        return sizeClass.toString();
      }
    }
    return sizeData.toString();
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ManifestMetadataExpansion extends StatelessWidget {
  const _ManifestMetadataExpansion({required this.manifest});

  final TransferManifest manifest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String payload;
    try {
      payload = const JsonEncoder.withIndent('  ').convert(manifest.toJson());
    } catch (_) {
      payload = manifest.toJson().toString();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      title: Text(
        'Full Manifest',
        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (!context.mounted) return;
              ToastOverlay.showSnackBar(context,
                const SnackBar(content: Text('Manifest JSON copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy JSON'),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: DialogScrollView(
            child: SelectableText(
              payload,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<OrganismAlias> _manifestAliases(TransferManifest manifest) {
  final raw = manifest.genet['aliases'];
  if (raw == null) return const [];
  if (raw is Iterable) {
    return OrganismAlias.listFromJson(raw);
  }
  if (raw is Map<String, dynamic>) {
    return OrganismAlias.listFromJson([raw]);
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Iterable) {
        return OrganismAlias.listFromJson(decoded);
      }
      if (decoded is Map<String, dynamic>) {
        return OrganismAlias.listFromJson([decoded]);
      }
    } catch (_) {
      // Fall through to empty list.
    }
  }
  return const [];
}
