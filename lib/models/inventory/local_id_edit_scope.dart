/// Scope for applying localID changes.
enum LocalIdEditScope {
  /// Update only the current organism record.
  recordOnly,

  /// Update all organism records that share the same genet.
  genetWide,
}
