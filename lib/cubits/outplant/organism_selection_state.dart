import 'package:equatable/equatable.dart';
import 'package:seafoundry_community/models/inventory/organism_record.dart';

/// State for managing organism selection in outplanting workflows
class OrganismSelectionState extends Equatable {
  const OrganismSelectionState({
    required this.availableOrganisms,
    required this.selectedOrganismIds,
    required this.quantityByOrganism,
    required this.tagByOrganism,
    required this.groupByOrganism,
    required this.searchQuery,
    required this.isLoading,
  });

  /// Factory constructor for initial state
  factory OrganismSelectionState.initial({
    List<OrganismRecord>? organisms,
  }) {
    return OrganismSelectionState(
      availableOrganisms: organisms ?? const [],
      selectedOrganismIds: const {},
      quantityByOrganism: const {},
      tagByOrganism: const {},
      groupByOrganism: const {},
      searchQuery: '',
      isLoading: false,
    );
  }

  /// All organisms available for selection
  final List<OrganismRecord> availableOrganisms;

  /// IDs of selected organisms
  final Set<String> selectedOrganismIds;

  /// Quantity to outplant per organism
  final Map<String, int> quantityByOrganism;

  /// Tag/label per organism
  final Map<String, String> tagByOrganism;

  /// Target group (plot/patch) ID per organism
  final Map<String, String> groupByOrganism;

  /// Search filter text
  final String searchQuery;

  /// Loading state
  final bool isLoading;

  /// Map of organism ID to organism for quick lookup
  Map<String, OrganismRecord> get availableOrganismsById {
    return {for (final organism in availableOrganisms) organism.id: organism};
  }

  /// Organisms matching search query
  List<OrganismRecord> get filteredOrganisms {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return availableOrganisms;
    return availableOrganisms
        .where(
          (organism) =>
              (organism.localGenetId?.toLowerCase().contains(query) ?? false) ||
              organism.id.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  /// Check if any organism has invalid quantity
  bool get hasInvalidQuantities {
    for (final id in selectedOrganismIds) {
      final organism = availableOrganismsById[id];
      if (organism == null) return true;
      final quantity = quantityByOrganism[id] ?? 0;
      final maxQuantity = organism.measurement.value.toInt();
      if (quantity < 1 || quantity > maxQuantity) {
        return true;
      }
    }
    return false;
  }

  /// Count of selected organisms
  int get totalSelected => selectedOrganismIds.length;

  /// Check if selection is valid (at least one organism selected with valid quantities)
  bool get isValid {
    return selectedOrganismIds.isNotEmpty && !hasInvalidQuantities;
  }

  OrganismSelectionState copyWith({
    List<OrganismRecord>? availableOrganisms,
    Set<String>? selectedOrganismIds,
    Map<String, int>? quantityByOrganism,
    Map<String, String>? tagByOrganism,
    Map<String, String>? groupByOrganism,
    String? searchQuery,
    bool? isLoading,
  }) {
    return OrganismSelectionState(
      availableOrganisms: availableOrganisms ?? this.availableOrganisms,
      selectedOrganismIds: selectedOrganismIds ?? this.selectedOrganismIds,
      quantityByOrganism: quantityByOrganism ?? this.quantityByOrganism,
      tagByOrganism: tagByOrganism ?? this.tagByOrganism,
      groupByOrganism: groupByOrganism ?? this.groupByOrganism,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        availableOrganisms,
        selectedOrganismIds,
        quantityByOrganism,
        tagByOrganism,
        groupByOrganism,
        searchQuery,
        isLoading,
      ];
}

/// Data transfer object for selected organisms with their metadata
class SelectedOrganism {
  const SelectedOrganism({
    required this.organism,
    required this.quantity,
    this.tag,
    this.groupId,
  });

  final OrganismRecord organism;
  final int quantity;
  final String? tag;
  final String? groupId;
}
