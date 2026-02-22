// @tier: community

/// Transfer ownership type - determines the ownership model after transfer
enum TransferOwnershipType {
  /// Full transfer of ownership to the recipient organization
  fullTransfer('fullTransfer'),

  /// Organisms remain under original ownership, hosted at recipient location
  retainedOwnership('retainedOwnership'),

  /// Organisms transferred to a third party (e.g., research institution)
  thirdPartyTransfer('thirdPartyTransfer');

  const TransferOwnershipType(this.id);

  final String id;
}

extension TransferOwnershipTypeX on TransferOwnershipType {
  String get displayName => switch (this) {
        TransferOwnershipType.fullTransfer => 'Full Transfer',
        TransferOwnershipType.retainedOwnership => 'Retained Ownership',
        TransferOwnershipType.thirdPartyTransfer => 'Third Party Transfer',
      };

  String get description => switch (this) {
        TransferOwnershipType.fullTransfer =>
          'Complete transfer of ownership to the recipient organization',
        TransferOwnershipType.retainedOwnership =>
          'Organisms hosted at recipient location but remain under your ownership',
        TransferOwnershipType.thirdPartyTransfer =>
          'Transfer to a third party such as a research institution',
      };

  static TransferOwnershipType? tryParse(String? value) {
    if (value == null) return null;
    return TransferOwnershipType.values
        .where((e) => e.id == value || e.name == value)
        .firstOrNull;
  }
}
