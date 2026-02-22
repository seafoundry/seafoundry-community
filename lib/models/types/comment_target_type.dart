// @tier: community

/// Type of entity that a comment targets.
enum CommentTargetType {
  event('event'),
  organismRecord('organism_record'),
  post('post');

  const CommentTargetType(this.id);
  final String id;
}
