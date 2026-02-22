// @tier: community

/// Size classification for coral organisms.
/// Extracted from legacy Coral model for continued use with OrganismRecord.
enum CoralSize {
  xs,
  s,
  m,
  l,
  xl;

  String get displayName => switch (this) {
    CoralSize.xs => 'Extra Small',
    CoralSize.s => 'Small',
    CoralSize.m => 'Medium',
    CoralSize.l => 'Large',
    CoralSize.xl => 'Extra Large',
  };
}
