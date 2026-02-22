// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/blocs/propagation/propagation_flow_event.dart';
import 'package:seafoundry_app/blocs/graph_node/group_node.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';

/// Sentinel value to explicitly clear optional fields in copyWith.
class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

class PropagationFragmentsPerInputInput
    extends
        RecordFormInput<
          int,
          RecordFormInputError,
          PropagationFragmentsPerInputChanged
        > {
  const PropagationFragmentsPerInputInput.pure({
    required this.minFragmentsPerInput,
  }) : super.pure();
  const PropagationFragmentsPerInputInput.dirty(
    super.value, {
    required this.minFragmentsPerInput,
  })
    : super.dirty();

  final int minFragmentsPerInput;

  @override
  String get label => 'Fragments per input';

  @override
  String? get hintText =>
      'Enter number of new fragments created per input';

  @override
  PropagationFragmentsPerInputInput copyWith({required int? value}) {
    if (value == this.value) return this;
    if (value == null) {
      return PropagationFragmentsPerInputInput.pure(
        minFragmentsPerInput: minFragmentsPerInput,
      );
    }
    return PropagationFragmentsPerInputInput.dirty(
      value,
      minFragmentsPerInput: minFragmentsPerInput,
    );
  }

  @override
  RecordFormInputError? validator(int? value) {
    if (value == null || value <= 0) {
      return const RecordFormInputError(
        'Fragments per input must be at least 1',
      );
    }
    if (value < minFragmentsPerInput) {
      return RecordFormInputError(
        'Fragments per input must be at least $minFragmentsPerInput',
      );
    }
    return null;
  }
}

// New organism input for tracking individual organism propagules
class NewOrganismInput extends Equatable {
  const NewOrganismInput({
    this.localId = '',
    this.recordName = '',
    this.quantity = 1,
    this.groupNode,
  });

  /// The localId is inherited from the source organism and stays the same
  /// for all fragments in a propagation event.
  final String localId;

  /// The recordName is unique per fragment and auto-generated with a suffix.
  final String recordName;
  final int quantity;
  final GroupNode? groupNode;

  NewOrganismInput copyWith({
    String? localId,
    String? recordName,
    int? quantity,
    Object? groupNode = _sentinel, // Use Object? to accept both GroupNode? and sentinel
  }) {
    return NewOrganismInput(
      localId: localId ?? this.localId,
      recordName: recordName ?? this.recordName,
      quantity: quantity ?? this.quantity,
      groupNode: groupNode == _sentinel
          ? this.groupNode
          : groupNode as GroupNode?,
    );
  }

  bool get isValid =>
      recordName.isNotEmpty && quantity > 0 && groupNode != null;

  @override
  List<Object?> get props => [localId, recordName, quantity, groupNode];
}

// Organism selection input for tracking selected organisms in step 1
class OrganismSelectionInput extends Equatable {
  const OrganismSelectionInput({
    this.selectedOrganisms = const <OrganismRecord>{},
    this.allOrganisms = const <OrganismRecord>[],
    this.selectedQuantities = const <String, int>{},
  });

  final Set<OrganismRecord> selectedOrganisms;
  final List<OrganismRecord> allOrganisms;
  final Map<String, int> selectedQuantities;

  /// Creates a copy with optional field updates.
  /// Enforces the invariant: selectedOrganisms ⊆ allOrganisms.
  /// If [allOrganisms] changes, filters out any selected organisms
  /// that are no longer in the new list.
  OrganismSelectionInput copyWith({
    Set<OrganismRecord>? selectedOrganisms,
    List<OrganismRecord>? allOrganisms,
    Map<String, int>? selectedQuantities,
  }) {
    final newAllOrganisms = allOrganisms ?? this.allOrganisms;
    var newSelectedOrganisms = selectedOrganisms ?? this.selectedOrganisms;
    var newSelectedQuantities = selectedQuantities ?? this.selectedQuantities;

    // Enforce invariant: selectedOrganisms must be subset of allOrganisms
    // Filter out any selected organisms not in the (potentially new) allOrganisms
    if (allOrganisms != null || selectedOrganisms != null) {
      newSelectedOrganisms = newSelectedOrganisms.where(
        (selected) => newAllOrganisms.any((available) => available.id == selected.id),
      ).toSet();
    }

    if (allOrganisms != null || selectedOrganisms != null || selectedQuantities != null) {
      final selectedIds = newSelectedOrganisms.map((organism) => organism.id).toSet();
      newSelectedQuantities =
          Map<String, int>.from(newSelectedQuantities)
            ..removeWhere((id, _) => !selectedIds.contains(id))
            ..addEntries(
              newSelectedOrganisms
                  .where((organism) => !newSelectedQuantities.containsKey(organism.id))
                  .map(
                    (organism) => MapEntry(
                      organism.id,
                      organism.measurement.value.toInt(),
                    ),
                  ),
            );
    }

    return OrganismSelectionInput(
      selectedOrganisms: newSelectedOrganisms,
      allOrganisms: newAllOrganisms,
      selectedQuantities: newSelectedQuantities,
    );
  }

  int get totalQuantity => selectedOrganisms.fold(
    0,
    (sum, organism) => sum + quantityFor(organism),
  );

  int quantityFor(OrganismRecord organism) {
    return selectedQuantities[organism.id] ?? organism.measurement.value.toInt();
  }

  bool isQuantityValid(OrganismRecord organism) {
    final available = organism.measurement.value.toInt();
    final selected = quantityFor(organism);
    return selected > 0 && selected <= available;
  }

  /// Validates that at least one organism is selected AND all selected
  /// organisms are in [allOrganisms]. The subset check is defensive -
  /// it should always pass after the propagation_state.dart fix, but
  /// ensures the invariant: selectedOrganisms ⊆ allOrganisms.
  bool get isValid {
    if (selectedOrganisms.isEmpty) return false;
    // Defensive check: all selected organisms must be in allOrganisms
    return selectedOrganisms.every(
          (selected) => allOrganisms.any((available) => available.id == selected.id),
        ) &&
        selectedOrganisms.every(isQuantityValid);
  }

  /// Toggles selection of an organism.
  /// Guards against adding organisms not in [allOrganisms] to maintain
  /// the invariant: selectedOrganisms ⊆ allOrganisms.
  OrganismSelectionInput toggleOrganism(OrganismRecord organism) {
    // Guard: only toggle organisms that exist in allOrganisms
    if (!allOrganisms.any((o) => o.id == organism.id)) {
      return this; // Silently ignore invalid toggle
    }

    final newSelection = Set<OrganismRecord>.from(selectedOrganisms);
    if (newSelection.contains(organism)) {
      newSelection.remove(organism);
      final updatedQuantities = Map<String, int>.from(selectedQuantities)
        ..remove(organism.id);
      return copyWith(
        selectedOrganisms: newSelection,
        selectedQuantities: updatedQuantities,
      );
    } else {
      newSelection.add(organism);
      final updatedQuantities = Map<String, int>.from(selectedQuantities)
        ..putIfAbsent(
          organism.id,
          () => organism.measurement.value.toInt(),
        );
      return copyWith(
        selectedOrganisms: newSelection,
        selectedQuantities: updatedQuantities,
      );
    }
  }

  OrganismSelectionInput updateQuantity(OrganismRecord organism, int quantity) {
    if (!selectedOrganisms.any((selected) => selected.id == organism.id)) {
      return this;
    }
    final available = organism.measurement.value.toInt();
    final clamped = quantity.clamp(1, available).toInt();
    final updatedQuantities = Map<String, int>.from(selectedQuantities)
      ..[organism.id] = clamped;
    return copyWith(selectedQuantities: updatedQuantities);
  }

  @override
  List<Object?> get props => [selectedOrganisms, allOrganisms, selectedQuantities];
}
