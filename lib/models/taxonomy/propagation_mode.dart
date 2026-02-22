// @tier: community
/// Describes how a species is commonly propagated so feature toggles (propagation,
/// gamete collection, seed banks) can be applied by organism families.
enum PropagationMode {
  asexualFragmentation,
  vegetativeCutting,
  larvalSettlement,
  sexualSpawning,
  hatcheryBreeding,
  clonalExpansion,
}

extension PropagationModeX on PropagationMode {
  static PropagationMode? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final mode in PropagationMode.values) {
      if (mode.name.toLowerCase() == normalized) {
        return mode;
      }
    }
    return null;
  }
}
