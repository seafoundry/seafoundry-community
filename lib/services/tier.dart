// @tier: community

/// Canonical tier enum for the SeaFoundry community platform.
///
/// Community-only fork: only [Tier.community] exists.
/// [fromString] safely maps any stored tier string (including legacy
/// "pro"/"scale" values in Firestore) back to [community].
enum Tier {
  community;

  static Tier fromString(String? value) {
    // Always returns community — legacy pro/scale values in Firestore
    // are safely normalized here.
    return Tier.community;
  }

  String get displayName => 'Community';

  bool get isCommunity => true;
}
