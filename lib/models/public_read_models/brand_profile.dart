import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';

/// Organization brand metadata powering public hero identity.
/// Stored in `brand_profiles` and mirrored to `public_brand_profiles`
/// when `published == true`.
class BrandProfile extends Record {
  const BrandProfile({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.metadata,
    required this.brandName,
    this.tagline,
    this.logoUrl,
    this.heroImageUrl,
    this.accentColor,
    this.kioskEnabled = false,
    this.published = false,
    this.publishedAt,
    this.socialMediaLinks,
  });

  BrandProfile.fromJson(super.json)
      : brandName = json['brandName'] ?? Missing.string,
        tagline = json['tagline'] is String ? json['tagline'] as String : null,
        logoUrl = json['logoUrl'] is String ? json['logoUrl'] as String : null,
        heroImageUrl =
            json['heroImageUrl'] is String ? json['heroImageUrl'] as String : null,
        accentColor =
            json['accentColor'] is String ? json['accentColor'] as String : null,
        kioskEnabled = json['kioskEnabled'] == true,
        published = json['published'] == true,
        publishedAt = json['publishedAt'] is String
            ? json['publishedAt'] as String
            : null,
        socialMediaLinks = _parseSocialLinks(json['socialMediaLinks']),
        super.fromJson();

  BrandProfile.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? brandName,
    String? tagline,
    String? logoUrl,
    String? heroImageUrl,
    String? accentColor,
    bool? kioskEnabled,
    bool? published,
    String? publishedAt,
    Map<String, String>? socialMediaLinks,
  })  : brandName = brandName ?? json?['brandName'] ?? Missing.string,
        tagline = tagline ?? _strIfString(json, 'tagline'),
        logoUrl = logoUrl ?? _strIfString(json, 'logoUrl'),
        heroImageUrl = heroImageUrl ?? _strIfString(json, 'heroImageUrl'),
        accentColor = accentColor ?? _strIfString(json, 'accentColor'),
        kioskEnabled = kioskEnabled ?? (json?['kioskEnabled'] == true),
        published = published ?? (json?['published'] == true),
        publishedAt = publishedAt ?? _strIfString(json, 'publishedAt'),
        socialMediaLinks = socialMediaLinks ?? _parseSocialLinks(json?['socialMediaLinks']),
        super.partial();

  final String brandName;
  final String? tagline;
  final String? logoUrl;
  final String? heroImageUrl;
  final String? accentColor; // e.g. #00AEEF
  final bool kioskEnabled;
  final bool published;
  final String? publishedAt; // ISO8601
  final Map<String, String>? socialMediaLinks;

  @override
  ModelType get modelType => ModelType.brandProfile;

  @override
  Map<String, dynamic> toJson() => {
        'brandName': brandName,
        if (tagline != null && tagline!.isNotEmpty) 'tagline': tagline,
        if (logoUrl != null && logoUrl!.isNotEmpty) 'logoUrl': logoUrl,
        if (heroImageUrl != null && heroImageUrl!.isNotEmpty)
          'heroImageUrl': heroImageUrl,
        if (accentColor != null && accentColor!.isNotEmpty)
          'accentColor': accentColor,
        'kioskEnabled': kioskEnabled,
        'published': published,
        if (publishedAt != null && publishedAt!.isNotEmpty)
          'publishedAt': publishedAt,
        if (socialMediaLinks != null && socialMediaLinks!.isNotEmpty)
          'socialMediaLinks': socialMediaLinks,
        ...super.toJson(),
      };

  @override
  BrandProfile copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    Map<String, dynamic>? metadata,
    String? brandName,
    String? tagline,
    String? logoUrl,
    String? heroImageUrl,
    String? accentColor,
    bool? kioskEnabled,
    bool? published,
    String? publishedAt,
    Map<String, String>? socialMediaLinks,
  }) =>
      BrandProfile(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        createdById: createdById ?? this.createdById,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedById: updatedById ?? this.updatedById,
        organizationId: organizationId ?? this.organizationId,
        metadata: metadata ?? this.metadata,
        brandName: brandName ?? this.brandName,
        tagline: tagline ?? this.tagline,
        logoUrl: logoUrl ?? this.logoUrl,
        heroImageUrl: heroImageUrl ?? this.heroImageUrl,
        accentColor: accentColor ?? this.accentColor,
        kioskEnabled: kioskEnabled ?? this.kioskEnabled,
        published: published ?? this.published,
        publishedAt: publishedAt ?? this.publishedAt,
        socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
      );

  @override
  List<Object?> get props => super.props + [
        brandName,
        tagline,
        logoUrl,
        heroImageUrl,
        accentColor,
        kioskEnabled,
        published,
        publishedAt,
        socialMediaLinks,
      ];

  static Map<String, String>? _parseSocialLinks(dynamic json) {
    if (json is Map) {
      final map = <String, String>{};
      json.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          map[key.toString()] = value;
        }
      });
      return map.isNotEmpty ? Map.unmodifiable(map) : null;
    }
    return null;
  }

  static String? _strIfString(Map<String, dynamic>? json, String key) {
    final v = json == null ? null : json[key];
    return v is String ? v : null;
  }
}
