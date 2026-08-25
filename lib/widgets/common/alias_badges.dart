import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/alias.dart';

/// Displays provenance/genet aliases as compact chips with their tagged source.
class AliasBadges extends StatelessWidget {
  const AliasBadges({
    super.key,
    required this.aliases,
    this.showPlaceholderWhenEmpty = false,
    this.emptyLabel = 'No aliases linked',
  });

  final List<OrganismAlias> aliases;
  final bool showPlaceholderWhenEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (aliases.isEmpty) {
      if (!showPlaceholderWhenEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: aliases.map(_AliasChip.new).toList(growable: false),
    );
  }
}

class _AliasChip extends StatelessWidget {
  const _AliasChip(this.alias);

  final OrganismAlias alias;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = alias.sourceSystem.trim().isEmpty
        ? 'custom'
        : alias.sourceSystem.trim();
    final baseLabel = alias.label?.trim().isNotEmpty == true
        ? alias.label!.trim()
        : alias.value.trim();
    final tooltipSuffix =
        alias.value.trim().isEmpty ? '' : ': ${alias.value.trim()}';

    return Tooltip(
      message: '${source.toUpperCase()} alias$tooltipSuffix',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Chip(
          backgroundColor: theme.colorScheme.secondaryContainer,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          label: Text(
            '$baseLabel (${source.toUpperCase()})',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
