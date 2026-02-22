// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/models/inventory/organism_extensions.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/utils/date_formatter.dart';
import 'package:seafoundry_app/widgets/dialogs/base/dialog_base.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/common/organism_reference_links.dart';
import 'package:seafoundry_app/widgets/organism_helpers.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for viewing organism details (read-only)
///
/// Universal details dialog supporting all organism types (coral, kelp, oyster,
/// seagrass, finfish, crab) with organism-aware formatting and capability display.
class OrganismDetailsDialog extends StatelessWidget {
  final OrganismNode organismNode;
  final User? creator;

  const OrganismDetailsDialog({
    super.key,
    required this.organismNode,
    this.creator,
  });

  static Future<void> show(
    BuildContext context, {
    required OrganismNode organismNode,
    User? creator,
  }) {
    final providers = _captureDialogProviders(context);
    if (providers.isEmpty) {
      return showDialog(
        context: context,
        useRootNavigator: false, // Stay within provider scope
        builder: (_) =>
            OrganismDetailsDialog(organismNode: organismNode, creator: creator),
      );
    }
    return DialogBase.showDialogWithProviders<void>(
      context: context,
      providers: providers,
      dialog: OrganismDetailsDialog(
        organismNode: organismNode,
        creator: creator,
      ),
    );
  }

  /// Helper to safely get organism from OrganismNode state
  OrganismRecord _getOrganism() {
    final state = organismNode.state;
    if (state is! GraphLoadedState<OrganismRecord>) {
      throw StateError('OrganismNode must be loaded to show details');
    }
    return state.record;
  }

  /// Helper to get species for the organism
  Species _getSpecies() {
    final organism = _getOrganism();
    if (organism.speciesId == null) return Species.fallback('unknown');
    final species =
        SpeciesRegistry.globalById(organism.speciesId!) ??
        Species.fallback(organism.speciesId!);
    return species;
  }

  @override
  Widget build(BuildContext context) {
    final organism = _getOrganism();

    return AlertDialog(
      title: Row(
        children: [
          Icon(_getOrganismIcon(organism)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${organism.organismKind.metadata.displayName} Details',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: DialogScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Organism Type
              _buildDetailSection(
                context,
                label: 'Organism Type',
                value: organism.organismKind.metadata.displayName,
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 16),

              // Record Name (optional individual specimen identifier)
              if (organism.recordName.trim().isNotEmpty) ...[
                _buildDetailSection(
                  context,
                  label: 'Record Name',
                  value: organism.recordName.trim(),
                  icon: Icons.label_outline,
                ),
                const SizedBox(height: 16),
              ],
              if (organism.localId != null &&
                  organism.localId!.trim().isNotEmpty) ...[
                _buildDetailSection(
                  context,
                  label: 'Local ID',
                  value: organism.localId!.trim(),
                  icon: Icons.fingerprint,
                  valueWidget: GenetIdLink(
                    localId: organism.localId!.trim(),
                    genetId: organism.genetId,
                    showUnderline: true,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Species
              if (organism.speciesId != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Species',
                  value: _getSpecies().name,
                  icon: Icons.science_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // Life Stage
              _buildDetailSection(
                context,
                label: 'Life Stage',
                value: organism.lifeStage.stage.displayName,
                icon: Icons.timeline_outlined,
              ),
              const SizedBox(height: 16),

              // Physical Form
              if (organism.physicalForm != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Physical Form',
                  value:
                      '${organism.physicalFormDisplayName ?? organism.physicalForm!.formId} (${organism.physicalForm!.sizeBandId})',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // Measurement
              _buildDetailSection(
                context,
                label: organism.measurement.unit.label,
                value: organism.measurement.value.toString(),
                icon: Icons.numbers_outlined,
              ),
              const SizedBox(height: 16),

              // Size (if available)
              if (organism.sizeSpec.hasSize) ...[
                _buildDetailSection(
                  context,
                  label: 'Size',
                  value:
                      organism.sizeSpec.sizeClass?.toUpperCase() ??
                      '${organism.sizeSpec.measuredDimension} ${organism.sizeSpec.dimensionUnit?.symbol ?? ''}',
                  icon: Icons.straighten_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // Health Status
              _buildDetailSection(
                context,
                label: 'Health Status',
                value: organism.healthStatus.displayName,
                icon: Icons.favorite_outline,
                valueColor: _getHealthStatusColor(organism.healthStatus),
              ),
              const SizedBox(height: 16),

              // Capabilities
              _buildCapabilitiesSection(context, organism),
              const SizedBox(height: 16),

              // Provenance
              if (organism.provenanceType != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Provenance Type',
                  value: organism.provenanceType!.displayName,
                  icon: Icons.account_tree_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // Genet ID
              if (organism.genetId != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Genet ID',
                  value: organism.genetId!,
                  icon: Icons.hub_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // Location
              _buildDetailSection(
                context,
                label: 'Location',
                value: _getLocationPath(),
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),

              // Created date
              _buildDetailSection(
                context,
                label: 'Created',
                value: DateFormatter.formatDateTime(
                  DateTime.parse(organism.createdAt),
                ),
                icon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 16),

              // Created by
              if (creator != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Created by',
                  value: creator?.name ?? creator?.email ?? 'Unknown',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
              ],

              // IDs section (collapsible)
              _buildIdSection(context, organism),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// Get appropriate icon for organism type
  IconData _getOrganismIcon(OrganismRecord organism) {
    return OrganismIconHelper.getIcon(
      organism.organismKind,
      organism.lifeStage.stage,
      organism.physicalForm,
    );
  }

  /// Build capabilities section showing what operations are possible
  Widget _buildCapabilitiesSection(
    BuildContext context,
    OrganismRecord organism,
  ) {
    final capabilities = organism.capabilities;
    final capabilityList = <String>[];

    if (capabilities.canPropagateAsexually) capabilityList.add('Can Propagate Asexually');
    if (capabilities.canRemount) capabilityList.add('Can Remount');
    if (capabilities.canSpawn) capabilityList.add('Can Spawn');
    if (capabilities.canMetamorphose) capabilityList.add('Can Metamorphose');
    if (capabilities.canMolt) capabilityList.add('Can Molt');
    if (capabilities.requiresSubstrate) {
      capabilityList.add('Requires Substrate');
    }

    if (capabilityList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            UIText.caption('Capabilities', color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: capabilityList
                .map(
                  (cap) => Chip(
                    label: Text(cap, style: const TextStyle(fontSize: 12)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    Widget? valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIText.caption(label, color: AppColors.textSecondary),
              const SizedBox(height: 4),
              valueWidget ??
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: valueColor != null ? FontWeight.w500 : null,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdSection(BuildContext context, OrganismRecord organism) {
    return ExpansionTile(
      leading: Icon(
        Icons.code_outlined,
        size: 20,
        color: AppColors.textSecondary,
      ),
      title: UIText.caption('Technical IDs', color: AppColors.textSecondary),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _buildIdRow(context, 'Organism ID', organism.id),
              const SizedBox(height: 8),
              if (organism.speciesId != null) ...[
                _buildIdRow(context, 'Species ID', organism.speciesId!),
                const SizedBox(height: 8),
              ],
              if (organism.siteId != null) ...[
                _buildIdRow(context, 'Site ID', organism.siteId!),
                const SizedBox(height: 8),
              ],
              if (organism.groupId != null) ...[
                _buildIdRow(context, 'Group ID', organism.groupId!),
                const SizedBox(height: 8),
              ],
              if (organism.genetId != null) ...[
                _buildIdRow(context, 'Genet ID', organism.genetId!),
                const SizedBox(height: 8),
              ],
              _buildIdRow(context, 'Slug', organism.slug),
              const SizedBox(height: 8),
              _buildIdRow(context, 'URL Path', organism.urlPath),
              const SizedBox(height: 8),
              _buildIdRow(context, 'Internal Path', organism.internalPath),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UIText.bodySmall(label, color: AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            showSafeDialogSnackBar(
              context,
              '$label copied',
              isSuccess: true,
              duration: const Duration(seconds: 1),
            );
          },
          tooltip: 'Copy $label',
        ),
      ],
    );
  }

  String _getLocationPath() {
    final parts = <String>[];
    GraphNode? current = organismNode.parent;

    while (current != null && current is! OrganizationNode) {
      final state = current.state;
      if (state is GraphLoadedState) {
        // Handle different record types with name field
        final record = state.record;
        if (record is Site) {
          parts.insert(0, record.name);
        } else if (record is Group) {
          parts.insert(0, record.name);
        } else if (record is OrganismRecord) {
          final recordName = record.recordName.trim();
          if (recordName.isNotEmpty) {
            parts.insert(0, recordName);
          } else if (record.localId != null && record.localId!.isNotEmpty) {
            parts.insert(0, record.localId!);
          }
        }
      }
      current = current.parent;
    }

    return parts.isEmpty ? 'Root' : parts.join(' > ');
  }

  Color _getHealthStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.healthy:
        return Colors.green;
      case HealthStatus.stressed:
        return Colors.orange;
      case HealthStatus.diseased:
        return Colors.red;
      case HealthStatus.recovering:
        return Colors.blue;
      case HealthStatus.bleached:
        return Colors.yellow[700]!;
      case HealthStatus.damaged:
        return Colors.red[300]!;
      case HealthStatus.fragmented:
        return Colors.purple;
      case HealthStatus.transferred:
        return Colors.indigo;
      case HealthStatus.outplanted:
        return Colors.teal;
      case HealthStatus.deceased:
      case HealthStatus.lost:
      case HealthStatus.unknown:
        return Colors.grey;
    }
  }
}

List<SingleChildWidget> _captureDialogProviders(BuildContext context) {
  final providers = <SingleChildWidget>[];

  void addBloc<T extends BlocBase<dynamic>>() {
    try {
      final bloc = context.read<T>();
      providers.add(BlocProvider<T>.value(value: bloc));
    } on ProviderNotFoundException {
      // Dialog can still render without this provider.
    }
  }

  addBloc<CurrentUser>();
  addBloc<NavigationCubit>();

  return providers;
}