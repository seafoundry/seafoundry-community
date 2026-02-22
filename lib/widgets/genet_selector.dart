// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/repositories.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/dialogs/create_genet_dialog.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_dropdown.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_secondary_button.dart';
import 'package:seafoundry_app/widgets/ui/oceanic_text_form_field.dart';

class GenetSelector extends StatefulWidget {
  const GenetSelector({
    super.key,
    required this.onSelected,
    this.genet,
    this.label,
    this.allowedProvenanceTypeIds,
    this.allowedSpeciesId,
    this.useOrgInventory = true,
    this.tooltip,
    this.readOnly = false,
    this.lockedMessage,
  });

  final void Function(Genet) onSelected;
  final Genet? genet;
  final String? label;
  /// Filter genets by provenance type IDs (e.g., 'provenance_type_wild').
  final List<String>? allowedProvenanceTypeIds;
  final String? allowedSpeciesId;
  final bool useOrgInventory;
  final String? tooltip;
  final bool readOnly;
  final String? lockedMessage;

  @override
  State<GenetSelector> createState() => _GenetSelectorState();
}

class _GenetSelectorState extends State<GenetSelector> {
  // Cache the stream to prevent creating new stream references on every rebuild.
  // CRITICAL: Accessing repository streams in build() can cause infinite rebuilds
  // if the repository creates new stream wrappers each time.
  late final Stream<List<Genet>> _genetsStream;

  @override
  void initState() {
    super.initState();
    final genetRepository = context.read<GenetRepository>();
    _genetsStream = genetRepository.streamAll;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      return OceanicTextFormField(
        label: widget.label ?? 'Genet',
        initialValue: widget.genet?.name ?? 'Unknown genet',
        enabled: false,
        suffix: const Icon(Icons.lock, size: 18),
      );
    }

    return StreamBuilder<List<Genet>>(
      stream: _genetsStream, // CACHED STREAM - no infinite loop!
      builder: (context, snapshot) {
        // Handle loading state
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allGenets = snapshot.data ?? [];

        // Filter genets by allowed types and species if specified
        var filteredGenets = allGenets;

        // Filter by allowed provenance types if specified
        if (widget.allowedProvenanceTypeIds != null) {
          filteredGenets = filteredGenets.where((g) {
            // Check if provenanceTypeId matches directly
            if (widget.allowedProvenanceTypeIds!.contains(g.provenanceTypeId)) {
              return true;
            }
            // Convert provenanceTypeId to ProvenanceType and check
            final provenanceType = ProvenanceTypeX.tryParse(g.provenanceTypeId);
            if (provenanceType != null && widget.allowedProvenanceTypeIds!.contains(provenanceType.id)) {
              return true;
            }
            return false;
          }).toList();
        }

        // Filter by species if specified
        if (widget.allowedSpeciesId != null) {
          filteredGenets = filteredGenets
              .where((g) => g.speciesId == widget.allowedSpeciesId)
              .toList();
        }

        // Handle empty state - show message when no genets match filter
        if (filteredGenets.isEmpty) {
          String emptyMessage = 'No genets available';
          if (widget.allowedProvenanceTypeIds != null) {
            final typeNames = widget.allowedProvenanceTypeIds!
                .map((typeId) {
                  // Try to get display name from ProvenanceType ID
                  final provenanceType = ProvenanceTypeX.tryParse(typeId);
                  return provenanceType?.displayName ?? typeId;
                })
                .join(' or ');
            emptyMessage = 'No $typeNames genets in inventory';
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OceanicDropdown<String>(
                label: widget.label,
                value: null,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    enabled: false,
                    child: Text(
                      emptyMessage,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                onChanged: null,
              ),
              const SizedBox(height: 8),
              OceanicSecondaryButton(
                onPressed: () => _showCreateGenetDialog(context),
                icon: Icons.add,
                label: 'Create New Genet',
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OceanicDropdown<Genet>(
              key: const Key('genet_selector_parent'),
              fieldKey: const Key('genet_selector_dropdown'),
              label: widget.label,
              value: filteredGenets.contains(widget.genet) ? widget.genet : null,
              hint: 'Select Genet',
              items: filteredGenets
                  .map((g) => DropdownMenuItem(value: g, child: Text(g.name)))
                  .toList(),
              onChanged: (selectedGenet) {
                if (selectedGenet != null) {
                  widget.onSelected(selectedGenet);
                }
              },
            ),
            const SizedBox(height: 8),
            OceanicSecondaryButton(
              onPressed: () => _showCreateGenetDialog(context),
              icon: Icons.add,
              label: 'Create New Genet',
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateGenetDialog(BuildContext context) async {
    Species? initialSpecies;
    if (widget.allowedSpeciesId != null) {
      initialSpecies = SpeciesRegistry.globalById(widget.allowedSpeciesId);
      if (initialSpecies == null) {
        final fallback = SpeciesRegistry.globalAll();
        if (fallback.isNotEmpty) {
          initialSpecies = fallback.first;
        }
      }
    }

    // CreateGenetDialog.show already returns Genet?
    final createdGenet = await CreateGenetDialog.show(
      context,
      initialSpecies: initialSpecies,
    );
    if (createdGenet != null && context.mounted) {
      widget.onSelected(createdGenet);
    }
  }
}
