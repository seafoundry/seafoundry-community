// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Public-facing media asset (image/video) with light metadata.
///
/// Stored in `media_assets` and mirrored to `public_media` when `published == true`.
class MediaAsset extends Record {
  const MediaAsset({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.metadata,
    required this.url,
    required this.assetType,
    this.width,
    this.height,
    this.durationSeconds,
    this.altText,
    this.attribution,
    this.tags = const <String>[],
    this.published = false,
    this.publishedAt,
  });

  MediaAsset.fromJson(super.json)
      : url = json['url'] ?? Missing.string,
        assetType = _typeFrom(json['assetType']) ?? MediaAssetType.image,
        width = _intOrNull(json['width']),
        height = _intOrNull(json['height']),
        durationSeconds = _intOrNull(json['durationSeconds']),
        altText = json['altText'] is String ? json['altText'] as String : null,
        attribution =
            json['attribution'] is String ? json['attribution'] as String : null,
        tags = _stringList(json['tags']),
        published = json['published'] == true,
        publishedAt = json['publishedAt'] is String
            ? json['publishedAt'] as String
            : null,
        super.fromJson();

  MediaAsset.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? url,
    MediaAssetType? assetType,
    int? width,
    int? height,
    int? durationSeconds,
    String? altText,
    String? attribution,
    List<String>? tags,
    bool? published,
    String? publishedAt,
  })  : url = url ?? json?['url'] ?? Missing.string,
        assetType = assetType ?? _typeFrom(json?['assetType']) ?? MediaAssetType.image,
        width = width ?? _intOrNull(json?['width']),
        height = height ?? _intOrNull(json?['height']),
        durationSeconds = durationSeconds ?? _intOrNull(json?['durationSeconds']),
        altText = altText ?? _strIfString(json, 'altText'),
        attribution = attribution ?? _strIfString(json, 'attribution'),
        tags = tags ?? _stringList(json?['tags']),
        published = published ?? (json?['published'] == true),
        publishedAt = publishedAt ?? _strIfString(json, 'publishedAt'),
        super.partial();

  final String url;
  final MediaAssetType assetType;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final String? altText;
  final String? attribution;
  final List<String> tags;
  final bool published;
  final String? publishedAt; // ISO8601

  @override
  ModelType get modelType => ModelType.mediaAsset;

  @override
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'assetType': assetType.name,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (altText != null && altText!.isNotEmpty) 'altText': altText,
      if (attribution != null && attribution!.isNotEmpty) 'attribution': attribution,
      if (tags.isNotEmpty) 'tags': tags,
      'published': published,
      if (publishedAt != null && publishedAt!.isNotEmpty) 'publishedAt': publishedAt,
      ...super.toJson(),
    };
  }

  @override
  MediaAsset copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    Map<String, dynamic>? metadata,
    String? url,
    MediaAssetType? assetType,
    int? width,
    int? height,
    int? durationSeconds,
    String? altText,
    String? attribution,
    List<String>? tags,
    bool? published,
    String? publishedAt,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      metadata: metadata ?? this.metadata,
      url: url ?? this.url,
      assetType: assetType ?? this.assetType,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      altText: altText ?? this.altText,
      attribution: attribution ?? this.attribution,
      tags: tags ?? this.tags,
      published: published ?? this.published,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  @override
  List<Object?> get props => super.props + [
        url,
        assetType,
        width,
        height,
        durationSeconds,
        altText,
        attribution,
        tags.join('|'),
        published,
        publishedAt,
      ];

  static int? _intOrNull(dynamic v) => v is int ? v : (v is num ? v.toInt() : null);
  static List<String> _stringList(dynamic v) =>
      v is List ? v.whereType<String>().toList(growable: false) : const <String>[];

  static MediaAssetType? _typeFrom(dynamic v) {
    if (v is String) {
      try {
        return MediaAssetType.values.byName(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
  static String? _strIfString(Map<String, dynamic>? json, String key) {
    final v = json == null ? null : json[key];
    return v is String ? v : null;
  }
}

enum MediaAssetType { image, video }
