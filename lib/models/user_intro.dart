import 'package:equatable/equatable.dart';

/// Lightweight introduction content for a user. Stored under
/// `/users/{userId}/intro/profile` in Firestore.
class UserIntro extends Equatable {
  const UserIntro({
    required this.kind,
    this.mediaUrl,
    this.note,
    this.isPublic = true,
  });

  /// One of: photo | video | note
  final String kind;
  final String? mediaUrl;
  final String? note;
  final bool isPublic;

  Map<String, dynamic> toMap() => {
        'kind': kind,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (note != null) 'note': note,
        'public': isPublic,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory UserIntro.fromMap(Map<String, dynamic> map) {
    return UserIntro(
      kind: (map['kind'] ?? 'note').toString(),
      mediaUrl: map['mediaUrl']?.toString(),
      note: map['note']?.toString(),
      isPublic: (map['public'] as bool?) ?? true,
    );
  }

  @override
  List<Object?> get props => [kind, mediaUrl, note, isPublic];
}
