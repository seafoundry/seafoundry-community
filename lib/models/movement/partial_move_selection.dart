class PartialMoveSelection {
  final bool moveAll;
  final Set<String> selectedChildIds;
  final Map<String, int> partialQuantities;

  const PartialMoveSelection({
    this.moveAll = true,
    this.selectedChildIds = const <String>{},
    this.partialQuantities = const <String, int>{},
  });

  bool get hasSelection =>
      moveAll || selectedChildIds.isNotEmpty || partialQuantities.isNotEmpty;

  int? quantityFor(String recordId) => partialQuantities[recordId];

  PartialMoveSelection copyWith({
    bool? moveAll,
    Set<String>? selectedChildIds,
    Map<String, int>? partialQuantities,
  }) {
    return PartialMoveSelection(
      moveAll: moveAll ?? this.moveAll,
      selectedChildIds: selectedChildIds ?? this.selectedChildIds,
      partialQuantities: partialQuantities ?? this.partialQuantities,
    );
  }

  PartialMoveSelection clearEmpty(Map<String, int> availableQuantities) {
    if (moveAll) return this;

    final filteredIds = selectedChildIds
        .where((id) => availableQuantities.containsKey(id))
        .toSet();

    final filteredQuantities = <String, int>{};
    for (final entry in partialQuantities.entries) {
      final available = availableQuantities[entry.key];
      if (available != null && entry.value > 0 && entry.value <= available) {
        filteredQuantities[entry.key] = entry.value;
      }
    }

    return copyWith(
      moveAll: false, // Keep moveAll as false for partial moves
      selectedChildIds: filteredIds,
      partialQuantities: filteredQuantities,
    );
  }

  PartialMoveSelection forChild(String childId) {
    if (moveAll) {
      return const PartialMoveSelection(moveAll: true);
    }

    final quantity = partialQuantities[childId];
    if (!selectedChildIds.contains(childId) && quantity == null) {
      return const PartialMoveSelection(moveAll: false);
    }

    if (quantity != null) {
      return PartialMoveSelection(
        moveAll: false,
        selectedChildIds: const <String>{},
        partialQuantities: {childId: quantity},
      );
    }

    return PartialMoveSelection(
      moveAll: false,
      selectedChildIds: {childId},
      partialQuantities: const <String, int>{},
    );
  }

  PartialMoveSelection clampQuantities(Map<String, int> available) {
    if (moveAll) return this;

    final adjustedQuantities = <String, int>{};
    for (final entry in partialQuantities.entries) {
      final availableQuantity = available[entry.key];
      if (availableQuantity == null) {
        adjustedQuantities[entry.key] = entry.value;
        continue;
      }

      final clamped = entry.value < 1
          ? 1
          : (entry.value > availableQuantity ? availableQuantity : entry.value);
      adjustedQuantities[entry.key] = clamped;
    }

    return copyWith(partialQuantities: adjustedQuantities);
  }

  Map<String, dynamic> toJson() => {
    'moveAll': moveAll,
    'selectedChildIds': selectedChildIds.toList(),
    'partialQuantities': partialQuantities,
  };

  factory PartialMoveSelection.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PartialMoveSelection();

    final moveAllValue = json['moveAll'];
    final selectedIdsList = json['selectedChildIds'];
    final partialQuantitiesJson = json['partialQuantities'];

    final selectedIds = <String>{};
    if (selectedIdsList is List) {
      for (final value in selectedIdsList) {
        if (value is String) {
          selectedIds.add(value);
        }
      }
    }

    final partials = <String, int>{};
    if (partialQuantitiesJson is Map) {
      for (final entry in partialQuantitiesJson.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is! String) continue;

        if (value is int) {
          partials[key] = value;
        } else if (value is num) {
          partials[key] = value.toInt();
        }
      }
    }

    return PartialMoveSelection(
      moveAll: moveAllValue is bool ? moveAllValue : true,
      selectedChildIds: selectedIds.isEmpty
          ? const <String>{}
          : Set<String>.unmodifiable(selectedIds),
      partialQuantities: partials.isEmpty
          ? const <String, int>{}
          : Map<String, int>.unmodifiable(partials),
    );
  }
}
