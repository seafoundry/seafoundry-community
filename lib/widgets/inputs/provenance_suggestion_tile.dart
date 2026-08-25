import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/provenance_suggestion.dart';
import 'package:seafoundry_community/services/clonal_id_display_service.dart';

/// Individual suggestion row: alias (bold), PID badge chip, organization.
/// Used by [ProvenanceAutocompleteField] in the dropdown overlay.
class ProvenanceSuggestionTile extends StatelessWidget {
  const ProvenanceSuggestionTile({
    super.key,
    required this.suggestion,
    required this.onTap,
    this.isHighlighted = false,
    this.displayValueBuilder,
    this.showOtherAliases = true,
  });

  final ProvenanceSuggestion suggestion;
  final ValueChanged<ProvenanceSuggestion> onTap;
  final bool isHighlighted;
  final String Function(ProvenanceSuggestion suggestion)? displayValueBuilder;
  final bool showOtherAliases;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    
    // Prefer a non-UUID clonal ID when available for display.
    final titleText =
        displayValueBuilder?.call(suggestion) ??
        ClonalIdDisplayService.resolveForSuggestion(suggestion);

    return ListTile(
      dense: true,
      selected: isHighlighted,
      selectedTileColor: colors.primary.withValues(alpha: 0.08),
      title: Text(
        titleText,
        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: _buildSubtitle(text, titleText),
      isThreeLine: false, // Adjusted as subtitle is simpler now
      trailing: Chip(
        label: Text(
          suggestion.provenanceId,
          style: text.labelSmall?.copyWith(color: colors.onSecondary),
        ),
        backgroundColor: colors.secondary,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      onTap: () => onTap(suggestion),
    );
  }

  Widget? _buildSubtitle(TextTheme text, String titleText) {
    if (!showOtherAliases) return null;
    // Collect all potential aliases including the one that matched (if different from title)
    final allAliases = {
      if (suggestion.aliasValue != titleText) suggestion.aliasValue,
      ...suggestion.otherAliases,
    };
    
    final displayAliases = allAliases
        .where((a) => a != titleText)
        .where(ClonalIdDisplayService.isHumanReadable)
        .toList();
    
    if (displayAliases.isEmpty) return null;

    return Text(
      'aka: ${displayAliases.join(", ")}',
      style: text.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
        color: text.bodySmall?.color?.withValues(alpha: 0.8),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
