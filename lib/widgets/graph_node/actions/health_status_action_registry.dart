// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';

/// Input for observation actions - works with any organism type
class ObservationActionInput {
  ObservationActionInput({
    required this.sheetContext,
    required this.actionContext,
    required this.hasOrganismData,
    required this.healthStatusSubtitle,
    required this.showHealthStatusDialog,
  });

  final BuildContext sheetContext;
  final BuildContext actionContext;
  final bool hasOrganismData;
  final String healthStatusSubtitle;
  final Future<void> Function() showHealthStatusDialog;
}

/// Health status action registry supporting all organism kinds.
/// Provides health status update functionality for all organisms with data.
/// Previously restricted to coral only, now supports all organism types.
class HealthStatusActionRegistry {
  static List<Widget> buildTiles({
    required OrganismKind organismKind,
    required ObservationActionInput input,
  }) {
    // Supports all organism kinds - only requires organism data
    if (!input.hasOrganismData) {
      return const [];
    }

    return [
      const Divider(),
      ListTile(
        leading: const Icon(Icons.favorite, color: Colors.green),
        title: const Text('Update Health Status'),
        subtitle: Text(input.healthStatusSubtitle),
        onTap: () async {
          Navigator.pop(input.sheetContext);
          await Future.delayed(const Duration(milliseconds: 100));
          if (input.actionContext.mounted) {
            await input.showHealthStatusDialog();
          }
        },
      ),
    ];
  }
}
