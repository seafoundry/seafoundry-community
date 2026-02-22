// @tier: community

/// Represents the visibility/access level of a channel.
enum ChannelVisibility {
  /// Public channel - any organization/community member can join
  public_('public'),

  /// Invite-only channel - requires invitation to join
  inviteOnly('invite_only');

  const ChannelVisibility(this.value);

  final String value;

  static ChannelVisibility fromString(String value) {
    return ChannelVisibility.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ChannelVisibility.public_,
    );
  }
}
