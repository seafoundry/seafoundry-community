// @tier: community
/// Utility for extracting email mentions from text content.
class MentionUtils {
  MentionUtils._();

  static final RegExp _mentionPattern = RegExp(
    r'@([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
  );

  /// Extract email mentions from content.
  /// Returns unique email addresses found with @email@domain.com pattern.
  static List<String> extractMentions(String content) {
    return _mentionPattern
        .allMatches(content)
        .map((match) => match.group(1))
        .whereType<String>()
        .toSet()
        .toList();
  }
}
