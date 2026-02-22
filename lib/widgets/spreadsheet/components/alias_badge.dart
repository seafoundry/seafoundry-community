// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/widgets/common/alias_badges.dart';

/// Compact alias badge renderer tailored for spreadsheet cells.
class SpreadsheetAliasBadges extends StatelessWidget {
  const SpreadsheetAliasBadges({
    super.key,
    required this.aliases,
    this.placeholder = '—',
  });

  final List<OrganismAlias> aliases;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    if (aliases.isEmpty) {
      final theme = Theme.of(context);
      return Text(
        placeholder,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return AliasBadges(
      aliases: aliases,
      showPlaceholderWhenEmpty: false,
    );
  }
}
