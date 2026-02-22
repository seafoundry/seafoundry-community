// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/utils/human_sort.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/local_id_edit_scope_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Result from the LocalIdSelectionDialog
class LocalIdSelectionResult {
  const LocalIdSelectionResult({
    this.selectedGenet,
    this.customLocalId,
    this.scope = LocalIdEditScope.recordOnly,
  });

  /// The genet selected from the list (if any)
  final Genet? selectedGenet;

  /// Custom local ID entered by user (if not selecting a genet)
  final String? customLocalId;

  /// The scope for applying the localID change (record-only or genet-wide)
  final LocalIdEditScope scope;

  /// Returns the effective local ID to use
  String? get effectiveLocalId => selectedGenet?.name ?? customLocalId;

  /// Returns true if a genet was selected
  bool get hasSelectedGenet => selectedGenet != null;
}

/// Dialog for selecting a Local ID - either from existing genets or custom entry
///
/// Shows existing genets with provenance type and metadata information,
/// allowing users to select an existing genet or enter a custom ID.
class LocalIdSelectionDialog extends StatefulWidget {
  const LocalIdSelectionDialog({
    super.key,
    this.currentLocalId,
    this.speciesId,
  });

  final String? currentLocalId;
  final String? speciesId;

  static Future<LocalIdSelectionResult?> show(
    BuildContext context, {
    String? currentLocalId,
    String? speciesId,
  }) {
    // Capture repositories before showing dialog
    final genetRepository = context.maybeRead<GenetRepository>();
    final organizationRepository = context.maybeRead<OrganizationRepository>();
    final invitationRepository = context.maybeRead<InvitationRepository>();
    final provenanceLookupService = context.maybeRead<ProvenanceLookupService>();

    return showDialog<LocalIdSelectionResult>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        final providers = <RepositoryProvider>[
          if (genetRepository != null)
            RepositoryProvider<GenetRepository>.value(value: genetRepository),
          if (organizationRepository != null)
            RepositoryProvider<OrganizationRepository>.value(
              value: organizationRepository,
            ),
          if (invitationRepository != null)
            RepositoryProvider<InvitationRepository>.value(
              value: invitationRepository,
            ),
          if (provenanceLookupService != null)
            RepositoryProvider<ProvenanceLookupService>.value(
              value: provenanceLookupService,
            ),
        ];

        final dialog = LocalIdSelectionDialog(
          currentLocalId: currentLocalId,
          speciesId: speciesId,
        );

        if (providers.isEmpty) {
          return dialog;
        }

        return MultiRepositoryProvider(
          providers: providers,
          child: dialog,
        );
      },
    );
  }

  @override
  State<LocalIdSelectionDialog> createState() => _LocalIdSelectionDialogState();
}

class _LocalIdSelectionDialogState extends State<LocalIdSelectionDialog>
    with SingleTickerProviderStateMixin, SafeDialogMixin<LocalIdSelectionDialog> {
  late TabController _tabController;
  final _customIdController = TextEditingController();
  Genet? _selectedGenet;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customIdController.text = widget.currentLocalId ?? '';
    if (_customIdController.text.trim().isEmpty && widget.speciesId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillSuggestedLocalId();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customIdController.dispose();
    super.dispose();
  }

  Future<void> _prefillSuggestedLocalId() async {
    final repo = context.maybeRead<GenetRepository>();
    final speciesId = widget.speciesId;
    if (repo == null || speciesId == null) return;

    try {
      final suggestion = await repo.suggestNextLocalId(speciesId);
      if (!mounted) return;
      final normalized = suggestion.trim();
      if (normalized.isEmpty) return;
      if (_customIdController.text.trim().isNotEmpty) return;
      setState(() {
        _customIdController.text = normalized;
      });
    } catch (_) {
      // Ignore errors in suggestion (silent failure)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Local ID'),
      content: SizedBox(
        width: 500,
        height: 450,
        child: Column(
          children: [
            // Tabs for selection mode
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.list),
                  text: 'Select Existing',
                ),
                Tab(
                  icon: Icon(Icons.edit),
                  text: 'Custom ID',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGenetListTab(theme),
                  _buildCustomIdTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popDialog(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm() ? _handleConfirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildGenetListTab(ThemeData theme) {
    final genetRepository = context.maybeRead<GenetRepository>();
    if (genetRepository == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No genets available',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the Custom ID tab to enter a local identifier',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search field
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search genets...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),
        // Genet list
        Expanded(
          child: StreamBuilder<List<Genet>>(
            stream: genetRepository.streamAll,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading genets: ${snapshot.error}'),
                );
              }

              var genets = snapshot.data ?? [];

              // Filter by species if specified
              final selectedSpeciesId = widget.speciesId?.trim().toLowerCase();
              if (selectedSpeciesId != null && selectedSpeciesId.isNotEmpty) {
                genets = genets
                    .where(
                      (g) => g.speciesId.trim().toLowerCase() == selectedSpeciesId,
                    )
                    .toList();
              }

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                genets = genets.where((g) {
                  return g.name.toLowerCase().contains(query) ||
                      g.speciesId.toLowerCase().contains(query) ||
                      (g.localId ?? '').toLowerCase().contains(query);
                }).toList();
              }

              genets.sort(
                (a, b) => compareHumanReadable(a.name, b.name),
              );

              if (genets.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No genets match your search'
                            : 'No genets in inventory',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: genets.length,
                itemBuilder: (context, index) {
                  final genet = genets[index];
                  final isSelected = _selectedGenet?.id == genet.id;
                  return _GenetListTile(
                    genet: genet,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedGenet = genet),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }



  Widget _buildCustomIdTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Custom Local ID',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Use a unique identifier for this organism within your organization.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customIdController,
            decoration: const InputDecoration(
              labelText: 'Local ID *',
              hintText: 'e.g., APAL-001, CORAL-123',
              border: OutlineInputBorder(),
              helperText: 'Required unique identifier for this organism',
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          // Info box about provenance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The local ID helps identify this organism in spreadsheets and exports. '
                    'Select an existing genet from the first tab to link to existing lineage data.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canConfirm() {
    // Can confirm if on genet tab with selection, or on custom tab with text
    if (_tabController.index == 0) {
      return _selectedGenet != null;
    } else {
      // Custom ID tab - require a non-empty value
      return _customIdController.text.trim().isNotEmpty;
    }
  }

  void _handleConfirm() {
    final customLocalId = _customIdController.text.trim();
    final result = LocalIdSelectionResult(
      selectedGenet: _tabController.index == 0 ? _selectedGenet : null,
      customLocalId: _tabController.index == 1
          ? (customLocalId.isEmpty ? null : customLocalId)
          : null,
    );
    popDialog(result);
  }
}

/// List tile for displaying a genet with provenance information
class _GenetListTile extends StatelessWidget {
  const _GenetListTile({
    required this.genet,
    required this.isSelected,
    required this.onTap,
  });

  final Genet genet;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provenanceType = ProvenanceTypeX.tryParse(genet.provenanceTypeId);
    final species = SpeciesRegistry.globalById(genet.speciesId);

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check,
                        size: 16, color: theme.colorScheme.onPrimary)
                    : null,
              ),
              const SizedBox(width: 12),
              // Genet info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      genet.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (species != null)
                          _InfoChip(
                            icon: Icons.eco,
                            label: species.id.toUpperCase(),
                            color: theme.colorScheme.tertiary,
                          ),
                        if (provenanceType != null)
                          _InfoChip(
                            icon: _getProvenanceIcon(provenanceType),
                            label: provenanceType.displayName,
                            color: _getProvenanceColor(provenanceType, theme),
                          ),
                      ],
                    ),
                    // Additional metadata
                    if (provenanceType != null &&
                        provenanceType.metadata.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        provenanceType.metadata.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getProvenanceIcon(ProvenanceType type) {
    switch (type) {
      case ProvenanceType.wild:
        return Icons.nature;
      case ProvenanceType.sexualCohort:
        return Icons.group;
      case ProvenanceType.graduatedIndividual:
        return Icons.school;
      case ProvenanceType.transfer:
        return Icons.swap_horiz;
      case ProvenanceType.unknown:
        return Icons.help_outline;
    }
  }

  Color _getProvenanceColor(ProvenanceType type, ThemeData theme) {
    switch (type) {
      case ProvenanceType.wild:
        return Colors.green;
      case ProvenanceType.sexualCohort:
        return Colors.blue;
      case ProvenanceType.graduatedIndividual:
        return Colors.purple;
      case ProvenanceType.transfer:
        return Colors.orange;
      case ProvenanceType.unknown:
        return Colors.grey;
    }
  }
}

/// Small info chip for displaying metadata
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
