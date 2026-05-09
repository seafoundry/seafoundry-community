// @tier: community
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/components/core/loading_indicator.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/forms/inputs/genet_form_inputs.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/taxonomy/species_record.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';

/// A reusable species selector that opens a modal with region grouping and alphabetical shortcuts
class SpeciesSelector extends StatelessWidget {
  final Species? value;
  final String? errorText;
  final ValueChanged<Species?> onChanged;
  final String? labelText;
  final String? hintText;
  final bool enabled;
  final bool autoFocus;
  final VoidCallback? onSelectionComplete;

  /// Optional organism kind filter - when provided, only species of this kind are shown
  final OrganismKind? organismKind;

  const SpeciesSelector({
    super.key,
    required this.onChanged,
    this.value,
    this.errorText,
    this.labelText = 'Species',
    this.hintText,
    this.enabled = true,
    this.autoFocus = false,
    this.onSelectionComplete,
    this.organismKind,
  });

  /// Create from FormZ input
  factory SpeciesSelector.fromFormInput({
    Key? key,
    required GenetSpeciesSelection input,
    required ValueChanged<Species?> onChanged,
    String? labelText = 'Species',
    String? hintText,
    bool enabled = true,
    bool autoFocus = false,
    VoidCallback? onSelectionComplete,
    OrganismKind? organismKind,
  }) {
    return SpeciesSelector(
      key: key,
      value: input.value,
      errorText: input.displayError?.message,
      onChanged: onChanged,
      labelText: labelText,
      hintText: hintText,
      enabled: enabled,
      autoFocus: autoFocus,
      onSelectionComplete: onSelectionComplete,
      organismKind: organismKind,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrentUser, CurrentUserState>(
      builder: (context, userState) {
        if (userState is! CurrentUserLoaded) {
          return _buildLoadingState();
        }

        final speciesRegistry = context.watch<SpeciesRegistry>();
        final hasSpecies = speciesRegistry.all.isNotEmpty;

        if (!hasSpecies) {
          return _buildEmptyState();
        }

        return _buildSelectorButton(context, userState.organization);
      },
    );
  }

  Widget _buildLoadingState() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: 'Loading species...',
        prefixIcon: const LoadingIndicator.small(),
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      child: const Text('Loading...'),
    );
  }

  Widget _buildEmptyState() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: 'No species loaded — seed taxonomy first',
        prefixIcon: const Icon(Icons.science),
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      child: Text(
        'No species available',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildSelectorButton(BuildContext context, Organization organization) {
    return InkWell(
      onTap: enabled ? () => _showSpeciesModal(context, organization) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: const Icon(Icons.science),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
          errorText: errorText,
          enabled: enabled,
        ),
        child: value != null
            ? Row(
                children: [
                  Text(
                    value!.code,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value!.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                hintText ?? 'Select species',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
      ),
    );
  }

  Future<void> _showSpeciesModal(BuildContext context, Organization organization) async {
    final taxonomyService = context.read<TaxonomyService?>();
    final speciesRegistry = context.read<SpeciesRegistry>();

    final result = await showModalBottomSheet<Species>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      // Uses root navigator so the modal overlays the entire app, ensuring
      // consistent full-screen experience regardless of nested navigation context.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _SpeciesSelectionModal(
        currentValue: value,
        organization: organization,
        taxonomyService: taxonomyService,
        speciesRegistry: speciesRegistry,
        organismKind: organismKind,
      ),
    );

    if (result != null) {
      onChanged(result);
      onSelectionComplete?.call();
    }
  }
}

/// Modal bottom sheet for species selection with region grouping and alphabetical shortcuts
class _SpeciesSelectionModal extends StatefulWidget {
  const _SpeciesSelectionModal({
    required this.currentValue,
    required this.organization,
    required this.taxonomyService,
    required this.speciesRegistry,
    this.organismKind,
  });

  final Species? currentValue;
  final Organization organization;
  final TaxonomyService? taxonomyService;
  final SpeciesRegistry speciesRegistry;
  final OrganismKind? organismKind;

  @override
  State<_SpeciesSelectionModal> createState() => _SpeciesSelectionModalState();
}

class _SpeciesSelectionModalState extends State<_SpeciesSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {};

  List<SpeciesRecord> _allRecords = [];
  Map<String, List<SpeciesRecord>> _groupedByRegion = {};
  List<String> _sortedRegions = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpeciesRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSpeciesRecords() async {
    final service = widget.taxonomyService;
    if (service == null) {
      // Fallback to registry species without region grouping
      if (kDebugMode) {
        LoggingService.instance.debug(
          'SpeciesSelector: TaxonomyService is null, falling back to registry',
        );
      }
      _buildFromRegistry();
      return;
    }

    try {
      // Filter by organism kind when provided
      final records = await service.listSpecies(organismKind: widget.organismKind);
      if (records.isEmpty) {
        // Firestore taxonomy collection is empty (e.g. emulator without seed data).
        // Fall back to the builtin species registry.
        if (kDebugMode) {
          LoggingService.instance.debug(
            'SpeciesSelector: TaxonomyService returned 0 species, falling back to registry',
          );
        }
        if (mounted) _buildFromRegistry();
        return;
      }
      if (kDebugMode) {
        LoggingService.instance.debug(
          'SpeciesSelector: Loaded ${records.length} species from TaxonomyService (filter: ${widget.organismKind?.name ?? "none"})',
        );
      }
      if (mounted) {
        setState(() {
          _allRecords = records;
          _groupByRegion();
          _isLoading = false;
        });
      }
    } catch (e) {
      LoggingService.instance.warning('SpeciesSelector: Error loading species', e);
      if (mounted) {
        _buildFromRegistry();
      }
    }
  }

  void _buildFromRegistry() {
    // Create pseudo-records from Species for fallback
    var records = widget.speciesRegistry.all.map((species) => SpeciesRecord(
      id: species.id,
      organismKind: _inferOrganismKind(species),
      genus: species.genus,
      species: species.species,
      code: species.code,
    )).toList();

    // Filter by organism kind when provided
    if (widget.organismKind != null) {
      records = records.where((r) => r.organismKind == widget.organismKind).toList();
    }

    setState(() {
      _allRecords = records;
      _groupByRegion();
      _isLoading = false;
    });
  }

  void _groupByRegion() {
    _sectionKeys.clear();
    _groupedByRegion = {};

    for (final record in _allRecords) {
      final region = _extractRegion(record);
      _groupedByRegion.putIfAbsent(region, () => []).add(record);
    }
    if (kDebugMode) {
      LoggingService.instance.debug(
        'SpeciesSelector: Grouped into regions: ${_groupedByRegion.keys.toList()}',
      );
      for (final entry in _groupedByRegion.entries) {
        LoggingService.instance.debug(
          '   ${entry.key}: ${entry.value.length} species',
        );
      }
    }

    // Sort each region's species alphabetically
    for (final species in _groupedByRegion.values) {
      species.sort((a, b) => a.scientificName.compareTo(b.scientificName));
    }

    // Sort regions: Caribbean first (most common for coral restoration), then alphabetically
    _sortedRegions = _groupedByRegion.keys.toList()
      ..sort((a, b) {
        if (a == 'Caribbean') return -1;
        if (b == 'Caribbean') return 1;
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.compareTo(b);
      });

    // Create keys for each section
    for (final region in _sortedRegions) {
      _sectionKeys[region] = GlobalKey();
    }
  }

  String _extractRegion(SpeciesRecord record) {
    final nativeRange = record.metadata['nativeRange']?.toString();
    if (nativeRange == null || nativeRange.isEmpty) {
      return 'Other';
    }
    return nativeRange;
  }

  List<SpeciesRecord> _getFilteredRecords() {
    if (_searchQuery.isEmpty) {
      return _allRecords;
    }

    final query = _searchQuery.toLowerCase();
    return _allRecords.where((record) {
      return record.scientificName.toLowerCase().contains(query) ||
          record.code.toLowerCase().contains(query) ||
          record.commonNames.any((name) => name.toLowerCase().contains(query));
    }).toList();
  }

  void _scrollToRegion(String region) {
    final key = _sectionKeys[region];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (sheetContext, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.science, color: Color(0xFF00897B)),
                    const SizedBox(width: 8),
                    Text(
                      'Select Species',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or code...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(height: 8),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        children: [
                          // Alphabetical shortcuts (region-based)
                          if (_searchQuery.isEmpty && _sortedRegions.length > 1)
                            _buildRegionShortcuts(),
                          // Species list
                          Expanded(
                            child: _searchQuery.isNotEmpty
                                ? _buildSearchResults(scrollController)
                                : _buildGroupedList(scrollController),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegionShortcuts() {
    return Container(
      width: 48,
      color: Colors.grey.shade100,
      child: ListView.builder(
        itemCount: _sortedRegions.length,
        itemBuilder: (context, index) {
          final region = _sortedRegions[index];
          final shortcut = _getRegionShortcut(region);
          final isSelected = widget.currentValue != null &&
              _groupedByRegion[region]?.any((r) => r.id == widget.currentValue!.id) == true;

          return InkWell(
            onTap: () => _scrollToRegion(region),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00897B).withValues(alpha: 0.1) : null,
              ),
              child: Center(
                child: Tooltip(
                  message: region,
                  child: Text(
                    shortcut,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getRegionShortcut(String region) {
    // Create 2-3 letter abbreviations
    switch (region.toLowerCase()) {
      case 'caribbean':
        return 'CAR';
      case 'indo-pacific':
        return 'IND';
      case 'atlantic':
        return 'ATL';
      case 'pacific':
        return 'PAC';
      case 'red sea':
        return 'RED';
      case 'gulf of mexico':
        return 'GOM';
      case 'north atlantic':
        return 'N.AT';
      case 'other':
        return '...';
      default:
        // Take first 3 letters
        return region.length > 3 ? region.substring(0, 3).toUpperCase() : region.toUpperCase();
    }
  }

  Widget _buildGroupedList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _sortedRegions.length,
      itemBuilder: (context, index) {
        final region = _sortedRegions[index];
        final species = _groupedByRegion[region] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Region header
            Container(
              key: _sectionKeys[region],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(
                    _getRegionIcon(region),
                    size: 16,
                    color: const Color(0xFF00897B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    region.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${species.length})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Species in this region
            ...species.map((record) => _buildSpeciesTile(record)),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(ScrollController scrollController) {
    final filtered = _getFilteredRecords();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No species found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildSpeciesTile(filtered[index]),
    );
  }

  Widget _buildSpeciesTile(SpeciesRecord record) {
    final species = widget.speciesRegistry.byId(record.id);
    final isSelected = widget.currentValue?.id == record.id;
    final commonName = record.commonNames.isNotEmpty ? record.commonNames.first : null;

    return ListTile(
      selected: isSelected,
      selectedTileColor: const Color(0xFF00897B).withValues(alpha: 0.1),
      leading: Container(
        width: 48,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          record.code,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
      title: Text(
        record.scientificName,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      subtitle: commonName != null
          ? Text(
              commonName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF00897B))
          : null,
      onTap: () {
        final selectedSpecies = species ?? Species(
          id: record.id,
          genus: record.genus,
          species: record.species,
          codeOverride: record.code,
        );
        Navigator.pop(context, selectedSpecies);
      },
    );
  }

  IconData _getRegionIcon(String region) {
    switch (region.toLowerCase()) {
      case 'caribbean':
        return Icons.beach_access;
      case 'indo-pacific':
      case 'pacific':
        return Icons.waves;
      case 'atlantic':
      case 'north atlantic':
        return Icons.sailing;
      case 'red sea':
        return Icons.water;
      case 'gulf of mexico':
        return Icons.anchor;
      default:
        return Icons.public;
    }
  }

  // Infer organism kind from species for fallback
  static OrganismKind _inferOrganismKind(Species species) {
    // Default to coral for backwards compatibility
    return OrganismKind.coral;
  }
}
