// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/graph/site_node.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/widgets/dialogs/structure_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Supported categories of missing entities detected during universal CSV import.
enum MissingEntityType { organization, site, enclosure, group }

class MissingEntity {
  const MissingEntity({
    required this.type,
    required this.value,
    required this.message,
  });

  final MissingEntityType type;
  final String value;
  final String message;
}

/// Modal wizard that guides users through resolving missing entities (org/site/group)
/// detected during CSV validation. The wizard keeps track of which entries have been
/// marked as resolved so the caller can re-run validation once everything is covered.
class UniversalCreateMissingWizard extends StatefulWidget {
  const UniversalCreateMissingWizard({
    super.key,
    required this.missingEntities,
    required this.graphRepository,
    required this.hostContext,
  });

  final List<MissingEntity> missingEntities;
  final GraphRepository graphRepository;
  final BuildContext hostContext;

  static Future<bool> show(
    BuildContext context, {
    required List<MissingEntity> missingEntities,
  }) async {
    if (missingEntities.isEmpty) return false;
    final graphRepository = context.read<GraphRepository>();
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => UniversalCreateMissingWizard(
        missingEntities: missingEntities,
        graphRepository: graphRepository,
        hostContext: context,
      ),
    );
    return result ?? false;
  }

  @override
  State<UniversalCreateMissingWizard> createState() =>
      _UniversalCreateMissingWizardState();
}

class _UniversalCreateMissingWizardState
    extends State<UniversalCreateMissingWizard> {
  int _currentStep = 0;
  late final Set<String> _resolvedValues;

  @override
  void initState() {
    super.initState();
    _resolvedValues = <String>{};
  }

  bool get _allResolved =>
      _resolvedValues.length == widget.missingEntities.length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 520,
        child: Stepper(
          currentStep: _currentStep,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, right: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_currentStep == 0 && !_allResolved)
                        ? null
                        : () {
                            if (_currentStep == 0) {
                              setState(() {
                                _currentStep = 1;
                              });
                            } else {
                              Navigator.of(context).pop(true);
                            }
                          },
                    child: Text(_currentStep == 0 ? 'Continue' : 'Close'),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Resolve missing entries'),
              state: _allResolved ? StepState.complete : StepState.editing,
              isActive: true,
              content: _MissingEntitiesList(
                entities: widget.missingEntities,
                resolvedValues: _resolvedValues,
                onToggleResolved: _toggleResolved,
                onCreateTapped: _handleCreateTapped,
              ),
            ),
            Step(
              title: const Text('Re-run validation'),
              isActive: _allResolved,
              state: _allResolved ? StepState.complete : StepState.disabled,
              content: const Text(
                'All missing entries have been marked as resolved. Re-run CSV '
                'validation to confirm the import can proceed.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleResolved(String value, bool resolved) {
    setState(() {
      if (resolved) {
        _resolvedValues.add(value);
      } else {
        _resolvedValues.remove(value);
      }
    });
  }

  Future<void> _handleCreateTapped(MissingEntity entity) async {
    switch (entity.type) {
      case MissingEntityType.group:
        await _openCreateGroupDialog(entity);
        break;
      case MissingEntityType.site:
        await _openCreateSiteDialog(entity.value);
        break;
      case MissingEntityType.organization:
      case MissingEntityType.enclosure:
        _showSnack(
          'Creation for ${entity.type.name} is not yet automated. '
          'Use the admin console, then mark the entry as resolved.',
        );
        break;
    }
  }

  Future<void> _openCreateSiteDialog(String siteName) async {
    final result = await StructureDialog.show(
      widget.hostContext,
      type: StructureType.site,
    );
    if (result is Site) {
      setState(() {
        _resolvedValues.add(siteName);
      });
    }
  }

  Future<void> _openCreateGroupDialog(MissingEntity entity) async {
    final hostContext = widget.hostContext;
    final messenger = ScaffoldMessenger.maybeOf(hostContext);
    final groupPath = entity.value;

    // Try to derive site path from the group path (inventory-style: org/site/group)
    var sitePath = _deriveSitePath(groupPath);

    // For outplanting, structure errors provide bare names (not paths).
    // Try to extract site name from the error message:
    //   'Unknown structure name within site "SiteName"'
    if (sitePath == null) {
      final siteNameMatch = RegExp(
        r'within site "([^"]+)"',
      ).firstMatch(entity.message);
      if (siteNameMatch != null) {
        final siteName = siteNameMatch.group(1)!;
        // Look up the site by name using SiteRepository from the host context
        final siteRepo = hostContext.maybeRead<SiteRepository>();
        if (siteRepo != null) {
          final snapshot = await siteRepo.collectionRef
              .where('name', isEqualTo: siteName)
              .limit(1)
              .get();
          if (snapshot.docs.isNotEmpty) {
            final siteData = Map<String, dynamic>.from(
              snapshot.docs.first.data(),
            );
            siteData['id'] = snapshot.docs.first.id;
            final site = Site.fromJson(siteData);
            final siteNode = await widget.graphRepository.getNodeForUrlPath(
              site.urlPath,
            );
            if (siteNode is SiteNode) {
              final result = await StructureDialog.show(
                hostContext,
                type: StructureType.group,
                parentNode: siteNode,
              );
              if (result != null) {
                setState(() {
                  _resolvedValues.add(groupPath);
                });
              }
              return;
            }
          }
        }
      }

      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Unable to determine parent site for "$groupPath". '
            'Create the site first, then rerun the wizard.',
          ),
        ),
      );
      return;
    }

    final siteNode = await widget.graphRepository.getNodeForUrlPath(sitePath);

    if (siteNode is SiteNode) {
      final result = await StructureDialog.show(
        hostContext,
        type: StructureType.group,
        parentNode: siteNode,
      );
      if (result != null) {
        setState(() {
          _resolvedValues.add(groupPath);
        });
      }
      return;
    }

    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Unable to locate site for "$groupPath". Create the site first, then rerun the wizard.',
        ),
      ),
    );
  }

  String? _deriveSitePath(String groupPath) {
    final normalized = groupPath.trim();
    if (normalized.isEmpty) return null;

    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final orgDomain = widget.graphRepository.organization.domain;
    if (segments.isEmpty) return null;

    final hasDomainPrefix = segments.first == orgDomain;
    final siteIndex = hasDomainPrefix ? 1 : 0;
    if (siteIndex >= segments.length) return null;

    final siteSlug = segments[siteIndex];
    return '$orgDomain/$siteSlug';
  }

  void _showSnack(String message, {ScaffoldMessengerState? messenger}) {
    final targetMessenger =
        messenger ?? ScaffoldMessenger.maybeOf(widget.hostContext);
    targetMessenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MissingEntitiesList extends StatelessWidget {
  const _MissingEntitiesList({
    required this.entities,
    required this.resolvedValues,
    required this.onToggleResolved,
    required this.onCreateTapped,
  });

  final List<MissingEntity> entities;
  final Set<String> resolvedValues;
  final void Function(String value, bool resolved) onToggleResolved;
  final Future<void> Function(MissingEntity entity) onCreateTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'We detected entries that reference organizations, sites, or groups '
          'that do not exist. Create or map these records before importing.',
        ),
        const SizedBox(height: 12),
        ...entities.map((entity) {
          final resolved = resolvedValues.contains(entity.value);
          final canCreate = entity.type == MissingEntityType.group ||
              entity.type == MissingEntityType.site;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entity.value,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (canCreate)
                        OutlinedButton.icon(
                          onPressed: () => onCreateTapped(entity),
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(entity.message),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: resolved,
                    onChanged: (value) =>
                        onToggleResolved(entity.value, value ?? false),
                    title: const Text('Mark as resolved'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
