// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/dialogs/gene_bank/gene_bank_audit_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/gene_bank/gene_bank_temperature_monitoring_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/gene_bank/gene_bank_viability_test_dialog.dart';

/// Input for husbandry actions - works with any GraphNode type
class HusbandryActionInput {
  HusbandryActionInput({
    required this.sheetContext,
    required this.actionContext,
    required this.node,
  });

  final BuildContext sheetContext;
  final BuildContext actionContext;
  final GraphNode node;
}

/// Gene bank action registry supporting all organism kinds.
/// Provides specialized actions for gene bank sites (audits, temperature monitoring, viability tests).
/// Previously restricted to coral only, now supports all organism types at gene bank sites.
class GeneBankActionRegistry {
  static List<Widget> buildTiles({
    required OrganismKind organismKind,
    required HusbandryActionInput input,
  }) {
    // Supports all organism kinds at gene bank sites

    final tiles = <Widget>[];
    if (input.node is SiteNode) {
      tiles.addAll(
        _buildSiteTiles(
          sheetContext: input.sheetContext,
          actionContext: input.actionContext,
          node: input.node as SiteNode,
        ),
      );
    }

    return tiles;
  }

  static List<Widget> _buildSiteTiles({
    required BuildContext sheetContext,
    required BuildContext actionContext,
    required SiteNode node,
  }) {
    final siteState = node.state;
    if (siteState is! SiteLoadedState) {
      return const [];
    }
    if (siteState.site.siteType != SiteType.geneBank) {
      return const [];
    }

    return [
      ListTile(
        leading: const Icon(Icons.fact_check, color: Colors.blue),
        title: const Text('Record Audit'),
        subtitle: const Text('Perform gene bank audit'),
        onTap: () async {
          Navigator.pop(sheetContext);
          await GeneBankAuditDialog.show(actionContext, targetNode: node);
        },
      ),
      ListTile(
        leading: const Icon(Icons.thermostat, color: Colors.red),
        title: const Text('Temperature Monitoring'),
        subtitle: const Text('Record temperature reading'),
        onTap: () async {
          Navigator.pop(sheetContext);
          await GeneBankTemperatureMonitoringDialog.show(
            actionContext,
            targetNode: node,
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.science, color: Colors.purple),
        title: const Text('Viability Test'),
        subtitle: const Text('Record viability test results'),
        onTap: () async {
          Navigator.pop(sheetContext);
          await GeneBankViabilityTestDialog.show(
            actionContext,
            targetNode: node,
          );
        },
      ),
    ];
  }
}
