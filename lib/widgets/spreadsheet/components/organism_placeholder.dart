// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Displays a consistent placeholder when a spreadsheet does not yet support
/// the selected organism kind. Keeps behavior aligned across spreadsheet views.
class SpreadsheetOrganismPlaceholder extends StatelessWidget {
  const SpreadsheetOrganismPlaceholder({
    super.key,
    required this.organismKind,
    this.message,
  });

  final OrganismKind organismKind;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final label = organismKind.metadata.displayName;
    final resolvedMessage =
        message ??
        '$label monitoring data is not available yet. Select Coral to view '
            'existing records.';
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          color: Colors.orange.shade50,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              resolvedMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
