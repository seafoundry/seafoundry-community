
/// Transfer recipient mode - determines how the recipient is specified
enum RecipientMode {
  /// Recipient is an existing organization in the system
  organization,

  /// Recipient is specified by email address (may not be in system yet)
  email,
}

extension RecipientModeX on RecipientMode {
  String get displayName => switch (this) {
        RecipientMode.organization => 'Organization',
        RecipientMode.email => 'Email',
      };

  String get description => switch (this) {
        RecipientMode.organization =>
          'Select an existing organization from the registry',
        RecipientMode.email => 'Send to an email address directly',
      };

  static RecipientMode? tryParse(String? value) {
    if (value == null) return null;
    return RecipientMode.values.where((e) => e.name == value).firstOrNull;
  }
}
