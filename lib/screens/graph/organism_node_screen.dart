// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/navigation/community_graph_scaffold.dart';
import 'package:seafoundry_app/services/tour_key_registry.dart';
import 'package:seafoundry_app/theme/spacing.dart';
import 'package:seafoundry_app/widgets/visual/did_you_know_banner.dart';

import '../../widgets/common/species_reference_photo.dart';
import '../../widgets/dialogs/observation/organism_observation_images_dialog.dart';
// GraphNodeEventsList is Pro-only - community uses simplified event display

/// Community version of OrganismNodeScreen without comments feature.
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
    return CommunitySimpleGraphScreenScaffold(
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              DidYouKnowBanner(
                nodeType:
                    loadedNodeState.organism.organismKind.metadata.displayName,
                speciesId: loadedNodeState.organism.speciesId,
                dismissKey: 'dyk-organism-${loadedNodeState.organism.id}',
              ),
              SizedBox(height: Spacing.md),
              // OrganismNodeInfo removed - Pro feature
              // Display basic organism info card
              Card(
                key: TourKeyRegistry.graphNodeInfoCard,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => OrganismObservationImagesDialog.show(
                    context,
                    organism: organism,
                    events: loadedNodeState.events,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SpeciesReferencePhoto(
                          speciesId: organism.speciesId,
                          modelType: organism.modelType,
                          size: 64,
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                organism.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              SizedBox(height: Spacing.xs),
                              Text(
                                'Type: ${organism.organismKind.metadata.displayName}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          SizedBox(height: Spacing.md),
          // Events list removed - Pro feature (GraphNodeEventsList)
        ],
      ),
    );
  }
}
