// @tier: community
import 'package:flutter/material.dart';
import 'package:seafoundry_app/models/types/group_type.dart';

/// Preset configurations for common nursery setups.
/// Makes it easy for users to select a familiar structure hierarchy.
class NurseryPreset {
  const NurseryPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.structureType,
    this.substructureType,
    required this.isExSitu,
    this.isProOnly = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final GroupType structureType;
  final GroupType? substructureType;
  final bool isExSitu;
  final bool isProOnly;

  /// Common presets for ex-situ (land-based) nurseries
  static const List<NurseryPreset> exSituPresets = [
    NurseryPreset(
      id: 'gene_bank_tanks',
      name: 'Gene Bank with Tanks',
      description: 'Tanks for holding coral fragments or broodstock',
      icon: Icons.science,
      structureType: GroupType.tank,
      isExSitu: true,
    ),
    NurseryPreset(
      id: 'tanks_with_trays',
      name: 'Tanks with Trays',
      description: 'Tanks subdivided by trays for organization',
      icon: Icons.grid_view,
      structureType: GroupType.tank,
      substructureType: GroupType.tray,
      isExSitu: true,
      isProOnly: true,
    ),
    NurseryPreset(
      id: 'raceway_system',
      name: 'Raceway System',
      description: 'Flow-through raceways for grow-out',
      icon: Icons.water,
      structureType: GroupType.raceway,
      isExSitu: true,
    ),
    NurseryPreset(
      id: 'pond_system',
      name: 'Pond System',
      description: 'Ponds for larger-scale culture',
      icon: Icons.waves,
      structureType: GroupType.pond,
      isExSitu: true,
    ),
  ];

  /// Common presets for in-situ (ocean-based) nurseries
  static const List<NurseryPreset> inSituPresets = [
    NurseryPreset(
      id: 'coral_trees',
      name: 'Coral Trees',
      description: 'Vertical trees for hanging coral fragments',
      icon: Icons.park,
      structureType: GroupType.tree,
      isExSitu: false,
    ),
    NurseryPreset(
      id: 'trees_with_branches',
      name: 'Trees with Branches',
      description: 'Track individual branches on each tree',
      icon: Icons.account_tree,
      structureType: GroupType.tree,
      substructureType: GroupType.treeBranch,
      isExSitu: false,
      isProOnly: true,
    ),
    NurseryPreset(
      id: 'domes',
      name: 'Nursery Domes',
      description: 'Dome structures for coral propagation',
      icon: Icons.wb_twilight,
      structureType: GroupType.dome,
      isExSitu: false,
    ),
    NurseryPreset(
      id: 'rebar_tables',
      name: 'Rebar Tables',
      description: 'Table structures for coral fragments',
      icon: Icons.table_bar,
      structureType: GroupType.reebarTable,
      isExSitu: false,
    ),
    NurseryPreset(
      id: 'aframes',
      name: 'A-Frames',
      description: 'A-frame structures for coral culture',
      icon: Icons.change_history,
      structureType: GroupType.aframe,
      isExSitu: false,
    ),
  ];

  static List<NurseryPreset> get allPresets => [...exSituPresets, ...inSituPresets];
}

class FirstSiteSetupPage extends StatefulWidget {
  const FirstSiteSetupPage({
    super.key,
    required this.onNext,
    this.onSkip,
    this.onBack,
    this.siteNameController,
    this.structureNameController,
    this.selectedStructureTypeId,
    this.selectedSubstructureTypeId,
    this.onStructureTypeChanged,
    this.onSubstructureTypeChanged,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final TextEditingController? siteNameController;
  final TextEditingController? structureNameController;
  final String? selectedStructureTypeId;
  final String? selectedSubstructureTypeId;
  final ValueChanged<String?>? onStructureTypeChanged;
  final ValueChanged<String?>? onSubstructureTypeChanged;
  final String? errorMessage;
  final bool isSubmitting;

  @override
  State<FirstSiteSetupPage> createState() => _FirstSiteSetupPageState();

  factory FirstSiteSetupPage.empty() {
    return FirstSiteSetupPage(
      onNext: () {},
    );
  }
}

class _FirstSiteSetupPageState extends State<FirstSiteSetupPage> {
  late TextEditingController _siteNameController;
  late TextEditingController _groupNameController;
  NurseryPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _siteNameController = widget.siteNameController ?? TextEditingController(text: 'Main Nursery');
    _groupNameController = widget.structureNameController ?? TextEditingController(text: 'Tank 1');
    
    // Initialize with first ex-situ preset (most common)
    _selectedPreset = NurseryPreset.exSituPresets.first;
    
    // Update structure name placeholder based on preset
    _updateStructureNameForPreset(_selectedPreset!);
  }

  @override
  void dispose() {
    // Only dispose if we created them locally (which shouldn't happen in main flow)
    if (widget.siteNameController == null) _siteNameController.dispose();
    if (widget.structureNameController == null) _groupNameController.dispose();
    super.dispose();
  }

  void _updateStructureNameForPreset(NurseryPreset preset) {
    // Update the structure name to match the preset type
    _groupNameController.text = '${preset.structureType.name} 1';
  }

  void _selectPreset(NurseryPreset preset) {
    setState(() {
      _selectedPreset = preset;
    });
    _updateStructureNameForPreset(preset);
    
    // Notify parent of structure type change
    widget.onStructureTypeChanged?.call(preset.structureType.id);
    widget.onSubstructureTypeChanged?.call(preset.substructureType?.id);
  }

  void _handleNext() {
    // Ensure structure type is set before proceeding
    if (_selectedPreset != null) {
      widget.onStructureTypeChanged?.call(_selectedPreset!.structureType.id);
      widget.onSubstructureTypeChanged?.call(_selectedPreset!.substructureType?.id);
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your First Site'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(
              Icons.location_city,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              "Let's set up your first nursery site",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you organize your nursery. You can always add more structures later.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Hierarchy Explainer
            _buildHierarchyExplainer(context),
            const SizedBox(height: 24),

            // Site Name Field
            Text(
              'Site Name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _siteNameController,
              decoration: const InputDecoration(
                hintText: 'Enter site name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will be your main nursery location',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Structure Type Selection
            Text(
              'Choose Your Setup',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the type of structures in your nursery:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.purple.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Starred presets require Pro and add an extra hierarchy level.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ex-Situ Presets
            _buildPresetSection(
              context,
              'Land-Based (Ex-Situ)',
              NurseryPreset.exSituPresets,
              Icons.home_work,
            ),
            const SizedBox(height: 16),

            // In-Situ Presets
            _buildPresetSection(
              context,
              'Ocean-Based (In-Situ)',
              NurseryPreset.inSituPresets,
              Icons.waves,
            ),
            const SizedBox(height: 24),

            // First Structure Name Field
            Text(
              'First ${_selectedPreset?.structureType.name ?? "Structure"} Name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Enter ${_selectedPreset?.structureType.name.toLowerCase() ?? "structure"} name',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_selectedPreset?.icon ?? Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will be your first ${_selectedPreset?.structureType.name.toLowerCase() ?? "container"} under the site',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Info Box
            _buildInfoBox(context),
            const SizedBox(height: 32),

            // Error Message
            if (widget.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            Row(
              children: [
                if (widget.onSkip != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.isSubmitting ? null : widget.onSkip,
                      child: const Text('Skip for now'),
                    ),
                  ),
                if (widget.onSkip != null)
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: widget.isSubmitting ? null : _handleNext,
                    child: widget.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Site'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyExplainer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'How SeaFoundry Organizes Data',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHierarchyLevel(
            context,
            '📍 Site',
            'Your nursery location (e.g., "Main Facility" or "Field Nursery")',
            0,
          ),
          _buildHierarchyLevel(
            context,
            '🏗️ Structure',
            'Containers within a site (e.g., Tanks, Trees, Domes)',
            1,
          ),
          _buildHierarchyLevel(
            context,
            '📦 Substructure',
            'Subdivisions within structures (e.g., Trays, Branches)',
            2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Your organisms are placed within structures or substructures for tracking.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyLevel(
    BuildContext context,
    String title,
    String description,
    int indentLevel, {
    bool isProFeature = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: indentLevel * 16.0, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (indentLevel > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isProFeature) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSection(
    BuildContext context,
    String title,
    List<NurseryPreset> presets,
    IconData sectionIcon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(sectionIcon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) => _buildPresetChip(context, preset)).toList(),
        ),
      ],
    );
  }

  String _buildPresetHierarchyLabel(NurseryPreset preset) {
    final structure = preset.structureType.name;
    final substructure = preset.substructureType?.name;
    if (substructure == null) {
      return 'Hierarchy: Site -> $structure';
    }
    return 'Hierarchy: Site -> $structure -> $substructure';
  }

  Widget _buildPresetChip(BuildContext context, NurseryPreset preset) {
    final isSelected = _selectedPreset?.id == preset.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPreset(preset),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withAlpha(25)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                preset.icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        preset.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (preset.isProOnly) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.purple.shade400,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    preset.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _buildPresetHierarchyLabel(preset),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'What we\'ll create:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(context, 'Site: ${_siteNameController.text.isNotEmpty ? _siteNameController.text : "Main Nursery"}'),
          _buildInfoItem(context, '${_selectedPreset?.structureType.name ?? "Structure"}: ${_groupNameController.text.isNotEmpty ? _groupNameController.text : "Tank 1"}'),
          if (_selectedPreset?.substructureType != null)
            _buildInfoItem(context, 'You can add ${_selectedPreset!.substructureType!.name.toLowerCase()}s within your ${_selectedPreset!.structureType.name.toLowerCase()}s'),
          _buildInfoItem(context, 'You can add more sites and structures anytime'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
