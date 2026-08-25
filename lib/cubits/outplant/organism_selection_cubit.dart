import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/cubits/outplant/organism_selection_state.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';

/// Cubit for managing organism selection in outplanting workflows
///
/// Extracted from OutplantBatchBloc to provide focused, reusable
/// organism selection logic. Handles:
/// - Organism filtering and search
/// - Selection toggling (individual and bulk operations)
/// - Quantity validation and assignment
/// - Tag/label assignment
/// - Group (plot/patch) assignment
class OrganismSelectionCubit extends Cubit<OrganismSelectionState> {
  OrganismSelectionCubit({
    List<OrganismRecord>? initialOrganisms,
  }) : super(OrganismSelectionState.initial(organisms: initialOrganisms));

  /// Load organisms into the selection state
  void loadOrganisms(List<OrganismRecord> organisms) {
    emit(
      state.copyWith(
        availableOrganisms: organisms,
        // Clear existing selections when loading new organisms
        selectedOrganismIds: const {},
        quantityByOrganism: const {},
        tagByOrganism: const {},
        groupByOrganism: const {},
      ),
    );
  }

  /// Update search query for filtering organisms
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Toggle selection state for a specific organism
  ///
  /// If [selected] is provided, explicitly sets the selection state.
  /// Otherwise, toggles the current selection state.
  void toggleSelection(String organismId, {bool? selected}) {
    final current = state.selectedOrganismIds;
    final updatedIds = Set<String>.from(current);
    final isSelected = selected ?? !current.contains(organismId);

    if (isSelected) {
      updatedIds.add(organismId);
    } else {
      updatedIds.remove(organismId);
    }

    final updatedQuantities = Map<String, int>.from(state.quantityByOrganism);
    final organism = state.availableOrganismsById[organismId];

    if (isSelected && organism != null) {
      // Initialize quantity to 1 if not already set
      updatedQuantities[organismId] = updatedQuantities[organismId] ?? 1;
    } else {
      // Remove quantity when deselecting
      updatedQuantities.remove(organismId);
    }

    final updatedTags = Map<String, String>.from(state.tagByOrganism);
    final updatedGroups = Map<String, String>.from(state.groupByOrganism);
    if (!isSelected) {
      // Clear tag and group assignments when deselecting
      updatedTags.remove(organismId);
      updatedGroups.remove(organismId);
    }

    emit(
      state.copyWith(
        selectedOrganismIds: updatedIds,
        quantityByOrganism: updatedQuantities,
        tagByOrganism: updatedTags,
        groupByOrganism: updatedGroups,
      ),
    );
  }

  /// Quantity is clamped between 1 and the organism's current measurement value.
  void setQuantity(String organismId, int quantity) {
    final organism = state.availableOrganismsById[organismId];
    if (organism == null) return;

    final maxQuantity = organism.measurement.value.toInt();
    final clamped = quantity.clamp(1, maxQuantity);

    final updated = Map<String, int>.from(state.quantityByOrganism);
    updated[organismId] = clamped;

    emit(state.copyWith(quantityByOrganism: updated));
  }

  /// Empty tags are removed from the state.
  void setTag(String organismId, String tag) {
    final updated = Map<String, String>.from(state.tagByOrganism);
    if (tag.trim().isEmpty) {
      updated.remove(organismId);
    } else {
      updated[organismId] = tag.trim();
    }
    emit(state.copyWith(tagByOrganism: updated));
  }

  /// Null or empty groupId removes the group assignment.
  void setGroup(String organismId, String? groupId) {
    final updated = Map<String, String>.from(state.groupByOrganism);
    if (groupId == null || groupId.trim().isEmpty) {
      updated.remove(organismId);
    } else {
      updated[organismId] = groupId;
    }
    emit(state.copyWith(groupByOrganism: updated));
  }

  /// Select all filtered organisms
  ///
  /// Applies to organisms matching the current search query.
  /// Initializes quantities to 1 for newly selected organisms.
  void selectAll() {
    final updatedIds = Set<String>.from(state.selectedOrganismIds);
    final updatedQuantities = Map<String, int>.from(state.quantityByOrganism);

    for (final organism in state.filteredOrganisms) {
      updatedIds.add(organism.id);
      // Only initialize quantity if not already set
      updatedQuantities.putIfAbsent(organism.id, () => 1);
    }

    emit(
      state.copyWith(
        selectedOrganismIds: updatedIds,
        quantityByOrganism: updatedQuantities,
      ),
    );
  }

  /// Clear all selections
  ///
  /// Removes all selected organisms and their associated quantities, tags, and groups.
  void clearSelection() {
    emit(
      state.copyWith(
        selectedOrganismIds: const {},
        quantityByOrganism: const {},
        tagByOrganism: const {},
        groupByOrganism: const {},
      ),
    );
  }

  /// Get list of selected organisms with their metadata
  ///
  List<SelectedOrganism> getSelectedOrganisms() {
    final items = <SelectedOrganism>[];
    for (final id in state.selectedOrganismIds) {
      final organism = state.availableOrganismsById[id];
      if (organism == null) continue;

      final quantity = state.quantityByOrganism[id] ?? 0;
      if (quantity < 1) continue;

      final tag = state.tagByOrganism[id];
      final groupId = state.groupByOrganism[id];

      items.add(
        SelectedOrganism(
          organism: organism,
          quantity: quantity,
          tag: (tag != null && tag.isNotEmpty) ? tag : null,
          groupId: groupId,
        ),
      );
    }
    return items;
  }

  /// Deselect organisms that are no longer in the available list
  ///
  /// Useful when the available organisms list changes (e.g., after filtering
  /// or reloading data) to keep selection state consistent.
  void pruneInvalidSelections() {
    final validIds = state.availableOrganisms.map((o) => o.id).toSet();
    final updatedIds = state.selectedOrganismIds.where(validIds.contains).toSet();

    if (updatedIds.length == state.selectedOrganismIds.length) {
      return; // No changes needed
    }

    final updatedQuantities = Map<String, int>.fromEntries(
      state.quantityByOrganism.entries.where((e) => validIds.contains(e.key)),
    );
    final updatedTags = Map<String, String>.fromEntries(
      state.tagByOrganism.entries.where((e) => validIds.contains(e.key)),
    );
    final updatedGroups = Map<String, String>.fromEntries(
      state.groupByOrganism.entries.where((e) => validIds.contains(e.key)),
    );

    emit(
      state.copyWith(
        selectedOrganismIds: updatedIds,
        quantityByOrganism: updatedQuantities,
        tagByOrganism: updatedTags,
        groupByOrganism: updatedGroups,
      ),
    );
  }
}
