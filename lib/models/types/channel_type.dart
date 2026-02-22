// @tier: community

/// Represents the type of channel in the SeaFoundry system.
enum ChannelType {
  /// Community-wide channels visible to all community members
  community('community'),

  /// Organization-specific channels (Pro tier)
  organization('organization'),

  /// Direct message channels between specific users
  directMessage('directMessage');

  const ChannelType(this.value);

  final String value;

  static ChannelType fromString(String value) {
    return ChannelType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ChannelType.community,
    );
  }
}
