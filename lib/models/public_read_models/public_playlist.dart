// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Playlist of public items (typically media assets) for public/org pages.
class PublicPlaylist extends Record {
  const PublicPlaylist({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.metadata,
    required this.title,
    this.description,
    this.items = const <PlaylistItem>[],
    this.published = false,
    this.publishedAt,
  });

  PublicPlaylist.fromJson(super.json)
      : title = json['title'] ?? Missing.string,
        description =
            json['description'] is String ? json['description'] as String : null,
        items = _itemsFrom(json['items']),
        published = json['published'] == true,
        publishedAt = json['publishedAt'] is String
            ? json['publishedAt'] as String
            : null,
        super.fromJson();

  final String title;
  final String? description;
  final List<PlaylistItem> items;
  final bool published;
  final String? publishedAt; // ISO8601

  @override
  ModelType get modelType => ModelType.publicPlaylist;

  @override
  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (items.isNotEmpty) 'items': items.map((e) => e.toJson()).toList(),
        'published': published,
        if (publishedAt != null && publishedAt!.isNotEmpty)
          'publishedAt': publishedAt,
        ...super.toJson(),
      };

  @override
  PublicPlaylist copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    Map<String, dynamic>? metadata,
    String? title,
    String? description,
    List<PlaylistItem>? items,
    bool? published,
    String? publishedAt,
  }) =>
      PublicPlaylist(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        createdById: createdById ?? this.createdById,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedById: updatedById ?? this.updatedById,
        organizationId: organizationId ?? this.organizationId,
        metadata: metadata ?? this.metadata,
        title: title ?? this.title,
        description: description ?? this.description,
        items: items ?? this.items,
        published: published ?? this.published,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  @override
  List<Object?> get props => super.props + [
        title,
        description,
        items.map((e) => e.props.join('-')).join('|'),
        published,
        publishedAt,
      ];

  static List<PlaylistItem> _itemsFrom(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    return const <PlaylistItem>[];
  }
}

class PlaylistItem {
  const PlaylistItem({
    required this.assetId,
    this.caption,
    this.order = 0,
  });

  PlaylistItem.fromJson(Map<String, dynamic> json)
      : assetId = json['assetId'] ?? Missing.string,
        caption = json['caption'] is String ? json['caption'] as String : null,
        order = safeInt(json['order']) ?? 0;

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        if (caption != null && caption!.isNotEmpty) 'caption': caption,
        'order': order,
      };

  final String assetId;
  final String? caption;
  final int order;

  List<Object?> get props => [assetId, caption, order];
}

