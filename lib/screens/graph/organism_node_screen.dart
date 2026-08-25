import 'package:flutter/material.dart';
import 'package:seafoundry_community/models/graph/graph_node_streams.dart';
import 'package:seafoundry_community/models/graph/organism_node.dart';
import 'package:seafoundry_community/models/inventory/organism_extensions.dart';
import 'package:seafoundry_community/models/types/life_stage.dart';
import 'package:seafoundry_community/models/types/provenance_type.dart';
import 'package:seafoundry_community/navigation/community_graph_scaffold.dart';
import 'package:seafoundry_community/services/species_registry.dart';
import 'package:seafoundry_community/theme/spacing.dart';
import 'package:seafoundry_community/widgets/common/species_reference_photo.dart';
import 'package:seafoundry_community/widgets/dialogs/inventory_action_sheet.dart';
import 'package:seafoundry_community/widgets/graph_node/graph_node_events_section.dart';
import 'package:seafoundry_community/widgets/dialogs/organism_edit_dialog.dart';
import 'package:seafoundry_community/widgets/navigation/bottom_action_bar.dart';


/// Community version of OrganismNodeScreen with details and split actions.
class OrganismNodeScreen extends StatelessWidget {
  const OrganismNodeScreen({
    super.key,
    required this.loadedNodeState,
    required this.graphNode,
  });

  final OrganismLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  Widget build(BuildContext context) {
    final organismNode = graphNode as OrganismNode;

    return CommunitySimpleGraphScreenScaffold(
      bottomActions: [
        BottomAction(
          label: 'Inventory',
          icon: Icons.inventory_2_outlined,
          onPressed: () => InventoryActionSheet.show(
            context,
            node: graphNode,
          ),
        ),
        BottomAction(
          label: 'Edit Record',
          icon: Icons.edit,
          onPressed: () => OrganismEditDialog.show(
            context,
            organismNode: organismNode,
          ),
        ),
      ],
      body: _OrganismNodeBody(
        loadedNodeState: loadedNodeState,
        graphNode: graphNode,
      ),
    );
  }
}

class _OrganismNodeBody extends StatelessWidget {
  const _OrganismNodeBody({
    required this.loadedNodeState,
    required this.graphNode,
  });

  final OrganismLoadedState loadedNodeState;
  final GraphNode graphNode;

  @override
  Widget build(BuildContext context) {
    final organism = loadedNodeState.organism;
    final species = SpeciesRegistry.globalById(organism.speciesId);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main organism info card
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SpeciesReferencePhoto(
                        speciesId: organism.speciesId,
                        modelType: organism.modelType,
                        size: 72,
                      ),
                      SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              organism.name,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (organism.localGenetId != null &&
                                organism.localGenetId!.isNotEmpty) ...[
                              SizedBox(height: 2),
                              Text(
                                'ID: ${organism.localGenetId}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            SizedBox(height: Spacing.xs),
                            if (species != null)
                              Text(
                                species.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Spacing.md),
                  Divider(height: 1),
                  SizedBox(height: Spacing.md),
                  // Detail rows
                  _DetailRow(
                    icon: Icons.numbers,
                    label: 'Quantity',
                    value: '${organism.measurement.value.toInt()}',
                  ),
                  _DetailRow(
                    icon: Icons.eco,
                    label: 'Life Stage',
                    value: organism.lifeStage.stage.displayName,
                  ),
                  if (organism.physicalForm?.formId != null)
                    _DetailRow(
                      icon: Icons.category,
                      label: 'Physical Form',
                      value: organism.physicalFormDisplayName ?? 'Unknown',
                    ),
                  if (organism.provenanceType != null)
                    _DetailRow(
                      icon: Icons.history,
                      label: 'Provenance',
                      value: organism.provenanceType!.displayName,
                    ),
                  _DetailRow(
                    icon: Icons.favorite,
                    label: 'Health',
                    value: organism.healthStatus.displayName,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Spacing.md),
          GraphNodeEventsSection(events: loadedNodeState.events),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: Spacing.sm),
          Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
