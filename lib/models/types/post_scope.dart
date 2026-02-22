// @tier: community

/// Scope of a post - determines visibility
enum PostScope {
  organization, // Private to org members only
  community, // Public to all SeaFoundry users
}

extension PostScopeX on PostScope {
  String get displayName => switch (this) {
        PostScope.organization => 'Organization',
        PostScope.community => 'Community',
      };

  static PostScope? tryParse(String? value) {
    if (value == null) return null;
    return PostScope.values.where((e) => e.name == value).firstOrNull;
  }
}
