// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/site_node.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';

class SiteOrganismDialog extends StatefulWidget {
  const SiteOrganismDialog({
    super.key,
    required this.siteNode,
    required this.siteRepository,
  });

  final SiteNode siteNode;
  final SiteRepository siteRepository;

  static Future<void> show(
    BuildContext context, {
    required SiteNode siteNode,
  }) {
    final siteRepository = context.read<SiteRepository>();
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) => SiteOrganismDialog(
        siteNode: siteNode,
        siteRepository: siteRepository,
      ),
    );
  }

  @override
  State<SiteOrganismDialog> createState() => _SiteOrganismDialogState();
}

class _SiteOrganismDialogState extends State<SiteOrganismDialog>
    with SafeDialogMixin<SiteOrganismDialog> {
  late final List<OrganismKind> _availableOrganisms;
  final Set<OrganismKind> _selectedOrganisms = <OrganismKind>{};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _availableOrganisms = _resolveAvailableOrganisms();
  }

  @override
  Widget build(BuildContext context) {
    final site = _resolvedSite;
    final hasOptions = _availableOrganisms.isNotEmpty;

    return AlertDialog(
      title: Text('Add Organism to ${site.name}'),
      content: SizedBox(
        width: 420,
        child: hasOptions ? _buildSelectionList() : _buildEmptyState(),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : popDialog,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _handleSave : null,
          child: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Organisms'),
        ),
      ],
    );
  }

  Widget _buildSelectionList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the organisms you want to enable for this site.',
        ),
        const SizedBox(height: 12),
        ..._availableOrganisms.map(
          (kind) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(kind.metadata.displayName),
            value: _selectedOrganisms.contains(kind),
            onChanged: _isSaving
                ? null
                : (checked) {
                    setState(() {
                      if (checked ?? false) {
                        _selectedOrganisms.add(kind);
                      } else {
                        _selectedOrganisms.remove(kind);
                      }
                    });
                  },
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Text(
      'All organisms supported by your organization are already enabled for '
      'this site.',
    );
  }

  bool get _canSubmit =>
      !_isSaving &&
      _selectedOrganisms.isNotEmpty &&
      _availableOrganisms.isNotEmpty;

  Future<void> _handleSave() async {
    if (_selectedOrganisms.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one organism.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final site = _resolvedSite;
    final updatedKinds = <OrganismKind>{
      ...site.supportedOrganismKinds,
      ..._selectedOrganisms,
    }.toList(growable: false);

    final updatedSite = site.copyWith(
      supportedOrganismKinds: updatedKinds,
    );

    try {
      await widget.siteRepository.updateSiteWithCorrection(
        originalSite: site,
        updatedSite: updatedSite,
      );
      widget.siteNode.add(const GraphNodeReloadRequested());
      if (!mounted) return;
      popDialog();
      showSafeDialogSnackBar(
        context,
        'Enabled ${_selectedOrganisms.length} organism(s) for ${site.name}.',
        isSuccess: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to update organisms. Please try again.';
      });
      showSafeDialogSnackBar(
        context,
        error.toString(),
        isError: true,
      );
    }
  }

  List<OrganismKind> _resolveAvailableOrganisms() {
    try {
      final organization = context.read<Organization>();
      final existing = _resolvedSite.supportedOrganismKinds.toSet();
      return organization.supportedOrganismKinds
          .where((kind) => !existing.contains(kind))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Site get _resolvedSite {
    final state = widget.siteNode.state;
    if (state is SiteLoadedState) {
      return state.site;
    }
    return widget.siteNode.initialRecord;
  }
}
