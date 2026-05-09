import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/provenance_search_state.dart';
import 'package:seafoundry_app/models/provenance_suggestion.dart';
import 'package:seafoundry_app/services/clonal_id_display_service.dart';

/// Displays the resolved provenance ID status from a [ProvenanceSearchState].
///
/// Three states:
/// - **Conflict**: error color + conflict message (when multiple provenance
///   fields resolve to different PIDs).
/// - **Resolved PID**: primary color + PID value + which field matched.
/// - **Auto-generated**: muted + "PID will be auto-generated".
class PidStatusChip extends StatelessWidget {
  const PidStatusChip({super.key, required this.searchState});

  final ProvenanceSearchState searchState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (searchState.hasConflict) {
      return _PidChipRow(
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
        text: searchState.conflictMessage!,
      );
    }

    final resolvedPid = searchState.resolvedProvenanceId;
    if (resolvedPid != null) {
      final match = searchState.resolvedMatch;
      if (match == null) {
        // Defensive fallback: resolvedPid exists but no match object.
        return _PidChipRow(
          icon: Icons.link,
          color: theme.colorScheme.primary,
          text: resolvedPid,
        );
      }

      final field = searchState.activeField ?? _inferField(match);
      final fieldLabel = switch (field) {
        ProvenanceMatchField.clonalId => 'Clonal ID',
        ProvenanceMatchField.accessionNumber => 'Accession Number',
        ProvenanceMatchField.alias => 'Alias',
        ProvenanceMatchField.provenanceId => 'PID',
      };
      final aliasValue = switch (field) {
        ProvenanceMatchField.clonalId =>
          ClonalIdDisplayService.resolveForSuggestion(match),
        ProvenanceMatchField.provenanceId => match.provenanceId,
        ProvenanceMatchField.alias => match.aliasValue,
        ProvenanceMatchField.accessionNumber => match.aliasValue,
      };

      final labelText = field == ProvenanceMatchField.provenanceId
          ? '$resolvedPid (selected via PID)'
          : "$resolvedPid (linked via $fieldLabel '$aliasValue')";

      return _PidChipRow(
        icon: Icons.link,
        color: theme.colorScheme.primary,
        text: labelText,
      );
    }

    return _PidChipRow(
      icon: Icons.fingerprint,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      text: 'PID will be auto-generated',
    );
  }

  ProvenanceMatchField _inferField(ProvenanceSuggestion match) {
    if (match.aliasType == ProvenanceAliasType.clonalId) {
      return ProvenanceMatchField.clonalId;
    }
    if (match.aliasType == ProvenanceAliasType.accessionNumber) {
      return ProvenanceMatchField.accessionNumber;
    }
    if (match.aliasValue == match.provenanceId ||
        match.aliasType == ProvenanceAliasType.primary) {
      return ProvenanceMatchField.provenanceId;
    }
    return ProvenanceMatchField.alias;
  }
}

class _PidChipRow extends StatelessWidget {
  const _PidChipRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
