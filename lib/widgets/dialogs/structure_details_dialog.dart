// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seafoundry_app/blocs/graph_node/organism_node.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/graph_node/organization_node.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/theme/theme.dart';
import 'package:seafoundry_app/widgets/ui_text.dart';
import 'components/dialog_scroll_view.dart';

/// Dialog for viewing structure details (read-only)
class StructureDetailsDialog extends StatelessWidget {
  final GraphNode node;
  final User? creator;

  const StructureDetailsDialog({super.key, required this.node, this.creator});

  static Future<void> show(BuildContext context, {required GraphNode node, User? creator}) {
    return showDialog(
      context: context,
      useRootNavigator: false, // Stay within provider scope
      builder: (_) => StructureDetailsDialog(node: node, creator: creator),
    );
  }

  /// Helper to safely get record from GraphNode state
  GraphNodeRecord _getRecord(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      throw StateError('Node must be loaded to show details');
    }
    return state.record;
  }

  /// Helper to safely get children from GraphNode state
  List<GraphNode> _getChildren(GraphNode node) {
    final state = node.state;
    if (state is! GraphLoadedState) {
      return const [];
    }
    return state.children;
  }

  @override
  Widget build(BuildContext context) {
    final record = _getRecord(node);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text('${_getTypeName()} Details')),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: DialogScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              _buildDetailSection(context, label: 'Name', value: record.name, icon: Icons.label_outline),
              const SizedBox(height: 16),

              // Type
              _buildDetailSection(context, label: 'Type', value: _getTypeValue(), icon: Icons.category_outlined),
              const SizedBox(height: 16),

              // Parent structure path
              if (node.parent != null) ...[
                _buildDetailSection(
                  context,
                  label: 'Location',
                  value: _getLocationPath(),
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
              ],

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

              // Coral count (for group structures)
              if (node is GroupNode) ...[
                _buildDetailSection(
                  context,
                  label: 'Coral Count',
                  value: _getCoralCount().toString(),
                  icon: Icons.water_drop_outlined,
                ),
                const SizedBox(height: 16),
              ],

              // IDs section (collapsible)
              _buildIdSection(context, record),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popSafeDialogContext(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
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
              UIText.bodyMedium(value),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdSection(BuildContext context, GraphNodeRecord record) {
    return ExpansionTile(
      leading: Icon(Icons.code_outlined, size: 20, color: AppColors.textSecondary),
      title: UIText.caption('Technical IDs', color: AppColors.textSecondary),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _buildIdRow(context, 'Record ID', record.id),
              const SizedBox(height: 8),
              _buildIdRow(context, 'Slug', record.slug),
              const SizedBox(height: 8),
              _buildIdRow(context, 'URL Path', record.urlPath),
              const SizedBox(height: 8),
              _buildIdRow(context, 'Internal Path', record.internalPath),
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
              Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
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
            );
          },
          tooltip: 'Copy $label',
        ),
      ],
    );
  }

  String _getTypeName() {
    if (node is SiteNode) return 'Site';
    if (node is GroupNode) return 'Structure';
    return 'Record';
  }

  String _getTypeValue() {
    if (node is SiteNode) {
      final site = _getRecord(node) as Site;
      final siteType = SiteType.maybeFromId(site.siteTypeId);
      return siteType?.name ?? 'Unknown Site Type';
    }
    if (node is GroupNode) {
      final group = _getRecord(node) as Group;
      final groupType = GroupType.builtins[group.groupTypeId];
      return groupType?.name ?? 'Unknown Group Type';
    }
    return _getRecord(node).modelType.name;
  }

  String _getLocationPath() {
    final parts = <String>[];
    GraphNode? current = node.parent;

    while (current != null && current is! OrganizationNode) {
      parts.insert(0, _getRecord(current).name);
      current = current.parent;
    }

    return parts.isEmpty ? 'Root' : parts.join(' > ');
  }

  int _getCoralCount() {
    if (node is! GroupNode) return 0;

    int count = 0;
    void countCorals(GraphNode node) {
      if (node is OrganismNode) {
        count++;
      }
      for (final child in _getChildren(node)) {
        countCorals(child);
      }
    }

    countCorals(node);
    return count;
  }
}