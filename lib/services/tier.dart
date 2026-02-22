// @tier: community

/// Canonical tier enum for the SeaFoundry platform.
///
/// Ordered by entitlement level: Community < Pro < Scale.
/// Use [Tier.fromString] for all string-to-tier parsing.
/// Use [allows] for tier gating checks.
enum Tier {
  community,
  pro,
  scale;

  static Tier fromString(String? value) {
    if (value == null) return Tier.community;
    final normalized = value.trim().toLowerCase();
    return Tier.values.firstWhere(
      (t) => t.name == normalized,
      orElse: () => Tier.community,
    );
  }

  String get displayName => switch (this) {
    Tier.community => 'Community',
    Tier.pro => 'Pro',
    Tier.scale => 'Scale',
  };

  int get rank => index;
  bool allows(Tier required) => rank >= required.rank;

  bool get isPro => this == Tier.pro || this == Tier.scale;
  bool get isCommunity => this == Tier.community;
  bool get isScale => this == Tier.scale;

  bool isAccessibleTo(Tier userTier) => userTier.allows(this);
}
