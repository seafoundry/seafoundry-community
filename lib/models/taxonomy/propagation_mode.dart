/// Describes how a species is commonly propagated so feature toggles can be
/// applied by organism families.
///
/// Sexual propagation modes (sexualSpawning, larvalSettlement, hatcheryBreeding)
/// have been removed. vegetativeCutting and clonalExpansion are retained for
/// backward-compatible Firestore parsing only.
enum PropagationMode {
  asexualFragmentation,
  vegetativeCutting,
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
    // Map removed sexual propagation modes to asexualFragmentation
    // so existing Firestore data doesn't crash.
    // Covers both camelCase (sexualSpawning) and snake_case (sexual_spawning) IDs.
    const removedAliases = <String, PropagationMode>{
      'sexualspawning': PropagationMode.asexualFragmentation,
      'larvalsettlement': PropagationMode.asexualFragmentation,
      'hatcherybreeding': PropagationMode.asexualFragmentation,
      'sexual_spawning': PropagationMode.asexualFragmentation,
      'larval_settlement': PropagationMode.asexualFragmentation,
      'hatchery_breeding': PropagationMode.asexualFragmentation,
    };
    return removedAliases[normalized];
  }
}
